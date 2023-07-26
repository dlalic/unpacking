use crate::authentication::{hash_password, verify_password};
use crate::error::Error;
use crate::models::{enums::Role, Password, User};
use crate::schema::{passwords, users};

use crate::config::{admin_email, admin_password};
use diesel::{
    BoolExpressionMethods, Connection, ExpressionMethods, PgConnection, QueryDsl, RunQueryDsl,
};
use uuid::Uuid;

pub fn create_admin_account_if_not_present(conn: &mut PgConnection) -> Result<(), Error> {
    let present = users::dsl::users
        .filter(users::dsl::email.eq(admin_email()))
        .first::<User>(conn)
        .map_err(Error::from);
    if present.is_ok() {
        return Ok(());
    }
    let user = User::new("Admin".to_string(), admin_email(), Role::Admin);
    insert(user, &admin_password(), conn).map(|_| ())
}

pub fn authenticate(
    email: &str,
    password: &str,
    conn: &mut PgConnection,
) -> Result<(Uuid, Role), Error> {
    let (user_id, role) = users::dsl::users
        .filter(
            users::dsl::is_deleted
                .eq(false)
                .and(users::dsl::email.eq(email)),
        )
        .select((users::dsl::id, users::dsl::role))
        .first::<(Uuid, Role)>(conn)
        .map_err(Error::from)?;
    let password_hash = passwords::dsl::passwords
        .filter(passwords::dsl::user_id.eq(user_id))
        .select(passwords::dsl::password)
        .first::<String>(conn)
        .map_err(Error::from)?;
    verify_password(password, &password_hash)?;
    Ok((user_id, role))
}

pub fn delete(id: Uuid, conn: &mut PgConnection) -> Result<usize, Error> {
    diesel::update(users::dsl::users.find(id))
        .set((users::dsl::is_deleted.eq(true),))
        .execute(conn)
        .map_err(Error::from)
}

pub fn insert(user: User, password: &str, conn: &mut PgConnection) -> Result<Uuid, Error> {
    conn.transaction::<_, Error, _>(|conn| {
        let uuid = diesel::insert_into(users::dsl::users)
            .values(user)
            .returning(users::dsl::id)
            .get_result::<Uuid>(conn)
            .map_err(Error::from)?;
        let password_hash = hash_password(password)?;
        let password = Password::new(uuid, password_hash);
        diesel::insert_into(passwords::dsl::passwords)
            .values(password)
            .execute(conn)
            .map_err(Error::from)?;
        Ok(uuid)
    })
}

pub fn select(id: Uuid, conn: &mut PgConnection) -> Result<User, Error> {
    users::dsl::users
        .filter(users::dsl::is_deleted.eq(false))
        .find(id)
        .get_result(conn)
        .map_err(Error::from)
}

pub fn select_all(conn: &mut PgConnection) -> Result<Vec<User>, Error> {
    users::dsl::users
        .filter(users::dsl::is_deleted.eq(false))
        .order(users::dsl::name)
        .load(conn)
        .map_err(Error::from)
}

pub fn update(
    id: Uuid,
    name: String,
    email: String,
    role: Role,
    conn: &mut PgConnection,
) -> Result<usize, Error> {
    diesel::update(users::dsl::users.find(id))
        .set((
            users::dsl::name.eq(name),
            users::dsl::email.eq(email),
            users::dsl::role.eq(role),
        ))
        .execute(conn)
        .map_err(Error::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::migrations::run_migrations_and_test_transactions;
    use fake::{Fake, Faker};

    fn verify_user_count(conn: &mut PgConnection, count: usize) {
        let result = select_all(conn).expect("Can not select all users");
        assert_eq!(result.len(), count);
    }

    #[tokio::test]
    async fn create_admin_account_skips_when_present() {
        run_migrations_and_test_transactions(|conn| {
            diesel::delete(users::dsl::users)
                .execute(conn)
                .expect("Can not delete");
            verify_user_count(conn, 0);
            create_admin_account_if_not_present(conn).expect("Can not create admin");
            verify_user_count(conn, 1);
            create_admin_account_if_not_present(conn).expect("Can not create admin");
            verify_user_count(conn, 1);
        })
        .await;
    }

    #[tokio::test]
    async fn authenticate_admin() {
        run_migrations_and_test_transactions(|conn| {
            create_admin_account_if_not_present(conn).expect("Can not create admin");
            authenticate(&admin_email(), &admin_password(), conn)
                .expect("Can not authenticate admin");
        })
        .await;
    }

    #[tokio::test]
    async fn password_is_not_stored_as_plain_text() {
        run_migrations_and_test_transactions(|conn| {
            let user: User = Faker.fake();
            let password: Password = Faker.fake();
            let id = insert(user, password.password(), conn).expect("Can not create");
            let passwords: Vec<Password> = passwords::dsl::passwords
                .filter(passwords::dsl::user_id.eq(id))
                .load(conn)
                .expect("Can not select");
            assert_eq!(passwords.len(), 1);
            for found in passwords {
                assert_ne!(found.password(), password.password());
                assert!(found.password().starts_with("$argon2id$"))
            }
        })
        .await;
    }

    #[tokio::test]
    async fn soft_deletion() {
        run_migrations_and_test_transactions(|conn| {
            let user = User::fake(Role::User);
            let password: Password = Faker.fake();

            let id = insert(user, password.password(), conn).expect("Can not create");

            let all = select_all(conn).expect("Can not select all");
            let existing = all.iter().find(|v| *v.id() == id);
            assert!(existing.is_some());

            let existing = select(id, conn);
            assert!(existing.is_ok());

            delete(id, conn).expect("Can not delete");

            let all = select_all(conn).expect("Can not select all");
            let existing = all.iter().find(|v| *v.id() == id);
            assert!(existing.is_none());

            let existing = select(id, conn);
            assert!(existing.is_err());
        })
        .await;
    }

    #[tokio::test]
    async fn username_is_unique() {
        run_migrations_and_test_transactions(|conn| {
            let user1 = User::new("Foo".to_string(), "foo@foo.com".to_string(), Role::User);
            let password: Password = Faker.fake();
            insert(user1, password.password(), conn).expect("Can not create");

            let user2 = User::new("Bar".to_string(), "foo@foo.com".to_string(), Role::Admin);
            let result = insert(user2, password.password(), conn);
            assert!(matches!(result, Err(Error::BadRequest(t)) if t == "Already exists"));
        })
        .await;
    }
}
