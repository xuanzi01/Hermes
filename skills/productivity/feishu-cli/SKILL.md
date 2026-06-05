---
title: 飞书 CLI (lark-cli) 操作指南
description: 安装、配置、授权及常见飞书操作的最佳实践和踩坑记录
name: feishu-cli
triggers:
  - 飞书 CLI
  - lark-cli
  - 飞书知识库
  - 飞书文档
  - 飞书云盘
  - 飞书授权
---

# 飞书 CLI (lark-cli) 操作指南

## 1. 安装

```bash
# 安装 CLI（避免全局权限问题，装到用户目录）
mkdir -p ~/.local/share/npm-global
npm config set prefix '~/.local/share/npm-global'
export PATH="$HOME/.local/share/npm-global/bin:$PATH"
npm install -g @larksuite/cli

# 安装 Skill（必须）
npx -y skills add https://open.feishu.cn --skill -y
```

## 2. 配置绑定

```bash
# 绑定到 Hermes 应用（user-default 身份可操作用户资源）
lark-cli config bind --source hermes --identity user-default

# 手动修复配置（如果绑定后 appId 有多余引号）
# 配置文件位置：~/.lark-cli/hermes/config.json
# 确保 appId 和 brand 没有多余引号
```

## 3. OAuth 授权（关键：避免反复扫码）

### ✅ 最佳方式：用 --recommend 一次性获取所有权限
### ✅ 最佳方式：用 --recommend 一次性获取所有权限

```bash
# 一次性获取所有推荐权限（自动审批，无需管理员确认）
lark-cli auth login --no-wait --json --recommend

# 生成二维码给用户扫描
lark-cli auth qrcode "<verification_url>" --output ./auth_qr.png
# 用户授权后，用 device-code 完成登录
lark-cli auth login --device-code "<device_code>"
```

**`--recommend` 会自动获取几乎所有需要的权限**，包括：
- 文档：`docx:document:create`, `docx:document:readonly`, `docx:document:write`
- 云盘：`drive:drive`, `drive:file:download`, `drive:file:upload`
- 知识库：`wiki:wiki`, `wiki:space:read`, `wiki:space:retrieve`, `wiki:node:create`
- 多维表格：`base:app:*`
- 日历：`calendar:calendar.*`
- 任务：`task:task:*`
- 会议：`vc:meeting.*`
- 邮件：`mail:user_mailbox:*`
- 通讯录：`contact:user.base:readonly`
- 消息：`im:chat`, `im:message`

### ✅ 批量补全缺失权限：正确方式是 --domain 一次性申请多个业务域（重要！）

**不要**逐个 scope 单独申请（每次都要用户扫码，体验极差）。

```bash
# ✅ 正确：按业务域一次性申请所有缺失权限（一次扫码，全部搞定）
lark-cli auth login --no-wait --json \
  --domain drive,docs,calendar,sheets,base,mail,task,search,vc,minutes,okr
```

哪些域需要申请（用 `lark-cli auth check --scope "xxx"` 逐个确认）：
- `drive` — 文件复制、移动（缺 `drive:file:copy`）
- `docs` — 文档内图片下载（缺 `docs:document:media:download`）
- `calendar` — 日历读写
- `sheets` — 电子表格读写
- `base` — 多维表格读写
- `mail` — 邮箱读写
- `task` — 任务读写
- `search` — 文档搜索
- `vc` — 会议记录搜索
- `minutes` — 会议纪要上传
- `okr` — OKR 管理

**已有足够权限的域**（无需申请）：im、wiki、contact、approval、board（白板）

### ✅ 权限检查：正确方法是用 auth check，不是看错误信息

遇到 1061004 / 403 / missing_scope 错误时，**不要盲目猜**。用以下命令确认缺失的 scope：

```bash
# 检查单个 scope
lark-cli auth check --scope "drive:file:copy"
# → ok: true 或 missing: [...]

# 批量检查（for 循环）
for scope in "drive:file:copy" "docs:document:media:download" "calendar:calendar"; do
    lark-cli auth check --scope "$scope"
done
```

**已确认缺少的 scope**（2026-06-02 实测）：
- `drive:file:copy` — 文件复制到文件夹必需
- `docs:document:media:download` — 文档内图片下载必需
- `im:message:send_as_bot` — bot 发消息
- `calendar:calendar` / `calendar:calendar.event` — 日历读写
- `sheets:spreadsheet` — 电子表格
- `base:record` / `base:table` — 多维表格
- `mail:user_mailbox` / `mail:user_mailbox.message` — 邮箱
- `task:task` — 任务
- `search:docs` — 文档搜索
- `vc:meeting.search` — 会议搜索
- `minutes:minutes.upload` — 会议纪要上传
- `okr:okr` — OKR

**常见误解**：auth status 显示的 scope 列表很完整，但某些 scope（如 `drive:file:copy`）并没有真正授权给 user token。**必须用 `auth check` 逐个确认**，不能只依赖 `auth status`。

### ❌ 避免：逐个申请 scope（会导致反复扫码）

```bash
# 不要这样做！每次只能申请一个或少量 scope
lark-cli auth login --no-wait --json --scope "wiki:wiki"
# ...用户扫码...
lark-cli auth login --no-wait --json --scope "drive:drive"
# ...用户再扫码...
# 重复多次，用户体验极差
```

### 如果 --recommend 后仍缺权限

某些特殊权限可能不在 `--recommend` 范围内。此时：
1. 运行命令，记录错误信息中的缺失权限
2. 一次性申请该权限：`lark-cli auth login --no-wait --json --scope "missing:scope"`
3. 用户扫码一次即可

**不要**在没试过 `--recommend` 之前就逐个申请权限。

## 4. 知识库操作

### 列出知识库空间
```bash
lark-cli wiki +space-list
```

### 在知识库创建文档节点
```bash
# ✅ 已验证可用：创建 wiki 节点（文档在知识库内）
# 注意：wiki +node-create 不支持 --api-version 参数
lark-cli wiki +node-create \
  --space-id "<space_id>" \
  --title "文档标题" \
  --obj-type docx

# 返回的 obj_token 是文档 ID，node_token 是 wiki 节点 ID
# 文档链接：https://my.feishu.cn/docx/<obj_token>
# Wiki 链接：https://my.feishu.cn/wiki/<node_token>
```

**重要参数**：
- `--space-id`：必须是数字 space_id（如 `7644558327271230430`），不是 wiki token
- `--obj-type`：必须指定 `docx`，否则报错
- `--title`：在 `--obj-type docx` 时标题会正常生效（不同于 `docs +create` 的 bug）

**从返回 JSON 提取 document_id**：
```bash
RESULT=$(lark-cli wiki +node-create --space-id "7644558327271230430" \
  --title "🎯 每日复盘" --obj-type docx 2>&1)
DOC_ID=$(echo "$RESULT" | grep -o '"obj_token":"[^"]*"' | cut -d'"' -f4)
NODE_ID=$(echo "$RESULT" | grep -o '"node_token":"[^"]*"' | cut -d'"' -f4)
echo "Doc: https://my.feishu.cn/docx/$DOC_ID"
echo "Wiki: https://my.feishu.cn/wiki/$NODE_ID"
```

