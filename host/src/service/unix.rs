//! The background service on macOS (a launchd agent) and Linux (a systemd user unit).

use super::{create_parent, current_exe, data_dir, home, run, wait_for_host_exit};
use anyhow::{Context, Result, bail};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const LABEL: &str = crate::environment::Environment::current().service_label();
const UNIT: &str = crate::environment::Environment::current().systemd_unit();

/// Stops the installed job, preserving its configuration for a later start.
/// A manually started daemon is never mistaken for the service we own.
pub fn stop() -> Result<()> {
    if cfg!(target_os = "macos") {
        let _ = Command::new("launchctl")
            .args(["bootout", &format!("gui/{}/{LABEL}", current_uid())])
            .stderr(Stdio::null())
            .status()?;
    } else if installed() {
        run("systemctl", &["--user", "stop", UNIT])?;
    }
    wait_for_host_exit()
}

pub fn start() -> Result<()> {
    if cfg!(target_os = "macos") {
        run("launchctl", &["bootstrap", &format!("gui/{}", current_uid()), &launchd_plist().to_string_lossy()])
    } else {
        run("systemctl", &["--user", "start", UNIT])
    }
}

/// Whether launchd or systemd started this process as the installed service, not a terminal or
/// the desktop app's development run.
pub fn started_by_service() -> bool {
    if cfg!(target_os = "macos") {
        // launchd names the job; a process started from a terminal or an app has another name.
        std::env::var("XPC_SERVICE_NAME").is_ok_and(|name| name == LABEL)
    } else {
        // systemd (248+) names the service's main process; a shell inherits its terminal's.
        std::env::var("SYSTEMD_EXEC_PID").is_ok_and(|pid| pid == std::process::id().to_string())
    }
}

/// Refuse to replace one installation while restarting a service owned by another.
pub fn require_executable(expected: &Path) -> Result<()> {
    let configured = if cfg!(target_os = "macos") {
        let output = Command::new("/usr/bin/plutil")
            .args(["-extract", "ProgramArguments.0", "raw", "-o", "-"])
            .arg(launchd_plist())
            .output()?;
        if !output.status.success() {
            bail!("cannot read the installed host service");
        }
        PathBuf::from(String::from_utf8(output.stdout)?.trim())
    } else {
        let unit = std::fs::read_to_string(systemd_unit())?;
        let command =
            unit.lines().find_map(|line| line.strip_prefix("ExecStart=")).context("service has no ExecStart")?;
        let args = shlex::split(command).context("invalid service ExecStart")?;
        let exe = args.first().context("service has no executable")?;
        PathBuf::from(exe.replace("%%", "%").replace("$$", "$"))
    };
    if configured.canonicalize()? != expected.canonicalize()? {
        bail!("the installed service runs another host binary; run that binary's update command");
    }
    Ok(())
}

fn launchd_plist() -> PathBuf {
    home().join(format!("Library/LaunchAgents/{LABEL}.plist"))
}

fn systemd_unit() -> PathBuf {
    dirs::config_dir().unwrap_or_else(|| home().join(".config")).join("systemd/user").join(UNIT)
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;")
}

/// One quoted systemd word: a PATH with spaces (WSL's `Program Files`) stays whole, and `%`
/// is never read as a specifier. `ExecStart` also expands `$`, so it is doubled there.
fn systemd_quote(s: &str, exec: bool) -> String {
    let s = s.replace('\\', "\\\\").replace('"', "\\\"").replace('%', "%%");
    format!("\"{}\"", if exec { s.replace('$', "$$") } else { s })
}

/// The environment keys a rewrite must carry over so the owner's settings survive an install.
const PRESERVED_ENV: [&str; 2] = ["CODYNC_CLOUD", "CODYNC_EXTERNAL_URL"];

