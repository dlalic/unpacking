use crate::error::Error;
use crate::models::Author;
use crate::schema::authors;
use diesel::{ExpressionMethods, PgConnection, QueryDsl, RunQueryDsl};
use uuid::Uuid;

pub fn delete(id: Uuid, conn: &mut PgConnection) -> Result<usize, Error> {
    diesel::delete(authors::dsl::authors.find(id))
        .execute(conn)
        .map_err(Error::from)
}

pub fn insert(names: Vec<String>, conn: &mut PgConnection) -> Result<Vec<Uuid>, Error> {
    let authors = names.into_iter().map(Author::new).collect::<Vec<_>>();
    let uuids = diesel::insert_into(authors::dsl::authors)
        .values(authors)
        .returning(authors::dsl::id)
        .get_results(conn)
        .map_err(Error::from)?;
    Ok(uuids)
}

pub fn select_all(conn: &mut PgConnection) -> Result<Vec<Author>, Error> {
    authors::dsl::authors
        .order(authors::dsl::name)
        .load(conn)
        .map_err(Error::from)
}

pub fn update(id: Uuid, name: String, conn: &mut PgConnection) -> Result<usize, Error> {
    diesel::update(authors::dsl::authors.find(id))
        .set(authors::dsl::name.eq(name))
        .execute(conn)
        .map_err(Error::from)
}
