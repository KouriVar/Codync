//! The apps' memory writes (C0102): adding, editing or taking out one fact of a layer's `MEMORY.md`
//! from the memory screen. Additive on purpose — it reuses the same compare-and-swap writer that
//! dreaming and the harness tools use (`chat::memory::files`), records the change as the user's, and
//! leaves how memory is read, what a bot may change, and every other behaviour untouched.

use crate::hub::Hub;
use crate::store::BotConfig;
use anyhow::{Result, anyhow, bail};
use codync_mem::files::{fact_id, hash, Author, Cause, MAIN};
use serde_json::{Value, json};
use std::sync::Arc;

pub async fn call(hub: &Arc<Hub>, method: &str, b: &Value) -> Result<Value> {
    let (hub, method, b) = (hub.clone(), method.to_owned(), b.clone());
    tokio::task::spawn_blocking(move || dispatch(&hub, &method, &b)).await?
}

fn dispatch(hub: &Hub, method: &str, b: &Value) -> Result<Value> {
    let cfg = bot(hub, str_arg(b, "botId")?)?;
    let shared = b["shared"].as_bool().unwrap_or(false);
    match method {
        "memoryAdd" => add(hub, &cfg, shared, str_arg(b, "text")?),
        "memoryEdit" => edit(hub, &cfg, shared, int_arg(b, "id")?, str_arg(b, "text")?),
        "memoryDelete" => delete(hub, &cfg, shared, int_arg(b, "id")?),
        other => bail!("unknown memory method: {other}"),
    }
}

/// Adds one fact line to the layer's `MEMORY.md`, as the user's own.
fn add(hub: &Hub, cfg: &BotConfig, shared: bool, text: &str) -> Result<Value> {
    let text = one_line(text)?;
    let layer = layer_of(cfg, shared)?;
    let before = current(hub, cfg, layer.as_deref())?;
    let trimmed = before.as_deref().unwrap_or_default().trim_end();
    let after = if trimmed.is_empty() { format!("- {text}\n") } else { format!("{trimmed}\n- {text}\n") };
    save(hub, cfg, layer.as_deref(), Some(after), before.as_deref().map(hash))?;
    Ok(json!({"status": "saved"}))
}

/// Rewrites the fact whose id is `id` (the apps' `fact_id`) to `text`.
fn edit(hub: &Hub, cfg: &BotConfig, shared: bool, id: i64, text: &str) -> Result<Value> {
    let text = one_line(text)?;
    let layer = layer_of(cfg, shared)?;
    let before = current(hub, cfg, layer.as_deref())?;
    let mut lines: Vec<String> = before.as_deref().unwrap_or_default().lines().map(str::to_owned).collect();
    let at = find(&lines, id)?;
    lines[at] = format!("- {text}");
    let after = finish(lines.join("\n"));
    save(hub, cfg, layer.as_deref(), Some(after), before.as_deref().map(hash))?;
    Ok(json!({"status": "saved"}))
}

/// Takes a fact out of the layer's `MEMORY.md`.
fn delete(hub: &Hub, cfg: &BotConfig, shared: bool, id: i64) -> Result<Value> {
    let layer = layer_of(cfg, shared)?;
    let before = current(hub, cfg, layer.as_deref())?;
    let mut lines: Vec<String> = before.as_deref().unwrap_or_default().lines().map(str::to_owned).collect();
    let at = find(&lines, id)?;
    lines.remove(at);
    let after = finish(lines.join("\n"));
    save(hub, cfg, layer.as_deref(), Some(after), before.as_deref().map(hash))?;
    Ok(json!({"status": "saved"}))
}

/// The line holding the fact with this id, skipping headings and blank lines the apps never show.
fn find(lines: &[String], id: i64) -> Result<usize> {
    lines
        .iter()
        .position(|line| {
            let fact = unmarked(line);
            !fact.is_empty() && !line.trim_start().starts_with('#') && fact_id(fact) == id
        })
        .ok_or_else(|| anyhow!("That memory isn't there any more. Refresh and try again."))
}

/// A `MEMORY.md` fact is one short line; the marker `- ` is the file's own formatting.
fn unmarked(line: &str) -> &str {
    let trimmed = line.trim();
    for marker in ["- ", "* ", "+ ", "• "] {
        if let Some(rest) = trimmed.strip_prefix(marker) {
            return rest.trim();
        }
    }
    trimmed
}

/// The layer to write: the bot's own, or `None` for what every bot shares.
fn layer_of(cfg: &BotConfig, shared: bool) -> Result<Option<String>> {
    if shared {
        if !super::shared(cfg) {
            bail!("This bot doesn't use the shared memory.");
        }
        return Ok(None);
    }
    Ok(Some(cfg.id.clone()))
}

/// The layer's `MEMORY.md` as it stands, after scanning for changes made on the computer.
fn current(hub: &Hub, cfg: &BotConfig, layer: Option<&str>) -> Result<Option<String>> {
    super::files::scan(hub, cfg);
    super::files::read(layer, MAIN)
}

/// Writes `content` over what we read, as the user's change. `expected` is the hash of the text we read,
/// so a change made meanwhile isn't overwritten (the writer refuses and the app reloads).
fn save(hub: &Hub, cfg: &BotConfig, layer: Option<&str>, content: Option<String>, expected: Option<String>) -> Result<()> {
    let _ = cfg;
    let writer = super::files::Writer { author: Author::User, bot: None, cause: Cause::Edit, message: None };
    super::files::write(hub, layer, MAIN, content.as_deref(), expected.as_deref(), writer)?;
    Ok(())
}

fn one_line(text: &str) -> Result<&str> {
    let text = text.trim();
    if text.is_empty() {
        bail!("Write something to remember.");
    }
    if text.contains('\n') {
        bail!("One line at a time.");
    }
    Ok(text)
}

fn finish(text: String) -> String {
    if text.is_empty() || text.ends_with('\n') { text } else { format!("{text}\n") }
}

fn bot(hub: &Hub, id: &str) -> Result<BotConfig> {
    let cfg = hub.store.bot(id)?.filter(|b| !b.deleted).ok_or_else(|| anyhow!("unknown bot"))?.config;
    if cfg.is_group() {
        bail!("a group has no memory of its own");
    }
    Ok(cfg)
}

fn str_arg<'a>(b: &'a Value, k: &str) -> Result<&'a str> {
    b[k].as_str().ok_or_else(|| anyhow!("{k} required"))
}

fn int_arg(b: &Value, k: &str) -> Result<i64> {
    b[k].as_i64().ok_or_else(|| anyhow!("{k} required"))
}
