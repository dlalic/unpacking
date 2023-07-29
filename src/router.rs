use crate::config::{app_url, jwt_secret};
use crate::resources;
use crate::resources::auth::AuthData;

use diesel::PgConnection;
use gotham::hyper::header::CONTENT_TYPE;
use gotham::hyper::Method;
use gotham::router::builder::{self, DefineSingleRoute, DrawRoutes};
use gotham::router::Router;
use gotham_middleware_diesel::DieselMiddleware;
use gotham_restful::cors::{Headers, Origin};
use gotham_restful::gotham::handler::FileOptions;
use gotham_restful::gotham::middleware::logger::RequestLogger;
use gotham_restful::gotham::pipeline::{new_pipeline, single_pipeline};
use gotham_restful::*;

pub type Repo = gotham_middleware_diesel::Repo<PgConnection>;

static API_URL: &str = "/api/v1";

#[cfg(debug_assertions)]
fn cors_origin() -> Origin {
    Origin::Star
}

#[cfg(not(debug_assertions))]
fn cors_origin() -> Origin {
    Origin::Single(app_url())
}

fn api_router(repo: Repo) -> Router {
    let auth: AuthMiddleware<AuthData, _> = AuthMiddleware::new(
        AuthSource::AuthorizationHeader,
        AuthValidation::default(),
        StaticAuthHandler::from_array(jwt_secret().as_ref()),
    );
    let (chain, pipelines) = single_pipeline(
        new_pipeline()
            .add(DieselMiddleware::new(repo))
            .add(RequestLogger::new(log::Level::Info))
            .add(CorsConfig {
                origin: cors_origin(),
                headers: Headers::List(vec![CONTENT_TYPE]),
                max_age: 86400,
                credentials: false,
            })
            .add(auth)
            .build(),
    );
    builder::build_router(chain, pipelines, |route| {
        let info = OpenapiInfo {
            title: format!("{} API", env!("CARGO_PKG_NAME")),
            version: env!("CARGO_PKG_VERSION").to_string(),
            urls: vec![app_url() + API_URL],
        };
        route.with_openapi(info, |mut route| {
            route.resource::<resources::snippet::Resource>("snippets");
            route.resource::<resources::snippet::StatsResource>("snippets");
            route.resource::<resources::term::Resource>("terms");
            route.resource::<resources::author::Resource>("authors");
            route.resource::<resources::term::GraphResource>("terms");
            route.resource::<resources::user::Resource>("users");
            route.resource::<resources::translation::Resource>("translations");
            route.resource::<resources::auth::Resource>("auth");
            route.openapi_spec("openapi");
            route.openapi_doc("api_doc");
        });
        for method in [Method::GET, Method::POST, Method::PUT, Method::DELETE] {
            route.cors("/users", method.clone());
            route.cors("/terms", method.clone());
            route.cors("/snippets", method.clone());
            route.cors("/authors", method.clone());
            route.cors("/transactions", method.clone());
            route.cors("/translations", method.clone());
        }
    })
}

pub fn router(repo: Repo) -> Router {
    builder::build_simple_router(|route| {
        route.delegate(API_URL).to_router(api_router(repo.clone()));

        route.get("/").to_file("frontend/public/index.html");
        route.get("/*").to_file("frontend/public/index.html");
        route
            .get("dist/elm.js")
            .to_file(file_options("frontend/public/dist/elm.js"));
        route
            .get("/PublicSans-Regular.woff2")
            .to_file(file_options("frontend/public/PublicSans-Regular.woff2"));
        route
            .get("/PublicSans-Bold.woff2")
            .to_file(file_options("frontend/public/PublicSans-Bold.woff2"));
        route
            .get("/Redaction-Regular.woff2")
            .to_file(file_options("frontend/public/Redaction-Regular.woff2"));
    })
}

fn file_options(path: &str) -> FileOptions {
    FileOptions::new(path)
        .with_cache_control("public, max-age=604800, immutable")
        .with_brotli(true)
        .build()
}
