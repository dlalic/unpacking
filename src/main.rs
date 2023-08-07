use unpacking::config::{app_address, database_url, db_pool_size, load_and_validate_env_vars};
use unpacking::db::users::create_admin_account_if_not_present;
use unpacking::router::router;

use env_logger::{Env, Target};
use futures::prelude::*;
use gotham_middleware_diesel::Repo;
use log::info;
use r2d2::Pool;
use unpacking::db::migrations::run_migrations;

#[tokio::main]
async fn main() {
    load_and_validate_env_vars();

    // By default it logs to stderr, using stdout instead
    env_logger::Builder::from_env(Env::default().default_filter_or("warn"))
        .target(Target::Stdout)
        .init();

    let repo = Repo::from_pool_builder(
        database_url().as_str(),
        Pool::builder().max_size(db_pool_size()),
    );
    repo.run(|mut conn| run_migrations(&mut conn))
        .await
        .expect("Error running migrations");
    repo.run(|mut conn| create_admin_account_if_not_present(&mut conn))
        .await
        .expect("Error creating the admin account");

    let server = gotham::init_server(app_address(), router(repo.clone()));

    tokio::select! {
        _ = server.boxed() => { panic!("server finished"); },
        _ = tokio::signal::ctrl_c() => { info!("ctrl-c pressed"); },
    }

    info!("Shutting down gracefully");
}
