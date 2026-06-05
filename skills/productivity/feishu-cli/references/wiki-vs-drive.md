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

## Wiki node token ≠ docx token（最高频踩坑）

| 输入 | 是什么 | 能直接用吗 |
|------|--------|-----------|
| `https://my.feishu.cn/docx/CjQXdkiiroGTyex7l9gcugDGnNg` 中的 token | **docx token** | ❌ 不能当 wiki node token 用 |
| `https://my.feishu.cn/wiki/YsQQwIblTiWLtOk51Q9ciQTwnAh` 中的 token | **wiki node token** | ❌ 不能当 docx token 用 |

**正确流程：**
```bash
# 解析 wiki URL → 得到 obj_type + obj_token + space_id + node_token
lark-cli wiki +node-get --node-token "https://my.feishu.cn/wiki/WIKI_TOKEN"
# 返回：obj_type=docx, obj_token=实际文档ID, node_token=节点ID, space_id=数字ID

# 解析 docx URL → 也需要先解析
lark-cli wiki +node-get --node-token "https://my.feishu.cn/docx/DOCX_TOKEN" --obj-type docx
```

## 2026-06-02 实测：各操作结果

| 操作 | 目标 | 结果 | 根因 |
|------|------|------|------|
| `drive files copy` → AI知识库文件夹 | `RqjFfHAEKlOYZedgnw9cd8XZnph` | ❌ 1061004 | 文件夹权限隔离 |
| `drive +upload` → AI知识库文件夹 | `RqjFfHAEKlOYZedgnw9cd8XZnph` | ❌ 1061004 | 文件夹权限隔离 |
| `drive +push` → 根目录 | `test_hermes_push` | ✅ 成功 | 根目录有完整权限 |
| `wiki +move --obj-type docx` | docx → AI知识库 | ❌ 131006 permission denied | 对源文档没有写权限 |
| `wiki +node-copy` | 独立 docx token 作源 | ❌ 131005 not found | 源必须是 wiki node，不能是 docx token |
| `wiki +node-get` | wiki URL | ✅ 成功 | 读权限正常 |
| `wiki spaces list` | - | ✅ 2个 space | 只返回有权限的 space |
| `wiki nodes list` | space `7644577685712194491` | ❌ 131005 not found | 该 space 不在列表中，应用无权限 |

**关键教训**：
- 不是所有 1061004 都是 scope 缺失，先检查文件夹权限
- `wiki +node-copy` 只能复制 wiki 节点，不能复制独立 docx
- 独立 docx 进 wiki 必须 `wiki +move --obj-type docx`（需要源文档写权限）或用户手动移动
- 应用看不到的 space，API 操作全部失败

## 解决方案（优先级顺序）

1. **用户手动操作（最稳）**：飞书 App → 打开文档 → 移动到 → 目标文件夹
2. **上传到根目录/普通文件夹**：再让用户在飞书界面手动移动到 AI 知识库
3. **API 写权限**：如果文档 owner 是用户自己，且有写权限 → `wiki +move --obj-type docx`
4. **别尝试**：不要试图用 `drive files copy`、`drive +upload`、`drive +push` 写入 AI 知识库文件夹

## 相关 Token（2026-06-02）

- 源文档 docx token: `CjQXdkiiroGTyex7l9gcugDGnNg`
- AI知识库文件夹 Token: `RqjFfHAEKlOYZedgnw9cd8XZnph`（权限孤岛）
- AI知识库 space_id: `7644577685712194491`（应用无权限，看不到）
- 根目录测试文件夹: `TclzfF5YklJzC7dgiSIcSM9Knhb`（可正常上传）
- 已创建的 wiki 节点: `YsQQwIblTiWLtOk51Q9ciQTwnAh`（指向空白 docx `WHekdTLlRoDu5Qxezghcs7TGnYe`）

## 落地分工（规避混用出错）

| 内容类型 | 存储位置 | CLI 命令 |
|---------|---------|---------|
| 原始素材、PSD/视频/压缩包 | drive云盘 | `drive` 命令 |
| 结构化手册、SOP、文档页面 | wiki知识库 | `wiki` 命令 |
| 云盘附件嵌入知识库页面 | 先下载本地 → CLI上传至指定wiki节点 | `drive +upload` → `wiki +node-*` |

## CLI 命令速查

```bash
# 列出全部知识库空间
lark-cli wiki spaces list

# 解析 wiki/docx URL，得到 obj_type + obj_token + space_id
lark-cli wiki +node-get --node-token "URL"

# 在知识库创建文档节点
lark-cli wiki +node-create --space-id SPACE_ID --title "标题" --obj-type docx

# 将云盘文档移入知识库（需要源文档写权限）
lark-cli wiki +move --obj-token DOCX_TOKEN --obj-type docx --target-space-id SPACE_ID --target-parent-token NODE_TOKEN

# 复制 wiki 节点（源必须是 wiki node token）
lark-cli wiki +node-copy --node-token WIKI_NODE_TOKEN --target-space-id SPACE_ID

# 云盘文件夹操作
lark-cli drive files list FOLDER_TOKEN
lark-cli drive +upload --file ./file.txt --folder-token FOLDER_TOKEN --name "name"
lark-cli drive +push --local-dir . --folder-token FOLDER_TOKEN
```