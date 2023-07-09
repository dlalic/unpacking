// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::query_builder::QueryId, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "media_enum"))]
    pub struct MediaEnum;

    #[derive(diesel::query_builder::QueryId, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "role_enum"))]
    pub struct RoleEnum;
}

diesel::table! {
    authors (id) {
        id -> Uuid,
        name -> Text,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

diesel::table! {
    authors_snippets (author_id, snippet_id) {
        author_id -> Uuid,
        snippet_id -> Uuid,
    }
}

diesel::table! {
    passwords (user_id) {
        user_id -> Uuid,
        password -> Text,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::MediaEnum;

    snippets (id) {
        id -> Uuid,
        text -> Text,
        media -> MediaEnum,
        link -> Nullable<Text>,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

diesel::table! {
    terms (id) {
        id -> Uuid,
        name -> Text,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

diesel::table! {
    terms_related (term_id, related_id) {
        term_id -> Uuid,
        related_id -> Uuid,
    }
}

diesel::table! {
    terms_snippets (term_id, snippet_id) {
        term_id -> Uuid,
        snippet_id -> Uuid,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::RoleEnum;

    users (id) {
        id -> Uuid,
        name -> Varchar,
        #[max_length = 254]
        email -> Varchar,
        role -> RoleEnum,
        is_deleted -> Bool,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

diesel::joinable!(authors_snippets -> authors (author_id));
diesel::joinable!(authors_snippets -> snippets (snippet_id));
diesel::joinable!(passwords -> users (user_id));
diesel::joinable!(terms_snippets -> snippets (snippet_id));
diesel::joinable!(terms_snippets -> terms (term_id));

diesel::allow_tables_to_appear_in_same_query!(
    authors,
    authors_snippets,
    passwords,
    snippets,
    terms,
    terms_related,
    terms_snippets,
    users,
);
