#!/bin/bash
# 最终综合健康检查
echo "=== running instance ==="
pgrep -af /opt/nextcloud/bin/nextcloud | grep -v pgrep | head -2
echo
echo "=== desktop entry ==="
cat /usr/share/applications/nextcloud.desktop
echo
echo "=== icon resolves ==="
ls -l /usr/share/pixmaps/nextcloud.png /usr/share/icons/hicolor/256x256/apps/nextcloud.png 2>&1
echo
echo "=== server reachable from client box ==="
curl -sk -m 15 -o /dev/null -w "home.cnraft.com:9443 -> HTTP %{http_code}\n" https://home.cnraft.com:9443/status.php
echo
echo "=== client binaries ==="
ls -l /opt/nextcloud/bin/nextcloud /opt/nextcloud/bin/nextcloudcmd /opt/nextcloud/bin/nextcloud-uos.sh
echo
echo "=== version (isolated) ==="
DISPLAY=:1 XAUTHORITY=/home/mrcool/.Xauthority /opt/nextcloud/bin/nextcloud-uos.sh --version 2>&1 | head -4
