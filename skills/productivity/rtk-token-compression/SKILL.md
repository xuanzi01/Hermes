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
# Terminal/物理机部署（HERMES_HOME=~/.hermes）
~/.local/bin/rtk init -g --agent hermes

# Docker/1Panel 部署（HERMES_HOME=/opt/data）
/opt/data/home/.local/bin/rtk init -g --agent hermes
```

Plugin 安装后自动写入 `config.yaml` 的 `plugins.enabled`，无需手动配置。

**Restart Hermes required** after plugin install.

## 部署路径对照

| 部署方式 | RTK 二进制路径 | Plugin 目录 | Config |
|--------|--------------|------------|--------|
| 终端/物理机（当前） | `/root/.hermes/home/.local/bin/rtk` | `/root/.hermes/plugins/rtk-rewrite` | `/root/.hermes/config.yaml` |
| Docker/1Panel | `/opt/data/home/.local/bin/rtk` | `/opt/data/plugins/rtk-rewrite` | `/opt/data/config.yaml` |

## Restart Domains (Docker部署需注意)

| What | How | What restarts |
|------|-----|---------------|
| Gateway restart | `/restart` slash command | Platform handlers — RTK plugin **不**重载 |
| Full Hermes restart | 1Panel panel / systemctl | Sandbox + gateway — RTK plugin 加载 |

**Key:** RTK plugin 需要 **full Hermes restart**，`/restart`不会激活插件。

## Common Issues

### "rtk: command not found" — Plugin Layer

Plugin 的 `__init__.py` 硬编码了 RTK 二进制路径，必须与实际安装路径一致。

**诊断：**
```python
# /root/.hermes/plugins/rtk-rewrite/__init__.py（终端部署）
# 或 /opt/data/plugins/rtk-rewrite/__init__.py（Docker 部署）
_rtk_available = os.path.exists("<此处路径>")
```

**Fix — patch the plugin directly（无需重启，立即生效）：**

```python
# Step 1: 确认 RTK 实际安装路径
ls /root/.hermes/home/.local/bin/rtk  # 终端部署
ls /opt/data/home/.local/bin/rtk       # Docker 部署

# Step 2: Patch __init__.py（两处路径必须同时改）
# 改1: _check_rtk() 中的路径判断
_rtk_available = os.path.exists("/root/.hermes/home/.local/bin/rtk")

# 改2: subprocess.run() 中的调用路径
["/root/.hermes/home/.local/bin/rtk", "rewrite", command],
```

File: `/root/.hermes/plugins/rtk-rewrite/__init__.py`（终端部署）

**Why no restart needed:** 插件每次命令执行时从磁盘重新导入，patch 后下一条命令立即生效。

## Verification

```bash
# 确认 Hook 注册成功（插件加载时会输出一行 warn 日志，第一次执行终端命令后可在 Hermes 日志中确认）
git status
# 输出被压缩则插件工作正常
```

## Reference

- RTK GitHub: https://github.com/rtk/rtk
- RTK Hermes plugin: https://github.com/ogallotti/rtk-hermes
- Version installed: 0.42.0
