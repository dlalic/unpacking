use crate::config::jwt_secret;
use crate::db::users::authenticate;
use crate::error::Error;
use crate::models::enums::Role;
use crate::resources::validation::users::*;

use chrono::Utc;
use diesel::PgConnection;
use gotham_restful::*;
use jsonwebtoken::{encode, EncodingKey, Header};
use openapi_type::OpenapiType;
use serde_derive::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Resource)]
#[resource(auth)]
pub struct Resource;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AuthData {
    sub: Uuid,
    role: Role,
    exp: u64,
}

impl AuthData {
    fn is_admin(&self) -> Result<Uuid, Error> {
        match self.role {
            Role::Admin => Ok(self.sub),
            Role::User => Err(Error::Forbidden),
        }
    }

    fn user_ok(&self, user_id: Uuid) -> Result<Uuid, Error> {
        if self.sub == user_id {
            Ok(self.sub)
        } else {
            Err(Error::Forbidden)
        }
    }
}

pub trait Permission {
    fn admin(self) -> Result<Uuid, Error>;
    fn user(self, user_id: Uuid) -> Result<Uuid, Error>;
}

impl Permission for Result<AuthData, AuthError> {
    fn admin(self) -> Result<Uuid, Error> {
        match self {
            Ok(auth) => auth.is_admin(),
            Err(err) => Err(err.into()),
        }
    }

    fn user(self, user_id: Uuid) -> Result<Uuid, Error> {
        match self {
            Ok(auth) => auth.is_admin().or_else(|_| auth.user_ok(user_id)),
            Err(err) => Err(err.into()),
        }
    }
}

pub(crate) type AuthenticationStatus = AuthStatus<AuthData>;

#[derive(Deserialize, Serialize, OpenapiType, Validate)]
struct CreateToken {
    #[validate(length(min = "MIN_EMAIL_LENGTH"))]
    pub email: String,
    #[validate(length(min = "MIN_PASSWORD_LENGTH"))]
    password: String,
}

#[derive(Debug, Deserialize, Serialize, OpenapiType)]
pub struct TokenResponse {
    id: Uuid,
    token: String,
    role: Role,
}

#[create]
fn auth(body: CreateToken, conn: &mut PgConnection) -> Result<TokenResponse, Error> {
    body.validate()?;
    let (uuid, role) = authenticate(&body.email, &body.password, conn)?;
    let token = generate_jwt(uuid, role)?;
    let response = TokenResponse {
        id: uuid,
        token,
        role,
    };
    Ok(response)
}

pub fn generate_jwt(uuid: Uuid, role: Role) -> Result<String, Error> {
    // https://datatracker.ietf.org/doc/html/rfc7519#section-4.1
    let auth_data = AuthData {
        sub: uuid,
        role,
        exp: (Utc::now().timestamp() + 30 * 60) as u64,
    };
    encode(
        &Header::default(),
        &auth_data,
        &EncodingKey::from_secret(jwt_secret().as_bytes()),
    )
    .map_err(Error::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::migrations::run_migrations_and_test_transactions;
    use crate::db::users::insert;
    use crate::models::{Password, User};
    use crate::router::router;
    use fake::{Fake, Faker};
    use gotham::mime::APPLICATION_JSON;
    use gotham::plain::test::AsyncTestServer;
    use gotham_restful::gotham::hyper::StatusCode;
    use jsonwebtoken::{decode, DecodingKey, Validation};
    use tokio::sync::oneshot;

    impl AuthData {
        fn test(role: Role) -> Self {
            Self {
                sub: Uuid::new_v4(),
                role,
                exp: 0,
            }
        }
    }

    #[test]
    fn is_admin() {
        let auth = AuthData::test(Role::Admin);
        assert!(auth.is_admin().is_ok());

        let auth = AuthData::test(Role::User);
        assert!(auth.is_admin().is_err());
    }

    #[test]
    fn user_ok() {
        let auth = AuthData::test(Role::Admin);
        assert!(auth.user_ok(auth.sub).is_ok());
        assert!(auth.user_ok(Uuid::new_v4()).is_err());

        let auth = AuthData::test(Role::User);
        assert!(auth.user_ok(auth.sub).is_ok());
        assert!(auth.user_ok(Uuid::new_v4()).is_err());
    }

    #[test]
    fn admin_permission() {
        let auth = AuthData::test(Role::Admin);
        let sub = auth.sub;
        assert_eq!(Ok(auth).admin().unwrap(), sub);

        let auth = AuthData::test(Role::User);
        assert!(Ok(auth).admin().is_err());
    }

    #[test]
    fn user_permission() {
        let auth = AuthData::test(Role::Admin);
        let sub = auth.sub;
        assert_eq!(Ok(auth).user(Uuid::new_v4()).unwrap(), sub);

        let auth = AuthData::test(Role::User);
        let sub = auth.sub;
        assert_eq!(Ok(auth).user(sub).unwrap(), sub);

        let auth = AuthData::test(Role::User);
        assert!(Ok(auth).user(Uuid::new_v4()).is_err());
    }

    #[tokio::test]
    async fn valid_request() {
        let user = User::fake(Role::User);
        let password: Password = Faker.fake();
        let (tx, rx) = oneshot::channel();
        let user_email = user.email().clone();
        let user_role = *user.role();
        let user_password = password.password().clone();
        let repo = run_migrations_and_test_transactions(move |conn| {
            let user_id = insert(user, password.password(), conn).expect("Can not create");
            tx.send(user_id).expect("Can not send");
        })
        .await;
        let user_id = rx.await.expect("Can not find id");
        let test_server = AsyncTestServer::new(router(repo))
            .await
            .expect("Can not start test server");
        let request = CreateToken {
            email: user_email,
            password: user_password,
        };
        let body = serde_json::to_string(&request).expect("Can not encode JSON");
        let response = test_server
            .client()
            .post("http://localhost:3000/api/v1/auth")
            .body(body)
            .mime(APPLICATION_JSON)
            .perform()
            .await
            .expect("Can not send a request");
        assert_eq!(response.status(), StatusCode::OK);
        let body = response
            .read_body()
            .await
            .expect("Can not get response body");
        let response: TokenResponse =
            serde_json::from_slice(&body).expect("Can not to convert bytes to string");
        let mut validation = Validation::default();
        validation.sub = Some(user_id.to_string());
        let result = decode::<AuthData>(
            &response.token,
            &DecodingKey::from_secret(jwt_secret().as_bytes()),
            &validation,
        )
        .expect("Can not decode JWT");
        assert_eq!(result.claims.sub, user_id);
        assert_eq!(result.claims.role, user_role);
    }
}
