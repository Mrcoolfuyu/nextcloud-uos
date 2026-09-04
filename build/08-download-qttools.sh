#!/bin/bash
# L420x - 下载 qttools（提供 lrelease/lupdate，Nextcloud 客户端中文翻译需要）
set -u
cd /home/mrcool/ncbuild/src || exit 1

MIRROR=$(grep "选用镜像" /home/mrcool/ncbuild/download.log 2>/dev/null | sed 's/.*镜像: //' | tail -1)
if [ -z "$MIRROR" ]; then
  MIRROR="https://download.qt.io/new_archive/qt/5.15/5.15.2/submodules"
fi
echo "使用镜像: $MIRROR"

F=qttools-everywhere-src-5.15.2.tar.xz
if [ -d qttools-everywhere-src-5.15.2 ]; then
  echo "qttools 已存在，跳过"
else
  echo "下载 $F ..."
  curl -fL --retry 3 -m 1800 -o "$F.part" "$MIRROR/$F" || { echo "!! 下载失败"; exit 1; }
  mv "$F.part" "$F"
  echo "解压..."
  tar xf "$F" || { echo "!! 解压失败"; exit 1; }
fi
ls -d qttools-everywhere-src-5.15.2 && echo "qttools 就绪"
