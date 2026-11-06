//! The pending-items digest (C0128): one read-only look at the end of every other bot's chat, so
//! the lead bot can tell the user what is still waiting on them. What counts as "waiting" is the
//! lead's prompt (`chat::lead::DIGEST`), not this file: here we only report what each chat ends with,
//! with times in Asia/Shanghai, so the model judges from text instead of code.

use crate::hub::Hub;
use anyhow::Result;
use chrono::{FixedOffset, TimeZone};
use serde_json::{Value, json};
use std::sync::Arc;

/// How many recent chat messages per bot are read when the call doesn't say.
const LIMIT: i64 = 30;
const MAX_LIMIT: i64 = 50;
/// What one message keeps of its text, in characters.
const TEXT_CHARS: usize = 600;

pub fn tools() -> Vec<Value> {
    vec![json!({
        "name": "pending_digest",
        "description": "Read, for every other bot on this computer, the newest messages of its chat with the user (the user's messages and the bot's final replies), with the last message's time in Asia/Shanghai and who wrote it. Read-only, and it judges nothing: use it when the user asks for a digest of what is waiting on them, then decide from the messages what still needs them, following your pending-digest instructions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "bots": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Only these bot ids (default: every other bot on this computer).",
                },
                "limit": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": MAX_LIMIT,
                    "description": "How many recent messages to read per bot (default 30).",
                },
            },
        },
        "annotations": {"readOnlyHint": true},
    })]
}

/// The digest call: `from` is the bot asking (the lead, whose own chat is left out).
pub fn call(hub: &Arc<Hub>, from: &str, args: &Value) -> Result<Value> {
    let only: Option<Vec<String>> =
        args["bots"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(str::to_owned)).collect());
    let limit = args["limit"].as_i64().unwrap_or(LIMIT).clamp(1, MAX_LIMIT);
    let shanghai = FixedOffset::east_opt(8 * 60 * 60).expect("+08:00 is a valid offset");
    let now = crate::store::now_ms();
    let mut bots: Vec<Value> = Vec::new();
    let mut skipped = 0u64;
    for row in hub.store.bots()? {
        let cfg = &row.config;
        // Its own chat, groups, and what the user hid or deleted are not "another bot with work".
        if row.deleted || cfg.hidden || cfg.is_group() || cfg.id == from {
            continue;
        }
        if let Some(only) = &only
            && !only.iter().any(|id| id == &cfg.id)
        {
            continue;
        }
        let mut messages: Vec<Value> = Vec::new();
        // Newest first; the last one read is the chat's end.
        let mut end: Option<(i64, &'static str)> = None;
        for entry in hub.store.recent_messages(&cfg.id, None, limit)? {
            let text = crate::store::message_text(&entry.data);
            let text = text.trim();
            if text.is_empty() {
                continue;
            }
            if crate::chat::recall::sensitive(text) {
                skipped += 1;
                continue;
            }
            let author = if entry.kind == "user" { "user" } else { "bot" };
            end.get_or_insert((entry.created_at, author));
            messages.push(json!({
                "at": entry.created_at,
                "local": local(shanghai, entry.created_at),
                "author": author,
                "text": text.chars().take(TEXT_CHARS).collect::<String>(),
            }));
        }
        let Some((last_at, last_author)) = end else { continue };
        // Oldest first, so the end of the chat reads last.
        messages.reverse();
        bots.push(json!({
            "botId": cfg.id,
            "botName": cfg.name,
            "lastAt": last_at,
            "lastLocal": local(shanghai, last_at),
            "lastAuthor": last_author,
            "messages": messages,
        }));
    }
    // The chats that moved last come first.
    bots.sort_by_key(|bot| -bot["lastAt"].as_i64().unwrap_or(0));
    Ok(json!({
        "now": {"at": now, "local": local(shanghai, now)},
        "timeZone": "Asia/Shanghai",
        "bots": bots,
        "skippedSensitive": skipped,
    }))
}

/// `at` in Asia/Shanghai, as `2026-11-06 10:29 +08:00`.
fn local(tz: FixedOffset, at: i64) -> String {
    tz.timestamp_millis_opt(at).single().map_or_else(String::new, |d| d.format("%Y-%m-%d %H:%M %:z").to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn times_are_asia_shanghai() {
        let shanghai = FixedOffset::east_opt(8 * 60 * 60).unwrap();
        // 2026-11-06T02:29:00Z
        assert_eq!(local(shanghai, 1_793_932_140_000), "2026-11-06 10:29 +08:00");
    }
}
