# 文档剪藏（clip）工作流：读取 → 写入知识库

## 两种方案

| 方案 | 保留内容 | 上传云盘 | 适用场景 |
|------|----------|----------|----------|
| **方案A：截图（推荐）** | 图文完整排版 | 需要 `drive:drive` scope | 图文并茂的网页/文档 |
| **方案B：纯文字** | 只有文字+图片token | 直接可用 | 内容为主、结构简单的文档 |

## 方案A：截图保存（完整图文）

**Step 1：用 Camofox 打开文档并截图**

```bash
# 启动 Camofox（如果未运行）
cd /opt/data/workspace/camofox-browser && node server.js

# 创建标签页打开源文档
TAB=$(curl -s http://localhost:9377/tabs \
  -X POST -H "Content-Type: application/json" \
  -d '{"userId": "hermes", "sessionKey": "clip1", "url": "https://my.feishu.cn/docx/<doc_token>"}')
TAB_ID=$(echo "$TAB" | grep -o '"tabId":"[^"]*"' | cut -d'"' -f4)

# 等待页面加载
sleep 5

# 全页面截图（PNG 二进制）
curl -s "http://localhost:9377/tabs/$TAB_ID/screenshot?userId=hermes&fullPage=true" \
  -o /tmp/clipped_screenshot.png
```

**Step 2：上传截图到飞书云盘**

⚠️ **`+push` 必须用 `--local-dir`（目录模式），不存在 `--local` 单文件参数**

```bash
LARK_CLI="/opt/data/home/.local/share/npm-global/bin/lark-cli"

# ✅ 正确：先建目录并放入文件，再用 --local-dir 推送
mkdir -p /tmp/lark_push
cp /tmp/clipped_screenshot.png /tmp/lark_push/
cd /tmp/lark_push
$LARK_CLI drive +push \
  --folder-token "<folder_token>" \
  --local-dir . \
  --as user \
  --if-exists=overwrite
```

❌ **错误示例：`--local` 参数不存在，会报 unknown flag**
```bash
$LARK_CLI drive +push --local /tmp/clipped_screenshot.png --remote "..." --as user
# → unknown flag: --local
```

**Step 3：⚠️ AI知识库文件夹权限隔离（2026-06-02 实测）**

飞书 AI知识库 Wiki 文件夹（RqjFfHAEKlOYZedgnw9cd8XZnph）对用户 token 有权限隔离，**即使授权了 `drive:drive` scope 仍然 1061004 forbidden**。

| 目标 | 结果 | 原因 |
|------|------|------|
| 根目录文件夹 | ✅ `+push` 成功 | 正常权限 |
| 普通云盘文件夹 | ✅ `+push` 成功 | 正常权限 |
| AI知识库 Wiki 文件夹 | ❌ 1061004 | 权限隔离，只有管理员可写 |

**有效解决方案**：
1. 上传到根目录或普通云盘文件夹 → 用户在飞书界面手动移动到 AI知识库
2. 上传到普通文件夹 → 用 `wiki +move` 移到知识库
3. 截图直接发微信（绕过飞书云盘）

**Step 4：drive scope 缺失时的解决（2026-06-02 实测）**

```bash
# 用 --recommend 授权（一次性获取所有推荐权限）
lark-cli auth login --no-wait --json --recommend
# 生成二维码，用户扫码一次，自动包含 drive:drive scope
# 授权成功后用 --device-code 完成登录
lark-cli auth login --device-code "<device_code>"
```

## 方案B：纯文字剪藏

```bash
LARK_CLI="/opt/data/home/.local/share/npm-global/bin/lark-cli"

# Step 1：读取源文档（获取内容）
CONTENT=$($LARK_CLI docs +fetch --doc "<source_doc_token>" --format pretty 2>&1)

# Step 2：清理内容写入本地文件
# <callout>、<whiteboard>、<image> 等标签需手动替换为文字描述
# 图片 token 无法在 API 中还原，标注 [图片: token值] 占位
echo "$CONTENT" | sed 's/<callout[^>]*>//g; s/<\/callout>//g' \
  | sed 's/<whiteboard token="\([^"]*\)"\/>\\[whiteboard [白板: \1]/g' \
  | sed 's/<image token="\([^"]*\)"\/>\\[image [图片: \1]/g' \
  | sed 's/<image token="\([^"]*\)"[^>]*\/>/[图片: \1]/g' \
  > /tmp/clipped_doc.md

# Step 3：在知识库创建 wiki 节点
RESULT=$($LARK_CLI wiki +node-create \
  --space-id "7644558327271230430" \
  --title "文档标题" \
  --obj-type docx 2>&1)
DOC_ID=$(echo "$RESULT" | grep -o '"obj_token":"[^"]*"' | cut -d'"' -f4)
NODE_ID=$(echo "$RESULT" | grep -o '"node_token":"[^"]*"' | cut -d'"' -f4)

# Step 4：写入内容
$LARK_CLI docs +update --doc "$DOC_ID" \
  --command overwrite \
  --content - --doc-format markdown --api-version v2 < /tmp/clipped_doc.md
```

## 关键注意点

1. **`docs +fetch` 返回飞书原生 XML 标签**：`<callout>`, `<whiteboard token="..."/>`, `<image token="..."/>`, `<text bgcolor=...>` 等。图片 token 无法还原，需要手动处理或告知用户查看原文档
2. **标题正常生效**：`wiki +node-create` 的 `--title` 在 `--obj-type docx` 时正确，不像 `docs +create` 有 bug
3. **截图方案**：Camofox 全页面截图可完整保留图文排版，但 `lark-cli drive +push` 需要 `drive:drive` scope 和正确的 `--local-dir` 用法
4. **AI知识库 Wiki 文件夹无写入权限**：即使授权完整，仍 1061004，需上传到普通文件夹后由用户手动移动

## image token 提取参考

从 `docs +fetch` 输出中提取所有图片 token：
```bash
echo "$CONTENT" | grep -o 'token="[^"]*"' | grep -v 'node_token\|obj_token' \
  | sort -u | while read t; do echo "Image: $t"; done
```

## 相关 API

- 读取文档（v1，已废弃但可用）：`GET /open-apis/docx/v1/documents/{document_id}`
- 创建 wiki 节点：`POST /open-apis/wiki/v2/spaces/{space_id}/nodes`
- 更新文档内容：`PUT /open-apis/docx/v1/documents/{document_id}`
- 上传文件到云盘：`POST /open-apis/drive/v1/files/upload_all`（需要 `drive:drive` scope）

最后更新：2026-06-02