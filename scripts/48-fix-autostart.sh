#!/bin/bash
# 修复根因：启动器 exec -a 伪装 argv[0]，使客户端写 autostart 时用启动器路径
set -e
APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=arm64
WORK="$HOME/packaging/${APPID}-${VER}"
WRAPPER="$WORK/opt/apps/$APPID/files/bin/com.cnraft.nextcloud"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

run_sudo chown -R mrcool:mrcool "$WORK"

echo "[*] 修改前 exec 行:"
grep -n "^exec" "$WRAPPER"

# 关键修复：exec -a "$0" 使 argv[0] 保持为启动器路径
# -> Qt applicationFilePath() 返回启动器路径
# -> 客户端"开机自启动"写出 Exec=<启动器路径>（自带隔离环境，可正常启动）
sed -i 's|^exec \$BASE/nextcloud/bin/nextcloud "\$@"$|exec -a "$0" "$BASE/nextcloud/bin/nextcloud" "$@"|' "$WRAPPER"

echo "[*] 修改后 exec 行:"
grep -n "^exec" "$WRAPPER"

# 重建 deb + 覆盖安装
( cd "$WORK" && find opt -type f -print0 | sort -z | xargs -0 md5sum ) > "$WORK/DEBIAN/md5sums"
rm -f "$DEB"
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB"

echo "[*] 覆盖安装..."
run_sudo dpkg -i "$DEB" 2>&1 | tail -2

# 重启客户端验证 argv[0]
echo "[*] 重启客户端..."
run_sudo pkill -x nextcloud 2>/dev/null || true
sleep 2
nohup setsid /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --background > /tmp/nc-autostart-test.log 2>&1 < /dev/null &
sleep 10
PID=$(pgrep -x nextcloud | head -1)
echo "=== 新实例 argv[0]（应为启动器路径）==="
tr '\0' '\n' < /proc/$PID/cmdline 2>/dev/null | head -2
echo
echo "=== 进程存活 ==="
ps -o pid,etime,rss -p "$PID" | tail -1
echo FIX_DONE
