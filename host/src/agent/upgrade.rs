//! Host upgrades can add MCP tools a bot is offered (`codync-team`'s `list_groups` and
//! `post_to_group`, say). An agent keeps its session across a host restart and resumes with the
//! tools it had when it started, so a new host version asks every bot to reopen: `Cmd::RefreshTools`
//! makes the bot's next turn drop the connection and load the session again, and the agent spawns
//! its MCP servers — and lists their tools — afresh.

use crate::agent::bot::Cmd;
use crate::hub::Hub;
use crate::store::Store;
use anyhow::Result;
use std::sync::Arc;

/// The host version that last asked the bots to reopen.
const KEY: &str = "host-version";

/// Asks every bot to refresh its tools when this version differs from the recorded one. Called
/// once, as the hub starts.
pub fn refresh_tools_on_upgrade(hub: &Arc<Hub>) {
    match take_upgrade(&hub.store) {
        Ok(true) => {}
        Ok(false) => return,
        Err(error) => tracing::warn!(error = format!("{error:#}"), "couldn't read the recorded host version"),
    }
    for row in hub.store.bots().unwrap_or_default() {
        if row.deleted || row.config.is_group() {
            continue;
        }
        if let Err(error) = hub.send_cmd(&row.config.id, Cmd::RefreshTools) {
            tracing::debug!(error = format!("{error:#}"), bot = %row.config.id, "couldn't ask the bot to refresh its tools");
        }
    }
}

/// Whether this host version differs from the recorded one, recording it. A failed write still
/// refreshes (the next start tries again), so it is logged rather than returned.
fn take_upgrade(store: &Store) -> Result<bool> {
    let current = env!("CARGO_PKG_VERSION");
    if store.kv_read(KEY)?.as_deref() == Some(current) {
        return Ok(false);
    }
    if let Err(error) = store.kv_set(KEY, current) {
        tracing::warn!(error = format!("{error:#}"), "couldn't record the host version");
    }
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_different_version_asks_once() {
        let store = Store::open(std::path::Path::new(":memory:")).unwrap();
        assert!(take_upgrade(&store).unwrap(), "the first start has no recorded version");
        assert!(!take_upgrade(&store).unwrap(), "the same version doesn't ask again");
        store.kv_set(KEY, "0.0.1").unwrap();
        assert!(take_upgrade(&store).unwrap(), "an upgrade asks again");
    }
}
