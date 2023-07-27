use crate::error::Error;
use crate::models::{AuthorSnippet, Snippet, TermSnippet};
use crate::schema::{authors, authors_snippets, snippets, terms, terms_snippets};
use std::collections::HashMap;

use crate::models::enums::Media;
use diesel::{Connection, ExpressionMethods, PgConnection, QueryDsl, RunQueryDsl};
use uuid::Uuid;

pub fn delete(id: Uuid, conn: &mut PgConnection) -> Result<usize, Error> {
    conn.transaction::<_, Error, _>(|conn| {
        diesel::delete(authors_snippets::dsl::authors_snippets)
            .filter(authors_snippets::dsl::snippet_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;
        diesel::delete(terms_snippets::dsl::terms_snippets)
            .filter(terms_snippets::dsl::snippet_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;
        diesel::delete(snippets::dsl::snippets.find(id))
            .execute(conn)
            .map_err(Error::from)
    })
}

pub fn insert(
    snippet: Snippet,
    terms: Vec<Uuid>,
    existing_authors: Vec<Uuid>,
    new_authors: Vec<String>,
    conn: &mut PgConnection,
) -> Result<Uuid, Error> {
    conn.transaction::<_, Error, _>(|conn| {
        let id = diesel::insert_into(snippets::dsl::snippets)
            .values(snippet)
            .returning(snippets::dsl::id)
            .get_result(conn)
            .map_err(Error::from)?;

        let bulk_terms = terms
            .into_iter()
            .map(|term| TermSnippet::new(term, id))
            .collect::<Vec<_>>();
        diesel::insert_into(terms_snippets::dsl::terms_snippets)
            .values(bulk_terms)
            .execute(conn)
            .map_err(Error::from)?;

        let bulk_known_authors = existing_authors
            .into_iter()
            .map(|author| AuthorSnippet::new(author, id))
            .collect::<Vec<_>>();
        diesel::insert_into(authors_snippets::dsl::authors_snippets)
            .values(bulk_known_authors)
            .execute(conn)
            .map_err(Error::from)?;

        let non_empty = new_authors.iter().filter(|v| !v.is_empty()).count();
        if non_empty > 0 {
            let uuids = crate::db::authors::insert(new_authors, conn)?;
            let bulk_new_authors = uuids
                .into_iter()
                .map(|author| AuthorSnippet::new(author, id))
                .collect::<Vec<_>>();
            diesel::insert_into(authors_snippets::dsl::authors_snippets)
                .values(bulk_new_authors)
                .execute(conn)
                .map_err(Error::from)?;
        }
        Ok(id)
    })
}

pub fn select_all(conn: &mut PgConnection) -> Result<Vec<Snippet>, Error> {
    snippets::dsl::snippets
        .order(snippets::dsl::created_at.asc())
        .load(conn)
        .map_err(Error::from)
}

pub fn select_terms(conn: &mut PgConnection) -> Result<HashMap<Uuid, Vec<(Uuid, String)>>, Error> {
    #[derive(Debug, Queryable)]
    struct SnippetTerm {
        pub snippet_id: Uuid,
        pub term_id: Uuid,
        pub name: String,
    }
    let snippet_terms = terms::dsl::terms
        .inner_join(terms_snippets::dsl::terms_snippets)
        .select((
            terms_snippets::dsl::snippet_id,
            terms::dsl::id,
            terms::dsl::name,
        ))
        .load::<SnippetTerm>(conn)
        .map_err(Error::from)?;
    let result: HashMap<Uuid, Vec<(Uuid, String)>> =
        snippet_terms
            .into_iter()
            .fold(HashMap::new(), |mut hmap, v| {
                hmap.entry(v.snippet_id)
                    .or_insert(Vec::new())
                    .push((v.term_id, v.name));
                hmap
            });
    Ok(result)
}

pub fn select_authors(
    conn: &mut PgConnection,
) -> Result<HashMap<Uuid, Vec<(Uuid, String)>>, Error> {
    #[derive(Debug, Queryable)]
    struct SnippetAuthor {
        pub snippet_id: Uuid,
        pub author_id: Uuid,
        pub name: String,
    }
    let snippet_authors = authors::dsl::authors
        .inner_join(authors_snippets::dsl::authors_snippets)
        .select((
            authors_snippets::dsl::snippet_id,
            authors::dsl::id,
            authors::dsl::name,
        ))
        .load::<SnippetAuthor>(conn)
        .map_err(Error::from)?;
    let result: HashMap<Uuid, Vec<(Uuid, String)>> =
        snippet_authors
            .into_iter()
            .fold(HashMap::new(), |mut hmap, v| {
                hmap.entry(v.snippet_id)
                    .or_insert(Vec::new())
                    .push((v.author_id, v.name));
                hmap
            });
    Ok(result)
}

#[allow(clippy::too_many_arguments)]
pub fn update(
    id: Uuid,
    text: String,
    media: Media,
    link: Option<String>,
    terms: Vec<Uuid>,
    existing_authors: Vec<Uuid>,
    new_authors: Vec<String>,
    conn: &mut PgConnection,
) -> Result<(), Error> {
    conn.transaction::<_, Error, _>(|conn| {
        diesel::update(snippets::dsl::snippets.find(id))
            .set((
                snippets::dsl::text.eq(text),
                snippets::dsl::media.eq(media),
                snippets::dsl::link.eq(link),
            ))
            .execute(conn)
            .map_err(Error::from)?;

        diesel::delete(terms_snippets::dsl::terms_snippets)
            .filter(terms_snippets::dsl::snippet_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;

        let bulk_terms = terms
            .into_iter()
            .map(|term| TermSnippet::new(term, id))
            .collect::<Vec<_>>();
        diesel::insert_into(terms_snippets::dsl::terms_snippets)
            .values(bulk_terms)
            .execute(conn)
            .map_err(Error::from)?;

        diesel::delete(authors_snippets::dsl::authors_snippets)
            .filter(authors_snippets::dsl::snippet_id.eq(id))
            .execute(conn)
            .map_err(Error::from)?;

        let bulk_known_authors = existing_authors
            .into_iter()
            .map(|author| AuthorSnippet::new(author, id))
            .collect::<Vec<_>>();
        diesel::insert_into(authors_snippets::dsl::authors_snippets)
            .values(bulk_known_authors)
            .execute(conn)
            .map_err(Error::from)?;

        let non_empty = new_authors.iter().filter(|v| !v.is_empty()).count();
        if non_empty > 0 {
            let uuids = crate::db::authors::insert(new_authors, conn)?;
            let bulk_new_authors = uuids
                .into_iter()
                .map(|author| AuthorSnippet::new(author, id))
                .collect::<Vec<_>>();
            diesel::insert_into(authors_snippets::dsl::authors_snippets)
                .values(bulk_new_authors)
                .execute(conn)
                .map_err(Error::from)?;
        }
        Ok(())
    })
}
