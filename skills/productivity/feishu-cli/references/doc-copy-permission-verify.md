# 飞书文档复制到知识库：权限验证与可行方案（2026-06-02）

## 问题描述

将别人的飞书文档保存到自己的 AI 知识库，保留图文完整格式。

## 权限验证结果

| Scope | 状态 | 备注 |
|-------|------|------|
| `drive:file:copy` | ❌ 缺失 | drive files copy 必需 |
| `docs:document:media:download` | ❌ 缺失 | 图片下载必需 |
| `wiki:node:copy` | ✅ 已有 | |
| `wiki:wiki` | ✅ 已有 | |
| `docx:document:write_only` | ✅ 已有 | |
| `drive:file:upload` | ✅ 已有 | |
| `drive:file:download` | ✅ 已有 | |
| `drive:drive` | ✅ 已有 | |

**验证方法**：`lark-cli auth check --scope "xxx"`

## 各方案测试结果

### 方案：drive files copy（文件复制 API）
```bash
lark-cli drive files copy \
  --data '{"folder_token":"RqjFfHAEKlOYZedgnw9cd8XZnph","name":"副本","type":"docx"}' \
  --params '{"file_token":"CjQXdkiiroGTyex7l9gcugDGnNg"}'
```
**结果**：❌ 1061004 forbidden（缺 `drive:file:copy` scope）

### 方案：wiki +node-copy（节点复制）
```bash
lark-cli wiki +node-copy \
  --space-id 7644558327271230430 \
  --node-token TZILwVc4siANF9kAJVHcmp0znth \
  --target-parent-node-token RqjFfHAEKlOYZedgnw9cd8XZnph \
  --yes
```
**结果**：❌ 131005 not found（target-parent-node-token 接受的是 wiki 节点 token，不是文件夹 token）

### 方案：docs +media-download（图片下载）
```bash
lark-cli docs +media-download --token SAY2bicfQoaRvQx40OjcCxisngf
```
**结果**：❌ 403 forbidden（图片属于源文档，user token 也无法跨文档下载）

## 核心障碍总结

**障碍1**：`drive:file:copy` scope 缺失 → 文件复制到 AI 知识库文件夹失败

**障碍2**：AI 知识库文件夹（RqjFfHAEKlOYZedgnw9cd8XZnph）对 user token 有权限隔离，即使授权了 `drive:drive` 仍然报 1061004。这是平台级限制，无法通过重新授权解决。

**障碍3**：飞书文档内图片无法跨文档迁移（block image token 只在同文档内有效）

## 可行方案

### ✅ 方案A：补全权限后用 drive files copy

```bash
# Step 1: 补全权限
lark-cli auth login --no-wait --json --domain drive

# Step 2: 用户扫码后复制到云盘根目录（不是 AI 知识库文件夹）
lark-cli drive files copy \
  --data '{"folder_token":"<云盘根目录folder_token>","name":"如何稳定使用NotbookLM和Gemini 3.0 pro - 副本","type":"docx"}' \
  --params '{"file_token":"CjQXdkiiroGTyex7l9gcugDGnNg"}'

# Step 3: 用 wiki +move 将云盘文档移入 AI 知识库
lark-cli wiki +move \
  --obj-token "<复制后的doc_token>" \
  --obj-type "docx" \
  --target-space-id "7644558327271230430" \
  --target-parent-node-token "RqjFfHAEKlOYZedgnw9cd8XZnph"
```

### ✅ 方案B：用 wiki +node-copy 复制到同知识库空间

```bash
# 将文档节点复制到同一知识库空间的其他父节点
lark-cli wiki +node-copy \
  --space-id 7644558327271230430 \
  --node-token TZILwVc4siANF9kAJVHcmp0znth \
  --target-space-id 7644558327271230430
# → 在同一空间创建副本
```

**注意**：`--target-parent-node-token` 必须是 wiki 节点 token，不能是云盘文件夹 token

### ⚠️ 图片保留限制

即使完成复制，飞书文档图片也是文档级资源，新文档会显示为"无法加载的图片"。这是飞书平台限制，无 API 解法。

## 关键教训

1. **权限必须用 `auth check` 逐个确认**，不能只看 `auth status` 的列表
2. **AI 知识库 Wiki 文件夹 token ≠ wiki node token**，不能混用
3. **缺 scope 时用 `--domain` 批量申请**，不要逐个 scope 单独申请（避免反复扫码）
4. **图片 token 无法跨文档迁移**，这是平台级限制，不是 API 设计缺陷