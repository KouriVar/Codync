//! Bots speaking in group chats on their own: `list_groups` and `post_to_group`.
//!
//! A tool call carries no client session, so the host takes the bot's identity from the call
//! context (`from`) and re-checks the group, the membership and the speak permission when it
//! writes — a group the bot was removed from (or a user who revoked it) can't be posted into with
//! an id it learned earlier. A post is a normal final bot line (`EntryKind::Agent`, `author`,
//! `final: true`) written straight into the group's transcript: it reuses the existing `entry`
//! sync, so every client shows it like any other member's message, and it deliberately does not
//! start a room turn, so no other member is woken by it. `requestId` makes a retry idempotent.

use crate::hub::Hub;
use crate::store::{BotConfig, BotRow, EntryKind, Lane};
use anyhow::{Result, anyhow, bail, ensure};
use serde_json::{Value, json};
use std::sync::Arc;

/// Longest message accepted, in bytes (the same ceiling as the other chat tools).
const MAX_TEXT_BYTES: usize = 32_000;
/// Longest `requestId` accepted, in bytes.
const MAX_REQUEST_BYTES: usize = 200;

pub fn tools() -> Vec<Value> {
    vec![
        json!({
            "name": "list_groups",
            "description": "List the group chats on this computer that you are a member of and may speak in: their names, IDs, descriptions and members. Groups can share a name; when the user names one ambiguously, ask which ID to use before posting. Use post_to_group to speak in one of them.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Words that must all appear in the group's name or description."},
                },
            },
            "annotations": {"readOnlyHint": true},
        }),
        json!({
            "name": "post_to_group",
            "description": "Post one message to a group chat you are a member of, as yourself. Use it only when the user explicitly asks you to say something in that group: it appears once in the room, with your name, and it does not start a group round, so the other members are not woken by it. Reuse the same requestId when retrying: the host posts it once. Your membership is checked again when it posts.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "groupId": {"type": "string", "description": "Group ID from list_groups."},
                    "text": {"type": "string", "description": "The message, as the group should read it (Markdown)."},
                    "requestId": {"type": "string", "description": "A stable id for this posting attempt; the same id never posts twice."},
                },
                "required": ["groupId", "text", "requestId"],
            },
            "annotations": {"readOnlyHint": false, "idempotentHint": true},
        }),
    ]
}

/// A group tool call. The caller (`from`) has already been checked to be a visible bot.
pub fn call(hub: &Arc<Hub>, from: &str, name: &str, args: &Value) -> Result<Value> {
    match name {
        "list_groups" => list(hub, from, args),
        "post_to_group" => post(hub, from, args),
        _ => bail!("unknown group tool: {name}"),
    }
}

/// The groups `from` may speak in, narrowed by `query` words.
fn list(hub: &Hub, from: &str, args: &Value) -> Result<Value> {
    let query = args["query"].as_str().unwrap_or_default().trim().to_lowercase();
    let mut groups = Vec::new();
    for row in hub.store.bots()? {
        if !may_speak(&row, from) || !matches(&row.config, &query) {
            continue;
        }
        groups.push(json!({
            "groupId": row.config.id,
            "name": row.config.name,
            "description": row.config.description,
            "members": row.config.members.iter().map(|id| hub.bot_name(id)).collect::<Vec<_>>(),
        }));
    }
    Ok(json!({"groups": groups}))
}

/// Posts `text` as a final `from` message in `groupId`'s transcript, once per `requestId`.
fn post(hub: &Arc<Hub>, from: &str, args: &Value) -> Result<Value> {
    let group_id = args["groupId"].as_str().unwrap_or_default().trim();
    ensure!(!group_id.is_empty(), "groupId is required");
    let text = args["text"].as_str().unwrap_or_default().trim();
    if text.is_empty() || text.len() > MAX_TEXT_BYTES {
        bail!("text must be nonempty and at most {MAX_TEXT_BYTES} bytes");
    }
    let request = args["requestId"].as_str().unwrap_or_default().trim();
    if request.is_empty() || request.len() > MAX_REQUEST_BYTES {
        bail!("requestId must be nonempty and at most {MAX_REQUEST_BYTES} bytes");
    }
    // Read again here rather than trusting the listing: the user may have removed the bot, hidden
    // or deleted the group since it looked.
    let row = hub.store.bot(group_id)?.ok_or_else(|| anyhow!("unknown group {group_id}"))?;
    ensure!(!row.deleted, "that group was deleted");
    ensure!(row.config.is_group(), "{group_id} isn't a group");
    ensure!(may_speak(&row, from), "you aren't a member of that group (the user removed you, or hasn't added you)");
    hub.store.bot(from)?.filter(|r| !r.deleted).ok_or_else(|| anyhow!("unknown bot {from}"))?;

    let data = json!({"text": text, "final": true, "author": from});
    let turn = hub.store.max_turn(group_id) + 1;
    let id = dedup_id(group_id, from, request);
    let (entry, added) = hub.add_entry_once(&id, &Lane::main(group_id), EntryKind::Agent, turn, &data)?;
    Ok(json!({
        "posted": true,
        "duplicate": !added,
        "entryId": entry.id,
        "groupId": row.config.id,
        "name": row.config.name,
        "note": if added {
            "Posted to the group. No group round was started, so the other members weren't woken."
        } else {
            "Already posted with this requestId; nothing was posted again."
        },
    }))
}

