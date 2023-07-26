use crate::error::Error;
use crate::models::{Term, TermRelated};
use crate::schema::{terms, terms_related};
use std::collections::HashMap;

use diesel::{Connection, ExpressionMethods, PgConnection, QueryDsl, RunQueryDsl};
use uuid::Uuid;

pub fn delete(id: Uuid, conn: &mut PgConnection) -> Result<usize, Error> {
    conn.transaction::<_, Error, _>(|conn| {
        diesel::delete(terms_related::dsl::terms_related)
            .filter(terms_related::dsl::term_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;
        diesel::delete(terms::dsl::terms.find(id))
            .execute(conn)
            .map_err(Error::from)
    })
}

pub fn insert(term: Term, related: Vec<Uuid>, conn: &mut PgConnection) -> Result<Uuid, Error> {
    conn.transaction::<_, Error, _>(|conn| {
        let id = diesel::insert_into(terms::dsl::terms)
            .values(term)
            .returning(terms::dsl::id)
            .get_result(conn)
            .map_err(Error::from)?;
        let bulk = related
            .into_iter()
            .map(|term| TermRelated::new(id, term))
            .collect::<Vec<_>>();
        diesel::insert_into(terms_related::dsl::terms_related)
            .values(bulk)
            .execute(conn)
            .map_err(Error::from)?;
        Ok(id)
    })
}

pub fn select_all(conn: &mut PgConnection) -> Result<Vec<Term>, Error> {
    terms::dsl::terms
        .order(terms::dsl::created_at.asc())
        .load(conn)
        .map_err(Error::from)
}

pub fn select_related(conn: &mut PgConnection) -> Result<Vec<TermRelated>, Error> {
    terms_related::dsl::terms_related
        .load(conn)
        .map_err(Error::from)
}

pub fn update(
    id: Uuid,
    name: String,
    related: Vec<Uuid>,
    conn: &mut PgConnection,
) -> Result<(), Error> {
    conn.transaction::<_, Error, _>(|conn| {
        diesel::update(terms::dsl::terms.find(id))
            .set(terms::dsl::name.eq(name))
            .execute(conn)
            .map_err(Error::from)?;
        diesel::delete(terms_related::dsl::terms_related)
            .filter(terms_related::dsl::term_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;
        let bulk = related
            .into_iter()
            .map(|term| TermRelated::new(id, term))
            .collect::<Vec<_>>();
        diesel::insert_into(terms_related::dsl::terms_related)
            .values(bulk)
            .execute(conn)
            .map_err(Error::from)?;
        Ok(())
    })
}

pub fn select_graph(conn: &mut PgConnection) -> Result<(Vec<String>, Vec<Vec<usize>>), Error> {
    // TODO: join
    let related = terms_related::dsl::terms_related.load::<TermRelated>(conn)?;
    let terms = select_all(conn)?;
    let hash = terms
        .iter()
        .enumerate()
        .map(|(index, term)| (term.id(), index))
        .collect::<HashMap<_, _>>();
    let result = related
        .iter()
        .map(|r| vec![hash[&r.term_id()], hash[&r.related_id()]])
        .collect::<Vec<_>>();
    let names = terms
        .iter()
        .map(|v| v.name().to_string())
        .collect::<Vec<_>>();
    Ok((names, result))
}
