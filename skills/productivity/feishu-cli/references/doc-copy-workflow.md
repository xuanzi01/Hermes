# 复制飞书文档到知识库：完整工作流（2026-06-02）

## 核心教训

复制他人文档失败时，**不要**先怀疑"权限隔离"等复杂原因。
先查最简单的原因：`drive:file:copy` scope 是否缺失。

---

## Step 1：检查权限（先做这个！）

```bash
# 检查文档复制权限
lark-cli auth check --scope drive:file:copy
lark-cli auth check --scope wiki:node:copy
```

- ✅ 全部 ok → 去 Step 2
- ❌ 有缺失 → 去 Step 1b

## Step 1b：补充缺失权限

```bash
# 添加缺失的 scope（用户只需扫码一次）
lark-cli auth login --no-wait --json --scope "drive:file:copy"
```

> 注意：`--recommend` 不会自动包含 `drive:file:copy`，需要单独添加。

## Step 2：识别文档位置

```bash
# 查看文档类型（区分 doc/docx/wiki）
lark-cli drive +inspect --url https://my.feishu.cn/docx/<token>
```

| 类型 | 来源 | 能否直接复制 |
|------|------|------------|
| docx（独立云文档） | 云盘 | ✅ `drive files copy` |
| wiki 节点 | Wiki 知识库 | ✅ `wiki +node-copy` |
| doc（旧格式） | 云盘 | ✅ `drive files copy` |

## Step 3：根据类型选择复制方式

### 情况 A：docx 独立云文档 → 复制到云盘文件夹

```bash
# 先确认目标文件夹可用（普通文件夹，非 AI 知识库 Wiki 文件夹）
lark-cli drive files copy \
  --data '{"folder_token": "<folder_token>", "name": "文档副本", "type": "docx"}' \
  --params '{"file_token": "<doc_token>"}'
```

- 成功 → 用 `wiki +move` 移到知识库
- 1061004 → 缺少 `drive:file:copy` scope，回去 Step 1b

### 情况 B：Wiki 节点 → 复制到另一个 Wiki 空间/节点

```bash
# 确认源 wiki 节点
# node_token = wiki 节点 ID，obj_token = 文档 ID
lark-cli wiki +node-get --node-token <node_token> --obj-type docx

# 复制到同一知识库的不同节点
lark-cli wiki +node-copy \
  --space-id <source_space_id> \
  --node-token <source_node_token> \
  --target-parent-node-token <target_wiki_node_token> \
  --title "新标题" \
  --yes

# 或复制到另一个知识库
lark-cli wiki +node-copy \
  --space-id <source_space_id> \
  --node-token <source_node_token> \
  --target-space-id <target_space_id> \
  --title "新标题" \
  --yes
```

**⚠️ 注意**：`--target-parent-node-token` 必须是 **wiki 节点 token**，不能用云盘文件夹 token。搞混会报 131005 not found。

## Step 4：移入 AI 知识库（如需要）

```bash
# 文档已经在云盘，现在移到 AI 知识库
lark-cli wiki +move \
  --obj-token <doc_token> \
  --obj-type "docx" \
  --target-space-id <ai_space_id> \
  --target-parent-token <ai_parent_node_token>
```

## 两个不同的 1061004

| 错误 | 场景 | 原因 | 处理 |
|------|------|------|------|
| 1061004 | 普通云盘文件夹操作 | 缺 `drive:file:copy` scope | 添加 scope 后重试 |
| 1061004 | AI 知识库 Wiki 文件夹 | 权限孤岛（平台级） | 换普通文件夹 + 手动移动 |

## 关于图片

飞书文档的图片 block（type 27）以 token 引用存储，属于文档级资源。
**跨文档迁移图片没有干净方案**，最实用的做法：

1. Camofox 截长图保存到本地
2. 上传到普通云盘文件夹
3. 用户手动移动到 AI 知识库

---

## 相关 Token（2026-06-02 实测）

- Hermes 知识库 space_id: `7644558327271230430`
- AI 知识库 Wiki 文件夹 token: `RqjFfHAEKlOYZedgnw9cd8XZnph`
- 根目录测试文件夹 token: `TclzfF5YklJzC7dgiSIcSM9Knhb`