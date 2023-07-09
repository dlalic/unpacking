use crate::db::snippets;
use crate::error::Error;
use crate::models::Snippet;
use crate::resources::auth::{AuthenticationStatus, Permission};

use crate::models::enums::Media;
use crate::resources::validation::snippets::MIN_TEXT_LENGTH;
use diesel::PgConnection;
use gotham_restful::*;
use openapi_type::OpenapiType;
use serde_derive::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Resource)]
#[resource(create, read_all, update, delete)]
pub struct Resource;

#[derive(Serialize, Deserialize, OpenapiType, Validate)]
pub struct CreateSnippet {
    #[validate(length(min = "MIN_TEXT_LENGTH"))]
    pub text: String,
    pub media: Media,
    pub link: Option<String>,
    pub existing_authors: Vec<Uuid>,
    pub new_authors: Vec<String>,
    pub terms: Vec<Uuid>,
}

#[derive(Serialize, Deserialize, OpenapiType, Validate)]
pub struct UpdateSnippet {
    #[validate(length(min = "MIN_TEXT_LENGTH"))]
    pub text: String,
    pub media: Media,
    pub link: Option<String>,
    pub existing_authors: Vec<Uuid>,
    pub new_authors: Vec<String>,
    pub terms: Vec<Uuid>,
}

#[derive(Serialize, OpenapiType)]
struct AuthorResponse {
    pub id: Uuid,
    pub name: String,
}

impl From<&(Uuid, String)> for AuthorResponse {
    fn from(tuple: &(Uuid, String)) -> Self {
        Self {
            id: tuple.0,
            name: tuple.1.to_owned(),
        }
    }
}

#[derive(Serialize, OpenapiType)]
struct SnippetTermResponse {
    pub id: Uuid,
    pub name: String,
}

impl From<&(Uuid, String)> for SnippetTermResponse {
    fn from(tuple: &(Uuid, String)) -> Self {
        Self {
            id: tuple.0,
            name: tuple.1.to_owned(),
        }
    }
}

#[derive(Serialize, OpenapiType)]
struct SnippetResponse {
    pub id: Uuid,
    pub text: String,
    pub media: Media,
    pub link: Option<String>,
    pub authors: Vec<AuthorResponse>,
    pub terms: Vec<SnippetTermResponse>,
}

impl From<(Snippet, Vec<SnippetTermResponse>, Vec<AuthorResponse>)> for SnippetResponse {
    fn from(input: (Snippet, Vec<SnippetTermResponse>, Vec<AuthorResponse>)) -> Self {
        let snippet = input.0;
        let terms = input.1;
        let authors = input.2;
        let (id, text, media, link, _, _) = snippet.dissolve();
        Self {
            id,
            text,
            media,
            link,
            terms,
            authors,
        }
    }
}

#[create]
fn create(
    auth: AuthenticationStatus,
    body: CreateSnippet,
    conn: &mut PgConnection,
) -> Result<Uuid, Error> {
    auth.ok().admin()?;
    body.validate()?;
    let snippet = Snippet::new(body.text, body.media, body.link);
    let uuid = snippets::insert(
        snippet,
        body.terms,
        body.existing_authors,
        body.new_authors,
        conn,
    )?;
    Ok(uuid)
}

#[read_all]
fn read_all(
    auth: AuthenticationStatus,
    conn: &mut PgConnection,
) -> Result<Vec<SnippetResponse>, Error> {
    auth.ok()?;
    let snippets = snippets::select_all(conn)?;
    let snippet_terms = snippets::select_terms(conn)?;
    let snippet_authors = snippets::select_authors(conn)?;
    let results = snippets
        .into_iter()
        .map(|snippet| {
            let terms = snippet_terms
                .get(snippet.id())
                .into_iter()
                .flatten()
                .map(|v| SnippetTermResponse::from(v))
                .collect();
            let authors = snippet_authors
                .get(snippet.id())
                .into_iter()
                .flatten()
                .map(|v| AuthorResponse::from(v))
                .collect();
            SnippetResponse::from((snippet, terms, authors))
        })
        .collect();
    Ok(results)
}

#[update]
fn update(
    auth: AuthenticationStatus,
    id: Uuid,
    body: UpdateSnippet,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    body.validate()?;
    snippets::update(
        id,
        body.text,
        body.media,
        body.link,
        body.terms,
        body.existing_authors,
        body.new_authors,
        conn,
    )
    .map(|_| NoContent::default())
}

#[delete]
fn delete(
    auth: AuthenticationStatus,
    id: Uuid,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    snippets::delete(id, conn).map(|_| NoContent::default())
}
