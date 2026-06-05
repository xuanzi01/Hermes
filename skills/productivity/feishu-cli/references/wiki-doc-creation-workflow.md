# 飞书知识库文档创建完整工作流

## 场景

在飞书 Wiki 知识库中创建带有 Markdown 内容的文档。

## 完整流程

### Step 1: 确保已登录

```bash
lark-cli auth status
# 如果未登录，用 --recommend 方式授权
lark-cli auth login --no-wait --json --recommend
# 生成二维码 → 用户扫码 → 用 device-code 完成登录
```

### Step 2: 获取知识库信息

```bash
# 列出所有知识库
lark-cli wiki +space-list

# 记录 space_id 和首页 node_token
```

### Step 3: 创建文档（到云盘，不在知识库内）

```bash
lark-cli docs +create --title "文档标题" \
  --wiki-space "SPACE_ID" \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# Markdown 内容

正文...

- 列表项
- 列表项
EOF
```

**注意**：
- `--title` 此时不生效，文档标题为 `Untitled`
- 返回的 `document_id` 需要记录

### Step 4: 修复标题

```bash
lark-cli docs +update --doc "DOCUMENT_ID" \
  --command str_replace \
  --pattern "Untitled" \
  --content "真实标题" \
  --api-version v2
```

### Step 5: 移动到知识库

```bash
lark-cli wiki +move \
  --obj-token "DOCUMENT_ID" \
  --obj-type "docx" \
  --target-space-id "SPACE_ID" \
  --target-parent-token "PARENT_NODE_TOKEN"
```

**参数说明**：
- `--obj-token`: 文档 ID（Step 3 返回的 document_id）
- `--obj-type`: 固定为 `docx`
- `--target-space-id`: 知识库空间 ID
- `--target-parent-token`: 父节点 token（首页或其他节点的 node_token）

## 替代方案：直接在知识库创建节点

```bash
# 创建 wiki 节点（文档直接在知识库内）
lark-cli wiki +node-create \
  --space-id "SPACE_ID" \
  --title "文档标题" \
  --obj-type docx

# 然后更新内容（需要 obj_token）
lark-cli docs +update --doc "OBJ_TOKEN" \
  --command overwrite \
  --content - --doc-format markdown --api-version v2 << 'EOF'
内容...
EOF
```

**注意**：`wiki +node-create` 创建的文档标题正确，但内容写入可能需要额外的 `docs +update` 步骤。

## 已知问题

| 问题 | 症状 | 解决 |
|------|------|------|
| 标题为 Untitled | `--title` 与 `--content` 同时使用时失效 | 创建后用 `str_replace` 修复 |
| 内容为空 | `--content "字符串"` 中 `\n` 被转义 | 用 `--content -` + heredoc |
| 文档不在知识库 | `docs +create --wiki-space` 只创建云盘文档 | 用 `wiki +move` 移动到知识库 |
| 权限不足 | `missing_scope` 错误 | 用 `--recommend` 重新授权 |