/// `key`'s raw (already XML-escaped) value in an existing plist's `EnvironmentVariables`.
fn env_value_in(text: &str, key: &str) -> Option<String> {
    let marker = format!("<key>{key}</key>");
    let start = text.find(&marker)? + marker.len();
    let rest = &text[start..];
    let open = rest.find("<string>")? + "<string>".len();
    let close = rest[open..].find("</string>")?;
    Some(rest[open..open + close].to_owned())
}

/// The environment variables to keep when rewriting the plist: the values already in it, else the
/// ones in this process's environment. Only `CODYNC_CLOUD` and `CODYNC_EXTERNAL_URL` are carried.
fn preserved_env(existing: Option<&str>) -> Vec<(String, String)> {
    PRESERVED_ENV
        .iter()
        .filter_map(|key| {
            if let Some(text) = existing {
                if let Some(value) = env_value_in(text, key) {
                    return Some(((*key).to_owned(), value));
                }
            }
            std::env::var(key).ok().filter(|value| !value.is_empty()).map(|value| ((*key).to_owned(), xml_escape(&value)))
        })
        .collect()
}

/// The launchd agent's plist text. `extra` holds preserved `key`/`value` pairs whose values are
/// already XML-escaped; they are appended to `EnvironmentVariables`.
fn launchd_plist_xml(exe: &str, path: &str, data: &str, log: &str, port: u16, extra: &[(String, String)]) -> String {
    let extra: String =
        extra.iter().map(|(key, value)| format!("<key>{key}</key><string>{value}</string>")).collect();
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>{LABEL}</string>
  <key>ProgramArguments</key><array><string>{exe}</string><string>serve</string><string>--port</string><string>{port}</string></array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>{path}</string><key>CODYNC_HOME</key><string>{data}</string>{extra}</dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>{log}</string>
  <key>StandardErrorPath</key><string>{log}</string>
</dict>
</plist>
"#,
        exe = xml_escape(exe),
        path = xml_escape(path),
        data = xml_escape(data),
        log = xml_escape(log),
    )
}

/// Installs and starts the host as a per-user background service. The current
/// PATH is captured so the service finds `npx`, `claude`, `codex`, …
pub fn install(port: u16) -> Result<()> {
    let exe = current_exe().context("locating the codync-host binary")?;
    let exe = exe.to_string_lossy();
    let path = std::env::var("PATH").unwrap_or_default();
    let log = data_dir().join("host.log");
    std::fs::create_dir_all(data_dir()).context("creating the data directory")?;
    if cfg!(target_os = "macos") {
        let file = launchd_plist();
        // A rewrite must not drop the owner's settings that live only in this plist
        // (`CODYNC_CLOUD`, `CODYNC_EXTERNAL_URL`).
        let existing = std::fs::read_to_string(&file).ok();
        let extra = preserved_env(existing.as_deref());
        let plist = launchd_plist_xml(
            &exe,
            &path,
            &data_dir().to_string_lossy(),
            &log.to_string_lossy(),
            port,
            &extra,
        );
        create_parent(&file)?;
        let uid = current_uid();
        // Not loaded yet is the normal case here.
        let _ =
            Command::new("launchctl").args(["bootout", &format!("gui/{uid}/{LABEL}")]).stderr(Stdio::null()).status();
        wait_for_host_exit()?;
        std::fs::write(&file, plist).with_context(|| format!("writing {}", file.display()))?;
        run("launchctl", &["bootstrap", &format!("gui/{uid}"), &file.to_string_lossy()])?;
    } else {
        let unit = format!(
            "[Unit]\nDescription=Codync host\nAfter=network-online.target\n\n[Service]\nExecStart={exe} serve --port {port}\nEnvironment={path}\nEnvironment={data}\nRestart=always\nRestartSec=3\n\n[Install]\nWantedBy=default.target\n",
            exe = systemd_quote(&exe, true),
            path = systemd_quote(&format!("PATH={path}"), false),
            data = systemd_quote(&format!("CODYNC_HOME={}", data_dir().display()), false),
        );
        let file = systemd_unit();
        create_parent(&file)?;
        std::fs::write(&file, unit).with_context(|| format!("writing {}", file.display()))?;
        run("systemctl", &["--user", "daemon-reload"])?;
        run("systemctl", &["--user", "stop", UNIT])?;
        wait_for_host_exit()?;
        run("systemctl", &["--user", "enable", "--now", UNIT])?;
        println!("Tip: `loginctl enable-linger $USER` keeps the host running while you're logged out.");
    }
    Ok(())
}

