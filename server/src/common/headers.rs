use crate::{get_header_as_str, ServerState};
use actix_web::{web, HttpRequest, HttpResponse};
use std::borrow::Cow;

pub fn evaluate_token(
    state: &mut web::Data<ServerState>,
    headers: &AuthHeaders<'_>,
) -> Result<(), HttpResponse> {
    if headers.auth_token.starts_with("Bearer ") && headers.auth_token == state.auth_token {
        Ok(())
    } else {
        log::warn!("Someone went through our server!");

        // This will seriously violate privacy laws but if you want to see
        // the request's IP address (if your country or server allows that),
        // you may enable `law_enforcement` feature. Do it at your own risk btw!
        #[cfg(feature = "law_enforcement")]
        {
            if let Some(addr) = req.connection_info().peer_addr() {
                log::warn!("[IP Address] {}", addr);
            }
        }

        Err(HttpResponse::Forbidden().finish())
    }
}

pub fn get_auth_headers(req: &HttpRequest) -> Result<AuthHeaders, HttpResponse> {
    let auth_token = get_header_as_str!(req.headers(), "Authorization");
    let server_id = get_header_as_str!(req.headers(), "Server");
    Ok(AuthHeaders {
        auth_token: Cow::Borrowed(auth_token),
        server_id: Cow::Borrowed(server_id),
    })
}

#[derive(Debug)]
pub struct AuthHeaders<'a> {
    /// Authorization token to access the database API.
    pub auth_token: Cow<'a, str>,

    /// Server job id given from ROBLOX
    pub server_id: Cow<'a, str>,
}