### 把云盘文档移到知识库
```bash
# ✅ docs_to_wiki 模式：将已创建的文档移动到知识库指定位置
lark-cli wiki +move \
  --obj-token "<doc_token>" \
  --obj-type "docx" \
  --target-space-id "<space_id>" \
  --target-parent-token "<parent_node_token>"

# 如果不指定 --target-parent-token，文档会移到知识库根目录
```

**⚠️ `wiki +move --apply` 的实际行为（2026-06-02 实测确认）**：
- `--apply` 参数的真实含义：**提交移动请求（move request），等待审批**，不是立即执行
- `status_msg: "move request submitted for approval"` = 移动请求已提交，等待 AI知识库管理员审批
- 如果文档进入了知识库（`wiki nodes list` 能看到节点），说明移动成功，不需要额外审批
- 如果状态是 pending approval，说明需要知识库管理员在飞书 App 内审批后才能完成移动

**正常移动流程（不需要 --apply）**：直接 `--apply` 不加时，移动立即执行（针对用户有写权限的文档）。

**完整可行工作流（tenant token + 移动请求）**：
```bash
# Step 1: 用 tenant token 批量写入 blocks 到新文档（已验证成功）
# Step 2: 文档进入 wiki（两种路径）
# 路径 A：docs +create --wiki-space 会自动创建 wiki 节点并放入知识库（最简）
lark-cli docs +create --wiki-space "7644558327271230430" \
  --title "文档标题" --markdown "内容"

# 路径 B：wiki +move --apply 提交移动请求
lark-cli wiki +move --obj-type docx --obj-token "<doc_token>" \
  --target-space-id "7644558327271230430" --apply
# → status_msg: "move request submitted for approval"
# → 等待用户/管理员在飞书 App 内审批
```

### 文档内容写入（✅ 已解决）

**关键**：必须用 `--content -`（stdin）配合 heredoc 传入真正换行的内容。

### ❌ 错误方式（内容为空）
```bash
# \n 会被转义为字面量，文档内容为空
lark-cli docs +create --title "标题" --content "# 标题\n\n内容" --api-version v2
lark-cli docs +create --title "标题" --content @file.md --api-version v2
```

### ✅ 正确方式（heredoc + --doc-format markdown）

```bash
lark-cli docs +create --title "🎯 今日工作复盘" \
  --wiki-space "7644558327271230430" \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 标题

内容

- 列表项1
- 列表项2
EOF
```

**要点**：
- `--content -` 表示从 stdin 读取（不能用 `"字符串"`，`\n` 会被转义）
- `<< 'EOF'` heredoc 提供真正换行（EOF 必须带引号防止变量展开）
- `--doc-format markdown` **必须加**，否则内容解析失败（degrade_code=1011）
- 支持完整 Markdown：标题、列表、表格、代码块、引用等

**关键区别**：
| 方式 | 结果 |
|------|------|
| `--content "# 标题\n内容"` | ❌ `\n` 被转义，内容为空 |
| `--content @file.md` | ❌ 不被支持，内容为空 |
| `--content - << 'EOF'` + `--doc-format markdown` | ✅ 正确解析 Markdown |

### ⚠️ 文档标题问题（已知 bug，已解决）

`docs +create` 的 `--title` 参数在同时传入 `--content` 时不生效，标题会变成 `Untitled`。

**修复方法**：创建后用 `str_replace` 更新标题
```bash
# Step 1: 创建文档（标题此时不生效，会显示为 Untitled）
lark-cli docs +create --title "AI提示词" \
  --wiki-space "xxx" --content - --doc-format markdown --api-version v2 << 'EOF'
内容...
EOF
# 记录返回的 document_id

# Step 2: 修复标题（必须）
lark-cli docs +update --doc "<document_id>" \
  --command str_replace \
  --pattern "Untitled" \
  --content "AI提示词" \
  --api-version v2
```

**注意**：如果不修复标题，文档在知识库中显示为 "Untitled"，用户会困惑。

完整工作流详见 `references/doc-creation-workflow.md`、`references/update-doc-content.md`、`references/lark-cli-markdown-writing-rules.md`、`references/zsxq-cli-setup.md`、`references/ai-agent-setup-pattern.md`、`references/zsxq-auth-troubleshooting.md`、`references/anysearch-skill-install.md`、`references/camofox-ops.md`、`references/model-switching.md`、`references/daily-review-cronjob.md`、`references/doc-clip-workflow.md`（文档剪藏工作流）和 **`references/wiki-vs-drive.md`**（Wiki vs 云盘权限区别）和 **`references/doc-copy-permission-verify.md`**（文档复制权限验证与可行方案）。

## 5. 文档操作

### 读取文档
```bash
lark-cli docs +fetch --doc "<doc_token>" --format pretty 2>&1
```

**注意**：`docs +fetch` 使用 v1 API（已废弃警告可忽略），返回飞书原生格式（含 `<callout>`、`<whiteboard token="..."/>`、`<image token="..."/>` 等标签）。图片 token 无法在 API 中还原为图片，**只能保存纯文本**，截图部分需查看原文档。如需保存图片，需要额外下载步骤。

### 更新文档内容（✅ 已解决）

**关键**：与创建文档一样，必须用 `--content -` + heredoc + `--doc-format markdown`。

```bash
# ✅ 正确：覆盖整个文档内容
lark-cli docs +update --doc "<doc_token>" \
  --command overwrite \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
# 新标题

新内容...

- 列表项
EOF
```

**常见错误**：
- ❌ `--content "字符串"` → `\n` 被转义，内容为空
- ❌ 忘记 `--doc-format markdown` → degrade_code=1011，内容解析失败
- ❌ `--command str_replace` 用于内容替换 → 只能替换标题等简单文本，不能批量写入内容块

**注意**：`docs +update` 的 `--command` 参数值是 `str_replace` / `overwrite` / `append` 等，但 `str_replace` 只能做简单文本替换（如修标题），**批量内容写入必须用 `overwrite` + `--content -` + `--doc-format markdown`**。

## 6. 云盘操作

### 创建文件夹
```bash
lark-cli drive +create-folder --name "文件夹名" --parent "<parent_token>"
```

# Wiki 知识库 vs 云盘文件夹 权限区别（2026-06-02 实测）

## 核心区别

| 维度 | Wiki 知识库 | 云盘文件夹 |
|------|------------|-----------|
| CLI 命令 | `lark-cli wiki ...` | `lark-cli drive ...` |
| 资源标识 | `space_id` + `node_token`（树形父子页面） | `file_token` / `folder_token`（平铺文件） |
| 链接样式 | `feishu.cn/wiki/xxxxx` | `feishu.cn/docx/xxxxx` 或 `feishu.cn/drive/folder/xxxxx` |
| 权限 scope | `wiki:node:*`、`wiki:wiki` | `drive:file:*`、`drive:drive` |
| 本地同步 | ❌ 无 | ✅ `drive +sync` |
| 递归遍历 | 默认只查一级子页面 | 不适用 |
| 适用场景 | 结构化手册、SOP、文档页面 | 原始素材、PSD/视频/压缩包 |

