use anyhow::{Context, Result};
use regex::Regex;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use crate::error::InfisicalError;

// ── dc CLI wrapper ────────────────────────────────────────────────────────────

/// Known dc redaction masks — must never be treated as real secret values.
pub fn is_redaction_sentinel(value: &str) -> bool {
    matches!(value, "🔒 **redacted**" | "**redacted**")
        || (value.contains("**redacted**") && value.len() <= 32)
}

/// Run `dc get <scope> <item_path>` with `--reveal --raw` so encrypted
/// `.envrc.dc` values decrypt. Without `--reveal`, dc emits a redaction
/// mask that must not be pushed into Infisical.
// ⟦𓎫𓄋𓈕𓉩⟧ dc_get :: Run `dc get <scope> <item_path>` and return the value string
pub fn dc_get(scope: &str, item_path: &str) -> Result<String> {
    let output = std::process::Command::new("dc")
        .args(["get", scope, item_path, "--reveal", "--raw"])
        .output()
        .context("run dc get — is 'dc' on PATH?")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(InfisicalError::DcCli(format!(
            "dc get {scope} {item_path}: {stderr}"
        ))
        .into());
    }

    let value = String::from_utf8_lossy(&output.stdout).trim().to_owned();
    if is_redaction_sentinel(&value) {
        return Err(InfisicalError::DcCli(format!(
            "dc get {scope} {item_path}: resolved to redaction sentinel (refusing)"
        ))
        .into());
    }
    Ok(value)
}

/// Run `dc set <scope> <item_path> <value>`
// ⟦𓎩𓅱𓈧𓄎⟧ dc_set :: Run `dc set <scope> <item_path> <value>`
pub fn dc_set(scope: &str, item_path: &str, value: &str) -> Result<()> {
    let status = std::process::Command::new("dc")
        .args(["set", scope, item_path, value])
        .status()
        .context("run dc set")?;

    if !status.success() {
        return Err(InfisicalError::DcCli(format!(
            "dc set {scope} {item_path}: exited {status}"
        ))
        .into());
    }
    Ok(())
}

/// Try `dc get`, return None on failure (for optional lookups)
// ⟦𓄾𓂘𓍺𓊢⟧ dc_get_optional :: Try `dc get`, return None on failure (for optional lookups)
pub fn dc_get_optional(scope: &str, item_path: &str) -> Option<String> {
    dc_get(scope, item_path).ok().filter(|s| !s.is_empty())
}

// ── .envrc.dc parser ──────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct DcDirective {
    pub line_number: usize,
    pub scope: String,
    pub item_path: String,
    pub raw_line: String,
}

static DC_REGEX: OnceLock<Regex> = OnceLock::new();

fn dc_regex() -> &'static Regex {
    DC_REGEX.get_or_init(|| {
        Regex::new(r"dc\s+get\s+(\S+)\s+(\S+)").unwrap()
    })
}

/// Parse all `dc get SCOPE ITEM.PATH` directives from a .envrc.dc file
// ⟦𓇏𓌮𓅲𓈅⟧ parse_envrc_dc :: Parse all `dc get SCOPE ITEM.PATH` directives from a .envrc.dc file
pub fn parse_envrc_dc(path: &Path) -> Result<Vec<DcDirective>> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("read {:?}", path))?;

    let re = dc_regex();
    let mut results = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        if let Some(caps) = re.captures(line) {
            results.push(DcDirective {
                line_number: idx + 1,
                scope: caps[1].to_owned(),
                item_path: caps[2].to_owned(),
                raw_line: line.to_owned(),
            });
        }
    }

    Ok(results)
}

/// Find a specific directive by scope + item_path
// ⟦𓐬𓈚𓈈𓍐⟧ find_dc_directive :: Find a specific directive by scope + item_path
pub fn find_dc_directive(
    path: &Path,
    scope: &str,
    item_path: &str,
) -> Result<Option<DcDirective>> {
    let directives = parse_envrc_dc(path)?;
    Ok(directives
        .into_iter()
        .find(|d| d.scope == scope && d.item_path == item_path))
}

/// Replace the content of a specific line in a file (1-indexed)
#[allow(dead_code)]
// ⟦𓎧𓈬𓁃𓈸⟧ edit_line :: Replace the content of a specific line in a file (1-indexed)
pub fn edit_line(path: &Path, line_number: usize, new_content: &str, backup: bool) -> Result<()> {
    let content = std::fs::read_to_string(path)?;
    let mut lines: Vec<&str> = content.lines().collect();

    if line_number == 0 || line_number > lines.len() {
        anyhow::bail!("line {} out of range (file has {} lines)", line_number, lines.len());
    }

    if backup {
        let bak = format!("{}.bak", path.display());
        std::fs::copy(path, &bak)?;
    }

    lines[line_number - 1] = new_content;
    std::fs::write(path, lines.join("\n") + "\n")?;
    Ok(())
}

// ── .envrc.dc discovery ───────────────────────────────────────────────────────

/// Walk up from cwd to find .envrc.dc
// ⟦𓀾𓁛𓌑𓃄⟧ find_envrc_dc :: Walk up from cwd to find .envrc.dc
pub fn find_envrc_dc() -> Result<PathBuf> {
    let mut dir = std::env::current_dir()?;
    loop {
        let candidate = dir.join(".envrc.dc");
        if candidate.exists() {
            return Ok(candidate);
        }
        if !dir.pop() {
            break;
        }
    }
    Err(InfisicalError::EnvrcNotFound.into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::Mutex;

    // Serialize PATH mutation across tests.
    static PATH_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn redaction_sentinel_matches_known_masks() {
        assert!(is_redaction_sentinel("🔒 **redacted**"));
        assert!(is_redaction_sentinel("**redacted**"));
        assert!(is_redaction_sentinel("x **redacted**"));
        assert!(!is_redaction_sentinel(
            "a-real-64-byte-secret-value-that-is-long-enough-abcdefghij"
        ));
        assert!(!is_redaction_sentinel(""));
        // Long string that merely mentions the token should not match (len > 32)
        assert!(!is_redaction_sentinel(
            "note: values looking like **redacted** should not appear in production dumps ever"
        ));
    }

    #[test]
    fn dc_get_requires_reveal_and_rejects_sentinel() {
        let _guard = PATH_LOCK.lock().unwrap();
        let dir = tempfile_dir();
        let mock = dir.join("dc");
        // Mock dc: without --reveal return redaction; with --reveal return real value.
        fs::write(
            &mock,
            r#"#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "$args" == *"--reveal"* ]]; then
  printf '%s' 'real-secret-value-from-mock-dc-abcdefghijklmnopqrstuvwxyz012345'
  exit 0
fi
printf '%s' '🔒 **redacted**'
exit 0
"#,
        )
        .unwrap();
        let mut perms = fs::metadata(&mock).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&mock, perms).unwrap();

        let old_path = std::env::var("PATH").unwrap_or_default();
        std::env::set_var("PATH", format!("{}:{}", dir.display(), old_path));

        let got = dc_get("services", "apps.test_secret").expect("dc_get should reveal");
        assert_eq!(
            got,
            "real-secret-value-from-mock-dc-abcdefghijklmnopqrstuvwxyz012345"
        );
        assert!(!is_redaction_sentinel(&got));

        // Without our --reveal flags, mock would emit sentinel — ensure our
        // helper would refuse that string if it ever appeared.
        assert!(is_redaction_sentinel("🔒 **redacted**"));

        std::env::set_var("PATH", old_path);
        let _ = fs::remove_dir_all(&dir);
    }

    fn tempfile_dir() -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "secret-utils-dc-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }
}
