# RTK + Hermes 部署路径与故障排查

## 部署路径对照

| 部署方式 | HERMES_HOME | RTK 二进制 | Plugin 目录 | Config |
|--------|------------|-----------|------------|--------|
| **终端/物理机（当前）** | `/root/.hermes` | `/root/.hermes/home/.local/bin/rtk` | `/root/.hermes/plugins/rtk-rewrite` | `/root/.hermes/config.yaml` |
| Docker/1Panel | `/opt/data` | `/opt/data/home/.local/bin/rtk` | `/opt/data/plugins/rtk-rewrite` | `/opt/data/config.yaml` |

## 两种 Restart 域（Docker 部署需注意）

| Command | Scope | RTK Plugin Reloads? |
|---------|-------|---------------------|
| `/restart`（Feishu slash） | Gateway进程 | ❌ 否 — platform handlers 重启，plugin 不重载 |
| 1Panel 重启 / systemctl | 完整容器重启 | ✅ 是 — sandbox + gateway |

**核心教训：** 从飞书发 `/restart` 只重启了消息网关，不重启执行环境，RTK 插件不会重新加载。Docker 部署必须用 1Panel 面板重启。

## Plugin Layer PATH 问题

**症状：** `rtk init -g --agent hermes`完成后，第一次执行终端命令时报 "rtk: command not found"。

**根因：** 插件的 `__init__.py` 硬编码了 RTK 二进制路径，必须与实际安装路径一致。Docker 部署装在 `/opt/data/...`，终端部署装在 `/root/.hermes/...`，路径错误则 `_check_rtk()` 返回 False，hook 不注册。

**诊断：**
```python
# 查看插件中的路径配置（两处必须一致）
grep -n "os.path.exists\|\.local/bin/rtk" /root/.hermes/plugins/rtk-rewrite/__init__.py
```

**修复（无需重启，立即生效）：**
```python
# 文件：/root/.hermes/plugins/rtk-rewrite/__init__.py

# 改1：_check_rtk() 中的路径判断
_rtk_available = os.path.exists("/root/.hermes/home/.local/bin/rtk")

# 改2：subprocess.run() 中的调用路径
["/root/.hermes/home/.local/bin/rtk", "rewrite", command],
```

**为什么无需重启：** 插件每次命令执行时从磁盘重新导入，patch 后下一条终端命令立即生效。

## 验证方法

```bash
# 终端测试 RTK CLI
/root/.hermes/home/.local/bin/rtk --version
# 应输出：rtk 0.42.0

# 终端测试重写
/root/.hermes/home/.local/bin/rtk rewrite "git status"
# 应输出压缩后的命令（exit 3 为正常）
```

## RTK 二进制安装位置说明

RTK 通过官方 install.sh 安装时默认装在 `~/.local/bin/rtk`，展开为 `/root/.hermes/home/.local/bin/rtk`（HERMES_HOME 的 home 子目录）。

Docker 部署时 install.sh 装在 `/opt/data/home/.local/bin/rtk`。

**不要重新安装**，已有正确路径的 RTK 二进制无需移动。