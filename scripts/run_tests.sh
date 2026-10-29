#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "===> 运行 TransBar 单元测试 (swift test)..."
swift test

if [ -f scripts/test_scan_release_secrets.py ]; then
    echo "===> 运行敏感信息扫描安全测试..."
    python3 scripts/test_scan_release_secrets.py
fi

echo "===> TransBar 全部自动化测试通过！"
