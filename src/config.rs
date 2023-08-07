use dotenv::dotenv;
use std::collections::HashMap;
use std::env;

pub fn load_and_validate_env_vars() {
    dotenv().ok();
    let result: HashMap<String, String> = dotenv::vars().collect();
    assert!(result.contains_key("DATABASE_URL"));
    assert!(result.contains_key("APP_URL"));
    assert!(result.contains_key("JWT_SECRET"));
    assert!(result.contains_key("HASHER_SALT"));
    assert!(result.contains_key("ADMIN_EMAIL"));
    assert!(result.contains_key("ADMIN_PASSWORD"));
}

pub fn app_address() -> String {
    let host = env::var("HOST").unwrap_or_else(|_| "localhost".to_string());
    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    format!("{host}:{port}")
}

pub fn database_url() -> String {
    env::var("DATABASE_URL").expect("DATABASE_URL must be set")
}

pub fn app_url() -> String {
    env::var("APP_URL").expect("APP_URL must be set")
}

pub fn jwt_secret() -> String {
    env::var("JWT_SECRET").expect("JWT_SECRET must be set")
}

pub fn hasher_salt() -> String {
    env::var("HASHER_SALT").expect("HASHER_SALT must be set")
}

pub fn admin_email() -> String {
    env::var("ADMIN_EMAIL").expect("ADMIN_EMAIL must be set")
}

pub fn admin_password() -> String {
    env::var("ADMIN_PASSWORD").expect("ADMIN_PASSWORD must be set")
}

pub fn db_pool_size() -> u32 {
    let size = env::var("DB_POOL_SIZE").unwrap_or_else(|_| "10".to_string());
    size.parse::<u32>().unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_address_defaults() {
        temp_env::with_vars_unset(vec!["HOST", "PORT"], || {
            assert_eq!(app_address(), "localhost:3000")
        });
    }

    #[test]
    fn app_address_from_env() {
        temp_env::with_vars(
            vec![("HOST", Some("piggy.bank")), ("PORT", Some("1234"))],
            || assert_eq!(app_address(), "piggy.bank:1234"),
        );
    }
}