**最核心原则：两种资源用两套完全独立的命令，混用是最高频报错根源。**

## `wiki +move --apply` 的实际行为（2026-06-02 新发现）

| 参数 | 实际行为 | 成功条件 |
|------|---------|---------|
| 不加 `--apply` | 立即移动（需要写权限） | 源文档 owner = 用户，且用户有写权限 |
| 加 `--apply` | 提交移动请求，等待审批 | 文档进入待审批队列，需要管理员/用户飞书 App 内审批 |

**实测**：`status_msg: "move request submitted for approval"` = 移动请求已提交，等待审批流程，不是立即执行成功。

## 文档内容 block 迁移的已知限制

**通过 `docx/v1/documents/{id}/blocks/{id}/children` 批量写入 blocks 的实测发现**：

| block 类型 | 从源文档复制到目标文档 | 说明 |
|-----------|----------------------|------|
| text（type=2） | ✅ 完全正常 | 内容 1:1 迁移 |
| heading（type=4） | ✅ 完全正常 | 标题样式保留 |
| bullet_list（type=5） | ✅ 完全正常 | 列表项完整 |
| callout（type=6） | ✅ 完全正常 | 提示块内容迁移 |
| image（type=27） | ⚠️ **只能创建空占位块** | `batch_create` 可插入 image block，但 token 字段为空（`"token": ""`），文档内显示为空白 240×240 占位框 |
| file（type=28） | ❌ 未测试 | - |

**根本原因**：飞书图片是文档内部资源，image block 的 token 只读，无法通过 API 写入源文档的图片 token。

**结论**：通过 REST API 迁移文档内容时，文本和列表可以完整迁移，图片只能保留"位置"但无法保留"画面"。图片的真实迁移只能靠：
1. 用户在飞书 App 内手动复制（飞书原生支持图片跨文档复制）
2. Camofox 截图 → 上传云盘 → 替换占位块（需要手动操作）
`https://my.feishu.cn/docx/CjQXdkiiroGTyex7l9gcugDGnNg` 中的 token 是 docx token，不是 wiki node token。直接用 docx token 调用 `wiki +node-copy` 会报 `131005 not found`。同理，用 wiki URL 中的 token 调用 `docs +fetch` 也会失败。

**正确的判断流程：**
```
收到 URL → 先判断链接样式
  feishu.cn/docx/XXX → docx token → 用 docs 命令
  feishu.cn/wiki/XXX → wiki node token → 用 wiki 命令（需先 +node-get 解析）
  混用必报错
```

**操作前必须解析（重要）：**
```bash
# 解析 wiki URL，得到 obj_type + obj_token + space_id
lark-cli wiki +node-get --node-token "https://my.feishu.cn/wiki/WIKI_TOKEN"
# 或 docx URL
lark-cli wiki +node-get --node-token "https://my.feishu.cn/docx/DOCX_TOKEN" --obj-type docx
```

### ⚠️ `wiki +move --obj-type docx` 需要对源文档有写权限

**报错 `131006 permission denied` = 对源文档没有 move 权限**，不是目标文件夹问题。

### ⚠️ `wiki +node-copy` 只能复制 wiki 节点，不能复制独立 docx

**源必须是 wiki node token（`wikcnXXX`），不能是 docx token（`doccnXXX`）**。独立 docx 想进 wiki，正确方式是 `wiki +move --obj-type docx`（需要源文档写权限），或者用户在飞书 App 内手动移动。

### ⚠️ AI 知识库可能是独立 Wiki Space（应用可能无权访问）

**`wiki spaces list` 只返回两个空间**：
- `7644558327271230430` (Hermes)
- `7514588864729890819` (梦开始的地方)

AI 知识库文件夹 `RqjFfHAEKlOYZedgnw9cd8XZnph` 如果属于第三个 space（`7644577685712194491`），应用无权访问，`wiki nodes list` 会返回 `131005 not found`。此时必须用户手动在飞书 App 内操作。

### ⚠️ 不是所有 1061004 都是 scope 缺失

**文件夹本身权限隔离也会导致 1061004**。先检查目标文件夹是否 AI 知识库/个人空间，再检查 scope。

### ⚠️ lark-cli 无 `--json` 参数

**正确参数是 `--format json`，不是 `--json`**。

### ⚠️ 飞书文档内图片无法跨文档迁移（2026-06-02 确认）

飞书文档中的图片以 token 引用形式存储，图片本身属于源文档资源。**无法通过任何 API 将图片从源文档迁移到目标文档**。
- `drive files copy` → 1061004（即使 scope 有 `drive:file:copy` + `docs:document:copy`）
- `drive +move` → 1062535 destination parent no permission
- `drive +upload` → 1061004
- `drive +push` → 1061004

**根因**：不是 scope 缺失，而是**文件夹本身的权限隔离**。Wiki 知识库的权限体系和普通云盘不同，应用 API 和用户 OAuth 均无法直接写入。

| 目标位置 | scope 充足 | 结果 |
|---------|-----------|------|
| 根目录普通文件夹 | ✅ | ✅ 可上传 |
| 普通云盘文件夹 | ✅ | ✅ 可上传 |
| AI 知识库 Wiki 文件夹 | ✅ | ❌ 1061004 forbidden |

**✅ 解决方案**：
1. 上传到**根目录普通文件夹**（`drive +push` / `drive +upload` 成功）
2. 用户在飞书 App/Web 界面**手动移动**到 AI 知识库（用户身份有完整权限）
3. 方案 C：文件夹 owner 在飞书客户端内把 AI知识库文件夹的编辑权限分享给应用（应用 token 可写）

**关键教训**：遇到 1061004 时，**先检查文件夹权限，再检查 scope**。不是所有 1061004 都是 scope 缺失。

### ⚠️ 飞书文档内图片无法跨文档迁移（2026-06-02 确认）

飞书文档中的图片以 token 引用形式存储在文档的 block 结构里（`type: 27` image block），图片本身属于源文档资源。**无法通过任何 API 将图片从源文档迁移到目标文档**：

| 方案 | 结果 |
|------|------|
| `drive/v1/medias/{token}/download`（tenant token） | ❌ 403 forbidden |
| `docs +media-download --token {img_token} --as user` | ❌ 403（图片属于其他文档） |
| `im/v1/images/{token}` | ❌ 234001 invalid params |
| 文档复制 `drive/v1/files/{id}/copy`（tenant token） | ❌ 1061004 forbidden |

**根本原因**：飞书文档图片是文档级资源，tenant token 无法跨文档访问图片，user token 也受限于资源归属。

**batch_create 方式插入图片 block 的实际行为（实测）**：
- `batch_create` 可以成功插入 image block（block_type=27），文档内有 23 个图片占位块
- **但图片 block 的 token 字段为空**（`"token": ""`），不是源文档的图片 token
- 图片在文档内显示为 **240×240 的空白占位框**，不是真实图片
- 无法通过后续 `batch_update` 把源图片 token 写入 image block（token 不可写）

**实际可行方案**：
1. **Camofox 截长图**：截取文档完整滚动截图作为 PNG 保存，再上传到云盘（需要手动移动到知识库）
2. **发微信/其他平台**：截图直接分享（绕过飞书云盘权限隔离）
3. **手动复制**：用户在飞书界面打开源文档，手动复制内容到目标文档（飞书原生支持）

