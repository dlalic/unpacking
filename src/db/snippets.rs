use crate::error::Error;
use crate::models::{AuthorSnippet, Snippet, TermSnippet};
use crate::schema::{authors, authors_snippets, snippets, terms, terms_snippets};

use crate::models::enums::Media;
use diesel::pg::sql_types::Record;
use diesel::sql_types::Array;
use diesel::{
    Connection, ExpressionMethods, JoinOnDsl, PgConnection, QueryDsl, Queryable, RunQueryDsl,
};
use uuid::Uuid;

#[derive(Queryable, Debug)]
pub struct SnippetWithRelated {
    pub id: Uuid,
    pub text: String,
    pub media: Media,
    pub link: Option<String>,
    pub terms: Vec<(Uuid, String)>,
    pub authors: Vec<(Uuid, String)>,
}

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

pub fn count(term_id: Option<Uuid>, page_size: i64, conn: &mut PgConnection) -> Result<i64, Error> {
    let count: i64 = match term_id {
        None => snippets::dsl::snippets
            .count()
            .get_result(conn)
            .map_err(Error::from)?,
        Some(id) => snippets::dsl::snippets
            .left_outer_join(
                terms_snippets::dsl::terms_snippets
                    .on(terms_snippets::dsl::snippet_id.eq(snippets::dsl::id)),
            )
            .filter(terms_snippets::dsl::term_id.eq(id))
            .count()
            .get_result(conn)
            .map_err(Error::from)?,
    };
    Ok(count / page_size + (count % page_size).signum())
}

pub fn search(
    term_id: Option<Uuid>,
    limit: Option<i64>,
    offset: Option<i64>,
    conn: &mut PgConnection,
) -> Result<Vec<SnippetWithRelated>, Error> {
    let mut query = snippets::dsl::snippets
        .left_outer_join(terms_snippets::dsl::terms_snippets.on(terms_snippets::dsl::snippet_id.eq(snippets::dsl::id)))
        .left_outer_join(terms::dsl::terms.on(terms::dsl::id.eq(terms_snippets::dsl::term_id)))
        .left_outer_join(authors_snippets::dsl::authors_snippets.on(authors_snippets::dsl::snippet_id.eq(snippets::dsl::id)))
        .left_outer_join(authors::dsl::authors.on(authors::dsl::id.eq(authors_snippets::dsl::author_id)))
        .select(
            (snippets::dsl::id,
             snippets::dsl::text,
             snippets::dsl::media,
             snippets::dsl::link,
             diesel::dsl::sql::<Array<Record<(diesel::sql_types::Uuid, diesel::sql_types::Text)>>>("coalesce(array_agg(distinct (terms.id, terms.name)) filter (where terms.id is not null), '{}')"),
             diesel::dsl::sql::<Array<Record<(diesel::sql_types::Uuid, diesel::sql_types::Text)>>>("coalesce(array_agg(distinct (authors.id, authors.name)) filter (where authors.id is not null), '{}')"),
            )
        )
        .group_by(snippets::dsl::id)
        .order(snippets::dsl::created_at.desc())
        .into_boxed();
    if let Some(id) = term_id {
        query = query.filter(terms_snippets::dsl::term_id.eq(id));
    }
    if let Some(n) = limit {
        query = query.limit(n);
    }
    if let Some(n) = offset {
        query = query.offset(n);
    }
    query.load(conn).map_err(Error::from)
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

pub fn select_media_stats(conn: &mut PgConnection) -> Result<Vec<(Media, i64)>, Error> {
    snippets::dsl::snippets
        .select((
            snippets::dsl::media,
            diesel::dsl::sql::<diesel::sql_types::BigInt>("count(*)"),
        ))
        .group_by(snippets::dsl::media)
        .load(conn)
        .map_err(Error::from)
}
