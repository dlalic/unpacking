use crate::error::Error::{BadRequest, InternalServerError, Unauthorized};

use argon2::password_hash::Error::Password;
use diesel::result::DatabaseErrorKind;
use diesel::result::Error::{DatabaseError, NotFound};
use diesel_migrations::MigrationError;
use gotham_restful::{AuthError, ResourceError};
use log::error;
use serde::ser::StdError;
use validator::{ValidationError, ValidationErrors};

#[derive(Debug, PartialEq, ResourceError)]
pub enum Error {
    #[status(BAD_REQUEST)]
    #[display("{0}")]
    BadRequest(String),
    #[status(UNAUTHORIZED)]
    #[display("Unauthorized")]
    Unauthorized,
    #[status(FORBIDDEN)]
    #[display("Forbidden")]
    Forbidden,
    #[status(INTERNAL_SERVER_ERROR)]
    #[display("Internal Server Error")]
    InternalServerError,
}

impl From<diesel::result::Error> for Error {
    fn from(error: diesel::result::Error) -> Self {
        error!("Diesel: {error:?}");
        match error {
            NotFound => BadRequest("Not found".to_string()),
            DatabaseError(DatabaseErrorKind::UniqueViolation, ..) => {
                BadRequest("Already exists".to_string())
            }
            _ => InternalServerError,
        }
    }
}

impl From<argon2::password_hash::Error> for Error {
    fn from(error: argon2::password_hash::Error) -> Self {
        error!("Argon: {error:?}");
        match error {
            Password => BadRequest("Not found".to_string()),
            _ => InternalServerError,
        }
    }
}

impl From<jsonwebtoken::errors::Error> for Error {
    fn from(error: jsonwebtoken::errors::Error) -> Self {
        error!("JWT: {error:?}");
        InternalServerError
    }
}

impl From<AuthError> for Error {
    fn from(error: AuthError) -> Self {
        error!("Auth: {error:?}");
        Unauthorized
    }
}

impl From<Error> for ValidationError {
    fn from(error: Error) -> Self {
        error!("Validation: {error:?}");
        ValidationError::new("invalid")
    }
}

impl From<ValidationErrors> for Error {
    fn from(error: ValidationErrors) -> Self {
        error!("Validation: {error:?}");
        BadRequest(error.to_string())
    }
}

impl From<MigrationError> for Error {
    fn from(error: MigrationError) -> Self {
        error!("Migrations: {error:?}");
        InternalServerError
    }
}

impl From<Box<dyn StdError + Send + Sync>> for Error {
    fn from(error: Box<dyn StdError + Send + Sync>) -> Self {
        error!("Migrations: {error:?}");
        InternalServerError
    }
}
