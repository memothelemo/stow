use std::time::SystemTime;

/// Information about the current server registered
#[derive(Debug)]
pub struct ServerInfo {
    /// Last activity time they do in the server.
    ///
    /// Useful for cleaning up these things later on.
    pub last_activity: SystemTime,
}
