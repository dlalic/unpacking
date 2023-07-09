use crate::db::authors;
use crate::error::Error;
use crate::models::Author;
use crate::resources::auth::AuthenticationStatus;

use diesel::PgConnection;
use gotham_restful::*;
use openapi_type::OpenapiType;
use serde_derive::Serialize;
use uuid::Uuid;

#[derive(Resource)]
#[resource(read_all)]
pub struct Resource;

#[derive(Debug, Queryable, Serialize, OpenapiType)]
pub struct AuthorResponse {
    pub id: Uuid,
    pub name: String,
}

impl From<Author> for AuthorResponse {
    fn from(author: Author) -> Self {
        let (id, name, _, _) = author.dissolve();
        AuthorResponse { id, name }
    }
}

#[read_all]
fn read_all(
    auth: AuthenticationStatus,
    conn: &mut PgConnection,
) -> Result<Vec<AuthorResponse>, Error> {
    auth.ok()?;
    let authors = authors::select_all(conn)?;
    let results = authors.into_iter().map(AuthorResponse::from).collect();
    Ok(results)
}
