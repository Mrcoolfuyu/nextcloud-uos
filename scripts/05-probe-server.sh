#!/bin/bash
# Nextcloud 服务端 - 查询支持的桌面客户端版本范围
NC=/data0/nextcloud

echo "===== 1. version.php ====="
grep -E "OC_Version|VersionString" "$NC/version.php" | head -6

echo ""
echo "===== 2. lib/private 中 desktop+version ====="
grep -rn -i "desktop" "$NC/lib/private/" --include="*.php" 2>/dev/null | grep -iE "minimum|version" | head -20

echo ""
echo "===== 3. 全库搜索 minimum.xxx.desktop/client ====="
grep -rn -iE "minimum.{0,40}(desktop|client)" "$NC/lib" "$NC/apps" "$NC/core" 2>/dev/null | head -15

echo ""
echo "===== 4. minimum.supported 关键字 ====="
grep -rn "minimum.supported" "$NC" 2>/dev/null | head -10

echo ""
echo "===== 5. config.php 相关项 ====="
grep -iE "version|minimum" "$NC/config/config.php" 2>/dev/null | head -12

echo ""
echo "===== 6. 客户端版本检查相关文件 ====="
ls "$NC/lib/versioncheck.php" 2>/dev/null && head -30 "$NC/lib/versioncheck.php"

echo ""
echo "===== 7. capabilities 端点 ====="
curl -sk -m 15 "https://home.cnraft.com:9443/ocs/v2.php/cloud/capabilities?format=json" 2>/dev/null | head -c 400
echo ""

echo ""
echo "===== 8. 搜索 'client' 版本号常量 ====="
grep -rn -E "(MINIMUM|LOWEST|OLDEST).{0,20}(CLIENT|VERSION)" "$NC/lib" 2>/dev/null | head -10
