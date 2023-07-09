use crate::db::terms;
use crate::error::Error;
use crate::models::Term;
use crate::resources::auth::{AuthenticationStatus, Permission};
use crate::resources::validation::terms::MIN_NAME_LENGTH;

use diesel::PgConnection;
use gotham_restful::gotham::hyper::Method;
use gotham_restful::*;
use openapi_type::OpenapiType;
use serde_derive::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Resource)]
#[resource(create, read_all, delete, update)]
pub struct Resource;

#[derive(Deserialize, OpenapiType, Validate)]
struct CreateTerm {
    #[validate(length(min = "MIN_NAME_LENGTH"))]
    name: String,
    related: Vec<Uuid>,
}

#[derive(Deserialize, OpenapiType, Validate)]
struct UpdateTerm {
    #[validate(length(min = "MIN_NAME_LENGTH"))]
    name: String,
    related: Vec<Uuid>,
}

#[derive(Debug, Queryable, Serialize, OpenapiType)]
pub struct TermResponse {
    pub id: Uuid,
    pub name: String,
    pub related: Vec<Uuid>,
}

impl From<(Term, Vec<Uuid>)> for TermResponse {
    fn from(input: (Term, Vec<Uuid>)) -> Self {
        let term = input.0;
        let related = input.1;
        let (id, name, _, _) = term.dissolve();
        TermResponse { id, name, related }
    }
}

#[create]
fn create(
    auth: AuthenticationStatus,
    body: CreateTerm,
    conn: &mut PgConnection,
) -> Result<Uuid, Error> {
    auth.ok().admin()?;
    body.validate()?;
    let term = Term::new(body.name);
    terms::insert(term, body.related, conn)
}

#[read_all]
fn read_all(
    auth: AuthenticationStatus,
    conn: &mut PgConnection,
) -> Result<Vec<TermResponse>, Error> {
    auth.ok()?;
    let terms = terms::select_all(conn)?;
    let related = terms::select_related(conn)?;
    let results = terms
        .into_iter()
        .map(|term| {
            let result = related
                .iter()
                .filter_map(|r| match term.id() == r.term_id() {
                    true => Some(*r.related_id()),
                    false => None,
                })
                .collect();
            TermResponse::from((term, result))
        })
        .collect();
    Ok(results)
}

#[update]
fn update(
    auth: AuthenticationStatus,
    id: Uuid,
    body: UpdateTerm,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    body.validate()?;
    terms::update(id, body.name, body.related, conn).map(|_| NoContent::default())
}

#[delete]
fn delete(
    auth: AuthenticationStatus,
    id: Uuid,
    conn: &mut PgConnection,
) -> Result<NoContent, Error> {
    auth.ok().admin()?;
    terms::delete(id, conn).map(|_| NoContent::default())
}

#[derive(Resource)]
#[resource(read_graph)]
pub struct GraphResource;

#[derive(Serialize, OpenapiType)]
struct TermGraphResponse {
    terms: Vec<String>,
    nodes: Vec<Vec<usize>>,
}

#[endpoint(
    uri = "read_graph",
    method = "Method::GET",
    params = false,
    body = false
)]
fn read_graph(
    auth: AuthenticationStatus,
    conn: &mut PgConnection,
) -> Result<TermGraphResponse, Error> {
    auth.ok()?;
    let graph = terms::select_graph(conn)?;
    let result = TermGraphResponse {
        terms: graph.0,
        nodes: graph.1,
    };
    Ok(result)
}
