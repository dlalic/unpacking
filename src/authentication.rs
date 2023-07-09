use crate::config::hasher_salt;
use crate::error::Error;

use argon2::password_hash::SaltString;
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier};

pub fn hash_password(password: &str) -> Result<String, Error> {
    let argon2 = Argon2::default();
    let salt = SaltString::from_b64(&hasher_salt())?;
    let hash = argon2
        .hash_password(password.as_ref(), &salt)
        .map_err(Error::from)?;
    Ok(hash.to_string())
}

pub fn verify_password(password: &str, hash: &str) -> Result<(), Error> {
    let argon2 = Argon2::default();
    let parsed_hash = PasswordHash::new(hash)?;
    argon2
        .verify_password(password.as_ref(), &parsed_hash)
        .map_err(Error::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::load_and_validate_env_vars;
    use crate::resources::validation::users::MIN_PASSWORD_LENGTH;
    use fake::faker::internet::en::Password;
    use fake::Fake;

    #[test]
    fn test_verify_random_password() {
        load_and_validate_env_vars();

        let password: String = Password(std::ops::Range {
            start: MIN_PASSWORD_LENGTH,
            end: 256,
        })
        .fake();
        let hash = hash_password(&password).expect("Can not hash password");
        verify_password(&password, &hash).expect("Can not verify password");
    }
}
