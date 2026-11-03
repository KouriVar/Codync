//! Google ID token verification for pairing.
//!
//! This replaces the Codync cloud's device certificate (`remote::certificate`): the phone proves
//! who it is with a Google ID token (RS256, signed by Google). We check the signature against
//! Google's JWKS, then `iss`, `aud`, `exp`, `email_verified` and that the email is allowed.
//!
//! The client IDs and allowed emails are configuration: `CODYNC_GOOGLE_CLIENT_IDS` and
//! `CODYNC_ALLOWED_EMAILS` (comma-separated) override the defaults compiled in below.

use crate::store::now_ms;
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey};
use serde::Deserialize;
use serde_json::Value;
#[cfg(not(test))]
use std::sync::{LazyLock, Mutex};
#[cfg(not(test))]
use std::time::{Duration, Instant};

/// Google's JWKS endpoint (its RS256 signing keys).
const JWKS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";
/// The iOS OAuth client this host trusts; `CODYNC_GOOGLE_CLIENT_IDS` overrides.
const DEFAULT_CLIENT_IDS: &[&str] = &["930074396465-fg6ftdlkn4n3cvj7kvtb9ptc13225qpe.apps.googleusercontent.com"];
/// The only email allowed to pair; `CODYNC_ALLOWED_EMAILS` overrides.
const DEFAULT_ALLOWED_EMAILS: &[&str] = &["suiyikou@gmail.com"];
const ISSUERS: &[&str] = &["accounts.google.com", "https://accounts.google.com"];

/// What a valid token says about the phone.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Verified {
    pub email: String,
    pub sub: String,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Refusal {
    /// No token was sent (an app older than Google sign-in).
    Missing,
    /// Signature, issuer, audience, expiry, verification or email check failed.
    Invalid,
}

#[derive(Deserialize)]
struct Claims {
    #[serde(default)]
    email: Option<String>,
    #[serde(default)]
    email_verified: Option<Value>,
    #[serde(default)]
    sub: Option<String>,
    #[serde(default)]
    exp: Option<i64>,
}

/// Google's JWKS document, reduced to what RS256 verification needs.
#[derive(Clone, Deserialize)]
struct KeySet {
    keys: Vec<JwkKey>,
}

#[derive(Clone, Deserialize)]
struct JwkKey {
    #[serde(default)]
    kid: Option<String>,
    #[serde(default)]
    kty: String,
    n: String,
    e: String,
}

/// The trusted client IDs, from `CODYNC_GOOGLE_CLIENT_IDS` or the default.
pub fn client_ids() -> Vec<String> {
    env_list("CODYNC_GOOGLE_CLIENT_IDS", DEFAULT_CLIENT_IDS)
}

/// The allowed emails, from `CODYNC_ALLOWED_EMAILS` or the default.
pub fn allowed_emails() -> Vec<String> {
    env_list("CODYNC_ALLOWED_EMAILS", DEFAULT_ALLOWED_EMAILS)
}

fn env_list(var: &str, default: &[&str]) -> Vec<String> {
    let fallback = || default.iter().map(|s| (*s).to_owned()).collect::<Vec<_>>();
    match std::env::var(var) {
        Ok(value) => {
            let list: Vec<String> =
                value.split(',').map(str::trim).filter(|s| !s.is_empty()).map(str::to_owned).collect();
            if list.is_empty() { fallback() } else { list }
        }
        Err(_) => fallback(),
    }
}

/// Verifies `token` against Google's published keys. `Missing` when none is sent.
pub async fn verify(token: Option<&str>) -> Result<Verified, Refusal> {
    let token = token.ok_or(Refusal::Missing)?;
    let key = decoding_key(token).await.ok_or(Refusal::Invalid)?;
    verify_with_key(token, &key, &client_ids(), &allowed_emails(), now_ms())
}

