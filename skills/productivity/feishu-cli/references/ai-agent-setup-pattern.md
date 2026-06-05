# AI Agent 第三方工具安装标准流程

## 适用场景

当用户要求安装某个第三方 CLI 工具（如 zsxq-cli、lark-cli 等）并配置授权时，按此流程执行。

## 标准步骤

### 1. 安装 CLI

```bash
# 先检查包名是否正确（常见错误：打错包名）
npm install -g <package-name>

# 确保 PATH
export PATH="$HOME/.local/share/npm-global/bin:$PATH"

# 验证安装
<cli-name> --version
```

### 2. 安装 Skill（如有）

```bash
npx skills add <skill-repo-url> --yes --global
```

### 3. 授权登录

#### 方式 A：Device Flow（标准 OAuth 2.0）

```bash
# 获取授权链接（不等待）
<cli-name> auth login --json --no-wait
```

提取 `verification_uri_complete` 和 `user_code` 发给用户。

#### 方式 B：后台轮询（Agent 代操作）

```bash
# 后台运行，读取输出后提供链接给用户
<cli-name> auth login
```

**注意**：需要在有交互能力的环境中运行，Docker 容器内可能缺少浏览器支持。

### 4. 验证授权

```bash
<cli-name> auth status
<cli-name> doctor  # 如有此命令
```

## 常见问题

| 问题 | 根因 | 解决 |
|-----|------|------|
| 包名错误（404） | 用户提供的包名有误 | 尝试常见变体（如 zsxg-cli → zsxq-cli）|
| 授权链接跳转错误 | OAuth 流程变更或环境问题 | 查看官方文档，尝试替代授权方式 |
| Token 存储失败 | Docker 容器无 Keychain 服务 | 尝试环境变量或配置文件方式 |
| 密钥类型不匹配 | access_token vs API Key vs MCP Key | 确认密钥类型，尝试不同认证方式 |

## 关键原则

- **试错 3 次后停止**，分析根因再搜索解决方案
- **优先查看官方文档**（README、官网、GitHub）
- **区分密钥类型**：OAuth Token、API Key、MCP Server Key 用途不同
- **Docker 环境限制**：无 Keychain、无浏览器，需替代方案
