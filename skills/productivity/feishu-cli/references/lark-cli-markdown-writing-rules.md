# lark-cli Markdown 文档写入 — 核心规则（2026-05-28）

## 一句话总结

`--content -` + heredoc + `--doc-format markdown` = 正确
`--content "字符串"` 或 `--content @文件` = 内容为空

## 正确做法（创建文档）

```bash
lark-cli docs +create \
  --wiki-space "<space_id>" \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 文档标题

正文内容...

- 列表项
- 列表项
EOF
```

## 正确做法（更新文档）

```bash
lark-cli docs +update --doc "<doc_token>" \
  --command overwrite \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 新内容
EOF
```

## 错误做法汇总

| 错误写法 | 结果 | 原因 |
|---------|------|------|
| `--content "# 标题\n内容"` | ❌ 内容为空 | `\n` 被转义为字面量 |
| `--content @file.md` | ❌ 内容为空 | `@文件` 不被支持 |
| 缺少 `--doc-format markdown` | ❌ degrade_code=1011 | Markdown 不被解析 |
| `--command str_replace` 写内容 | ❌ 只能替换标题 | 不能批量写内容块 |

## 标题修复（已知 bug）

`docs +create` 的 `--title` 与 `--content` 同时用时不生效，需单独修复：

```bash
lark-cli docs +update --doc "<doc_token>" \
  --command str_replace \
  --pattern "Untitled" \
  --content "正确标题" \
  --api-version v2
```

## 支持的 Markdown 元素

- `# 标题` — 各级标题
- `- 列表` / `1. 有序列表`
- `| 表头 |` — 表格
- `` `code` `` / ```` ``` ```` — 代码
- `> 引用` — 引用块
- `**粗体**` / `*斜体*`
- `---` — 分隔线
- `[ ]` / `[x]` — 复选框

## 环境要求

```bash
export PATH="$HOME/.local/share/npm-global/bin:$PATH"
```
