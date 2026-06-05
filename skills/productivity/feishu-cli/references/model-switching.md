# 模型切换参考脚本

当主模型额度不足时，快速切换到备用模型。

## 使用场景

- 主模型（kimi）额度用完，需要临时切换到 minimax 或 deepseek
- 测试不同模型的效果
- 故障恢复

## 前提条件

config.yaml 中已配置好所有 provider：

```yaml
providers:
  kimi-coding:
    base_url: https://api.moonshot.cn/v1
    api_key: sk-xxx
    models:
      kimi-for-coding:
        cost_input: 0.0015
        cost_output: 0.006
    default_model: kimi-for-coding
  minimax:
    base_url: https://api.minimax.chat/v1
    api_key: sk-xxx
    models:
      minimax-pro:
        cost_input: 0.0015
        cost_output: 0.006
    default_model: minimax-pro
  deepseek:
    base_url: https://api.deepseek.com/v1
    api_key: sk-xxx
    models:
      deepseek-chat:
        cost_input: 0.001
        cost_output: 0.002
    default_model: deepseek-chat
```

## 切换脚本

```bash
#!/bin/bash
# 用法: switch-model [kimi|minimax|deepseek]

CONFIG="/opt/data/config.yaml"
TARGET=${1:-}

if [ -z "$TARGET" ]; then
    echo "当前: $(grep "^  default:" "$CONFIG" | head -1)"
    echo "用法: switch-model [kimi|minimax|deepseek]"
    exit 0
fi

case "$TARGET" in
  kimi)     MODEL="kimi-for-coding"; PROVIDER="kimi-coding" ;;
  minimax)  MODEL="minimax-pro";     PROVIDER="minimax" ;;
  deepseek) MODEL="deepseek-chat";   PROVIDER="deepseek" ;;
  *) echo "错误: 未知模型 '$TARGET'"; exit 1 ;;
esac

sed -i "s/^  default: .*/  default: $MODEL/" "$CONFIG"
sed -i "s/^  provider: .*/  provider: $PROVIDER/" "$CONFIG"
echo "已切换到: $TARGET (需重启 Hermes 生效)"
```

## 手动切换命令

```bash
# 切换到 minimax
hermes config set model.default minimax-pro
hermes config set model.provider minimax

# 切换到 deepseek
hermes config set model.default deepseek-chat
hermes config set model.provider deepseek

# 切回 kimi
hermes config set model.default kimi-for-coding
hermes config set model.provider kimi-coding
```

## 注意事项

1. **切换后需重启 Hermes** 使配置生效
2. **fallback_providers** 只在主模型完全不可用时触发，额度不足不会自动切换
3. 建议保持 `fallback_providers: [deepseek]` 作为最后一道防线
