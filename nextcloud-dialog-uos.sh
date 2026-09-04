#!/bin/bash
# Nextcloud "打开主对话框" 启动封装
# 临时设置 LIBGL_ALWAYS_SOFTWARE=1，让主窗口 QML 走 Mesa 软件 GL 渲染（避免白屏）
# 仅本进程内生效（exec 后子进程继承此变量），不影响系统其他组件与托盘/同步进程

export LIBGL_ALWAYS_SOFTWARE=1
exec /opt/nextcloud/bin/nextcloud-uos.sh "$@"
