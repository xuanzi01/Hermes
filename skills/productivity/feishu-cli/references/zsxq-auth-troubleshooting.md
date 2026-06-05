# 知识星球 zsxq-cli 授权问题排查（2026-05-28）

## 问题现象

Device Flow 授权链接跳转到 MCP 开发者后台（显示"密钥管理"），而非 OAuth 确认页面，没有"确认授权"按钮。

## 根因分析

1. **OAuth 流程与 MCP 开发者平台是两套系统**
   - Device Flow 需要用户在授权页面点击"确认"
   - MCP 后台显示的是 API Key 管理，不是 OAuth 授权

2. **Docker 环境限制**
   - 无系统 Keychain（gnome-keyring/libsecret）
   - 即使授权成功也无法存储 Token

3. **密钥类型不匹配**
   - MCP 后台显示的"密钥"可能是 MCP Server Key
   - 不是 OAuth access_token
   - 直接用于 Bearer Token 认证返回 401

## 排查步骤

```bash
# 1. 检查当前配置
cat ~/.config/zsxq-cli/config.json

# 2. 检查 CLI 版本和配置
zsxq-cli config show
zsxq-cli doctor

# 3. 测试密钥是否有效
curl -s "https://api.zsxq.com/v2/groups" \
  -H "Authorization: Bearer <key>"
# 401 = 密钥类型不匹配或已失效
```

## 已知限制（v0.4.7）

| 限制 | 说明 |
|-----|------|
| 无 `--token` 参数 | CLI 不支持直接传入 Token |
| Token 存 Keychain | Docker 环境无法使用 |
| Device Flow 跳转错误 | 授权链接可能指向错误页面 |

## 解决方案（已验证）

### 方案 A：本地电脑授权 + 导出 Token（推荐）

在本地电脑（Mac/Windows/Linux 桌面版，有 Keychain）完成授权，导出 Token 给容器使用。

**步骤**：
```bash
# 1. 本地安装
npm install -g zsxq-cli

# 2. 本地授权
zsxq-cli auth login
# 按提示用手机/浏览器打开链接完成授权

# 3. 导出 Access Token
# Mac:
security find-generic-password -s "zsxq-cli" -w
# Windows:
zsxq-cli config show
# Linux:
secret-tool lookup service zsxq-cli

# 4. 将 Token 配置到 Hermes 环境变量
export ZSXQ_TOKEN="<token>"
```

**验证 Token**：
```bash
curl -s "https://api.zsxq.com/v2/groups" \
  -H "Authorization: Bearer $ZSXQ_TOKEN"
# 返回星球列表 = 有效
```

### 方案 B：直接调 REST API

绕过 CLI，用 MCP 开发者后台的密钥直接调知识星球 API。

**注意**：MCP 后台的"密钥"（如 `7a9384f34ac8bd2182f0da05e8528d84`）**不是 OAuth Token**，直接用于 Bearer Token 认证返回 401。

**正确做法**：
1. 在 MCP 后台创建 OAuth 应用，获取 `Client ID` + `Client Secret`
2. 用标准 OAuth 2.0 Client Credentials 流程获取 Token
3. 或使用知识星球官方 REST API 文档中的认证方式

### 方案 C：宿主机安装 Keychain（不推荐）

| 方面 | 影响 |
|-----|------|
| 空间占用 | ~80-150MB |
| 维护复杂度 | 高（需运行 dbus + keyring daemon，改 entrypoint）|
| 稳定性 | Docker 重启后数据可能丢失 |
| 升级兼容性 | 1Panel 升级 Hermes 镜像时自定义改动可能被覆盖 |
| 安全边界 | 打破容器隔离原则 |

**结论**：Keychain 是给桌面环境设计的，在 Docker 里硬跑是反模式。

## Docker 环境 OAuth 工具通用排查流程

当在 Docker 容器内安装需要 OAuth 授权的 CLI 工具时：

```
1. 安装 CLI → 2. 尝试授权 → 3. 检查是否跳转正确页面
    ↓ 跳转错误/无确认按钮
4. 分析授权流程类型（OAuth / API Key / MCP）
    ↓
5. 检查容器是否有 Keychain 服务
    ↓ 无 Keychain
6. 选择替代方案：
   - 本地授权 + 导出 Token
   - 环境变量注入
   - 直接调 REST API
   - 配置文件明文存储（控制权限 600）
```

**关键原则**：
- 试错 3 次后停止，分析根因
- 区分密钥类型（OAuth Token / API Key / MCP Server Key）
- 优先用官方文档确认授权流程
- Docker 容器内不要硬跑 Keychain
