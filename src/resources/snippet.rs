use crate::db::snippets;
use crate::error::Error;
use crate::models::Snippet;
use crate::resources::auth::{AuthenticationStatus, Permission};

use crate::db::snippets::{count, SnippetWithRelated};
use crate::models::enums::Media;
use crate::resources::validation::snippets::MIN_TEXT_LENGTH;
use diesel::PgConnection;
use gotham_derive::{StateData, StaticResponseExtender};
use gotham_restful::gotham::hyper::Method;
use gotham_restful::*;
use openapi_type::OpenapiType;
use serde_derive::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

pub const PAGE_SIZE: i64 = 20;

#[derive(Resource)]
#[resource(create, read_all, search, update, delete)]
pub struct Resource;

#[derive(Deserialize, StateData, StaticResponseExtender, OpenapiType, Clone, Debug)]
pub struct SnippetQueryStringExtractor {
    term_id: Option<Uuid>,
    page: i64,
}

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

impl From<(Uuid, String)> for AuthorResponse {
    fn from(tuple: (Uuid, String)) -> Self {
        Self {
            id: tuple.0,
            name: tuple.1,
        }
    }
}

#[derive(Serialize, OpenapiType)]
struct SnippetTermResponse {
    pub id: Uuid,
    pub name: String,
}

impl From<(Uuid, String)> for SnippetTermResponse {
    fn from(tuple: (Uuid, String)) -> Self {
        Self {
            id: tuple.0,
            name: tuple.1,
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

#[derive(Serialize, OpenapiType)]
struct SnippetSearchResponse {
    pub pages: i64,
    pub snippets: Vec<SnippetResponse>,
}

impl From<SnippetWithRelated> for SnippetResponse {
    fn from(snippet: SnippetWithRelated) -> Self {
        Self {
            id: snippet.id,
            text: snippet.text,
            media: snippet.media,
            link: snippet.link,
            terms: snippet
                .terms
                .into_iter()
                .map(SnippetTermResponse::from)
                .collect(),
            authors: snippet
                .authors
                .into_iter()
                .map(AuthorResponse::from)
                .collect(),
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
    let result = load_snippets(None, None, None, conn)?;
    Ok(result)
}

fn load_snippets(
    term_id: Option<Uuid>,
    limit: Option<i64>,
    offset: Option<i64>,
    conn: &mut PgConnection,
) -> Result<Vec<SnippetResponse>, Error> {
    let snippets = snippets::search(term_id, limit, offset, conn)?;
    let result = snippets.into_iter().map(SnippetResponse::from).collect();
    Ok(result)
}

#[search]
fn search(
    auth: AuthenticationStatus,
    query: SnippetQueryStringExtractor,
    conn: &mut PgConnection,
) -> Result<SnippetSearchResponse, Error> {
    auth.ok()?;
    let limit = PAGE_SIZE;
    let offset = (query.page - 1) * PAGE_SIZE;
    let pages = count(query.term_id, PAGE_SIZE, conn)?;
    let snippets = load_snippets(query.term_id, Some(limit), Some(offset), conn)?;
    let result = SnippetSearchResponse { pages, snippets };
    Ok(result)
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

#[derive(Resource)]
#[resource(stats)]
pub struct StatsResource;

#[derive(Serialize, OpenapiType)]
struct StatsResponse {
    pub media: Vec<MediaStatsResponse>,
}

#[derive(Serialize, OpenapiType)]
struct MediaStatsResponse {
    pub media: Media,
    pub count: i64,
}

#[endpoint(uri = "stats", method = "Method::GET", params = false, body = false)]
fn stats(auth: AuthenticationStatus, conn: &mut PgConnection) -> Result<StatsResponse, Error> {
    auth.ok()?;
    let media_stats = snippets::select_media_stats(conn)?;
    let media = media_stats
        .into_iter()
        .map(|(media, count)| MediaStatsResponse { media, count })
        .collect();
    let result = StatsResponse { media };
    Ok(result)
}