/// The pure check for a token already paired with its key. `now` is milliseconds.
pub fn verify_with_key(
    token: &str,
    key: &DecodingKey,
    client_ids: &[String],
    allowed: &[String],
    now: i64,
) -> Result<Verified, Refusal> {
    let header = decode_header(token).map_err(|_| Refusal::Invalid)?;
    if header.alg != Algorithm::RS256 {
        return Err(Refusal::Invalid);
    }
    let mut validation = jsonwebtoken::Validation::new(Algorithm::RS256);
    // The expiry clock is checked here against `now`, so a test can pin it.
    validation.validate_exp = false;
    let audiences: Vec<&str> = client_ids.iter().map(String::as_str).collect();
    validation.set_audience(&audiences);
    validation.set_issuer(ISSUERS);
    validation.set_required_spec_claims(&["exp", "aud", "iss"]);
    let data = decode::<Claims>(token, key, &validation).map_err(|_| Refusal::Invalid)?;
    let claims = data.claims;
    let exp = claims.exp.ok_or(Refusal::Invalid)?;
    if exp.saturating_mul(1000) <= now {
        return Err(Refusal::Invalid);
    }
    let email = claims.email.filter(|e| !e.is_empty()).ok_or(Refusal::Invalid)?;
    if !email_verified(claims.email_verified.as_ref()) {
        return Err(Refusal::Invalid);
    }
    if !allowed.iter().any(|allowed| allowed.eq_ignore_ascii_case(&email)) {
        return Err(Refusal::Invalid);
    }
    Ok(Verified { email, sub: claims.sub.unwrap_or_default() })
}

/// `email_verified` comes as a bool; some tokens carry the string `"true"`.
fn email_verified(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Bool(verified)) => *verified,
        Some(Value::String(text)) => text.eq_ignore_ascii_case("true"),
        _ => false,
    }
}

// MARK: keys

#[cfg(not(test))]
async fn decoding_key(token: &str) -> Option<DecodingKey> {
    let kid = decode_header(token).ok()?.kid;
    let mut keys = fetch_jwks(false).await?;
    if let Some(kid) = kid.as_deref() {
        if let Some(key) = keys.keys.iter().find(|key| key.kid.as_deref() == Some(kid)) {
            return DecodingKey::from_rsa_components(&key.n, &key.e).ok();
        }
        // Google rotated its keys: refetch once, then give up.
        keys = fetch_jwks(true).await?;
        return keys
            .keys
            .iter()
            .find(|key| key.kid.as_deref() == Some(kid))
            .and_then(|key| DecodingKey::from_rsa_components(&key.n, &key.e).ok());
    }
    keys.keys.iter().find(|key| key.kty == "RSA").and_then(|key| DecodingKey::from_rsa_components(&key.n, &key.e).ok())
}

#[cfg(test)]
async fn decoding_key(_token: &str) -> Option<DecodingKey> {
    DecodingKey::from_rsa_pem(TEST_PUB.as_bytes()).ok()
}

#[cfg(not(test))]
struct CacheEntry {
    at: Instant,
    ttl: Duration,
    set: KeySet,
}

#[cfg(not(test))]
static JWKS: LazyLock<Mutex<Option<CacheEntry>>> = LazyLock::new(|| Mutex::new(None));

/// Google's keys, cached for the `Cache-Control: max-age` it sends (default an hour).
#[cfg(not(test))]
async fn fetch_jwks(force: bool) -> Option<KeySet> {
    // Tests point the host at a local JWKS so verification never reaches the network.
    if let Ok(raw) = std::env::var("CODYNC_GOOGLE_JWKS_JSON") {
        if let Ok(set) = serde_json::from_str::<KeySet>(&raw) {
            return Some(set);
        }
    }
    if !force {
        let cached = {
            let guard = JWKS.lock().ok()?;
            match guard.as_ref() {
                Some(entry) if entry.at.elapsed() < entry.ttl => Some(entry.set.clone()),
                Some(_) | None => None,
            }
        };
        if let Some(set) = cached {
            return Some(set);
        }
    }
    let response = crate::http().get(JWKS_URL).send().await.ok()?;
    if !response.status().is_success() {
        return None;
    }
    let ttl = cache_ttl(response.headers());
    let set: KeySet = response.json().await.ok()?;
    if let Ok(mut guard) = JWKS.lock() {
        *guard = Some(CacheEntry { at: Instant::now(), ttl, set: set.clone() });
    }
    Some(set)
}

