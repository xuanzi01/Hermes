# 每日复盘定时任务 — Cron Job 模板

## 概述

创建定时任务，每天自动从 Hermes 会话数据库读取当日对话，生成结构化复盘文档并存入飞书知识库。

**创建命令**：
```
/opt/data/hermes-agent/venv/bin/python -m cronjob create \
  --name "每日复盘-飞书文档" \
  --skill feishu-cli,feishu-docs-api \
  --prompt "$(cat << 'PROMPT'
你是璇子的 AI 军师 foxx。每天晚 23:30 运行一次，生成今日工作总结并保存到飞书文档。
[见下方完整 prompt 内容]
PROMPT
)" \
  --schedule "30 23 * * *" \
  --deliver origin
```

> ⚠️ `session_search` skill 不一定可用（已验证：2026-06-04 cron job 运行时该 skill 被跳过）。**必须用 Python execute_code 直接查数据库**，不要依赖 session_search。

## Cron Job Python 查询模板（已验证可用，2026-06-04）

```python
import sqlite3
from datetime import date, datetime

today = date.today().strftime('%Y-%m-%d')
today_start = datetime.combine(date.today(), datetime.min).timestamp()
today_end = datetime.combine(date.today(), datetime.max).timestamp()

conn = sqlite3.connect('/opt/data/state.db')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# 查询今日 sessions（注意：started_at 是 Unix 时间戳，不是 date 字符串）
cursor.execute("""
    SELECT id, title, started_at, message_count, tool_call_count, api_call_count
    FROM sessions
    WHERE started_at >= ? AND started_at <= ?
    ORDER BY started_at
""", (today_start, today_end))
sessions = cursor.fetchall()

# 查询每个 session 的消息
for s in sessions:
    cursor.execute("""
        SELECT role, content FROM messages
        WHERE session_id = ? ORDER BY timestamp
    """, (s['id'],))
    msgs = cursor.fetchall()
    # ... 生成复盘内容

conn.close()
```

**已验证成功**（2026-06-04 晚 23:33 执行）：
- 4 个 sessions，225 条消息，111 次 API 调用
- 使用 `datetime.combine(date.today(), datetime.min).timestamp()` 生成 timestamp range
- 直接用 `started_at >= ? AND started_at <= ?` 查询，避免 `date()` 字符串转换函数的不兼容问题

## 核心 Cron Prompt 模板

```python
from datetime import date

prompt = f"""你是璇子的 AI 军师 foxx。每天晚 23:30 运行一次，生成今日工作总结并保存到飞书文档。

## 执行步骤

### 1. 从数据库读取今日 session 数据
数据库路径：/opt/data/state.db
今日日期：{date.today().strftime('%Y-%m-%d')}

查询语句（推荐方式）：
```sql
SELECT id, title, message_count, api_call_count,
       input_tokens, output_tokens, estimated_cost_usd
FROM sessions
WHERE date(started_at, 'unixepoch', 'localtime') = '{date.today().strftime('%Y-%m-%d')}'
ORDER BY started_at
```

关联查询 messages 表获取对话内容：
```sql
SELECT m.session_id, m.role, m.content, m.tool_name,
       datetime(m.timestamp, 'unixepoch', 'localtime') as local_time
FROM messages m
JOIN sessions s ON m.session_id = s.id
WHERE date(s.started_at, 'unixepoch', 'localtime') = '{date.today().strftime('%Y-%m-%d')}'
ORDER BY m.timestamp
```

### 2. 生成复盘文档内容
根据今日对话内容，生成以下结构的中文复盘文档：

# 🎯 {日期} 每日复盘

## 📊 今日概况
- 今日 session 数
- 今日总消息数
- 今日 API 调用数
- 主要工作方向

## 💡 今日完成事项
按时间线列举今日完成的主要工作，用列表形式。

## 🤔 今日反思
分析今日工作的亮点和可改进之处（2-3 条）。

## 📋 明日规划
列出明日计划做的 3-5 件事。

## 📝 关键对话记录
记录今日有价值的对话片段或决策要点。

### 3. 创建飞书文档

**lark-cli 路径**：`/opt/data/home/.local/share/npm-global/bin/lark-cli`

**Step 1**：创建 wiki 节点
```bash
# 注意：wiki +node-create 不支持 --api-version 参数
lark-cli wiki +node-create \
  --space-id "7644558327271230430" \
  --title "🎯 {日期} 每日复盘" \
  --obj-type docx
