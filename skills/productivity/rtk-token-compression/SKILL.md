---
name: rtk-token-compression
description: "RTK (Reduce Token Konsumption) — compress shell command output to reduce LLM token consumption 60-90%. Installs as Hermes plugin, intercepts and rewrites terminal commands."
version: 1.0.0
author: foxx
tags: [rtk, token-reduction, compression, shell, hermes-plugin]
triggers:
  - "reduce token"
  - "compress shell output"
  - "RTK"
  - "token saving"
  - "shell output too long"
---

# RTK Token Compression

RTK (Reduce Token Konsumption) is a CLI proxy + Hermes plugin that compresses shell command output, reducing LLM token consumption by 60-90%.

## What it does

Intercepts terminal commands, executes them, then compresses the output before returning it to the conversation context. The LLM sees a condensed version instead of raw verbose output.

**Supported commands:** `ls`, `tree`, `read`, `git`, `gh`, `glab`, `aws`, `psql`, `pnpm`, `err`, `test`, `json`, `deps`, `env`, `npm`, `yarn`, and more.

## Installation

### Binary (for direct shell use)

```bash
curl -fsSL https://raw.githubusercontent.com/rtk/rtk/main/install.sh | bash
# Installs to ~/.local/bin/rtk
```

### Hermes Plugin (recommended — auto-intercepts all commands)

```bash
# Must use absolute path since PATH may not include ~/.local/bin
~/.local/bin/rtk init -g --agent hermes

# For Docker deployments with HERMES_HOME=/opt/data:
/opt/data/home/.local/bin/rtk init -g --agent hermes
```

The plugin installs to:
- `/opt/data/plugins/rtk-rewrite` (plugin code)
- `/opt/data/config.yaml` (Hermes config — plugin entry added)

**Restart Hermes required** after plugin install.

## Docker Deployment Path Mapping

When `HERMES_HOME=/opt/data` (Docker/1Panel deployment):
- Config: `/opt/data/config.yaml` (NOT `~/.hermes/config.yaml`)
- RTK binary: `/opt/data/home/.local/bin/rtk`
- Plugin dir: `/opt/data/plugins/rtk-rewrite`

## Restart Domains (important)

In Docker deployments, there are **two separate restart domains**:

| What | How | What restarts |
|------|-----|---------------|
| Gateway restart | `/restart` slash command | Platform handlers (Feishu, Telegram, etc.) — RTK plugin does NOT reload |
| Full Hermes restart | 1Panel panel / systemctl | Sandbox execution environment + gateway — RTK plugin loads |

**Key:** RTK plugin requires a **full Hermes restart**, not just gateway restart. `/restart` won't activate the plugin.

## Common Issues

### "rtk: command not found" in Hermes terminal

**Cause:** PATH in `.env` (`export PATH="/opt/data/home/.local/bin:$PATH"`) is read at Hermes startup but does NOT propagate to shell subprocesses spawned by the terminal tool.

**Solution:** Install RTK as Hermes plugin (`rtk init -g --agent hermes`) — bypasses PATH entirely by rewriting commands at the Hermes layer.

### "rtk: command not found" — Plugin Layer (Docker PATH issue)

Even after `rtk init -g --agent hermes` and full Hermes restart, the plugin fails with "rtk: command not found" because the plugin's `__init__.py` hardcodes `subprocess.run(["rtk", "rewrite", ...])` without an absolute path.

**Diagnosis:**
```python
# /opt/data/plugins/rtk-rewrite/__init__.py
result = subprocess.run(["rtk", "rewrite", command], ...)  # "rtk" not in PATH for Hermes process
_rtk_available = shutil.which("rtk") is not None  # also fails
```

**Fix — patch the plugin directly (no restart needed):**

```python
# Step 1: Add os import
import os

# Step 2: Fix which() check
_rtk_available = os.path.exists("/opt/data/home/.local/bin/rtk")

# Step 3: Fix subprocess call
result = subprocess.run(
    ["/opt/data/home/.local/bin/rtk", "rewrite", command],
    shell=False,
    timeout=2,
    capture_output=True,
    text=True,
)
```

File: `/opt/data/plugins/rtk-rewrite/__init__.py`

**Why no restart needed:** The plugin is re-imported from disk on every command. The patched code takes effect on the next terminal command.

### No Docker/systemd access to restart

**Cause:** Running in sandbox container without Docker socket or systemd.

**Solution:** Use 1Panel panel restart, or ask user to send `/restart` from a gateway-connected platform (but note this only restarts gateway, not the plugin).

## Verification

After full Hermes restart:
```bash
git status
# Output should be compressed (fewer lines, token-efficient format)
```

With plugin active, RTK shows no "No hook installed" warning.

## Reference

- RTK GitHub: https://github.com/rtk/rtk
- RTK Hermes plugin: https://github.com/ogallotti/rtk-hermes
- Version installed: 0.42.0