**不要**尝试的方案（已验证失败）：
- 下载图片 token → 本地文件 → 再插入新文档（图片下载阶段就被卡死）
- 文档复制 API（tenant token 无此权限）
- Camofox 打开飞书文档（飞书需要登录状态，tab 创建超时）
- `batch_update` image block 写入 token（token 字段只读，不可写）
- Camofox 打开飞书文档（飞书需要登录状态，tab 创建超时）

### ⚠️ 飞书文档内图片无法跨文档迁移（2026-06-02 确认）

飞书文档中的图片以 token 引用形式存储在文档的 block 结构里（`type: 27` image block），图片本身属于源文档资源。**无法通过任何 API 将图片从源文档迁移到目标文档**：

| 方案 | 结果 |
|------|------|
| `drive/v1/medias/{token}/download`（tenant token） | ❌ 403 forbidden |
| `docs +media-download --token {img_token} --as user` | ❌ 403（图片属于其他文档） |
| `im/v1/images/{token}` | ❌ 234001 invalid params |
| 文档复制 `drive/v1/files/{id}/copy`（tenant token） | ❌ 1061004 forbidden |

**根本原因**：飞书文档图片是文档级资源，tenant token 无法跨文档访问图片，user token 也受限于资源归属。

**batch_create 方式插入图片 block 的实际行为（实测）**：
- `batch_create` 可以成功插入 image block（block_type=27），文档内有 23 个图片占位块
- **但图片 block 的 token 字段为空**（`"token": ""`），不是源文档的图片 token
- 图片在文档内显示为 **240×240 的空白占位框**，不是真实图片
- 无法通过后续 `batch_update` 把源图片 token 写入 image block（token 不可写）

**实际可行方案**：
1. **Camofox 截长图**：截取文档完整滚动截图作为 PNG 保存，再上传到云盘（需要手动移动到知识库）
2. **发微信/其他平台**：截图直接分享（绕过飞书云盘权限隔离）
3. **手动复制**：用户在飞书界面打开源文档，手动复制内容到目标文档（飞书原生支持）

**不要**尝试的方案（已验证失败）：
- 下载图片 token → 本地文件 → 再插入新文档（图片下载阶段就被卡死）
- 文档复制 API（tenant token 无此权限）
- Camofox 打开飞书文档（飞书需要登录状态，tab 创建超时）
- `batch_update` image block 写入 token（token 字段只读，不可写）
- Camofox 打开飞书文档（飞书需要登录状态，tab 创建超时）

### 上传文件（⚠️ 权限问题，2026-06-02 确认）

**`lark-cli drive +push` 上传到云盘有 scope 限制**：
- `drive +push` 需要 `drive:drive` scope（云盘读写）
- 如果用户授权时没用 `--recommend`，该 scope 可能缺失
- 缺失时会报 `1061004 forbidden`

**⚠️ 正确用法：必须用 `--local-dir`（目录模式），不存在 `--local` 单文件参数**
```bash
# ✅ 正确：先建目录并放入文件，再用 --local-dir 推送
mkdir -p /tmp/lark_push
cp /tmp/test.png /tmp/lark_push/
cd /tmp/lark_push
lark-cli drive +push --folder-token "<folder_token>" --local-dir . --as user --if-exists=overwrite

# ❌ 错误：--local 参数不存在
lark-cli drive +push --local /tmp/test.png --remote "<folder_token>" --as user
# → unknown flag: --local
```

**⚠️ AI知识库 Wiki 文件夹权限隔离**：RqjFfHAEKlOYZedgnw9cd8XZnph 对用户 token 有权限隔离，**即使授权了 drive:drive scope 仍然 1061004**。上传到根目录或普通文件夹后让用户手动移动。

**检查方式**：
```bash
# 在普通文件夹测试（根目录可以）
mkdir -p /tmp/test_push && cp /tmp/test.png /tmp/test_push/ && cd /tmp/test_push
lark-cli drive +push --folder-token "<folder_token>" --local-dir . --as user --dry-run
```

**解决方案**：重新用 `--recommend` 授权
```bash
lark-cli auth login --no-wait --json --recommend
# 用户扫码一次，自动获取所有推荐权限包括 drive:drive
```

**备选方案（不重新授权）**：
- 截图文件通过 **Feishu 开放平台 REST API** 上传（需要正确的 multipart/form-data）
- 或改用文档内嵌方式（截图作为图片插入飞书文档，再存入知识库）
- 或截图直接发微信（绕过云盘）

### 创建文件夹
```bash
lark-cli drive +create-folder --name "文件夹名" --parent "<parent_token>"
```

## 7. 多维表格（Bitable）操作

### 创建多维表格（新表）

```bash
# 创建新表
lark-cli --as user api POST /open-apis/bitable/v1/apps/{app_token}/tables \
  --data '{"table":{"name":"表名"}}'
# 返回 table_id
```

### 添加字段

```bash
# 文本字段
lark-cli --as user api POST /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/fields \
  --data '{"field_name":"字段名","type":1}'

# 单选字段（含选项）
lark-cli --as user api POST /open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/fields \
  --data '{"field_name":"方向","type":3,"property":{"options":[{"name":"效率工具","color":5}]}}'
```

### ⚠️ 写入记录的已知限制（2026-06-02 已解决：建在云盘）

**在个人空间创建 base → tenant/user token 都无法写 records（403 91403）。**

**✅ 正确方案**：把多维表格创建在**云盘（AI知识库）文件夹**下，而不是在个人空间直接创建：
1. `GET /open-apis/drive/v1/files` 获取 AI知识库 folder_token（示例：`RqjFfHAEKlOYZedgnw9cd8XZnph`）
2. `POST /open-apis/bitable/v1/apps` body: `{"name": "表名", "folder_token": "RqjFfHAEKlOYZedgnw9cd8XZnph"}`
3. 在这个 base 下，tenant token 可以正常写入 tables/fields/records

**已验证成功**：
- Base Token: `EfctboZDma3FFRslEfKc3haTnO8`（创建在 AI知识库文件夹内）
- 写入 records 全部成功（batch_create 分批写入，10条/批）
- 个人空间 base 则全部 403，不受飞书开放平台权限控制

详细踩坑记录见 `references/lark-base-bitable.md`。

## 8. 使用已安装工具（Camofox 浏览器）

当 `curl` 直接抓取被限流（Google 429、GitHub 搜索限制等）时，**必须使用已安装的 Camofox 反检测浏览器**，而不是继续用 `curl` 重试。

### 启动与使用

**关键：必须在正确的工作目录启动**

```bash
# ✅ 正确：在 camofox-browser 目录启动
cd /opt/data/workspace/camofox-browser && node server.js

# ❌ 错误：目录不存在或路径错误
cd /opt/data/home/camofox   # 不存在！
```

