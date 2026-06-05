# 飞书文档内容更新 — 正确做法（2026-05-28）

## 问题背景
`docs +update` 命令用于更新已有文档内容，但容易犯与 `docs +create` 相同的错误。

## 正确工作流

### 覆盖全部内容

```bash
lark-cli docs +update --doc "<doc_token>" \
  --command overwrite \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 新标题

新内容...

- 列表项1
- 列表项2
EOF
```

### 追加内容到末尾

```bash
lark-cli docs +update --doc "<doc_token>" \
  --command append \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'

## 新增章节

追加的内容...
EOF
```

## 关键参数

| 参数 | 作用 | 是否必须 |
|------|------|----------|
| `--content -` | 从 stdin 读取 | ✅ 必须 |
| `--doc-format markdown` | 指定 Markdown 格式 | ✅ 必须 |
| `--command overwrite` | 覆盖全部内容 | 二选一 |
| `--command append` | 追加到末尾 | 二选一 |
| `--api-version v2` | 使用 v2 API | ✅ 必须 |
| `<< 'EOF'` | heredoc 真正换行 | ✅ 必须 |

## 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| 内容未更新 | `--content` 传了字符串 | 改用 `--content - << 'EOF'` |
| degrade_code=1011 | 缺少 `--doc-format markdown` | 加上 `--doc-format markdown` |
| 只能改标题 | 用了 `--command str_replace` | 内容写入用 `overwrite` 或 `append` |

## 与 docs +create 的区别

| 场景 | 命令 | 注意 |
|------|------|------|
| 创建新文档 | `docs +create` | 标题需单独用 `str_replace` 修复 |
| 更新已有文档 | `docs +update` | `--command` 必须指定 `overwrite` 或 `append` |
| 修复标题 | `docs +update --command str_replace` | 仅用于简单文本替换 |
