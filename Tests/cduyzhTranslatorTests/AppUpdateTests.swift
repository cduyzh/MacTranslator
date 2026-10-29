import XCTest
@testable import cduyzhTranslatorCore

final class AppUpdateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ChangelogManager.shared.resetToDefaults()
    }

    override func tearDown() {
        ChangelogManager.shared.resetToDefaults()
        super.tearDown()
    }

    // MARK: - AppVersion 语义化版本测试
    func testVersionParsingAndFormatting() {
        let v1 = AppVersion(string: "1.0.0")
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.major, 1)
        XCTAssertEqual(v1?.minor, 0)
        XCTAssertEqual(v1?.patch, 0)
        XCTAssertNil(v1?.prerelease)
        XCTAssertEqual(v1?.description, "1.0.0")

        let v2 = AppVersion(string: "v2.3.4-alpha.1", buildNumber: 42)
        XCTAssertNotNil(v2)
        XCTAssertEqual(v2?.major, 2)
        XCTAssertEqual(v2?.minor, 3)
        XCTAssertEqual(v2?.patch, 4)
        XCTAssertEqual(v2?.prerelease, "alpha.1")
        XCTAssertEqual(v2?.buildNumber, 42)
        XCTAssertEqual(v2?.fullDisplayString, "v2.3.4-alpha.1 (Build 42)")
    }

    func testVersionComparison() {
        let v1_0_0 = AppVersion(string: "1.0.0")!
        let v1_0_1 = AppVersion(string: "1.0.1")!
        let v1_1_0 = AppVersion(string: "1.1.0")!
        let v2_0_0 = AppVersion(string: "2.0.0")!
        let v1_0_0_beta = AppVersion(string: "1.0.0-beta")!

        XCTAssertTrue(v1_0_0 < v1_0_1)
        XCTAssertTrue(v1_0_1 < v1_1_0)
        XCTAssertTrue(v1_1_0 < v2_0_0)
        XCTAssertTrue(v1_0_0_beta < v1_0_0)
        XCTAssertEqual(v1_0_0, AppVersion(string: "1.0.0")!)

        // Build 编号比对
        let vBuild1 = AppVersion(major: 1, minor: 0, patch: 0, buildNumber: 1)
        let vBuild2 = AppVersion(major: 1, minor: 0, patch: 0, buildNumber: 2)
        XCTAssertTrue(vBuild1 < vBuild2)
    }

    func testCurrentVersionNotNull() {
        let current = AppVersion.current
        XCTAssertGreaterThanOrEqual(current.major, 1)
        XCTAssertFalse(AppVersion.appName.isEmpty)
    }

    // MARK: - ChangelogManager 更新日志测试
    func testChangelogManager() {
        let manager = ChangelogManager.shared
        XCTAssertFalse(manager.releases.isEmpty)

        // 验证最新发布
        let latest = manager.latestRelease
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.version, "1.0.0")
        XCTAssertFalse(latest?.highlights.isEmpty ?? true)
        XCTAssertFalse(latest?.features.isEmpty ?? true)

        // 验证根据版本号查询
        let v100 = manager.release(for: "1.0.0")
        XCTAssertNotNil(v100)
        XCTAssertEqual(v100?.version, "1.0.0")

        // 验证 Markdown 与 JSON 导出
        let markdown = manager.exportFullChangelogMarkdown()
        XCTAssertTrue(markdown.contains("译栏 TransBar 更新日志与发布历史"))
        XCTAssertTrue(markdown.contains("1.0.0"))

        let json = manager.exportAsJSON()
        XCTAssertTrue(json.contains("\"version\" : \"1.0.0\"") || json.contains("\"version\": \"1.0.0\""))
    }

    func testChangelogRegisterRemoteRelease() {
        let manager = ChangelogManager.shared
        let remoteItem = ReleaseNoteItem(
            version: "9.9.9",
            buildNumber: 99,
            releaseDate: "2029-01-01",
            title: "未来版本测试",
            summary: "测试远端更新注入",
            highlights: ["未来亮点"]
        )

        manager.registerRemoteRelease(remoteItem)
        XCTAssertEqual(manager.latestRelease?.version, "9.9.9")
        XCTAssertEqual(manager.release(for: "9.9.9")?.title, "未来版本测试")
    }

    // MARK: - AppUpdateChecker 检查更新测试
    @MainActor
    func testAppUpdateCheckerEvaluateManifest() {
        let checker = AppUpdateChecker.shared
        let currentVer = AppVersion(string: "1.0.0", buildNumber: 1)!

        // 1. 发现新版本测试
        let updateManifest = UpdateManifest(
            version: "1.2.0",
            build: 10,
            releaseDate: "2026-11-01",
            title: "新版发布",
            summary: "功能优化",
            downloadUrl: "https://example.com/download"
        )
        let result1 = checker.evaluateManifest(updateManifest, currentVer: currentVer)
        XCTAssertTrue(result1.isUpdateAvailable)
        if case .updateAvailable(let latest, let curr, let note, let url) = result1 {
            XCTAssertEqual(latest.description, "1.2.0")
            XCTAssertEqual(curr.description, "1.0.0")
            XCTAssertEqual(note?.title, "新版发布")
            XCTAssertEqual(url?.absoluteString, "https://example.com/download")
        } else {
            XCTFail("应返回 updateAvailable")
        }

        // 2. 当前已是最新版本测试
        let olderManifest = UpdateManifest(
            version: "1.0.0",
            build: 1,
            releaseDate: "2026-10-16",
            title: "当前版本"
        )
        let result2 = checker.evaluateManifest(olderManifest, currentVer: currentVer)
        XCTAssertFalse(result2.isUpdateAvailable)
        if case .upToDate(let curr) = result2 {
            XCTAssertEqual(curr.description, "1.0.0")
        } else {
            XCTFail("应返回 upToDate")
        }

        // 3. 非法版本号测试
        let invalidManifest = UpdateManifest(version: "abc..def")
        let result3 = checker.evaluateManifest(invalidManifest, currentVer: currentVer)
        if case .failed = result3 {
            // 通过
        } else {
            XCTFail("应返回 failed")
        }
    }

    // MARK: - 网关接口测试 (/v1/version & /v1/changelog)
    func testGatewayVersionEndpoints() async throws {
        let server = AgentGatewayServer.shared
        let testPort: UInt16 = 11989
        server.start(port: testPort)

        try await Task.sleep(nanoseconds: 300_000_000)

        // 测试 /v1/version
        let versionUrl = URL(string: "http://127.0.0.1:\(testPort)/v1/version")!
        let (verData, verResp) = try await URLSession.shared.data(from: versionUrl)
        XCTAssertEqual((verResp as? HTTPURLResponse)?.statusCode, 200)
        let verJson = try JSONSerialization.jsonObject(with: verData) as? [String: Any]
        XCTAssertNotNil(verJson?["version"])
        XCTAssertNotNil(verJson?["app_name"])

        // 测试 /v1/changelog
        let changelogUrl = URL(string: "http://127.0.0.1:\(testPort)/v1/changelog")!
        let (clData, clResp) = try await URLSession.shared.data(from: changelogUrl)
        XCTAssertEqual((clResp as? HTTPURLResponse)?.statusCode, 200)
        let clArray = try JSONSerialization.jsonObject(with: clData) as? [[String: Any]]
        XCTAssertNotNil(clArray)
        XCTAssertFalse(clArray?.isEmpty ?? true)

        server.stop()
    }
}
