#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"
# Keep the macOS 14 deployment baseline even when the build host uses macOS 27.
export MACOSX_DEPLOYMENT_TARGET=14.0

ARCH_MODE="universal" # 默认构建 Universal 2 (arm64 + x86_64)
for arg in "$@"; do
    case "$arg" in
        --arm64)
            ARCH_MODE="arm64"
            ;;
        --x86_64)
            ARCH_MODE="x86_64"
            ;;
        --universal)
            ARCH_MODE="universal"
            ;;
        --native)
            ARCH_MODE="native"
            ;;
        -h|--help)
            echo "用法: ./build_app.sh [--universal | --arm64 | --x86_64 | --native]"
            echo "  --universal (默认) : 构建同时支持 Apple Silicon 与 Intel 的 Universal 2 通用应用"
            echo "  --arm64            : 仅构建 Apple Silicon (M1/M2/M3/M4) 架构"
            echo "  --x86_64           : 仅构建 Intel 架构"
            echo "  --native           : 仅构建当前本机硬件架构"
            exit 0
            ;;
    esac
done

echo "=========================================="
echo "正在构建 极译 AI iTrans (架构模式: $ARCH_MODE)..."
echo "=========================================="

# 凭证只留在本机钥匙串。先扫描参与编译和打包的输入，不读取或复制用户配置。
python3 scripts/scan_release_secrets.py Sources Resources Package.swift build_app.sh README.md

BUILD_DIR="$DIR/.build.noindex"
mkdir -p "$BUILD_DIR"
touch "$BUILD_DIR/.metadata_never_index"

FINAL_BIN="$BUILD_DIR/cduyzhTranslator_bin"
rm -f "$FINAL_BIN"

case "$ARCH_MODE" in
    arm64)
        echo "==> 编译 arm64 (Apple Silicon)..."
        swift build -c release --build-path .build/arm64 --triple arm64-apple-macosx
        cp .build/arm64/release/cduyzhTranslator "$FINAL_BIN"
        ;;
    x86_64)
        echo "==> 编译 x86_64 (Intel Mac)..."
        swift build -c release --build-path .build/x86_64 --triple x86_64-apple-macosx
        cp .build/x86_64/release/cduyzhTranslator "$FINAL_BIN"
        ;;
    native)
        echo "==> 编译当前主机原生架构..."
        swift build -c release
        BIN_PATH="$(swift build -c release --show-bin-path)/cduyzhTranslator"
        cp "$BIN_PATH" "$FINAL_BIN"
        ;;
    universal)
        echo "==> 编译 Universal 2 (arm64 + x86_64)..."
        echo "  -> 编译 Apple Silicon 架构..."
        swift build -c release --build-path .build/arm64 --triple arm64-apple-macosx
        echo "  -> 编译 Intel 架构..."
        swift build -c release --build-path .build/x86_64 --triple x86_64-apple-macosx
        echo "  -> 使用 lipo 缝合通用二进制..."
        lipo -create .build/arm64/release/cduyzhTranslator .build/x86_64/release/cduyzhTranslator -output "$FINAL_BIN"
        ;;
esac

if [ ! -f "$FINAL_BIN" ]; then
    echo "❌ 编译失败：未生成可执行文件 $FINAL_BIN"
    exit 1
fi

echo "==> 产物架构信息:"
file "$FINAL_BIN"

APP_NAME="iTrans.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 创建 macOS App Bundle 目录树
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 仅拷贝明确列出的发行文件；禁止递归拷贝项目、偏好设置或本机凭证
cp "$FINAL_BIN" "$MACOS_DIR/cduyzhTranslator"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "Resources/AppIcon_1024.png" ]; then
    cp "Resources/AppIcon_1024.png" "$RESOURCES_DIR/AppIcon_1024.png"
fi
if [ -f "Resources/version_manifest.json" ]; then
    cp "Resources/version_manifest.json" "$RESOURCES_DIR/version_manifest.json"
fi

# Ad-hoc 代码签名
DESIGNATED_REQUIREMENT='=designated => identifier "com.cduyzh.translator"'
codesign --force --deep --sign - \
    --requirements "$DESIGNATED_REQUIREMENT" \
    "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

# 扫描实际签名 Bundle 中的二进制/资源，并校验所有文件都在白名单内
python3 scripts/scan_release_secrets.py --bundle "$APP_DIR"

echo "=========================================="
echo "✅ 构建打包成功！"
echo "产物路径: $APP_DIR"
echo "支持芯片: $(lipo -archs "$MACOS_DIR/cduyzhTranslator" 2>/dev/null || echo "$ARCH_MODE")"
echo "可直接在访达中双击启动，或通过命令: open '$APP_DIR'"
echo "=========================================="
