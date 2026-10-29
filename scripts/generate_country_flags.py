#!/usr/bin/env python3
import urllib.request
import ssl
import json
import re

# 使用未校验上下文以防 macOS 本机 Python 缺失根证书
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

MAPPINGS = [
    ("cn", ["zh-CN", "zh", "zh-Hans"]),
    ("tw", ["zh-TW", "zh-Hant"]),
    ("hk", ["zh-HK"]),
    ("us", ["en", "en-US"]),
    ("gb", ["en-GB"]),
    ("jp", ["ja"]),
    ("kr", ["ko"]),
    ("fr", ["fr"]),
    ("de", ["de"]),
    ("es", ["es"]),
    ("ru", ["ru"]),
    ("it", ["it"]),
    ("pt", ["pt"]),
    ("br", ["pt-BR"]),
    ("sa", ["ar"]),
    ("vn", ["vi"]),
    ("th", ["th"]),
    ("id", ["id"]),
    ("in", ["hi"]),
    ("tr", ["tr"]),
    ("nl", ["nl"]),
    ("pl", ["pl"]),
    ("ua", ["uk"]),
    ("se", ["sv"]),
    ("dk", ["da"]),
    ("fi", ["fi"]),
    ("no", ["no"]),
    ("cz", ["cs"]),
    ("gr", ["el"]),
    ("hu", ["hu"]),
    ("ro", ["ro"]),
    ("my", ["ms"]),
    ("ph", ["fil", "tl"]),
    ("il", ["he"]),
    ("ir", ["fa"]),
]

# 下载 UN / Globe 作为 auto
auto_svg_url = "https://raw.githubusercontent.com/HatScripts/circle-flags/gh-pages/flags/other/united_nations.svg"
req = urllib.request.Request(auto_svg_url, headers={"User-Agent": "TransBar-Builder"})
auto_svg = urllib.request.urlopen(req, context=ctx).read().decode("utf-8").strip()

flag_svgs = {}
flag_svgs["un"] = auto_svg

for country, _ in MAPPINGS:
    url = f"https://raw.githubusercontent.com/HatScripts/circle-flags/gh-pages/flags/{country}.svg"
    req = urllib.request.Request(url, headers={"User-Agent": "TransBar-Builder"})
    try:
        svg = urllib.request.urlopen(req, context=ctx).read().decode("utf-8").strip()
        flag_svgs[country] = svg
        print(f"Downloaded {country}: {len(svg)} bytes")
    except Exception as e:
        print(f"Error {country}: {e}")

# 生成 Swift 代码
swift_code = """//
// CountryFlagAssets.swift
// cduyzhTranslatorCore
//
// 矢量圆形国旗资源库（基于开源 Circle Flags / MIT License）
// https://github.com/HatScripts/circle-flags
//

import SwiftUI
import AppKit

public enum CountryFlagAssets {
    /// 语言代码到国旗资产标识的映射表
    public static let languageToCountryCode: [String: String] = [
        "auto": "un",
"""

for country, langs in MAPPINGS:
    for lang in langs:
        swift_code += f'        "{lang}": "{country}",\n'

swift_code += """    ]

    /// 预置的开源矢量圆形国旗 SVG 资源表 (Circle Flags, MIT License)
    public static let svgs: [String: String] = [
"""

for key, svg in flag_svgs.items():
    # 转义可能的引号
    escaped = svg.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '')
    swift_code += f'        "{key}": "{escaped}",\n'

swift_code += """    ]
}

/// 现代化国旗图像提供者，提供极速内存缓存与高保真矢量渲染
public final class CountryFlagProvider {
    public static let shared = CountryFlagProvider()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 120
    }

    /// 获取对应语言或国家的矢量国旗 NSImage
    public func flagImage(for languageOrCountryCode: String, targetSize: CGFloat = 48) -> NSImage? {
        let key = languageOrCountryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "\\(key)_\\(Int(targetSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // 查找映射表
        let resolvedCountry = CountryFlagAssets.languageToCountryCode[key] ??
            CountryFlagAssets.languageToCountryCode[key.lowercased()] ??
            CountryFlagAssets.languageToCountryCode[key.split(separator: "-").first.map(String.init) ?? key] ??
            key.lowercased()

        guard let svgString = CountryFlagAssets.svgs[resolvedCountry] ?? CountryFlagAssets.svgs[key.lowercased()],
              let data = svgString.data(using: .utf8),
              let image = NSImage(data: data) else {
            return nil
        }

        image.size = NSSize(width: targetSize, height: targetSize)
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

/// 符合 Quiet Signal 视觉阶梯的高保真圆形国旗/标志视图
public struct CountryFlagView: View {
    public let code: String
    public var size: CGFloat = 20
    @Environment(\\.colorScheme) private var colorScheme

    public init(code: String, size: CGFloat = 20) {
        self.code = code
        self.size = size
    }

    public var body: some View {
        Group {
            if code == "auto" {
                // 自动识别专属：精致全球多语言渐变圆标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.53, blue: 0.90),
                                    Color(red: 0.05, green: 0.38, blue: 0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: size * 0.62, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
            } else if let image = CountryFlagProvider.shared.flagImage(for: code, targetSize: size * 2) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // 回退到系统 Emoji 徽标或默认地球
                let fallback = SupportedLanguages.find(by: code)?.flag ?? "🌐"
                Text(fallback)
                    .font(.system(size: size * 0.76))
                    .frame(width: size, height: size)
            }
        }
        .overlay {
            Circle()
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.16)
                        : Color.black.opacity(0.10),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 1.5, x: 0, y: 0.8)
    }
}
"""

with open("Sources/cduyzhTranslatorCore/UI/CountryFlagAssets.swift", "w", encoding="utf-8") as f:
    f.write(swift_code)

print("Successfully generated Sources/cduyzhTranslatorCore/UI/CountryFlagAssets.swift")
