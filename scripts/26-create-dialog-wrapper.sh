#!/bin/bash
# L420x - 创建"打开主对话框"封装脚本
# 仅在调用本脚本时临时启用 Mesa 软件 GL（LIBGL_ALWAYS_SOFTWARE=1），
# 让 Nextcloud 主窗口的 QML 能正常渲染（避免软件 QML 后端导致的空白主窗口）。
# 变量仅在本进程内生效（exec 后子进程继承），不影响其他进程。

set -u
NC=/opt/nextcloud

WRAPPER="$NC/bin/nextcloud-dialog-uos.sh"

echo "[*] 写入 $WRAPPER"
cat > "$WRAPPER" <<'EOS'
#!/bin/bash
# Nextcloud "打开主对话框" 启动封装
# 临时设置 LIBGL_ALWAYS_SOFTWARE=1，让主窗口 QML 走 Mesa 软件 GL 渲染（避免白屏）
# 仅本进程内生效（exec 后子进程继承此变量），不影响系统其他组件与托盘/同步进程

export LIBGL_ALWAYS_SOFTWARE=1
exec /opt/nextcloud/bin/nextcloud-uos.sh "$@"
EOS

chmod +x "$WRAPPER" || { echo "!!!! chmod 失败"; exit 1; }

echo
echo "[*] 校验"
echo "--- 脚本内容 ---"
cat "$WRAPPER"
echo "--- 可执行 ---"
ls -l "$WRAPPER"