/// Best effort: every step tolerates "already gone".
pub fn uninstall() {
    if cfg!(target_os = "macos") {
        let _ = Command::new("launchctl")
            .args(["bootout", &format!("gui/{}/{LABEL}", current_uid())])
            .stderr(Stdio::null())
            .status();
        let _ = std::fs::remove_file(launchd_plist());
    } else {
        let _ = run("systemctl", &["--user", "disable", "--now", UNIT]);
        let _ = std::fs::remove_file(systemd_unit());
        let _ = run("systemctl", &["--user", "daemon-reload"]);
    }
}

pub fn installed() -> bool {
    if cfg!(target_os = "macos") { launchd_plist().exists() } else { systemd_unit().exists() }
}

fn current_uid() -> String {
    Command::new("id")
        .arg("-u")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map_or_else(|| "501".into(), |s| s.trim().to_owned())
}

#[cfg(test)]
mod tests {
    use super::{launchd_plist_xml, preserved_env, systemd_quote};

    #[test]
    fn unit_values_stay_one_word() {
        let path = r#"/usr/bin:/mnt/c/Program Files/a"b\c:/x%y"#;
        assert_eq!(
            systemd_quote(&format!("PATH={path}"), false),
            r#""PATH=/usr/bin:/mnt/c/Program Files/a\"b\\c:/x%%y""#
        );
        let exe = systemd_quote("/home/me/My $bin/codync-host", true);
        assert_eq!(exe, r#""/home/me/My $$bin/codync-host""#);
        let parsed = shlex::split(&format!("{exe} serve")).unwrap();
        assert_eq!(parsed[0].replace("%%", "%").replace("$$", "$"), "/home/me/My $bin/codync-host");
    }

    #[test]
    fn a_rewrite_keeps_the_owners_cloud_and_url_settings() {
        let old = r#"<plist version="1.0"><dict>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/bin</string>
  <key>CODYNC_HOME</key><string>/Users/me/.codync</string>
  <key>CODYNC_CLOUD</key><string>off</string>
  <key>CODYNC_EXTERNAL_URL</key><string>https://bot.suiyk.link</string></dict>
</dict></plist>"#;
        let extra = preserved_env(Some(old));
        assert!(extra.iter().any(|(k, v)| k == "CODYNC_CLOUD" && v == "off"));
        assert!(extra.iter().any(|(k, v)| k == "CODYNC_EXTERNAL_URL" && v == "https://bot.suiyk.link"));
        let xml = launchd_plist_xml("/x/codync-host", "/bin", "/Users/me/.codync", "/Users/me/.codync/host.log", 19222, &extra);
        assert!(xml.contains("<key>CODYNC_CLOUD</key><string>off</string>"), "{xml}");
        assert!(xml.contains("<key>CODYNC_EXTERNAL_URL</key><string>https://bot.suiyk.link</string>"), "{xml}");
        // The other variables are still there.
        assert!(xml.contains("<key>CODYNC_HOME</key><string>/Users/me/.codync</string>"), "{xml}");
    }

    #[test]
    fn preserved_values_are_not_escaped_twice() {
        let old = r#"<dict><key>CODYNC_EXTERNAL_URL</key><string>https://x.test/?a=1&amp;b=2</string></dict>"#;
        let extra = preserved_env(Some(old));
        let xml = launchd_plist_xml("/x", "/bin", "/d", "/d/log", 1, &extra);
        assert!(xml.contains("https://x.test/?a=1&amp;b=2"), "{xml}");
        assert!(!xml.contains("&amp;amp;"), "{xml}");
    }
}
