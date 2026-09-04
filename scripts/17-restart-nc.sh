#!/bin/bash
# L420x - 清理旧实例并启动 Nextcloud（用 -x 按进程名精确匹配，避免 pkill -f 自匹配）
set -u

echo "===== 清理旧实例 ====="
PIDS=$(pgrep -x nextcloud 2>/dev/null)
if [ -n "$PIDS" ]; then
  echo "  旧实例 PID: $PIDS"
  kill $PIDS 2>/dev/null
  sleep 3
  kill -9 $PIDS 2>/dev/null
  sleep 1
else
  echo "  无旧实例"
fi

echo ""
echo "===== 启动新实例 ====="
rm -f /tmp/nextcloud-session.log
nohup setsid /opt/nextcloud/bin/nextcloud-uos.sh > /tmp/nextcloud-session.log 2>&1 < /dev/null &
sleep 12

echo ""
echo "===== 状态 ====="
NEWPID=$(pgrep -x nextcloud 2>/dev/null | head -1)
if [ -n "$NEWPID" ]; then
  echo "  [OK] nextcloud 运行中"
  ps -o pid,etime,rss,cmd -p "$NEWPID" 2>/dev/null | head -2
else
  echo "  [!!] 未检测到运行实例"
fi

echo ""
echo "--- 启动日志 ---"
tail -10 /tmp/nextcloud-session.log 2>/dev/null
echo ""
echo "--- 错误扫描 ---"
if cat /tmp/nextcloud-session.log 2>/dev/null | grep -aiE "cannot mix|incompatible|symbol lookup|undefined symbol|Failed to load|SIGSEGV|段错误"; then
  echo "  [!!] 发现错误"
else
  echo "  [OK] 无 ABI 冲突 / 插件失败 / 段错误"
fi
echo ""
echo "--- 环境 ---"
DISPLAY=:1 XAUTHORITY=/home/mrcool/.Xauthority /opt/nextcloud/bin/nextcloud-uos.sh --version 2>&1 | head -4
