use crate::schema::*;

use chrono::{NaiveDateTime, Utc};
use derive_getters::{Dissolve, Getters};
use diesel::{Identifiable, Insertable, Queryable};
use enums::{Media, Role};
use uuid::Uuid;

#[cfg(test)]
use fake::{
    faker::{
        internet::en::{FreeEmail, Password},
        name::en::FirstName,
    },
    Dummy, Fake, Faker,
};

pub mod enums {
    #[cfg(test)]
    use fake::Dummy;
    use openapi_type::OpenapiType;
    use serde_derive::{Deserialize, Serialize};

    #[derive(Clone, Copy, Debug, DbEnum, Serialize, Deserialize, OpenapiType)]
    #[ExistingTypePath = "crate::schema::sql_types::MediaEnum"]
    #[cfg_attr(test, derive(Dummy))]
    pub enum Media {
        Blog,
        Book,
        News,
        Twitter,
        Video,
        Website,
    }

    #[derive(Clone, Copy, Debug, PartialEq, Eq, DbEnum, Serialize, Deserialize, OpenapiType)]
    #[ExistingTypePath = "crate::schema::sql_types::RoleEnum"]
    #[cfg_attr(test, derive(Dummy))]
    pub enum Role {
        User,
        Admin,
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[cfg_attr(test, derive(Dummy))]
pub struct User {
    id: Uuid,
    #[cfg_attr(test, dummy(faker = "FirstName()"))]
    name: String,
    #[cfg_attr(test, dummy(faker = "FreeEmail()"))]
    email: String,
    role: Role,
    is_deleted: bool,
    created_at: NaiveDateTime,
    updated_at: NaiveDateTime,
}

impl User {
    pub fn new(name: String, email: String, role: Role) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            email,
            role,
            is_deleted: false,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        }
    }

    #[cfg(test)]
    pub fn fake(role: Role) -> User {
        let fake: User = Faker.fake();
        let (_, name, email, _, _, _, _) = fake.dissolve();
        User::new(name, email, role)
    }
}

#[derive(Insertable, Queryable, Debug, Getters)]
#[diesel(belongs_to(User))]
#[cfg_attr(test, derive(Dummy))]
pub struct Password {
    user_id: Uuid,
    #[cfg_attr(test, dummy(faker = "Password(6..8)"))]
    password: String,
    created_at: NaiveDateTime,
    updated_at: NaiveDateTime,
}

impl Password {
    pub fn new(user_id: Uuid, password: String) -> Self {
        Self {
            user_id,
            password,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[cfg_attr(test, derive(Dummy))]
pub struct Term {
    id: Uuid,
    name: String,
    created_at: NaiveDateTime,
    updated_at: NaiveDateTime,
}

impl Term {
    pub fn new(name: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[diesel(table_name = terms_related)]
#[diesel(primary_key(term_id, related_id))]
pub struct TermRelated {
    term_id: Uuid,
    related_id: Uuid,
}

impl TermRelated {
    pub fn new(term_id: Uuid, related_id: Uuid) -> Self {
        Self {
            term_id,
            related_id,
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[cfg_attr(test, derive(Dummy))]
pub struct Snippet {
    id: Uuid,
    text: String,
    media: Media,
    link: Option<String>,
    created_at: NaiveDateTime,
    updated_at: NaiveDateTime,
}

impl Snippet {
    pub fn new(text: String, media: Media, link: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            text,
            media,
            link,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[diesel(table_name = terms_snippets)]
#[diesel(primary_key(term_id, snippet_id))]
pub struct TermSnippet {
    term_id: Uuid,
    snippet_id: Uuid,
}

impl TermSnippet {
    pub fn new(term_id: Uuid, snippet_id: Uuid) -> Self {
        Self {
            term_id,
            snippet_id,
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[cfg_attr(test, derive(Dummy))]
pub struct Author {
    id: Uuid,
    name: String,
    created_at: NaiveDateTime,
    updated_at: NaiveDateTime,
}

impl Author {
    pub fn new(name: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        }
    }
}

#[derive(Identifiable, Insertable, Queryable, Debug, Getters, Dissolve)]
#[diesel(belongs_to(Author))]
#[diesel(belongs_to(Snippet))]
#[diesel(table_name = authors_snippets)]
#[diesel(primary_key(author_id, snippet_id))]
pub struct AuthorSnippet {
    pub author_id: Uuid,
    pub snippet_id: Uuid,
}

impl AuthorSnippet {
    pub fn new(author_id: Uuid, snippet_id: Uuid) -> Self {
        Self {
            author_id,
            snippet_id,
        }
    }
}
