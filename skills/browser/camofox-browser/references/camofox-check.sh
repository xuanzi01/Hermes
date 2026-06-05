# Camofox 健康检查 & 启动脚本
# 用法: bash /opt/data/skills/browser/camofox-browser/references/camofox-check.sh

HEALTH_URL="http://localhost:9377/health"
MAX_WAIT=12

echo "=== Camofox 健康检查 ==="

# 1. 检查服务端
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 服务端运行中"
else
    echo "❌ 服务端未运行 (HTTP $HTTP_CODE)"
    echo "启动: cd /opt/data/workspace/camofox-browser && node server.js > /tmp/camofox.log 2>&1 &"
    exit 1
fi

# 2. 检查浏览器引擎
HEALTH_JSON=$(curl -s "$HEALTH_URL" 2>/dev/null)
BROWSER_OK=$(echo "$HEALTH_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('browserConnected') and d.get('browserRunning') else 'false')" 2>/dev/null)

if [ "$BROWSER_OK" = "true" ]; then
    echo "✅ 浏览器引擎就绪"
    echo "健康状态: $HEALTH_JSON"
    exit 0
else
    echo "⚠️  服务端在跑但浏览器引擎未就绪"
    echo "健康状态: $HEALTH_JSON"
    echo ""
    echo "常见原因:"
    echo "  1. 系统库缺失 → 检查 /tmp/camofox.log 中是否有 'libgtk-3.so.0' 错误"
    echo "  2. better-sqlite3 版本不匹配 → 需要 npm rebuild"
    echo ""
    echo "修复步骤:"
    echo "  1. 在 1Panel 终端执行: apt-get update && apt-get install -y libgtk-3-0 libnss3 libnspr4 libasound2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxshmfence1"
    echo "  2. 重启: pkill -f 'node server.js'; sleep 2; cd /opt/data/workspace/camofox-browser && node server.js > /tmp/camofox.log 2>&1 &"
    exit 1
fi