//! Pairing lets in the phone's Google account: a valid Google ID token for the allowed email.

use super::*;

async fn pairing_phone(hub: &Arc<Hub>) -> (Phone, String) {
    let code = hub.pairing.locked().issue().code;
    let mut p = Phone::direct(hub, SigningKey::from_bytes(&crypto::random()));
    assert!(matches!(p.hello(hub, true).await, Out::Msg(v) if v["t"] == "welcome"));
    (p, code)
}

#[tokio::test]
async fn an_app_without_a_google_token_is_refused_and_the_code_stays() {
    let hub = temp_hub();
    let (mut p, code) = pairing_phone(&hub).await;
    let reply = p.call(1, "pair", json!({"code": code, "name": "Old app", "platform": "ios"})).await;
    assert_eq!(reply["err"]["status"], 403);
    assert!(hub.pairing.locked().open(), "the code isn't used up");
    assert!(hub.store.device(&p.dk()).is_none());
}

#[tokio::test]
async fn a_phone_with_another_google_email_is_refused() {
    let hub = temp_hub();
    let (mut p, code) = pairing_phone(&hub).await;
    let body = pair_body_as(&p, &code, "Pixel", "android", "intruder@example.com");
    let reply = p.call(1, "pair", body).await;
    assert_eq!(reply["err"]["status"], 403);
    assert!(hub.store.device(&p.dk()).is_none());
    assert!(hub.pairing.locked().open(), "the code isn't used up");
}

#[tokio::test]
async fn a_valid_google_token_lets_the_phone_in_and_stores_its_email() {
    let hub = temp_hub();
    let (mut p, code) = pairing_phone(&hub).await;
    let email = crate::remote::google_auth::allowed_emails()[0].clone();
    let reply = p.call(1, "pair", pair_body(&p, &code, "Pixel", "android", "ignored")).await;
    assert_eq!(reply["ok"]["computerId"], hub.identity.computer_id());
    let device = hub.store.device(&p.dk()).unwrap();
    assert_eq!(device.email.as_deref(), Some(email.as_str()));
    assert_eq!(device.source, DeviceSource::Local);
    assert_eq!(device.scopes, [Scope::Control, Scope::Screen]);
    assert!(!hub.pairing.locked().valid(&code), "the code was used up");
}

#[tokio::test]
async fn without_a_live_code_a_phone_learns_nothing() {
    let hub = temp_hub();
    let (mut p, _) = pairing_phone(&hub).await;
    let reply = p.call(1, "pair", pair_body(&p, "CAgICAgICAgICAgICAgICA", "Pixel", "android", "x")).await;
    let message = reply["err"]["message"].as_str().unwrap();
    assert!(message.contains("expired"), "{message}");
    assert!(hub.store.device(&p.dk()).is_none());
}