**启动前检查端口是否被占用**：
```bash
# 检查 9377 端口（Camofox 默认端口）
curl -s http://localhost:9377/health

# 如果返回连接拒绝，说明服务未运行，需要启动
# 如果之前的进程崩溃但端口仍被占用，先释放端口：
fuser 9377/tcp 2>/dev/null && fuser -k 9377/tcp 2>/dev/null
# 或查找并杀掉 node 进程：ps aux | grep "camofox" | grep -v grep
```

**完整启动流程**：
```bash
# 1. 确保端口释放
fuser -k 9377/tcp 2>/dev/null

# 2. 在正确目录启动（后台模式）
cd /opt/data/workspace/camofox-browser
nohup node server.js > /tmp/camofox.log 2>&1 &

# 3. 等待并验证
sleep 3
curl -s http://localhost:9377/health
# → {"ok":true,"engine":"camoufox",...}
```

**创建标签页并访问目标 URL**：
```bash
# 创建标签页
TAB=$(curl -s http://localhost:9377/tabs \
  -X POST -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "sessionKey": "task1", "url": "https://github.com/rtk-ai/rtk"}')
TAB_ID=$(echo "$TAB" | grep -o '"tabId":"[^"]*"' | cut -d'"' -f4)

# 获取页面内容（可交互元素快照）
curl -s "http://localhost:9377/tabs/$TAB_ID/snapshot?userId=hermes"

# 使用搜索宏（绕过反爬）
curl -s http://localhost:9377/tabs/$TAB_ID/navigate \
  -X POST -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "macro": "@google_search", "query": "RTK AI token compression"}'
```

### 搜索宏列表

| 宏 | 站点 |
|----|------|
| `@google_search` | Google |
| `@youtube_search` | YouTube |
| `@reddit_search` | Reddit |
| `@twitter_search` | Twitter/X |

### 关键原则

- **遇到 429 / CAPTCHA / 搜索限制 → 立即切换 Camofox**，不要重试 `curl`
- Camofox 基于 Firefox，自带反检测，能绕过大多数反爬机制
- 服务已在后台运行（`http://localhost:9377`），直接使用即可

## 8. 大内容写入策略（避免中断和超时）

当需要写入大量 Markdown 内容（如整篇文章、长文档）时，**不要**用单条 heredoc 命令直接传给 `lark-cli`。

### ❌ 不推荐：超长 heredoc 直接写入

```bash
# 问题：内容太长时用户可能中断，命令行历史混乱，出错后难定位
lark-cli docs +create --title "长文章" --wiki-space "xxx" \
  --content - --doc-format markdown --api-version v2 << 'EOF'
# 非常长的内容...
# ...几十行...
# ...几百行...
EOF
```

### ✅ 推荐：先写本地文件，再分批上传

**Step 1：内容写入本地文件**
```bash
# 用 write_file 或 cat 写入 /tmp/article.md
cat > /tmp/article.md << 'CONTENT_EOF'
# 文章标题

正文内容...
CONTENT_EOF
```

**Step 2：创建空文档**
```bash
# 先创建文档，获取 document_id
RESULT=$(lark-cli docs +create --title "文章标题" \
  --wiki-space "7644558327271230430" \
  --content - --doc-format markdown --api-version v2 << 'EOF'
EOF)
DOC_ID=$(echo "$RESULT" | grep -o '"document_id":"[^"]*"' | cut -d'"' -f4)
echo "Document ID: $DOC_ID"
```

**Step 3：分批更新内容**：
```bash
# overwrite 一次性覆盖（用 < 输入重定向，内容已在文件）
lark-cli docs +update --doc "$DOC_ID" \
  --command overwrite \
  --content - --doc-format markdown --api-version v2 < /tmp/article.md
```

**关键原则**：
- 长内容先落盘到 `/tmp/` 文件，再传给 CLI
- 避免在终端里直接粘贴/输入几十行 heredoc
- 如果内容超长，拆成多个 `append` 调用

---

## 9. Docker 环境限制与 OAuth 工具

当在 Docker 容器内安装需要 OAuth 授权的 CLI 工具（如 zsxq-cli）时，需注意：

### 容器内无法使用 Keychain

- Docker 容器无 `gnome-keyring`、`libsecret` 等 Keychain 服务
- OAuth Token 无法加密存储，授权流程无法完成

### 不推荐：宿主机安装 Keychain

| 方面 | 影响 |
|-----|------|
| 空间占用 | ~80-150MB |
| 维护复杂度 | 高（需运行 dbus + keyring daemon，改 entrypoint）|
| 稳定性 | Docker 重启后数据可能丢失 |
| 升级兼容性 | 1Panel 升级 Hermes 镜像时自定义改动可能被覆盖 |
| 安全边界 | 打破容器隔离原则 |

**结论**：Keychain 是给桌面环境设计的，在 Docker 里硬跑是反模式。

### 推荐替代方案

| 方案 | 适用场景 | 操作 |
|-----|---------|------|
| **本地授权** | 有桌面环境的电脑 | 本地完成 OAuth，导出 Token 给容器 |
| **环境变量** | 工具支持 `ZSXQ_TOKEN` 等 | `export ZSXQ_TOKEN="xxx"` |
| **配置文件** | 需要持久化 | 写入明文配置，文件权限 600 |
| **直接调 API** | 有 API Key 时 | 绕过 CLI，直接调 REST API |

**本地授权标准流程**：
```bash
# 1. 本地电脑安装
npm install -g zsxq-cli

# 2. 本地授权
zsxq-cli auth login
# 按提示完成授权

# 3. 导出 Token
# Mac: security find-generic-password -s "zsxq-cli" -w
# Windows: zsxq-cli config show
# Linux: secret-tool lookup service zsxq-cli

# 4. 配置到 Hermes
export ZSXQ_TOKEN="<token>"
```

### 第三方工具安装标准流程

```bash
# 1. 检查包名（常见错误：打错包名）
npm install -g <package-name>

# 2. 确保 PATH
export PATH="$HOME/.local/share/npm-global/bin:$PATH"

# 3. 验证
<cli-name> --version

# 4. 安装 Skill（如有）
npx skills add <repo-url> --yes --global

# 5. 授权（Docker 内可能走不通，需替代方案）
<cli-name> auth login

# 6. 验证
<cli-name> auth status
<cli-name> doctor
```

**关键原则**：试错 3 次后停止，分析根因，查看官方文档，区分密钥类型（OAuth Token / API Key / MCP Server Key）。

**通用排查流程**：
```
1. 安装 CLI → 2. 尝试授权 → 3. 检查是否跳转正确页面
    ↓ 跳转错误/无确认按钮
4. 分析授权流程类型（OAuth / API Key / MCP）
    ↓
5. 检查容器是否有 Keychain 服务
    ↓ 无 Keychain
6. 选择替代方案（本地授权 / 环境变量 / 直接调 API / 配置文件）
```