```
返回的 `obj_token` 即文档 ID（不是 document_id）。

**Step 2**：内容先落盘到文件，再 overwrite 写入
```bash
# 内容写入 /tmp/review.md
cat > /tmp/review.md << 'REVIEW_EOF'
# 复盘内容...
REVIEW_EOF

# 用 overwrite 写入（不支持 < 输入重定向时用 heredoc）
lark-cli docs +update --doc "$DOC_ID" \
  --command overwrite \
  --content - --doc-format markdown --api-version v2 \
  < /tmp/review.md
```

**文档链接**：`https://my.feishu.cn/docx/{obj_token}`

### 4. 返回结果
输出：文档链接 + 3-5 句话今日复盘摘要。
格式：「📋 今日复盘已完成：[文档标题](链接)」

## 注意事项
- 如果今日无 session 数据，文档内容写「今日无工作记录」
- lark-cli 路径必须用完整路径
- MiniMax 模型生成复盘内容
- 内容写入推荐用 `< file` 输入重定向，而非 heredoc 直接传内容
"""
```

## 数据库表结构（/opt/data/state.db）

### sessions 表关键字段
| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT | session 唯一 ID |
| title | TEXT | session 标题 |
| source | TEXT | 来源（feishu/terminal/web 等） |
| started_at | REAL | Unix 时间戳（秒） |
| ended_at | REAL | Unix 时间戳（秒） |
| message_count | INTEGER | 消息总数 |
| api_call_count | INTEGER | API 调用数 |
| input_tokens | INTEGER | 输入 token |
| output_tokens | INTEGER | 输出 token |
| estimated_cost_usd | REAL | 估算费用 |

### messages 表关键字段
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 自增 ID |
| session_id | TEXT | 所属 session |
| role | TEXT | user/assistant/system/tool |
| content | TEXT | 消息内容 |
| tool_name | TEXT | 调用的工具名 |
| timestamp | REAL | Unix 时间戳（秒） |

### 查询今日数据（推荐方法）

**直接用 date() 转换函数 — 最简洁**：
```python
today = date.today().strftime('%Y-%m-%d')  # e.g. '2026-06-01'
cursor.execute("""
    SELECT id, title, message_count, api_call_count
    FROM sessions
    WHERE date(started_at, 'unixepoch', 'localtime') = ?
    ORDER BY started_at
""", (today,))
```

`date(started_at, 'unixepoch', 'localtime')` 在 Python sqlite3 中可用，直接字符串匹配日期即可。`localtime` 将 UTC 时间转为本地时间后再提取日期部分。

### 获取所有用户消息（用于生成复盘）

```python
cursor.execute("""
    SELECT m.content,
           datetime(m.timestamp, 'unixepoch', 'localtime') as local_time
    FROM messages m
    JOIN sessions s ON m.session_id = s.id
    WHERE date(s.started_at, 'unixepoch', 'localtime') = ?
      AND m.role = 'user'
    ORDER BY m.timestamp
""", (today,))
user_msgs = cursor.fetchall()
```

## Cron Job 验证

查看已创建的复盘任务：
```bash
hermes cron list
# 或
/opt/data/hermes-agent/venv/bin/python -m cronjob list
```

手动触发测试（不等 23:30）：
```bash
hermes cron run <job_id>
```

## 删除 wiki 节点（清理失败任务）

如果文档创建失败需要清理：
```bash
lark-cli wiki +node-delete --node-token "<node_token>" --obj-type docx --yes
# 或用 obj_token
lark-cli wiki +node-delete --obj-token "<doc_token>" --obj-type docx --yes
```