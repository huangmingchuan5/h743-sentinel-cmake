#!/usr/bin/env bash
# ============================================================
# 新工程初始化
#
# 用法：把模板整个目录复制成新工程后，在新目录里执行
#         ./tools/new_project.sh
#
# 它做三件事：
#   1. 删除复制过来的 build/（CMakeCache 里是上一个工程的绝对路径）
#   2. 重置被继承的 git 仓库（模板的提交历史不该属于新工程）
#   3. 清掉 .workbuddy/（上一个工程的会话记录）
#
# 工程名与产物名无需手动修改：CMakeLists.txt 会自动取目录名，
# run.sh / flash / launch.json 也会跟随。
# ============================================================
set -e

cd "$(dirname "$0")/.."
NAME="$(basename "$(pwd)")"

# ---------- 防止在模板目录误执行 ----------
if [ "$NAME" = "Cmake_2_Projects_Template" ]; then
    echo "当前目录是模板本身（$NAME），拒绝执行。"
    echo "请先把整个目录复制成新工程，再到新目录里运行本脚本。"
    exit 1
fi

echo "工程目录：$(pwd)"
echo "自动命名：$NAME"
echo ""

# ---------- 1. 清理构建缓存 ----------
if [ -d build ]; then
    rm -rf build
    echo "[1/3] 已删除 build/"
else
    echo "[1/3] 无 build/，跳过"
fi

# ---------- 2. 重置继承的 git ----------
if [ -d .git ]; then
    OLD_REMOTE="$(git remote get-url origin 2>/dev/null || echo '<none>')"
    echo "[2/3] 检测到继承的 .git（origin = $OLD_REMOTE），正在重置 ..."
    rm -rf .git
    git init -q
    echo "      已重置为全新的空仓库，模板历史与 remote 均已解除"
else
    echo "[2/3] 无 .git，跳过"
fi

# ---------- 3. 清理工程记录 ----------
if [ -d .workbuddy ]; then
    rm -rf .workbuddy
    echo "[3/3] 已删除 .workbuddy/"
else
    echo "[3/3] 无 .workbuddy/，跳过"
fi

echo ""
echo "完成。新工程可直接开始写代码："
echo "  ./run.sh         编译，产物为 build/$NAME.elf"
echo "  ./run.sh flash   编译并烧录"
echo ""
echo "新增源文件放在 User/Src/，头文件放 User/Inc/，"
echo "CMake 会自动收集（GLOB + CONFIGURE_DEPENDS），无需改 CMakeLists.txt。"
