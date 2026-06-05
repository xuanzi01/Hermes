# AnySearch Skill 安装指南（2026-05-28）

## 安装步骤

```bash
# 1. 下载 Skill 仓库
cd /tmp && curl -L -o anysearch-skill.zip \
  https://github.com/anysearch-ai/anysearch-skill/archive/refs/heads/main.zip

# 2. 解压
python3 -c "import zipfile; zipfile.ZipFile('anysearch-skill.zip').extractall('.')"

# 3. 安装到 skills 目录
mkdir -p ~/.agents/skills/anysearch
cp -r /tmp/anysearch-skill-main/* ~/.agents/skills/anysearch/

# 4. 选择运行时（优先 Node.js，零依赖）
echo "Runtime: Node.js" > ~/.agents/skills/anysearch/runtime.conf
echo "Command: node ~/.agents/skills/anysearch/scripts/anysearch_cli.js" >> ~/.agents/skills/anysearch/runtime.conf
```

## 运行时选择

| 运行时 | 依赖 | 状态 |
|-------|------|------|
| Python | requests | ❌ 容器内可能缺少 |
| **Node.js** | 无 | ✅ **推荐** |
| Bash | curl, jq | ✅ 可用 |

## 验证

```bash
# 测试搜索
node ~/.agents/skills/anysearch/scripts/anysearch_cli.js \
  search "hello world" --max_results 1

# 测试提取
node ~/.agents/skills/anysearch/scripts/anysearch_cli.js \
  extract "https://example.com"
```

## 配置 API Key（可选）

匿名访问可用，但有限流。如需高配额：
```bash
export ANYSEARCH_API_KEY="your-key"
```

## 可用命令

| 命令 | 用途 |
|-----|------|
| `search` | 单查询搜索 |
| `batch_search` | 并行批量搜索 |
| `extract` | URL 内容提取 |
| `list_domains` | 垂直领域查询 |
| `doc` | 查看完整接口文档 |

## 垂直领域

finance, academic, travel, health, code, geo, ecommerce, gaming, film, music, legal, business, ip, energy, environment

## 使用示例

```bash
# 一般搜索
node scripts/anysearch_cli.js search "AI news" --max_results 5

# 带时间过滤
node scripts/anysearch_cli.js search "AI news" --freshness week

# 批量搜索
node scripts/anysearch_cli.js batch_search \
  --queries '[{"query":"q1","max_results":5},{"query":"q2","max_results":5}]'

# 提取网页内容
node scripts/anysearch_cli.js extract "https://example.com/article"
```
