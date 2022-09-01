mod headers;
mod server;

pub use headers::*;
pub use server::*;

#[macro_export]
macro_rules! try_respond {
    ($expr:expr) => {
        match $expr {
            Ok(auth) => auth,
            Err(err) => return Ok(err),
        }
    };
}

#[macro_export]
macro_rules! get_header_as_str {
    ($headers:expr, $header:expr) => {
        match $headers.get($header).map(|v| v.to_str()) {
            Some(n) => match n {
                Ok(n) => n,
                Err(err) => {
                    log::debug!("failed to get '{}' header: {}", $header, err);
                    return Err(actix_web::HttpResponse::PreconditionFailed().finish());
                }
            },
            None => return Err(actix_web::HttpResponse::PreconditionFailed().finish()),
        }
    };
}
