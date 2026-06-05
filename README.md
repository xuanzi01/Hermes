# Hermes

> 个人 AI Agent 系统配置备份

## 包含内容

- `config-template.yaml` — 脱敏配置模板
- `.env.example` — 环境变量空模板
- `skills/` — 自定义 Skills
- `memories/` — 用户偏好和记忆
- `cron/jobs.json` — 定时任务定义
- `references.md` — 配置参考文档
- `jobs.json` — Cron 任务配置备份

## 恢复流程

1. `git clone` 本仓库
2. 复制 `config-template.yaml` → `~/.hermes/config.yaml`
3. 创建 `~/.hermes/.env`，填入真实 keys（参考 `.env.example`）
4. 复制 `skills/` 到 `~/.hermes/skills/`
5. 复制 `memories/` 到 `~/.hermes/memories/`
6. `hermes config check` 验证配置

## 敏感信息

**不要**把 `.env` 或包含真实 API key 的配置文件推上来。
所有 keys 必须放在 `.env` 中，不在 Git 管理范围内。
