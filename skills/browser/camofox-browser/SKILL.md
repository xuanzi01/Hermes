---
title: Camofox Browser
name: camofox-browser
version: 1.0.0
description: 通过 HTTP API 调用本地 Camofox 反检测浏览器，支持页面导航、元素交互、截图等功能。
author: hermes
---

# Camofox Browser Skill

Camofox 是一个基于 Firefox 的反检测浏览器，通过 HTTP API 提供自动化能力。

## 前置条件

- Camofox 服务器已运行在 `http://localhost:9377`
- 启动命令：`cd /opt/data/workspace/camofox-browser && node server.js`

### 启动前必做检查（避免端口冲突）

**常见错误：服务已在运行却重复启动，导致 `port in use` 错误**

```bash
# 1. 先检查服务是否已在运行
curl -s http://localhost:9377/health
# → {"ok":true,...}  说明已在运行，直接使用
# → 连接拒绝        说明未运行，需要启动

# 2. 如果端口被旧进程占用但服务无响应，先释放端口
fuser 9377/tcp 2>/dev/null && fuser -k 9377/tcp 2>/dev/null
# 或查找 node 进程：ps aux | grep "camofox\|server.js" | grep -v grep

# 3. 在正确目录启动（后台模式）
cd /opt/data/workspace/camofox-browser
nohup node server.js > /tmp/camofox.log 2>&1 &
sleep 3
curl -s http://localhost:9377/health
```

**关键原则**：
- ✅ 启动前先 `curl /health` 检查状态
- ✅ 用 `fuser` 或 `lsof` 确认端口占用情况
- ❌ 不要假设服务没运行就直接启动新实例
- ❌ 不要在错误目录启动（如 `/opt/data/home/camofox` 不存在）

### 常见启动问题

**问题：Node.js 版本不匹配（better-sqlite3）**
```
NODE_MODULE_VERSION mismatch — was compiled against NODE_MODULE_VERSION 115,
but this version of Node.js requires NODE_MODULE_VERSION 127.
```
**解决**：
```bash
cd /opt/data/workspace/camofox-browser && npm rebuild better-sqlite3
# 然后重启服务
```

**问题：缺少 libgtk-3.so.0（浏览器引擎启动失败）**
```
XPCOMGlueLoad error: libgtk-3.so.0: cannot open shared object file
```
**症状**：健康检查 `ok: true`，但 `browserConnected: false`，`browserRunning: false`

**完整依赖安装（在 1Panel 终端 root 执行）**：
```bash
apt-get update && apt-get install -y libgtk-3-0 libnss3 libnspr4 libasound2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxshmfence1
```

**验证安装成功**：
```bash
ldconfig -p | grep libgtk-3.so.0
# 或直接测试浏览器
curl -s http://localhost:9377/health
# → browserConnected 应为 true
```

**环境说明（1Panel + Docker 部署的特殊性）**：
- Hermes 运行在 **Docker 容器**内（1Panel 应用商店安装）
- 但 Camofox 浏览器运行在 **宿主机**上（`/opt/data/workspace/camofox-browser`）
- 因此 `apt-get install` 需要在 **1Panel 终端**（宿主机 root）执行，**不是**在容器内执行
- 容器内 `/usr/bin/ldconfig -p | grep libgtk` 查不到不代表宿主机也没装
- 验证方式：在 1Panel 终端执行 `ldconfig -p | grep libgtk-3.so.0`，有输出即成功

**注意**：服务端能启动不代表浏览器能运行 — 要同时检查 `browserConnected` 字段

## API 使用

### 1. 创建标签页

```bash
curl -s http://localhost:9377/tabs \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "sessionKey": "task1", "url": "https://example.com"}'
```

返回：`{"tabId": "abc123", "url": "...", "title": "..."}`

### 2. 获取页面快照

```bash
curl -s "http://localhost:9377/tabs/{tabId}/snapshot?userId=hermes"
```

返回可交互元素的 accessibility tree，带 ref 标识（如 `e1`, `e2`）。

### 3. 点击元素

```bash
curl -s http://localhost:9377/tabs/{tabId}/click \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "ref": "e1"}'
```

### 4. 输入文字

```bash
curl -s http://localhost:9377/tabs/{tabId}/type \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "ref": "e2", "text": "搜索内容", "pressEnter": true}'
```

### 5. 导航

```bash
curl -s http://localhost:9377/tabs/{tabId}/navigate \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "url": "https://google.com"}'
```

支持搜索宏：
```bash
curl -s http://localhost:9377/tabs/{tabId}/navigate \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "macro": "@google_search", "query": "天气"}'
```

### 6. 关闭标签页

```bash
curl -s -X DELETE "http://localhost:9377/tabs/{tabId}?userId=hermes"
```

## 搜索宏

| 宏 | 站点 |
|----|------|
| `@google_search` | Google |
| `@youtube_search` | YouTube |
| `@amazon_search` | Amazon |
| `@reddit_search` | Reddit |
| `@wikipedia_search` | Wikipedia |
| `@twitter_search` | Twitter/X |
| `@yelp_search` | Yelp |
| `@linkedin_search` | LinkedIn |

## 7. 全页面截图（fullPage screenshot）

截取页面完整滚动内容，用于保存图文并茂的网页：

```bash
# 全页面截图（直接返回 PNG 二进制）
curl -s "http://localhost:9377/tabs/{tabId}/screenshot?userId=hermes&fullPage=true" \
  -o /tmp/fullpage.png

# 或用 execute_code 处理 base64 返回的情况
curl -s "http://localhost:9377/tabs/{tabId}/screenshot?userId=hermes&fullPage=true" \
  | python3 -c "import sys,base64; open('/tmp/screenshot.png','wb').write(base64.b64decode(sys.stdin.read()))"
```

**返回值**：可能是 PNG 二进制（`image/png` content-type）或 base64 编码字符串，写入文件前先验证格式。

**用途**：保存网页完整图文排版到本地文件（177KB PNG），之后可通过飞书 API 上传到云盘，或作为素材保存。

**注意**：如果截图需要上传到飞书云盘，`lark-cli drive +push` 需要 `drive:drive` scope（缺失会导致 1061004），解决方法是重新 `--recommend` 授权。**但 AI 知识库 Wiki 文件夹是权限孤岛，即使授权成功仍然无法直接写入**，需要先传到根目录普通文件夹，再让用户手动移动。

### ⚠️ 无法用 Camofox 访问飞书文档

飞书文档需要登录状态，Camofox 创建新 tab 打开飞书文档会**超时/失败**。因此：
- ❌ 无法用 Camofox 自动抓取飞书文档内容
- ✅ 可以用 `lark-cli docs +fetch` 读取文本内容（API 方式）
- ✅ 可以用 Camofox 截图**非飞书**的图文页面（如微信公众号文章、网页等）

## 健康检查

```bash
curl -s http://localhost:9377/health
```

**判断标准**：
- `ok: true` + `browserConnected: true` + `browserRunning: true` → 完全就绪 ✅
- `ok: true` + `browserConnected: false` → 服务在跑但浏览器引擎启动失败（通常是系统库缺失）⚠️ → 重装 GTK3 依赖后再验证
- `ok: false` → 服务未运行 ❌

## 注意事项

- `userId` 用于隔离会话和 cookie
- `sessionKey` 用于分组标签页
- Refs 在页面导航后会重置，需要重新获取 snapshot
- 会话 30 分钟无活动后超时
