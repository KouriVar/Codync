//! Proactive follow-up (C0105): the three fixed-time routines on the lead bot, their editable times, and
//! the log of what it did on its own. Additive: it creates/edits routines only through the public
//! `Routines` API and keeps its own `kv` bookkeeping. Nothing about how routines run changes, except the
//! new optional `silent` flag the runner honours (off by default, so every existing routine is untouched).

use crate::hub::Hub;
use crate::routines::local_zone;
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::Duration;

/// What a run may do on its own; worded into every report instruction.
const SMALL: &str = "Small things you may do yourself and then report: read-only checks, summaries, \
organizing your memory, and changing reminders. Never do on your own: message other people, delete \
files, edit code, push, spend money, or change system settings. For anything else, first send the user \
a confirmation card that says exactly what you will do and why, and wait for their approval; if they \
do not answer, do not do it.";

const BRIEF: &str = "It is midday. In this chat, give the user a short report: in two or three sentences, \
only what you have done so far and anything you need them to decide. Read your memory and recent \
conversations to see what is in progress. SMALL If there is nothing to report, return exactly (pass).";

const SUMMARY: &str = "The day is ending. In this chat, give one full summary: what you finished today, \
what is still open, and what you suggest doing next. SMALL If there is nothing to report, return \
exactly (pass).";

const SILENT: &str = "Quietly organize your memory from today's conversations, using your memory tools. \
Do not send the user any message: when you are done, return exactly (pass).";

const K_BRIEF: &str = "proactive.brief";
const K_SUMMARY: &str = "proactive.summary";
const K_SILENT: &str = "proactive.silent";
const K_TIMES: &str = "proactive.times";
const K_DISABLED: &str = "proactive.checkInDisabled";
const K_LOG: &str = "proactive.actions";
const K_SEEN: &str = "proactive.seen";

const DEFAULT_TIMES: [(&str, &str); 3] = [("brief", "12:00"), ("summary", "20:00"), ("silent", "00:00")];

struct Report {
    key: &'static str,
    id_key: &'static str,
    name: &'static str,
    instruction: String,
    silent: bool,
}

fn reports() -> [Report; 3] {
    [
        Report { key: "brief", id_key: K_BRIEF, name: "Midday report", instruction: BRIEF.replace("SMALL", SMALL), silent: false },
        Report { key: "summary", id_key: K_SUMMARY, name: "Daily summary", instruction: SUMMARY.replace("SMALL", SMALL), silent: false },
        Report { key: "silent", id_key: K_SILENT, name: "Memory tidy", instruction: SILENT.to_owned(), silent: true },
    ]
}

