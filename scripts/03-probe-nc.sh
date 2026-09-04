#!/bin/bash
# NAS - 确认是否存在 Nextcloud 服务端
echo "===== 1. 端口 80/443/8080 监听 ====="
ss -tlnp 2>/dev/null | grep -E ":80 |:443 |:8080 |:8888 |:9000 |:8000 " || echo "  80/443/8080/8888/9000/8000 均未在监听"

echo ""
echo "===== 2. 所有监听端口（去重）====="
ss -tln 2>/dev/null | awk '/LISTEN/{print $4}' | sort -u | tr '\n' ' '; echo

echo ""
echo "===== 3. docker 容器（含已停止）====="
docker ps -a --format "{{.Names}} | {{.Image}} | {{.Status}}" 2>&1 | head -20

echo ""
echo "===== 4. 磁盘上搜索 nextcloud ====="
for d in /vol1 /vol2 /vol3 /mnt /opt /srv /var/www /home /root /usr/share; do
  [ -d "$d" ] || continue
  hits=$(find "$d" -maxdepth 6 -iname "*nextcloud*" 2>/dev/null | head -8)
  [ -n "$hits" ] && { echo "  [$d]"; echo "$hits" | sed 's/^/    /'; }
done
echo "  (以上为空则未找到)"

echo ""
echo "===== 5. 搜索 status.php（Nextcloud 特征文件）====="
find /vol1 /vol2 /opt /srv /var/www /home -maxdepth 7 -name "status.php" 2>/dev/null | head -10
echo "  (以上为空则未找到)"

echo ""
echo "===== 6. Caddy 配置（80 端口返回 Server: Caddy）====="
for f in /etc/caddy/Caddyfile /usr/local/etc/caddy/Caddyfile /vol1/docker/caddy/Caddyfile; do
  [ -f "$f" ] && { echo "  === $f ==="; head -40 "$f" | sed 's/^/    /'; }
done

echo ""
echo "===== 7. nginx 配置中的 nextcloud ====="
grep -ril "nextcloud" /etc/nginx/ /usr/local/etc/nginx/ 2>/dev/null | head -5
echo "  (以上为空则未找到)"
