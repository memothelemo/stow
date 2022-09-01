use crate::{
    common::{evaluate_token, get_auth_headers, ServerInfo},
    try_respond, ServerState,
};
use actix_web::{web, HttpRequest, HttpResponse};
use std::{sync::Arc, time::SystemTime};
use tokio::sync::Mutex;

#[actix_web::post("/register")]
pub async fn register(
    mut state: web::Data<ServerState>,
    req: HttpRequest,
) -> actix_web::Result<HttpResponse> {
    let headers = try_respond!(get_auth_headers(&req));
    try_respond!(evaluate_token(&mut state, &headers));

    // check for any existing connections with this specific server
    let server_id = headers.server_id.to_string();
    if state.connected_servers.contains_key(&server_id) {
        return Ok(HttpResponse::BadRequest().body("Already connected"));
    }

    log::info!("Registered server: {}", headers.server_id);
    state.connected_servers.insert(
        server_id,
        Arc::new(Mutex::new(ServerInfo {
            last_activity: SystemTime::now(),
        })),
    );

    HttpResponse::Ok().await
}
