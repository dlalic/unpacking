use openapi_type::OpenapiType;
use serde_derive::Deserialize;
use serde_derive::Serialize;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Translation {
    pub buttons: Buttons,
    pub titles: Titles,
    pub dialogs: Dialogs,
    pub forms: Forms,
    pub labels: Labels,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Buttons {
    pub cancel: String,
    pub confirm: String,
    pub delete: String,
    pub edit: String,
    pub new_snippet: String,
    pub new_term: String,
    pub new_user: String,
    pub sign_in: String,
    pub sign_out: String,
    pub source: String,
    pub submit: String,
    pub view: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Titles {
    pub home: String,
    pub name: String,
    pub snippets: String,
    pub source_code: String,
    pub terms: String,
    pub users: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Dialogs {
    pub confirm_title: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Forms {
    pub authors: String,
    pub edit: String,
    pub email: String,
    pub link: String,
    pub media: String,
    pub media_blog: String,
    pub media_book: String,
    pub media_news: String,
    pub media_twitter: String,
    pub media_video: String,
    pub media_website: String,
    pub name: String,
    pub on_email_empty: String,
    pub on_length_less_than: String,
    pub on_name_empty: String,
    pub on_password_empty: String,
    pub on_snippet_empty: String,
    pub password: String,
    pub role: String,
    pub role_admin: String,
    pub role_user: String,
    pub related: String,
    pub text: String,
    pub terms: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, OpenapiType)]
pub struct Labels {
    pub hello: String,
    pub loading: String,
    pub no_snippets: String,
    pub no_terms: String,
    pub no_users: String,
    pub on_error: String,
    pub on_sign_out: String,
}
