# Hermes 系统配置参考

> 详细部署配置，由 memory tool 中精简后的引用指向此处。
> 更新于：2026-05-28

## Docker 部署

- Docker 容器，PID 1 为 docker-init
- entrypoint: `/opt/hermes/docker/entrypoint.sh`
- 容器内从 root 降为 hermes 用户（gosu），**无 sudo**
- 安装系统依赖：从宿主机 `docker exec -u root <container>`
- HERMES_HOME: `/opt/data`（非 ~/.hermes）
- hermes 命令: `/opt/hermes/.venv/bin/hermes`，软链到 `~/.local/bin/hermes`
- Dashboard: `0.0.0.0:9119`
- Kanban DB: `/opt/data/kanban.db`

## 工具配置要点

### 飞书 CLI
- 内容写入用 `--content -` + heredoc（不能用 `--content "字符串"`）
- `--title` 与 `--content` 同时用时不生效，需 `str_replace` 修复标题
- `wiki +move` 移文档到知识库
- `--doc-format markdown` 可正确解析 Markdown
- OAuth 用 `--recommend` 一次性授权
- 用户身份：璇子
- 知识库空间 ID：`7644558327271230430`
- 飞书 CLI 使用 OAuth 用户授权，与开发者平台应用权限是两套系统

### RTK (Rust Token Killer)
- 版本 v0.42.0
- Hermes 插件已启用
- 可减少 shell 命令 60-90% token 消耗

### 知识星球 (zsxq-cli)
- 使用 OAuth 2.0 Device Flow，Token 存储在系统 Keychain
- Docker 容器环境无 Keychain 服务（gnome-keyring/libsecret），标准 `auth login` 走不通
- 用户有 MCP 开发者平台密钥 `7a9384f34ac8bd2182f0da05e8528d84`（非 OAuth Token，返回 401）
- **解决方案**：本地电脑完成 OAuth → 导出 Token → 配置环境变量

### Camofox 浏览器
- 已安装，在 curl 被反爬时优先使用
- 取代暴力 curl 抓取

## Provider 配置

### DashScope（阿里百炼 / 视觉）
- Vision provider，用于图片理解
- API Key: `sk-04902bad740440d5b3970a7abae3deda`
- 默认模型：`qwen3-vl-flash`（免费）
- 备用：`qwen-vl-plus`（免费额度用完时）
- `show_cost: enabled`

### Tencent MaaS TokenHub（验证）
- 交叉验证模型，用于重要结论的事实校对
- Endpoint: `https://tokenhub.tencentmaas.com/v1`
- Bearer Token 认证
- 模型：`hy3-preview`
- 与 Tencent Cloud Hunyuan API（TC3-HMAC-SHA256 签名）不同

### AnySearch
- 已安装，Node.js 运行时
- API Key: `as_sk_00352ba4783a1245875cf0e0a242aec2`
- 支持垂直领域搜索（finance, academic, travel 等）

### Tavily（网页搜索）
- API Key: `tvly-dev-...`（dev tier，1000次/月免费）
- 用途：网页搜索、内容提取
- 配置位置：`/opt/data/.env`

### Gemini（待办）
- 账号申诉中，待提供有效 API Key
- 申诉通过后配置 `google` provider
