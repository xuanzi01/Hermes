# RTK + Hermes Docker Deployment — Key Discoveries

## 1. Two Restart Domains

In a Docker-deployed Hermes (1Panel, HERMES_HOME=/opt/data), there are two separate restart mechanisms with different effects:

| Command | Scope | RTK Plugin Reloads? |
|---------|-------|---------------------|
| `/restart` (Feishu slash) | Gateway process only | ❌ No — platform handlers restart |
| 1Panel restart / systemctl | Full container restart | ✅ Yes — sandbox + gateway |

**Lesson:** Sending `/restart` from Feishu only restarts the messaging gateway, NOT the execution environment where the RTK plugin runs. Must use 1Panel panel or host-level restart.

## 2. PATH Inheritance Failure in Sandbox

**Problem:** RTK binary at `/opt/data/home/.local/bin/rtk` is not on PATH for shell subprocesses spawned by the Hermes terminal tool.

**Root cause:** The `.env` file (at `/opt/data/.env`) contains `export PATH="/opt/data/home/.local/bin:$PATH"`, but Hermes shell subprocesses do NOT source `.env`. The PATH is set at the Hermes process level, not inherited by child processes.

**Evidence:**
```bash
# In Hermes terminal tool:
$ echo $PATH
/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
# /opt/data/home/.local/bin is MISSING

# Direct absolute path works:
$ /opt/data/home/.local/bin/rtk --version
rtk 0.42.0
```

## 3. Plugin Install Bypasses PATH Issue

`rtk init -g --agent hermes` installs the RTK plugin directly into Hermes's command rewrite layer. It intercepts commands before spawning a shell, so PATH is irrelevant.

**Install command (Docker path):**
```bash
/opt/data/home/.local/bin/rtk init -g --agent hermes
```

Output confirms Docker paths:
```
RTK configured for Hermes.
  Plugin: /opt/data/plugins/rtk-rewrite
  Config: /opt/data/config.yaml
  Hermes will now rewrite terminal commands through rtk.
Restart Hermes. Test with: git status
```

## 4. Config.yaml Location in Docker

`hermes config edit` writes to `/opt/data/config.yaml` (HERMES_HOME), NOT `~/.hermes/config.yaml`. This is the Docker path mapping.

## 5. Verification After Restart

After full Hermes restart, confirm plugin is active:
```bash
# Should show compressed output, no "No hook installed" warning
git status
ls -la /opt/data
```

If "No hook installed" still appears, the full restart did not complete — check 1Panel.