## 10. 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `--content is required` | `docs +create` 时 heredoc 内容为空或只有空白 | heredoc 至少传一行非空内容（如一个 `# 标题`），内容通过后续 `overwrite` 写入 |
| `missing_scope` | 权限不足 | 用 `--recommend` 重新授权 |
| `degrade_code=1011` | `--content` 传了字符串而非 heredoc，或缺少 `--doc-format markdown` | 改用 `--content - << 'EOF'` + `--doc-format markdown` |
| `param err: space_id is not int` | 用了 wiki token 而非 space_id | 用数字 space_id |
| `permission denied: wiki space permission denied` | 应用不在知识库成员中 | 添加应用到知识库成员 |
| `Invalid access token` | token 过期 | 重新获取 |
| `device_code has expired` | 授权链接超时（10分钟） | 重新生成授权链接 |
| `rtk binary not found in PATH` | RTK 未加入 PATH 或 Hermes 启动时未加载 | 将 `export PATH="$HOME/.local/bin:$PATH"` 写入 `~/.bashrc`，重启 Hermes |
| `--command is required` | `docs +update` 缺少 `--command` 参数 | 必须指定 `--command str_replace` / `overwrite` / `append` |
| `--command str_replace requires --pattern` | 用 `str_replace` 时缺少 `--pattern` | 加上 `--pattern "旧文本" --content "新文本"` |
| Camofox `port in use` | 上次进程未完全退出，9377 仍被占用 | `fuser -k 9377/tcp` 或 `ps aux \| grep camofox \| grep -v grep` 杀掉旧进程 |
| `lark-cli: command not found` | `~/.local/share/npm-global/bin` 不在 PATH | `export PATH="$HOME/.local/share/npm-global/bin:$PATH"` 写入 `~/.bashrc` |

RTK 是 CLI 代理，可减少 60-90% 的 LLM token 消耗，且**官方支持 Hermes**。

### 安装步骤

```bash
# 1. 下载预编译二进制（Linux x86_64）
cd /tmp
curl -fsSL -o rtk.tar.gz \
  "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-unknown-linux-musl.tar.gz"
tar -xzf rtk.tar.gz
mkdir -p ~/.local/bin
mv rtk ~/.local/bin/
chmod +x ~/.local/bin/rtk

# 2. 确保 PATH 包含 ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# 3. 验证
rtk --version   # → rtk 0.42.0

# 4. 安装 Hermes 插件
rtk init --agent hermes
# → 插件安装到 /opt/data/plugins/rtk-rewrite/
# → 配置自动写入 /opt/data/config.yaml

# 5. 重启 Hermes 使插件生效
```

### 验证插件状态

```bash
/opt/hermes/.venv/bin/hermes plugins list
# → rtk-rewrite | enabled | 0.1.0
```

### RTK 对用户的价值

| 场景 | 是否有用 |
|------|----------|
| Hermes Agent 终端命令 | ✅ **有用！官方支持** |
| Claude Code / Cursor / Copilot | ✅ 非常有用 |
| 阿里百炼视觉模型（图片理解） | ❌ 不适用 |
| 腾讯混元交叉验证 | ❌ 不适用 |

**注意**：RTK 压缩的是 **Shell 命令输出**（`git status`、`ls`、`cat` 等），对图片 token 无效。

## 12. Feishu REST API 直接调用（feishu-docs-api 合并）

当 CLI 工具不满足需求时，使用飞书开放平台 REST API。

### 获取 Tenant Access Token

```bash
APP_SECRET=$(grep FEISHU_APP_SECRET /opt/data/.env | cut -d= -f2 | tr -d "'" | tr -d '\n')
curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$FEISHU_APP_ID\",\"app_secret\":\"$APP_SECRET\"}"
```

### 创建文档

```bash
TOKEN="<tenant_access_token>"
curl -s -X POST "https://open.feishu.cn/open-apis/docx/v1/documents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"folder_token":"","title":"文档标题"}'
```

### 批量写入内容（纯 text block 模式）

**重要**：飞书 docx API 对 block 参数要求严格。推荐使用 `block_type: 2`（text）最稳定。

```python
import requests, time

headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
lines = ["🎯 标题", "", "## 一级标题", "", "• 列表项1", "• 列表项2", "□ 待办事项", "═══════════════════", ""]

for line in lines:
    payload = {"children": [{"block_type": 2, "text": {"elements": [{"text_run": {"content": line}}]}}], "index": -1}
    requests.post(f"https://open.feishu.cn/open-apis/docx/v1/documents/{DOC_TOKEN}/blocks/{PAGE_ID}/children", headers=headers, json=payload)
    time.sleep(0.3)
```

详细 block_type 实测记录见 `references/feishu-block-types.md`。

### Wiki vs Drive 文件夹（重要区分）

| 概念 | API端点 | 应用访问性 | 适用场景 |
|------|---------|-----------|---------|
| **Wiki知识库** | `/wiki/v2/spaces` | ❌ 个人空间不可访问，仅团队空间 | 团队知识管理 |
| **云文档(docx)** | `/docx/v1/documents` | ✅ 完全可控 | 单篇文档 |
| **云空间文件夹** | `/drive/v1/files/create_folder` | ✅ 完全可控 | 文件+文档混合管理 |

**当用户要求"知识库"时**：确认是 Wiki 还是云空间文件夹。个人 Wiki（`my.feishu.cn/wiki`）应用无法访问，改用云空间文件夹。

详见 `references/wiki-vs-drive.md`。

## 13. 关键概念

- **开发者平台权限** ≠ **OAuth 用户授权**：前者是应用能调哪些 API，后者是应用以"用户身份"操作。CLI 需要后者。
- **个人空间**（my.feishu.cn/wiki）和 **团队空间** API 不同，应用只能访问团队空间。
- **obj_token** = 文档本身 ID，**node_token** = 知识库中的节点 ID。
- **文档内容写入三要素**：`--content -`（stdin）+ `<< 'EOF'`（heredoc 真正换行）+ `--doc-format markdown`（解析 Markdown）。缺一不可。
- **Docker 环境限制**：容器内无系统 Keychain（gnome-keyring/libsecret），OAuth Token 无法存储。需要替代方案（本地授权、环境变量、或直接调 API）。
- **第三方 Skill 安装**：优先选择零依赖运行时（Node.js 纯脚本），用 `cp -rL` 解析符号链接避免 broken symlink。

## 14. 用户偏好：问题解决机制

当遇到技术问题时，遵循以下机制避免无限循环：

```
第1次尝试 → 失败
第2次尝试 → 失败  
第3次尝试 → 失败
    ↓
停止试错，分析错误信息
    ↓
搜索官方文档 / GitHub Issues / 社区（用 Camofox 绕过反爬）
    ↓
找到根因和正确方案后再执行
```

**当某个方案失败时，正确思维顺序**：
1. **是我的问题，不是平台的问题** — 先找自己的工具/配置/权限问题
2. **检查 lark-cli 官方文档** — 看有没有更简单的内置命令（如 `drive files copy`、`docs +media-download`）
3. **思考有没有更简单的路径** — 文档复制有没有现成命令？block API 能不能用？
4. **确认权限是否完整** — 用 `lark-cli auth check --scope` 逐个确认，不要猜
5. **区分"平台限制"和"配置错误"** — 先确认是权限/配置问题还是飞书真的不支持

**关键原则**：
- ❌ 不要在没试过官方内置命令之前就说"API 不支持"
- ❌ 不要遇到 1061004/403 就认为是平台限制，先查 scope
- ❌ 不要逐个 scope 单独申请权限，用 `--domain` 一次性批量申请
- ✅ 先查官方文档和 CLI help，再搜索社区，最后才是自己猜测
- ✅ 先用 `auth check` 确认缺少什么权限，再决定怎么补

