import XCTest
import AppKit
@testable import cduyzhTranslatorCore

final class CountryFlagAssetsTests: XCTestCase {
    func testAllSupportedLanguagesHaveFlagAssetsOrValidImages() {
        let provider = CountryFlagProvider.shared
        for item in SupportedLanguages.all {
            if item.code == "auto" {
                // auto 特殊全球/联合国标志
                let image = provider.flagImage(for: "auto")
                XCTAssertNotNil(image, "auto 应该具备有效的全球/联合国标志")
            } else {
                let image = provider.flagImage(for: item.code)
                XCTAssertNotNil(image, "语言 \\(item.code) (\\(item.name)) 应该具备开源矢量圆形国旗")
                XCTAssertGreaterThan(image?.size.width ?? 0, 0)
                XCTAssertGreaterThan(image?.size.height ?? 0, 0)
            }
        }
    }

    func testFlagProviderCacheHit() {
        let provider = CountryFlagProvider.shared
        let img1 = provider.flagImage(for: "zh-CN", targetSize: 32)
        let img2 = provider.flagImage(for: "zh-CN", targetSize: 32)
        XCTAssertNotNil(img1)
        XCTAssertEqual(img1, img2, "二次获取相同尺寸的国旗应当命中内存缓存")
    }

    func testLanguageAliasResolving() {
        let provider = CountryFlagProvider.shared
        XCTAssertNotNil(provider.flagImage(for: "zh-Hans"))
        XCTAssertNotNil(provider.flagImage(for: "zh"))
        XCTAssertNotNil(provider.flagImage(for: "en-US"))
        XCTAssertNotNil(provider.flagImage(for: "en-GB"))
    }
}