/// Whether `from` may speak in `row`: a live, visible group on this computer with `from` among
/// its members. Revoking the permission means removing the bot from the group.
fn may_speak(row: &BotRow, from: &str) -> bool {
    !row.deleted
        && !row.config.hidden
        && row.config.is_group()
        && row.config.members.iter().any(|member| member.as_str() == from)
}

/// Whether every word of `query` appears in the group's name or description.
fn matches(cfg: &BotConfig, query: &str) -> bool {
    if query.is_empty() {
        return true;
    }
    let haystack = format!("{} {}", cfg.name, cfg.description).to_lowercase();
    query.split_whitespace().all(|word| haystack.contains(word))
}

/// The entry id a (`group`, `from`, `request`) triple always maps to, unambiguous even when an id
/// contains the separators (each part is length-prefixed).
fn dedup_id(group: &str, from: &str, request: &str) -> String {
    format!("group-post:{}:{group}:{}:{from}:{request}", group.len(), from.len())
}

#[cfg(test)]
mod tests {
    use super::super::call as team_call;
    use super::super::tests::Fixture;
    use super::*;

    #[test]
    fn the_dedup_id_is_stable_and_unambiguous() {
        assert_eq!(dedup_id("g1", "b1", "r1"), dedup_id("g1", "b1", "r1"));
        assert_ne!(dedup_id("g1", "b1", "r1"), dedup_id("g1", "b1", "r2"));
        // A colon in one part can't make two different triples collide.
        assert_ne!(dedup_id("g", "b", "x:y"), dedup_id("g", "b:x", "y"));
    }

    #[test]
    fn the_team_server_advertises_the_group_tools() {
        let tools = crate::chat::team::tools();
        let names: Vec<&str> = tools.as_array().unwrap().iter().filter_map(|tool| tool["name"].as_str()).collect();
        assert!(names.contains(&"list_groups"), "{names:?}");
        assert!(names.contains(&"post_to_group"), "{names:?}");
    }

    /// A group row holding `members`.
    fn group(id: &str, name: &str, members: &[&str]) -> BotConfig {
        serde_json::from_value(json!({"id": id, "kind": "group", "name": name, "members": members})).unwrap()
    }

    #[tokio::test]
    async fn a_bot_lists_only_its_groups_and_posts_one_message_per_request() {
        let f = Fixture::new();
        f.hub.store.save_bot(&group("g1", "Ship room", &["a", "b"])).unwrap();

        // A member sees the group; a bot outside it doesn't.
        let listed = team_call(&f.hub, "a", "list_groups", &json!({})).unwrap();
        let ids: Vec<&str> =
            listed["groups"].as_array().unwrap().iter().filter_map(|g| g["groupId"].as_str()).collect();
        assert_eq!(ids, ["g1"]);
        assert_eq!(listed["groups"][0]["name"], "Ship room");
        let listed = team_call(&f.hub, "c", "list_groups", &json!({})).unwrap();
        assert!(listed["groups"].as_array().unwrap().is_empty(), "`c` isn't a member");

        // A post is a final agent line with the bot as its author.
        let posted =
            team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "g1", "text": "Good night", "requestId": "r1"}))
                .unwrap();
        assert_eq!(posted["posted"], true);
        assert_eq!(posted["duplicate"], false);
        let lines = f.hub.store.history("g1", i64::MAX, 50).unwrap();
        assert_eq!(lines.len(), 1);
        assert_eq!(lines[0].kind, "agent");
        assert_eq!(lines[0].data["text"], "Good night");
        assert_eq!(lines[0].data["author"], "a");
        assert_eq!(lines[0].data["final"], true);

        // The same requestId posts once; a different one is a new line.
        let again =
            team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "g1", "text": "Good night", "requestId": "r1"}))
                .unwrap();
        assert_eq!(again["duplicate"], true);
        assert_eq!(f.hub.store.history("g1", i64::MAX, 50).unwrap().len(), 1);
        team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "g1", "text": "Sleep well", "requestId": "r2"}))
            .unwrap();
        assert_eq!(f.hub.store.history("g1", i64::MAX, 50).unwrap().len(), 2);

        // No room turn started, so no member was prompted: the other bots keep sleeping.
        assert!(f.prompts_of("b").is_empty(), "a group post must not wake the members");

        f.shutdown().await;
    }

    #[tokio::test]
    async fn posting_is_refused_once_the_bot_leaves_the_group() {
        let f = Fixture::new();
        f.hub.store.save_bot(&group("g1", "Ship room", &["a", "b"])).unwrap();
        team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "g1", "text": "hi", "requestId": "r1"})).unwrap();

        // The user removes `a`: the id it learned no longer posts.
        f.hub.store.save_bot(&group("g1", "Ship room", &["b"])).unwrap();
        let refused =
            team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "g1", "text": "again", "requestId": "r2"}))
                .unwrap_err();
        assert!(refused.to_string().contains("aren't a member of that group"), "{refused}");
        assert_eq!(f.hub.store.history("g1", i64::MAX, 50).unwrap().len(), 1);

        // Nor can a bot post into something that isn't a group.
        let not_a_group =
            team_call(&f.hub, "a", "post_to_group", &json!({"groupId": "b", "text": "hi", "requestId": "r3"}));
        assert!(not_a_group.unwrap_err().to_string().contains("isn't a group"));

        f.shutdown().await;
    }
}
