//! The pairing channel (§4.1): one `pair`, answered, then closed with `4100`. The phone proves who
//! it is with a Google ID token (`remote::google_auth`): only the allowed Google account is let in.
//! After pairing, the device key and the E2E channel are the existing ones; nothing else changes.
//! The one-time code, its TTL and the attempt limit are unchanged.

use super::*;
use crate::remote::google_auth::{self, Refusal, Verified};

const PROTOCOL: CloseWith = (close::PROTOCOL, "protocolError");
const EXPIRED: &str = "This pairing code expired. Show a new one on the computer.";

/// Why `let_in` left the phone out.
enum Kept {
    /// Turned away: the message and the close reason.
    Out(String, &'static str),
    /// Let in, but it couldn't be saved.
    Unsaved,
}

impl Channel {
    pub(super) async fn pair(
        &mut self,
        incoming: &mut mpsc::Receiver<Value>,
        opener: Opener,
        source: &str,
    ) -> CloseWith {
        let (id, b) = match read_pair(incoming, opener).await {
            Ok(request) => request,
            Err(close) => return close,
        };
        let name = b["name"].as_str().map(str::trim).filter(|n| !n.is_empty() && n.chars().count() <= 100);
        let platform = b["platform"].as_str().filter(|p| matches!(*p, "ios" | "macos" | "android"));
        let (Some(name), Some(platform)) = (name, platform) else {
            self.send(err(id, 400, "`name` and `platform` (ios, macos or android) are required")).await;
            return PROTOCOL;
        };
        let code = b["code"].as_str().unwrap_or_default();
        let account = match self.admit(id, &b, code, source).await {
            Ok(account) => account,
            Err(close) => return close,
        };
        match self.let_in(&account, code, name, platform) {
            Ok(()) => {}
            Err(Kept::Out(message, reason)) => return self.refuse(id, &message, reason).await,
            Err(Kept::Unsaved) => {
                self.send(err(id, 500, "couldn't save this device")).await;
                return (close::NORMAL, "");
            }
        }
        tracing::info!(device = self.key, platform, "device paired");
        crate::analytics::device_paired(&self.hub, crate::analytics::Via::Qr, platform, false);
        let ok = json!({"computerId": self.hub.identity.computer_id(), "name": crate::service::host_name()});
        self.send(json!({"id": id, "ok": ok})).await;
        (close::PAIRED, "paired")
    }

    /// A live code first, then the phone's Google account: a valid ID token whose email is allowed.
    async fn admit(&self, id: u64, b: &Value, code: &str, source: &str) -> Result<Verified, CloseWith> {
        if !self.hub.pairing.locked().attempt(source) {
            return Err(self.reject(RejectCode::RateLimited).await);
        }
        if !self.hub.pairing.locked().valid(code) {
            return Err(self.refuse(id, EXPIRED, "unauthorized").await);
        }
        match google_auth::verify(b["google_id_token"].as_str()).await {
            Ok(account) => Ok(account),
            Err(Refusal::Missing) => {
                Err(self.refuse(id, "Sign in with Google on this phone, then scan a new code.", "unauthorized").await)
            }
            Err(Refusal::Invalid) => {
                let message =
                    "Couldn't confirm your Google account. Sign in with the allowed Google account and try again.";
                Err(self.refuse(id, message, "unauthorized").await)
            }
        }
    }

    /// Saves the device only once the code is spent: a phone turned away leaves the code for the right one.
    fn let_in(&self, account: &Verified, code: &str, name: &str, platform: &str) -> Result<(), Kept> {
        if !self.hub.pairing.locked().redeem(code) {
            return Err(Kept::Out(EXPIRED.into(), "unauthorized"));
        }
        let device = Device {
            key: self.key.clone(),
            name: name.to_owned(),
            platform: platform.to_owned(),
            source: DeviceSource::Local,
            grant_id: None,
            scopes: vec![Scope::Control, Scope::Screen],
            lease_until: None,
            created_at: now_ms(),
            last_seen_at: None,
            account: Some(account.email.clone()),
            email: Some(account.email.clone()),
        };
        if let Err(e) = self.hub.store.put_device(&device) {
            tracing::error!(error = format!("{e:#}"), "couldn't save a paired device");
            return Err(Kept::Unsaved);
        }
        Ok(())
    }

    async fn refuse(&self, id: u64, message: &str, reason: &'static str) -> CloseWith {
        self.send(err(id, 403, message)).await;
        (close::UNAUTHORIZED, reason)
    }
}

/// Waits for the phone's one `pair`: its id and body.
async fn read_pair(incoming: &mut mpsc::Receiver<Value>, mut opener: Opener) -> Result<(u64, Value), CloseWith> {
    let deadline = Instant::now() + PAIRING_MAX_AGE;
    let bytes = loop {
        let msg = tokio::select! {
            msg = incoming.recv() => msg,
            () = sleep_until(deadline) => return Err((close::PAIRING_EXPIRED, "pairingExpired")),
        };
        let Some(msg) = msg else { return Err((close::NORMAL, "")) };
        match opener.open(&msg) {
            Ok(Some(bytes)) => break bytes,
            Ok(None) => {}
            Err(e) => return Err(frame_close(&e)),
        }
    };
    let Ok(mut v) = serde_json::from_slice::<Value>(&bytes) else { return Err(PROTOCOL) };
    match v["id"].as_u64() {
        Some(id) if v["m"] == "pair" => Ok((id, v["b"].take())),
        _ => Err(PROTOCOL),
    }
}
