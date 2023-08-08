use std::fs::File;
use std::io::BufReader;

use accept_language::{intersection, parse};
use gotham::hyper::header::{HeaderMap, HeaderValue, ACCEPT_LANGUAGE};
use gotham::state::State;
use gotham_restful::*;
use language_tags::LanguageTag;
use log::error;

use crate::error::Error;
use crate::resources::i18n::Translation;

#[derive(Resource)]
#[resource(read_all)]
pub struct Resource;

#[read_all]
async fn read_all(state: &mut State) -> Result<Translation, Error> {
    let headers: &HeaderMap = state.borrow();
    let header_value = &headers[ACCEPT_LANGUAGE];
    let lang = detect_language(header_value);
    read_translations(&lang)
}

fn detect_language(header_value: &HeaderValue) -> String {
    let fallback = "en".to_string();
    let supported = vec!["en", "pt"];
    match header_value.to_str() {
        Ok(some) => {
            let user_languages = parse(some);
            let raw_languages = user_languages
                .iter()
                .flat_map(|v| {
                    v.parse::<LanguageTag>()
                        .map(|v| v.primary_language().to_string())
                })
                .collect::<Vec<_>>();
            let common_languages = intersection(&raw_languages.join(","), &supported);
            let first: Option<LanguageTag> = common_languages
                .iter()
                .find_map(|lang| lang.parse::<LanguageTag>().ok());
            match first {
                None => fallback,
                Some(some) => some.primary_language().to_string(),
            }
        }
        Err(_) => fallback,
    }
}

fn read_translations(lang: &str) -> Result<Translation, Error> {
    let path = format!("frontend/translations/translations.{lang}.json");
    let file = File::open(path).map_err(|e| {
        error!("{e:?}");
        Error::InternalServerError
    })?;
    read_translations_file(file)
}

fn read_translations_file(file: File) -> Result<Translation, Error> {
    let reader = BufReader::new(file);
    serde_json::from_reader(reader).map_err(|e| {
        error!("{e:?}");
        Error::InternalServerError
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use gotham::hyper::header::HeaderValue;

    #[test]
    fn lang_valid() {
        let header = HeaderValue::from_static("en-US,en;q=0.9,de;q=0.8,hr;q=0.7");
        let result = detect_language(&header);
        assert_eq!(&result, "en");
    }

    #[test]
    fn lang_non_default() {
        let header = HeaderValue::from_static("pt");
        let result = detect_language(&header);
        assert_eq!(&result, "pt");

        let header = HeaderValue::from_static("pt-BR");
        let result = detect_language(&header);
        assert_eq!(&result, "pt");
    }

    #[test]
    fn lang_not_supported() {
        let header = HeaderValue::from_static("hr;q=0.7");
        let result = detect_language(&header);
        assert_eq!(&result, "en");
    }

    #[test]
    fn lang_invalid() {
        let header = HeaderValue::from_static("this is wrong");
        let result = detect_language(&header);
        assert_eq!(&result, "en");
    }

    #[test]
    fn translations_en_ok() {
        let result = read_translations("en");
        assert!(result.is_ok())
    }

    #[test]
    fn translations_not_found() {
        let result = read_translations("fr");
        assert_eq!(result, Err(Error::InternalServerError));
    }

    #[test]
    fn translations_invalid() {
        let file = File::open("src/main.rs").expect("open failed");
        let result = read_translations_file(file);
        assert_eq!(result, Err(Error::InternalServerError));
    }
}
