use actix_web::{web, HttpRequest, HttpResponse};

use crate::{
    common::{evaluate_token, get_auth_headers},
    try_respond, ServerState,
};

#[actix_web::post("/logout")]
pub async fn logout(
    mut state: web::Data<ServerState>,
    req: HttpRequest,
) -> actix_web::Result<HttpResponse> {
    let headers = try_respond!(get_auth_headers(&req));
    try_respond!(evaluate_token(&mut state, &headers));

    // check for any unexisting connections upon logging out
    let server_id = headers.server_id.to_string();
    if !state.connected_servers.contains_key(&server_id) {
        return Ok(HttpResponse::BadRequest().body("Already logged out"));
    }

    log::info!("Logged out server: {}", headers.server_id);
    state.connected_servers.remove(&server_id);

    HttpResponse::Ok().await
}
