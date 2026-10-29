#!/usr/bin/env python3
"""Fail a release if a bundle contains credentials or files outside its allowlist.

Never print matched values, subprocess output, or credential lengths.
"""
import argparse
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path

PATTERNS = (
    re.compile(rb"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(rb"AIza[A-Za-z0-9_-]{30,}"),
    re.compile(rb"AKIA[A-Z0-9]{16}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
)
BUNDLE_FILES = {
    "Contents/MacOS/cduyzhTranslator",
    "Contents/Info.plist",
    "Contents/Resources/AppIcon.icns",
    "Contents/Resources/AppIcon_1024.png",
    "Contents/Resources/version_manifest.json",
    "Contents/_CodeSignature/CodeResources",
}


def local_keys():
    """Read only legacy prefs/environment; values stay in memory and are never printed."""
    values = []
    value = os.environ.get("DEEPSEEK_API_KEY", "")
    if value:
        values.append(value.encode())
    result = subprocess.run(
        ["/usr/bin/defaults", "export", "com.cduyzh.translator", "-"],
        capture_output=True, timeout=10, check=False,
    )
    if result.returncode == 0:
        try:
            value = plistlib.loads(result.stdout).get("cduyzh_deepseek_api_key", "")
            if isinstance(value, str) and value:
                values.append(value.encode())
        except (plistlib.InvalidFileException, ValueError):
            pass
    return values


def scan(paths, known_keys=(), bundle=False):
    findings = []
    scanned = 0
    for root in paths:
        root = Path(root)
        if not root.exists():
            findings.append((str(root), "路径不存在"))
            continue
        candidates = [root] if root.is_file() else sorted(root.rglob("*"))
        for file in candidates:
            if file.is_symlink():
                findings.append((str(file), "不允许的符号链接"))
                continue
            if not file.is_file():
                continue
            if bundle and file.relative_to(root).as_posix() not in BUNDLE_FILES:
                findings.append((str(file), "不在安装包文件白名单中"))
            data = file.read_bytes()
            scanned += 1
            match = any(
                item.group(0) != b"sk-" + b"0" * (len(item.group(0)) - 3)
                for pattern in PATTERNS for item in pattern.finditer(data)
            )
            if match or any(key in data for key in known_keys if key):
                findings.append((str(file), "检测到疑似凭证"))
    return scanned, findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--bundle", action="store_true", help="同时检查安装包文件白名单")
    args = parser.parse_args()
    try:
        scanned, findings = scan(args.paths, local_keys(), args.bundle)
    except (OSError, subprocess.SubprocessError):
        print("密钥扫描失败：无法完成安全读取；未输出凭证。", file=sys.stderr)
        return 1
    for path, reason in findings:
        print(f"FAIL: {path}: {reason}", file=sys.stderr)
    print(f"密钥扫描：{scanned} 个文件，{len(findings)} 项问题。未输出任何凭证。")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