## 15. 安装第三方 Skill（GitHub）

当用户要求安装 GitHub 上的第三方 Skill 时：

```bash
# 1. 确定分类（media, research, productivity, creative 等）
# 2. 下载并安装
mkdir -p ~/.agents/skills/<category>/<skill-name>
cd /tmp && curl -L -o skill.zip https://github.com/<owner>/<repo>/archive/refs/heads/main.zip
python3 -c "import zipfile; zipfile.ZipFile('skill.zip').extractall('.')"
cp -rL /tmp/<repo>-main/* ~/.agents/skills/<category>/<skill-name>/

# 3. 验证
ls ~/.agents/skills/<category>/<skill-name>/SKILL.md
```

**注意**：
- 用 `cp -rL` 解析符号链接，避免 broken symlink
- 检查 `runtime.conf` 或 `package.json` 确认运行时依赖
- 优先选择零依赖的运行时（如 Node.js 纯脚本）

**示例**：AnySearch Skill
```bash
cd /tmp && curl -L -o anysearch-skill.zip \
  https://github.com/anysearch-ai/anysearch-skill/archive/refs/heads/main.zip
python3 -c "import zipfile; zipfile.ZipFile('anysearch-skill.zip').extractall('.')"
mkdir -p ~/.agents/skills/anysearch
cp -r /tmp/anysearch-skill-main/* ~/.agents/skills/anysearch/
echo "Runtime: Node.js" > ~/.agents/skills/anysearch/runtime.conf
echo "Command: node ~/.agents/skills/anysearch/scripts/anysearch_cli.js" >> ~/.agents/skills/anysearch/runtime.conf
```

## 16. Wiki 节点创建（feishu-workspace 合并）

`docs +create --wiki-space` 不会创建 Wiki 节点，只创建独立云文档。创建 Wiki 节点需要 `wiki +node-create`：

```bash
# 创建 wiki 节点（文档在知识库内）
lark-cli wiki +node-create \
  --space-id "7644558327271230430" \
  --title "文档标题" \
  --obj-type docx

# 返回的 obj_token 是文档 ID，node_token 是 wiki 节点 ID
# 文档链接：https://my.feishu.cn/docx/<obj_token>
# Wiki 链接：https://my.feishu.cn/wiki/<node_token>
```

**重要参数**：
- `--space-id`：必须是数字 space_id（如 `7644558327271230430`），不是 wiki token
- `--obj-type`：必须指定 `docx`，否则报错
- `--title`：在 `--obj-type docx` 时标题会正常生效（不同于 `docs +create` 的 bug）

**从返回 JSON 提取 document_id**：
```bash
RESULT=$(lark-cli wiki +node-create --space-id "7644558327271230430" \
  --title "🎯 每日复盘" --obj-type docx 2>&1)
DOC_ID=$(echo "$RESULT" | grep -o '"obj_token":"[^"]*"' | cut -d'"' -f4)
NODE_ID=$(echo "$RESULT" | grep -o '"node_token":"[^"]*"' | cut -d'"' -f4)
echo "Doc: https://my.feishu.cn/docx/$DOC_ID"
echo "Wiki: https://my.feishu.cn/wiki/$NODE_ID"
```

### 把云盘文档移到知识库

```bash
# ✅ docs_to_wiki 模式：将已创建的文档移动到知识库指定位置
lark-cli wiki +move \
  --obj-token "<doc_token>" \
  --obj-type "docx" \
  --target-space-id "<space_id>" \
  --target-parent-token "<parent_node_token>"

# 如果不指定 --target-parent-token，文档会移到知识库根目录
```

完整工作流详见 `references/doc-creation-workflow.md`、`references/update-doc-content.md` 和 **`references/daily-review-cronjob.md`**（每日复盘定时任务模板）。

## 17. RTK CLI 代理（token 压缩）

RTK 是 CLI 代理，可减少 60-90% 的 LLM token 消耗，且**官方支持 Hermes**。

### 安装步骤

```bash
# 1. 下载预编译二进制（Linux x86_64）
cd /tmp
curl -fsSL -o rtk.tar.gz \
  "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-unknown-linux-musl.tar.gz"
tar -xzf rtk.tar.gz
mkdir -p ~/.local/bin
mv rtk ~/.local/bin/
chmod +x ~/.local/bin/rtk

# 2. 确保 PATH 包含 ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# 3. 验证
rtk --version   # → rtk 0.42.0

# 4. 安装 Hermes 插件
rtk init --agent hermes
# → 插件安装到 /opt/data/plugins/rtk-rewrite/
# → 配置自动写入 /opt/data/config.yaml

# 5. 重启 Hermes 使插件生效
```

### 验证插件状态

```bash
/opt/hermes/.venv/bin/hermes plugins list
# → rtk-rewrite | enabled | 0.1.0
```

### RTK 对用户的价值

| 场景 | 是否有用 |
|------|----------|
| Hermes Agent 终端命令 | ✅ **有用！官方支持** |
| Claude Code / Cursor / Copilot | ✅ 非常有用 |
| 阿里百炼视觉模型（图片理解） | ❌ 不适用 |
| 腾讯混元交叉验证 | ❌ 不适用 |

**注意**：RTK 压缩的是 **Shell 命令输出**（`git status`、`ls`、`cat` 等），对图片 token 无效。

## 18. 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `--content is required` | `docs +create` 时 heredoc 内容为空或只有空白 | heredoc 至少传一行非空内容（如一个 `# 标题`），内容通过后续 `overwrite` 写入 |
| `missing_scope` | 权限不足 | 用 `--recommend` 重新授权 |
| `degrade_code=1011` | `--content` 传了字符串而非 heredoc，或缺少 `--doc-format markdown` | 改用 `--content - << 'EOF'` + `--doc-format markdown` |
| `param err: space_id is not int` | 用了 wiki token 而非 space_id | 用数字 space_id |
| `permission denied: wiki space permission denied` | 应用不在知识库成员中 | 添加应用到知识库成员 |
| `Invalid access token` | token 过期 | 重新获取 |
| `device_code has expired` | 授权链接超时（10分钟） | 重新生成授权链接 |
| `rtk binary not found in PATH` | RTK 未加入 PATH 或 Hermes 启动时未加载 | 将 `export PATH="$HOME/.local/bin:$PATH"` 写入 `~/.bashrc`，重启 Hermes |
| `--command is required` | `docs +update` 缺少 `--command` 参数 | 必须指定 `--command str_replace` / `overwrite` / `append` |
| `--command str_replace requires --pattern` | 用 `str_replace` 时缺少 `--pattern` | 加上 `--pattern "旧文本" --content "新文本"` |
| Camofox `port in use` | 上次进程未完全退出，9377 仍被占用 | `fuser -k 9377/tcp` 或 `ps aux \| grep camofox \| grep -v grep` 杀掉旧进程 |
| 131005 not found | 资源不在 wiki 中，或 space 应用无权访问 | 确认 docx 是否已加入 wiki；确认 space_id 在 wiki spaces list 中 |
| 131006 permission denied | 对源文档无 move 权限 | 用户手动在飞书 App 内操作，或确认文档 owner |
| 1062535 destination parent no permission | 目标文件夹无写入权限 | 目标可能是 AI 知识库权限孤岛，改用普通文件夹 |
| 1062524 source parent no permission | 源文件夹无读取/移动权限 | 确认源文档所在位置 |
| `lark-cli: command not found` | 二进制不在 PATH | lark-cli 实际路径 `/opt/data/home/.local/share/npm-global/bin/lark-cli`；用绝对路径 |
| 1770001 (block参数无效) | API block 结构不正确 | 改用纯 text block，或检查嵌套结构 |
| 1063001 (参数无效) | 权限接口的 type 参数错误 | 检查 type 参数（doc/docx） |
| 99991661 (Token缺失/过期) | tenant_access_token 失效 | 重新获取 tenant_access_token |
| 403 (权限不足) | 应用权限未发布生效 | 检查应用权限配置 |