#[cfg(not(test))]
fn cache_ttl(headers: &reqwest::header::HeaderMap) -> Duration {
    let secs = headers
        .get(reqwest::header::CACHE_CONTROL)
        .and_then(|value| value.to_str().ok())
        .and_then(|text| {
            text.split(',')
                .find_map(|part| part.trim().strip_prefix("max-age=").and_then(|n| n.trim().parse::<u64>().ok()))
        })
        .unwrap_or(3600);
    Duration::from_secs(secs.clamp(60, 86_400))
}

// MARK: test tokens

#[cfg(test)]
const TEST_PRIV: &str = include_str!("google_auth_test_priv.pem");
#[cfg(test)]
const TEST_PUB: &str = include_str!("google_auth_test_pub.pem");

#[cfg(test)]
fn signing_key() -> jsonwebtoken::EncodingKey {
    jsonwebtoken::EncodingKey::from_rsa_pem(TEST_PRIV.as_bytes()).expect("test private key")
}

#[cfg(test)]
fn test_key() -> DecodingKey {
    DecodingKey::from_rsa_pem(TEST_PUB.as_bytes()).expect("test public key")
}

/// A token as Google would issue for `email`, valid for an hour from `now`.
#[cfg(test)]
pub fn test_token(email: &str) -> String {
    test_token_with(email, true, "https://accounts.google.com", &client_ids()[0], now_ms() / 1000 + 3600)
}

/// A token with every field chosen, for the refusal tests.
#[cfg(test)]
pub fn test_token_with(email: &str, verified: bool, iss: &str, aud: &str, exp: i64) -> String {
    #[derive(serde::Serialize)]
    struct C<'a> {
        iss: &'a str,
        aud: &'a str,
        sub: &'a str,
        email: &'a str,
        email_verified: bool,
        exp: i64,
    }
    let claims = C { iss, aud, sub: "sub_test", email, email_verified: verified, exp };
    let mut header = jsonwebtoken::Header::new(Algorithm::RS256);
    header.kid = Some("test".to_owned());
    jsonwebtoken::encode(&header, &claims, &signing_key()).expect("encode test token")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn allowed() -> Vec<String> {
        allowed_emails()
    }
    fn aud() -> Vec<String> {
        client_ids()
    }
    fn check(token: &str) -> Result<Verified, Refusal> {
        verify_with_key(token, &test_key(), &aud(), &allowed(), now_ms())
    }

    #[test]
    fn a_valid_token_is_accepted_with_its_email() {
        let token = test_token(&allowed()[0]);
        assert_eq!(check(&token), Ok(Verified { email: allowed()[0].clone(), sub: "sub_test".into() }));
    }

    #[test]
    fn a_wrong_audience_is_refused() {
        let token = test_token_with(&allowed()[0], true, "https://accounts.google.com", "someone-else", now_ms() / 1000 + 3600);
        assert_eq!(check(&token), Err(Refusal::Invalid));
    }

    #[test]
    fn another_email_is_refused() {
        assert_eq!(check(&test_token("intruder@example.com")), Err(Refusal::Invalid));
    }

    #[test]
    fn an_expired_token_is_refused() {
        let token = test_token_with(&allowed()[0], true, "https://accounts.google.com", &client_ids()[0], now_ms() / 1000 - 1);
        assert_eq!(check(&token), Err(Refusal::Invalid));
    }

    #[test]
    fn an_unverified_email_is_refused() {
        let token =
            test_token_with(&allowed()[0], false, "https://accounts.google.com", &client_ids()[0], now_ms() / 1000 + 3600);
        assert_eq!(check(&token), Err(Refusal::Invalid));
    }

    #[test]
    fn a_wrong_issuer_is_refused() {
        let token = test_token_with(&allowed()[0], true, "https://evil.example.com", &client_ids()[0], now_ms() / 1000 + 3600);
        assert_eq!(check(&token), Err(Refusal::Invalid));
    }

    #[test]
    fn no_token_is_missing() {
        let runtime = tokio::runtime::Builder::new_current_thread().build().expect("runtime");
        assert_eq!(runtime.block_on(verify(None)), Err(Refusal::Missing));
    }
}
