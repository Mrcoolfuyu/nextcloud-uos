#!/bin/bash
# L420x - 下载并解压 Qt 5.15.2 子模块源码
set -u
SRC=/home/mrcool/ncbuild/src
mkdir -p "$SRC" && cd "$SRC"

MODS="qtbase qtdeclarative qtsvg qtgraphicaleffects qtquickcontrols2"
BASES="
https://download.qt.io/new_archive/qt/5.15/5.15.2/submodules
https://download.qt.io/archive/qt/5.15/5.15.2/submodules
https://mirrors.tuna.tsinghua.edu.cn/qt/archive/qt/5.15/5.15.2/submodules
https://mirrors.ustc.edu.cn/qtproject/archive/qt/5.15/5.15.2/submodules
https://mirrors.aliyun.com/qt/archive/qt/5.15/5.15.2/submodules
https://mirrors.cloud.tencent.com/qt/archive/qt/5.15/5.15.2/submodules
"

echo "===== 探测可用镜像 ====="
GOOD=""
for b in $BASES; do
  u="$b/qtbase-everywhere-src-5.15.2.tar.xz"
  code=$(curl -sI -m 25 -o /dev/null -w "%{http_code}" "$u" 2>/dev/null)
  echo "  [$code] $b"
  if [ "$code" = "200" ] && [ -z "$GOOD" ]; then GOOD="$b"; fi
done

if [ -z "$GOOD" ]; then echo "!! 无可用镜像，退出"; exit 1; fi
echo ""
echo "选用镜像: $GOOD"

echo ""
echo "===== 下载 ====="
for m in $MODS; do
  f="${m}-everywhere-src-5.15.2.tar.xz"
  if [ -f "$f" ]; then echo "  已存在跳过: $f ($(du -h "$f" | cut -f1))"; continue; fi
  echo "  下载 $f ..."
  if curl -fL --retry 3 --retry-delay 2 -m 1800 -o "$f.part" "$GOOD/$f"; then
    mv "$f.part" "$f"
    echo "  完成: $f ($(du -h "$f" | cut -f1))"
  else
    echo "  !! 下载失败: $f"
    exit 1
  fi
done

echo ""
echo "===== 解压 ====="
for m in $MODS; do
  f="${m}-everywhere-src-5.15.2.tar.xz"
  echo "  解压 $f ..."
  tar xf "$f" || { echo "  !! 解压失败"; exit 1; }
done

echo ""
echo "===== 完成 ====="
ls -d */ 2>/dev/null
df -h /home | tail -1
