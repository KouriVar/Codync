//! Cross-bot history recall (C0104): one keyword/time/bot query over every bot's chat, for the bot to
//! consult before answering and for the apps to look back. Purely additive — it calls the existing
//! per-bot `Store::search_messages` / `recent_messages` and changes nothing about them.
//!
//! Sensitive entries — passwords, API keys, tokens, private keys — are dropped from the results before
//! they leave here, and only counts are logged, never text. This reads chat messages from the database
//! and never opens a file, so login files and certificates are never read at all.

use crate::hub::Hub;
use crate::store::{message_text, BotConfig, Entry};
use anyhow::{anyhow, Result};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::sync::Arc;

const DEFAULT_LIMIT: i64 = 20;
const MAX_LIMIT: i64 = 50;
const MAX_TERMS: usize = 8;
const SNIPPET: usize = 280;

/// Markers of a secret in a message's text. Case-insensitive; deliberately blunt, since a false
/// positive only means one message a bot can't cite from.
const SECRET_MARKERS: &[&str] = &[
    "password", "passwd", "api_key", "api-key", "apikey", "client_secret", "client-secret",
    "secret", "token", "private key", "-----begin", "begin rsa", "begin openssh", "begin ec private",
    "密码", "密钥", "私鑰", "私钥", "令牌",
];

/// A message kept out of recall because it looks like it holds a secret.
pub fn sensitive(text: &str) -> bool {
    let lowered = text.to_lowercase();
    SECRET_MARKERS.iter().any(|m| lowered.contains(m))
}

pub async fn api_call(hub: &Arc<Hub>, method: &str, b: &Value) -> Result<Value> {
    let (hub, method, b) = (hub.clone(), method.to_owned(), b.clone());
    tokio::task::spawn_blocking(move || match method.as_str() {
        "recallSearch" => {
            let query = b["query"].as_str().unwrap_or_default();
            let bots = b["bots"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(str::to_owned)).collect::<Vec<_>>());
            let from = b["from"].as_i64();
            let to = b["to"].as_i64();
            let limit = b["limit"].as_i64().unwrap_or(DEFAULT_LIMIT);
            let out = search(&hub, query, bots.as_deref(), from, to, limit)?;
            Ok(json!({ "hits": out.hits, "skipped": out.skipped }))
        }
        other => Err(anyhow!("unknown recall method: {other}")),
    })
    .await?
}

/// The bot tool: the same search, phrased for a harness and telling it how to cite what it uses.
pub async fn tool(hub: &Arc<Hub>, _cfg: &BotConfig, args: &Value) -> Result<Value> {
    let (hub, args) = (hub.clone(), args.clone());
    tokio::task::spawn_blocking(move || {
        let query = args["query"].as_str().unwrap_or_default();
        let bots = args["bots"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(str::to_owned)).collect::<Vec<_>>());
        let from = args["from"].as_i64();
        let to = args["to"].as_i64();
        let limit = args["limit"].as_i64().unwrap_or(10);
        let out = search(&hub, query, bots.as_deref(), from, to, limit)?;
        Ok(json!({
            "hits": out.hits,
            "skipped": out.skipped,
            "cite": "Quote the sources you use in your answer as [[cite:<botId>/<entryId>]] so the app can link them.",
        }))
    })
    .await?
}

pub struct Outcome {
    pub hits: Vec<Value>,
    pub skipped: i64,
}

/// The query over every bot (or `only`), within `[from, to]` (ms), newest first, at most `limit`.
pub fn search(hub: &Hub, query: &str, only: Option<&[String]>, from: Option<i64>, to: Option<i64>, limit: i64) -> Result<Outcome> {
    let limit = limit.clamp(1, MAX_LIMIT);
    let mut terms: Vec<String> = Vec::new();
    for word in query.split_whitespace() {
        let word = word.trim().to_owned();
        if !word.is_empty() && !terms.iter().any(|t| t.eq_ignore_ascii_case(&word)) {
            terms.push(word);
        }
        if terms.len() == MAX_TERMS {
            break;
        }
    }
    let rows = hub.store.bots()?;
    let names: HashMap<String, String> = rows.iter().map(|r| (r.config.id.clone(), r.config.name.clone())).collect();
    // A wider net than the final limit: time/bot filtering and the secret filter happen here.
    let per_bot = (limit * 2).clamp(4, MAX_LIMIT);
    let mut hits: Vec<(i64, Value)> = Vec::new();
    let mut skipped: i64 = 0;
    for row in rows.iter().filter(|r| !r.deleted && !r.config.is_group()) {
        let id = row.config.id.as_str();
        if let Some(only) = only {
            if !only.iter().any(|b| b == id) {
                continue;
            }
        }
        let found: Vec<Entry> = if terms.is_empty() {
            hub.store.recent_messages(id, None, per_bot)?
        } else {
            hub.store.search_messages(id, &terms, None, per_bot)?
        };
        for entry in found {
            let at = entry.created_at;
            if from.is_some_and(|f| at < f) || to.is_some_and(|t| at > t) {
                continue;
            }
            let text = message_text(&entry.data);
            if text.trim().is_empty() {
                continue;
            }
            if sensitive(&text) {
                skipped += 1;
                continue;
            }
            let author = if entry.kind == "user" { "user" } else { "bot" };
            let snippet: String = text.chars().take(SNIPPET).collect();
            hits.push((
                at,
                json!({
                    "botId": id,
                    "botName": names.get(id).cloned().unwrap_or_default(),
                    "entryId": entry.id,
                    "seq": entry.seq,
                    "at": at,
                    "kind": entry.kind,
                    "author": author,
                    "text": snippet,
                }),
            ));
        }
    }
    hits.sort_by(|a, b| b.0.cmp(&a.0));
    hits.truncate(limit as usize);
    // Counts only — never the text itself.
    tracing::info!(query_terms = terms.len(), bots = rows.len(), found = hits.len(), skipped, "recall search");
    Ok(Outcome { hits: hits.into_iter().map(|(_, hit)| hit).collect(), skipped })
}