pub fn start(hub: Arc<Hub>) {
    tokio::spawn(async move {
        // The lead bot is made asynchronously at startup; wait for it, then set the routines up.
        for _ in 0..120 {
            if lead(&hub).is_some() {
                break;
            }
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
        if let Some(bot) = lead(&hub) {
            if let Err(error) = ensure(&hub, &bot) {
                tracing::warn!(error = format!("{error:#}"), "couldn't set up the proactive routines");
            }
        }
        // The action log: fold each finished run of the three routines into `kv`; counts and short text only.
        loop {
            tokio::time::sleep(Duration::from_secs(20)).await;
            if let Some(bot) = lead(&hub) {
                if let Err(error) = scan_log(&hub, &bot) {
                    tracing::warn!(error = format!("{error:#}"), "couldn't record the proactive log");
                }
            }
        }
    });
}

pub async fn api_call(hub: &Arc<Hub>, method: &str, b: &Value) -> Result<Value> {
    let hub = hub.clone();
    let b = b.clone();
    let method = method.to_owned();
    tokio::task::spawn_blocking(move || match method.as_str() {
        "proactiveSettings" => settings(&hub),
        "proactiveSetTimes" => set_times(&hub, &b),
        "proactiveLog" => Ok(json!({ "entries": log_read(&hub) })),
        other => bail!("unknown proactive method: {other}"),
    })
    .await?
}

fn lead(hub: &Hub) -> Option<String> {
    hub.store.bots().ok()?.into_iter().find(|b| !b.deleted && b.config.lead).map(|b| b.config.id)
}

fn times(hub: &Hub) -> Vec<(String, String)> {
    let stored: Option<Value> = hub.store.kv_get(K_TIMES).and_then(|v| serde_json::from_str(&v).ok());
    DEFAULT_TIMES
        .iter()
        .map(|(key, fallback)| {
            let value = stored.as_ref().and_then(|v| v[key].as_str()).map(str::to_owned).unwrap_or_else(|| (*fallback).to_owned());
            ((*key).to_owned(), value)
        })
        .collect()
}

/// `"HH:MM"` → a five-field cron in the host's time zone.
fn cron(at: &str) -> Result<(String, String)> {
    let (hour, minute) = at.split_once(':').context("time must be HH:MM")?;
    let hour: u32 = hour.trim().parse().context("bad hour")?;
    let minute: u32 = minute.trim().parse().context("bad minute")?;
    if hour > 23 || minute > 59 {
        bail!("time out of range");
    }
    Ok((format!("{minute} {hour} * * *"), local_zone()))
}

/// Creates the three routines if missing, keeps their schedule in step with the saved times, and retires
/// the upstream default "Check in" (twice a day) once so only these three times report.
fn ensure(hub: &Hub, bot: &str) -> Result<()> {
    let times = times(hub);
    let listed = hub.routines.list(bot);
    for report in reports() {
        let at = times.iter().find(|(k, _)| k == report.key).map(|(_, v)| v.clone()).unwrap_or_default();
        let (expression, zone) = cron(&at)?;
        let found = hub
            .store
            .kv_get(report.id_key)
            .and_then(|id| listed["routines"].as_array().and_then(|rs| rs.iter().find(|r| r["id"] == id.as_str())).cloned());
        let same_trigger = found
            .as_ref()
            .and_then(|r| r["triggers"].as_array().and_then(|t| t.first()).and_then(|t| t["expression"].as_str()))
            .is_some_and(|e| e == expression);
        let up_to_date = found
            .as_ref()
            .is_some_and(|r| r["enabled"] == true && r["silent"] == report.silent && same_trigger);
        if up_to_date {
            continue;
        }
        let mut body = json!({
            "name": report.name,
            "instruction": report.instruction,
            "triggers": [{"type": "cron", "expression": expression, "timeZone": zone}],
            "silent": report.silent,
            "enabled": true,
        });
        if let Some(id) = found.as_ref().and_then(|r| r["id"].as_str()) {
            body["id"] = Value::String(id.to_owned());
        }
        let saved = hub.routines.save(hub, bot, &body)?;
        if let Some(id) = saved["routine"]["id"].as_str() {
            hub.store.kv_set(report.id_key, id)?;
        }
    }
    // Retire the upstream default check-in once, so the user gets exactly these three times.
    if hub.store.kv_get(K_DISABLED).is_none() {
        if let Some(id) = hub.store.kv_get("lead.checkIn") {
            let _ = hub.routines.set_enabled(&hub.store, bot, &id, false);
        }
        hub.store.kv_set(K_DISABLED, "1")?;
    }
    Ok(())
}

fn settings(hub: &Hub) -> Result<Value> {
    let times = times(hub);
    let map: serde_json::Map<String, Value> = times.iter().map(|(k, v)| (k.clone(), Value::String(v.clone()))).collect();
    let routines = match lead(hub) {
        Some(bot) => {
            let ids: Vec<String> = reports().iter().filter_map(|r| hub.store.kv_get(r.id_key)).collect();
            hub.routines.list(&bot)["routines"]
                .as_array()
                .map(|rs| rs.iter().filter(|r| r["id"].as_str().is_some_and(|id| ids.iter().any(|x| x == id))).cloned().collect::<Vec<_>>())
                .unwrap_or_default()
        }
        None => Vec::new(),
    };
    Ok(json!({ "times": map, "routines": routines }))
}

fn set_times(hub: &Hub, b: &Value) -> Result<Value> {
    let mut next = Vec::new();
    for (key, fallback) in DEFAULT_TIMES {
        let value = b[key].as_str().unwrap_or(fallback).trim().to_owned();
        cron(&value)?;
        next.push((key.to_owned(), value));
    }
    let map: serde_json::Map<String, Value> = next.iter().map(|(k, v)| (k.clone(), Value::String(v.clone()))).collect();
    hub.store.kv_set(K_TIMES, &serde_json::to_string(&map)?)?;
    if let Some(bot) = lead(hub) {
        ensure(hub, &bot)?;
    }
    settings(hub)
}

/// Folds the newly finished runs of the three routines into the log.
fn scan_log(hub: &Hub, bot: &str) -> Result<()> {
    let ids: Vec<String> = reports().iter().filter_map(|r| hub.store.kv_get(r.id_key)).collect();
    if ids.is_empty() {
        return Ok(());
    }
    let names: HashMap<String, &str> = reports()
        .iter()
        .filter_map(|r| hub.store.kv_get(r.id_key).map(|id| (id, r.name)))
        .collect();
    let listed = hub.routines.list(bot);
    let mut seen: HashSet<String> =
        hub.store.kv_get(K_SEEN).and_then(|v| serde_json::from_str::<Vec<String>>(&v).ok()).unwrap_or_default().into_iter().collect();
    let mut entries = log_read(hub);
    let mut added = false;
    for run in listed["runs"].as_array().into_iter().flatten() {
        let id = run["id"].as_str().unwrap_or_default();
        let routine_id = run["routineId"].as_str().unwrap_or_default();
        if !ids.iter().any(|x| x == routine_id) || seen.contains(id) || run["finishedAt"].as_i64().is_none() {
            continue;
        }
        let status = run["status"].as_str().unwrap_or_default();
        if status != "succeeded" && status != "failed" {
            continue;
        }
        let raw = run["result"].as_str().or(run["detail"].as_str()).unwrap_or_default().trim();
        let summary = if super::recall::sensitive(raw) { "(redacted)".to_owned() } else { truncate(raw, 240) };
        entries.push(json!({
            "at": run["finishedAt"].as_i64().unwrap_or_default(),
            "routine": names.get(routine_id).copied().unwrap_or("Routine"),
            "status": status,
            "summary": summary,
        }));
        seen.insert(id.to_owned());
        added = true;
    }
    if added {
        entries.sort_by(|a, b| b["at"].as_i64().cmp(&a["at"].as_i64()));
        entries.truncate(300);
        hub.store.kv_set(K_LOG, &serde_json::to_string(&entries)?)?;
        let mut all: Vec<String> = seen.into_iter().collect();
        if all.len() > 1000 {
            all.drain(0..all.len() - 1000);
        }
        hub.store.kv_set(K_SEEN, &serde_json::to_string(&all)?)?;
    }
    Ok(())
}

fn log_read(hub: &Hub) -> Vec<Value> {
    hub.store.kv_get(K_LOG).and_then(|v| serde_json::from_str::<Vec<Value>>(&v).ok()).unwrap_or_default()
}

fn truncate(text: &str, max: usize) -> String {
    text.chars().take(max).collect()
}
