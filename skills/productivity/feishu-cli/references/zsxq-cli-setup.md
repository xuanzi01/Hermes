# zsxq-cli（知识星球 CLI）安装与授权

## 安装

```bash
# 安装 CLI（包名是 zsxq-cli，不是 zsxg-cli）
npm install -g zsxq-cli

# 确保 PATH 包含 npm global bin
export PATH="$HOME/.local/share/npm-global/bin:$PATH"

# 验证
zsxq-cli --version  # → zsxq-cli version 0.4.7
```

## 安装 Skill

```bash
npx skills add https://github.com/unnoo/zsxq-skill --yes --global
```

安装后会得到 5 个 Skill：
- `zsxq-group` — 星球管理
- `zsxq-note` — 笔记管理
- `zsxq-shared` — 分享管理
- `zsxq-topic` — 主题管理
- `zsxq-user` — 用户管理

### 授权流程（Docker 环境限制）

**关键限制**：Docker 容器内无系统 Keychain（gnome-keyring/libsecret），zsxq-cli 的 OAuth Token 无法存储。

#### Device Flow（标准流程，容器内走不通）

```bash
zsxq-cli auth login
```

输出示例：
```
┌─────────────────────────────────────────┐
│            知识星球 授权登录            │
└─────────────────────────────────────────┘

请访问以下链接完成授权：
  →  https://garden.zsxq.com/jasmine/index.html?code=***
  确认码：XXXX-XXXX
```

**问题**：v0.4.7 的授权链接会跳转到 MCP 开发者后台（显示"密钥管理"），而非 OAuth 确认页面，没有"确认授权"按钮。且即使授权成功，Docker 内无 Keychain 也无法存储 Token。

#### 可行方案

| 方案 | 做法 | 可行性 |
|-----|------|--------|
| A. 宿主机授权 | 在本地电脑（Mac/Windows）安装 zsxq-cli，完成授权后导出 Token | ✅ 最佳 |
| B. 环境变量 | 检查是否支持 `ZSXQ_TOKEN`（当前版本不支持） | ❌ 不可行 |
| C. 配置文件 | 直接写入 `~/.config/zsxq-cli/config.json`（需确认密钥类型） | ⚠️ 待验证 |
| D. 直接调 API | 绕过 CLI，用密钥直接调知识星球 REST API | ✅ 可行但安全性需评估 |

**推荐**：方案 A（宿主机授权）或方案 D（直接调 API，需用户确认安全风险）。

**宿主机安装 Keychain 不推荐**：
- 空间占用 ~80-150MB
- 维护复杂度高（需运行 dbus + keyring daemon）
- Docker 重启后数据可能丢失
- 打破容器隔离原则
- 1Panel 升级时自定义改动可能被覆盖

## 常用命令

```bash
# 查看登录状态
zsxq-cli auth status

# 列出加入的星球
zsxq-cli group +list

# 查看星球内容
zsxq-cli group +get --group-id <id>

# 搜索帖子
zsxq-cli topic +search --keyword <keyword>

# 查看足迹
zsxq-cli user +footprint
```

## 已知问题

| 问题 | 状态 |
|------|------|
| Device Flow 授权链接跳转错误 | 已知，待官方修复 |
| 密钥类型不明确（access_token vs MCP Key） | 需用户确认 |
| 无 `--token` 参数支持 | 当前版本不支持 |

## 相关路径

- 二进制：`~/.local/share/npm-global/lib/node_modules/zsxq-cli/node_modules/@zsxq/cli-linux-x64/bin/zsxq-cli`
- 配置：`~/.config/zsxq-cli/config.json`
- Skill 目录：`~/.agents/skills/zsxq-*`
