#!/bin/bash
# L420x - Nextcloud 客户端冒烟验证
set -u
QT=/opt/qt515
NC=/opt/nextcloud
log() { echo "[*] $*"; }

echo "===== 1. 版本信息 ====="
"$NC/bin/nextcloud" --version 2>&1 | head -6
echo "--- nextcloudcmd (CLI) ---"
"$NC/bin/nextcloudcmd" --version 2>&1 | head -4

echo ""
echo "===== 2. QML 模块完整性 ====="
for m in QtQuick.2 QtQuick/Controls.2 QtQuick/Layouts QtQuick/Window.2 QtGraphicalEffects QtQml/Models.2; do
  if [ -d "$QT/qml/$m" ]; then echo "  [OK]      $m"; else echo "  [MISSING] $m"; fi
done

echo ""
echo "===== 3. 平台插件 ====="
ls "$QT/plugins/platforms/" 2>/dev/null | tr '\n' ' '; echo

echo ""
echo "===== 4. 中文翻译文件 ====="
find "$NC" -name "*zh_CN*.qm" 2>/dev/null | head -5 || true
echo "  (空则无中文翻译)"

echo ""
echo "===== 5. 冒烟测试：offscreen 启动 22 秒 ====="
rm -f /tmp/nc-smoke.log /tmp/nc-smoke-stdout.log
export QT_QPA_PLATFORM=offscreen
"$NC/bin/nextcloud-uos.sh" --logfile /tmp/nc-smoke.log > /tmp/nc-smoke-stdout.log 2>&1 &
PID=$!
sleep 22
if kill -0 "$PID" 2>/dev/null; then
  echo "  [OK] 进程存活，PID=$PID"
  kill "$PID" 2>/dev/null
  sleep 2
  kill -9 "$PID" 2>/dev/null
else
  echo "  [!!] 进程已退出"
fi
wait "$PID" 2>/dev/null

echo ""
echo "--- stdout/stderr ---"
tail -25 /tmp/nc-smoke-stdout.log 2>/dev/null
echo "--- 客户端日志文件 ---"
tail -25 /tmp/nc-smoke.log 2>/dev/null

echo ""
echo "===== 6. 错误特征检查 ====="
if cat /tmp/nc-smoke*.log 2>/dev/null | grep -aiE "cannot mix|incompatible|version.*mismatch|symbol lookup|undefined symbol|qt.qpa.plugin|Failed to load|SIGSEGV|段错误"; then
  echo "  [!!] 发现可疑错误，见上"
else
  echo "  [OK] 未发现 ABI 冲突 / 插件加载失败 / 段错误"
fi
