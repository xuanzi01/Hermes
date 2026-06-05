# 飞书 CLI 文档创建与写入 — 完整工作流（2025-05-28）

## 场景
在飞书知识库（Wiki）中创建带内容的文档，并确保标题和内容都正确。

## 完整步骤

### Step 1: 创建文档（内容正确，但标题会变 Untitled）

```bash
export PATH="$HOME/.local/share/npm-global/bin:$PATH"

# 创建文档到知识库
RESULT=$(lark-cli docs +create --title "AI提示词" \
  --wiki-space "<space_id>" \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 文档标题

正文内容...

```
code block
```
EOF
)

# 提取 document_id
DOC_ID=$(echo "$RESULT" | grep -o '"document_id": "[^"]*"' | cut -d'"' -f4)
echo "Document ID: $DOC_ID"
```

**注意**：`--title` 参数此时不生效，文档标题会显示为 `Untitled`。这是已知 bug。

### Step 2: 修复标题（必须）

```bash
lark-cli docs +update --doc "$DOC_ID" \
  --command str_replace \
  --pattern "Untitled" \
  --content "AI提示词" \
  --api-version v2
```

### Step 3: 验证内容

```bash
lark-cli docs +fetch --doc "$DOC_ID" --api-version v2
```

## 关键参数说明

| 参数 | 作用 | 是否必须 |
|------|------|----------|
| `--content -` | 从 stdin 读取内容 | ✅ 必须 |
| `--doc-format markdown` | 指定 Markdown 格式 | ✅ 必须 |
| `--api-version v2` | 使用 v2 API | ✅ 必须 |
| `<< 'EOF'` | heredoc 传入真正换行 | ✅ 必须 |

## 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| 内容为空 | `--content` 传了字符串或文件路径 | 改用 `--content - << 'EOF'` |
| 标题为 Untitled | `--title` 与 `--content` 同时用时不生效 | 创建后用 `str_replace` 修复 |
| `degrade_code=1011` | 内容格式不被识别 | 确保 `--doc-format markdown` 且内容有真正换行 |

## 支持的 Markdown 语法

- `# 标题` — 各级标题
- `- 列表` / `1. 有序列表` — 列表
- `| 表头 |` — 表格
- `` `code` `` / ```` ``` ```` — 行内代码 / 代码块
- `> 引用` — 引用块
- `**粗体**` — 粗体
- `---` — 分隔线

## 把云盘文档移到知识库

如果文档已创建在云盘，需要移到知识库：

```bash
lark-cli wiki +move \
  --obj-token "$DOC_ID" \
  --obj-type "docx" \
  --target-space-id "<space_id>" \
  --target-parent-token "<parent_node_token>"
```

- `--target-parent-token`：父节点 token（如首页），省略则移到根目录
- 这是异步操作，CLI 会自动轮询直到完成
