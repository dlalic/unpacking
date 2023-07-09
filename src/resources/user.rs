use crate::db::users;
use crate::error::Error;
use crate::models::{enums::Role, User};
use crate::resources::auth::{AuthenticationStatus, Permission};
use crate::resources::validation::users::*;

use diesel::PgConnection;
use gotham_restful::*;
use openapi_type::OpenapiType;
use serde_derive::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Resource)]
#[resource(create, read, read_all, update, delete)]
pub struct Resource;

#[derive(Serialize, Deserialize, OpenapiType, Validate)]
pub struct CreateUser {
    #[validate(length(min = "MIN_NAME_LENGTH"))]
    pub name: String,
    pub role: Role,
    #[validate(length(min = "MIN_EMAIL_LENGTH"))]
    pub email: String,
    #[validate(length(min = "MIN_PASSWORD_LENGTH"))]
    pub password: String,
}

#[derive(Serialize, Deserialize, OpenapiType, Validate)]
pub struct UpdateUser {
    #[validate(length(min = "MIN_NAME_LENGTH"))]
    pub name: String,
    pub role: Role,
    #[validate(length(min = "MIN_EMAIL_LENGTH"))]
    pub email: String,
}

#[derive(Serialize, OpenapiType)]
struct UserResponse {
    id: Uuid,
    name: String,
    email: String,
    role: Role,
}

impl From<User> for UserResponse {
    fn from(user: User) -> Self {
        let (id, name, email, role, _, _, _) = user.dissolve();
        Self {
            id,
            name,
            email,
            role,
        }
    }
}

#[create]
fn create(
    auth: AuthenticationStatus,
    body: CreateUser,
    conn: &mut PgConnection,
) -> Result<Uuid, Error> {
    auth.ok().admin()?;
    body.validate()?;
    let user = User::new(body.name, body.email, body.role);
    let uuid = users::insert(user, &body.password, conn)?;
    Ok(uuid)
}

#[read]
fn read(
    auth: AuthenticationStatus,
    id: Uuid,
    conn: &mut PgConnection,
) -> Result<UserResponse, Error> {
    auth.ok().user(id)?;
    users::select(id, conn).map(UserResponse::from)
}

#[read_all]
fn read_all(
    auth: AuthenticationStatus,
    conn: &mut PgConnection,
) -> Result<Vec<UserResponse>, Error> {
    auth.ok().admin()?;
    let result = users::select_all(conn)?;
    Ok(result.into_iter().map(UserResponse::from).collect())
}

#[update]
fn update(
    auth: AuthenticationStatus,
    id: Uuid,
    body: UpdateUser,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    body.validate()?;
    users::update(id, body.name, body.email, body.role, conn).map(|_| NoContent::default())
}

#[delete]
fn delete(
    auth: AuthenticationStatus,
    id: Uuid,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    users::delete(id, conn).map(|_| NoContent::default())
}

#[cfg(test)]
mod tests {
    use super::*;
    use fake::{
        faker::internet::{en::FreeEmail, en::Password},
        faker::name::en::FirstName,
        Fake,
    };

    impl CreateUser {
        fn test_name(name: &str) -> Self {
            Self {
                name: name.to_string(),
                role: Role::User,
                email: FreeEmail().fake(),
                password: Password(std::ops::Range {
                    start: MIN_PASSWORD_LENGTH,
                    end: 256,
                })
                .fake(),
            }
        }

        fn test_password(password: &str) -> Self {
            Self {
                name: FirstName().fake(),
                role: Role::User,
                email: FreeEmail().fake(),
                password: password.to_string(),
            }
        }
    }

    impl UpdateUser {
        fn test_name(name: &str) -> Self {
            Self {
                name: name.to_string(),
                role: Role::User,
                email: FreeEmail().fake(),
            }
        }

        fn test_email(email: &str) -> Self {
            Self {
                name: FirstName().fake(),
                role: Role::User,
                email: email.to_string(),
            }
        }
    }

    #[test]
    fn update_short_name_validates() {
        let update = UpdateUser::test_name("Ο");
        assert!(update.validate().is_ok());
    }

    #[test]
    fn update_empty_name_does_not_validate() {
        let update = UpdateUser::test_name("");
        assert!(update.validate().is_err());
    }

    #[test]
    fn update_short_email_validates() {
        let update = UpdateUser::test_email("123456");
        assert!(update.validate().is_ok());
    }

    #[test]
    fn update_very_short_email_does_not_validate() {
        let update = UpdateUser::test_email("12345");
        assert!(update.validate().is_err());
    }

    #[test]
    fn create_short_name_validates() {
        let create = CreateUser::test_name("😱");
        assert!(create.validate().is_ok());
    }

    #[test]
    fn create_empty_name_does_not_validate() {
        let create = CreateUser::test_name("");
        assert!(create.validate().is_err());
    }

    #[test]
    fn create_short_password_validates() {
        let create = CreateUser::test_password("123456");
        assert!(create.validate().is_ok());
    }

    #[test]
    fn create_very_short_password_does_not_validate() {
        let create = CreateUser::test_password("12345");
        assert!(create.validate().is_err());
    }
}
