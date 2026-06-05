# Camofox 浏览器运维笔记

## 安装位置

| 路径 | 说明 |
|------|------|
| `/opt/data/workspace/camofox-browser/` | 实际代码目录 |
| `/opt/data/workspace/camofox-browser/server.js` | 入口文件 |
| `/opt/data/workspace/camofox-browser/camofox.config.json` | 插件配置 |
| `http://localhost:9377` | HTTP API 端点 |

**注意**：`~/.local/share/camofox` 或 `~/camofox` 不是正确路径。

## 启动流程

```bash
# 1. 检查并释放端口（关键！避免 port in use）
fuser -k 9377/tcp 2>/dev/null

# 2. 在正确目录启动
cd /opt/data/workspace/camofox-browser
nohup node server.js > /tmp/camofox.log 2>&1 &

# 3. 等待并验证
sleep 3
curl -s http://localhost:9377/health
```

## 健康状态解读

```json
{"ok":true,"engine":"camoufox","browserConnected":false,"browserRunning":false,...}
```

| 字段 | `false` 含义 | 是否需要处理 |
|------|-------------|-------------|
| `ok` | 服务异常 | ✅ 检查日志 |
| `browserConnected` | 无活动标签页 | ❌ 正常，创建标签页后自动变 true |
| `browserRunning` | 浏览器实例未启动 | ❌ 正常，按需启动 |

## 端口冲突排查

```bash
# 方法1：fuser（推荐，最轻量）
fuser 9377/tcp 2>/dev/null && fuser -k 9377/tcp

# 方法2：ps + grep（备用）
ps aux | grep "camofox\|node.*server.js" | grep -v grep | awk '{print $2}' | xargs kill -9

# 方法3：netstat（如果可用）
netstat -tlnp 2>/dev/null | grep 9377
```

**注意**：`lsof` 和 `ss` 在 Hermes Docker 环境中通常不可用。

## 抓取动态页面内容

飞书社区文章等动态加载页面，需要滚动才能获取完整内容：

```bash
# 创建标签页
TAB=$(curl -s http://localhost:9377/tabs \
  -X POST -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "sessionKey": "task1", "url": "<URL>"}')
TAB_ID=$(echo "$TAB" | grep -o '"tabId":"[^"]*"' | cut -d'"' -f4)

# 等待加载
sleep 5

# 获取快照
curl -s "http://localhost:9377/tabs/$TAB_ID/snapshot?userId=hermes"

# 滚动加载更多内容
curl -s http://localhost:9377/tabs/$TAB_ID/scroll \
  -X POST -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "direction": "down", "amount": 3000}'

# 重新获取快照
curl -s "http://localhost:9377/tabs/$TAB_ID/snapshot?userId=hermes"
```

## 日志查看

```bash
tail -f /tmp/camofox.log
```

## 关闭标签页

```bash
curl -s -X DELETE "http://localhost:9377/tabs/$TAB_ID?userId=hermes"
```
