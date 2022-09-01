use actix_web::{web::Data, App, HttpServer};
use common::ServerInfo;
use dashmap::DashMap;
use dotenv::dotenv;
use env_logger::Env;
use std::{env, sync::Arc};
use tokio::sync::Mutex;

mod common;
mod routes;

type Servers = Arc<DashMap<String, Arc<Mutex<ServerInfo>>>>;

#[derive(Debug)]
pub struct ServerState {
    /// Authorization password, not secured at the moment right now...
    pub auth_token: String,

    /// Connected servers. It is pretty inefficient but it allows
    /// us to makes a behavior like DDRAM
    pub connected_servers: Servers,
}

async fn garbage_cleanup(servers: Servers) {
    log::info!("[garbage_cleanup] starting server connections garbage collection");

    // we're going to loop this every 10 minutes to clean up junk
    const INTERVAL: tokio::time::Duration = tokio::time::Duration::from_secs(60 * 5);
    const LAST_ACTIVITY_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(60 * 5);
    loop {
        log::trace!("[garbage_cleanup] loop iteration started, sleeping for 5 minutes");
        tokio::time::sleep(INTERVAL).await;

        log::trace!("[garbage_cleanup] begin collecting inactive servers");
        for entry in servers.iter() {
            let (key, server) = entry.pair();
            let server = server.lock().await;
            if server.last_activity.elapsed().unwrap_or_default() >= LAST_ACTIVITY_TIMEOUT {
                log::warn!(
                    "[garbage_cleanup] Server ({}) exceeded no activity timeout (> 5 mins.), disconnecting...",
                    key
                );
                servers.remove(key);
            }
        }

        log::trace!("[garbage_cleanup] loop iteration ended");
    }
}

fn main() -> std::io::Result<()> {
    dotenv().unwrap();
    env_logger::builder()
        .parse_env(Env::default().default_filter_or("trace"))
        .init();

    log::info!("Starting server...");

    let connected_servers = Arc::new(DashMap::new());
    let connected_servers_1 = connected_servers.clone();

    let server = HttpServer::new(move || {
        let mut auth_token = env::var("AUTHORIZATION").expect("expected server authorization key");
        if !auth_token.starts_with("Bearer ") {
            auth_token = format!("Bearer {}", auth_token);
        }
        App::new()
            .app_data(Data::new(ServerState {
                auth_token,
                connected_servers: connected_servers_1.clone(),
            }))
            .service(routes::logout)
            .service(routes::register)
    })
    .bind(("127.0.0.1", 8080))
    .unwrap()
    .run();

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap();

    rt.spawn(garbage_cleanup(connected_servers));
    rt.block_on(server)
}