- **开发者平台权限** ≠ **OAuth 用户授权**：前者是应用能调哪些 API，后者是应用以"用户身份"操作。CLI 需要后者。
- **个人空间**（my.feishu.cn/wiki）和 **团队空间** API 不同，应用只能访问团队空间。
- **obj_token** = 文档本身 ID，**node_token** = 知识库中的节点 ID。
- **文档内容写入三要素**：`--content -`（stdin）+ `<< 'EOF'`（heredoc 真正换行）+ `--doc-format markdown`（解析 Markdown）。缺一不可。
- **Docker 环境限制**：容器内无系统 Keychain（gnome-keyring/libsecret），OAuth Token 无法存储。需要替代方案（本地授权、环境变量、或直接调 API）。
- **第三方 Skill 安装**：优先选择零依赖运行时（Node.js 纯脚本），用 `cp -rL` 解析符号链接避免 broken symlink。

## 10. 用户偏好：问题解决机制

当遇到技术问题时，遵循以下机制避免无限循环：

```
第1次尝试 → 失败
第2次尝试 → 失败  
第3次尝试 → 失败
    ↓
停止试错，分析错误信息
    ↓
搜索官方文档 / GitHub Issues / 社区（用 Camofox 绕过反爬）
    ↓
找到根因和正确方案后再执行
```

**不要**：
- ❌ 同一个命令反复重试超过3次
- ❌ 不分析错误信息就盲目换参数
- ❌ 忽略用户的"停止"信号
- ❌ `curl` 被限流后继续重试，不用 Camofox

**要**：
- ✅ 第3次失败后主动搜索解决方案
- ✅ 理解错误根源后再行动
- ✅ 及时汇报问题并请求用户确认新方案
- ✅ **优先使用已安装的 Skill 和工具**（Camofox、web search 等）

## 11. 安装第三方 Skill（GitHub）

当用户要求安装 GitHub 上的第三方 Skill 时：

```bash
# 1. 确定分类（media, research, productivity, creative 等）
# 2. 下载并安装
mkdir -p ~/.agents/skills/<category>/<skill-name>
cd /tmp && curl -L -o skill.zip https://github.com/<owner>/<repo>/archive/refs/heads/main.zip
python3 -c "import zipfile; zipfile.ZipFile('skill.zip').extractall('.')"
cp -rL /tmp/<repo>-main/* ~/.agents/skills/<category>/<skill-name>/

# 3. 验证
ls ~/.agents/skills/<category>/<skill-name>/SKILL.md
```

**注意**：
- 用 `cp -rL` 解析符号链接，避免 broken symlink
- 检查 `runtime.conf` 或 `package.json` 确认运行时依赖
- 优先选择零依赖的运行时（如 Node.js 纯脚本）

**示例**：AnySearch Skill
```bash
cd /tmp && curl -L -o anysearch-skill.zip \
  https://github.com/anysearch-ai/anysearch-skill/archive/refs/heads/main.zip
python3 -c "import zipfile; zipfile.ZipFile('anysearch-skill.zip').extractall('.')"
mkdir -p ~/.agents/skills/anysearch
cp -r /tmp/anysearch-skill-main/* ~/.agents/skills/anysearch/
echo "Runtime: Node.js" > ~/.agents/skills/anysearch/runtime.conf
echo "Command: node ~/.agents/skills/anysearch/scripts/anysearch_cli.js" >> ~/.agents/skills/anysearch/runtime.conf
```

**核心要点**：CLI 的 `--content` 参数必须用 stdin（`-`）配合 heredoc，不能传字符串或文件路径。**`--doc-format markdown` 必须同时加**，否则 Markdown 内容解析失败（degrade_code=1011）。
### ✅ 正确：创建新文档（heredoc + stdin，内容先落盘到文件）

```bash
# Step 1：内容先写入本地文件
cat > /tmp/doc_content.md << 'CONTENT_EOF'
# 文档标题

正文内容...
CONTENT_EOF

# Step 2：创建空文档（传入空 heredoc，内容在 Step 4 写入）
RESULT=$(lark-cli docs +create --title "AI提示词" \
  --wiki-space "<space_id>" \
  --content - \
  --doc-format markdown \
  --api-version v2 << 'EOF'
EOF
)

# 提取 document_id
DOC_ID=$(echo "$RESULT" | grep -o '"document_id": "[^"]*"' | cut -d'"' -f4)
echo "Document ID: $DOC_ID"

# Step 3：修复标题（必须，因为 --title 与 --content 共用时 bug 会变成 Untitled）
lark-cli docs +update --doc "$DOC_ID" \
  --command str_replace \
  --pattern "Untitled" \
  --content "AI提示词" \
  --api-version v2

# Step 4：覆盖写入完整内容（overwrite 模式，用 < 输入重定向）
lark-cli docs +update --doc "$DOC_ID" \
  --command overwrite \
  --content - \
  --doc-format markdown \
  --api-version v2 < /tmp/doc_content.md
```

**关键要点**：
- 创建新文档时 heredoc 必须是**非空**（哪怕只有标题行），传入空 heredoc 会报错 `--content is required`
- 真正内容通过 Step 4 的 `< /tmp/file` **输入重定向**写入，不要试图在 `docs +create` 时同时传内容
- 内容超长时先落盘到 `/tmp/doc.md`，再 `< /tmp/doc.md` 传入，避免 heredoc 在命令行里超长难维护
- `str_replace` 只能修标题，内容写入必须用 `overwrite` + `< file`

### ✅ 正确：更新已有文档（覆盖全部内容）

```bash
# 覆盖全部内容（用 < 输入重定向）
lark-cli docs +update --doc "<doc_token>" --command overwrite \
  --content - --doc-format markdown --api-version v2 < /tmp/doc_content.md
```

**常见错误**：
- ❌ `--content "# 标题\n\n内容"` → `\n` 被转义为字面量，内容为空
- ❌ `--content @file.md` → 不被支持，内容为空
- ❌ 忘记 `--doc-format markdown` → Markdown 不被解析，degrade_code=1011
- ❌ `docs +update` 用 `str_replace` 试图批量写入内容 → 只能替换简单文本，不能写内容块
