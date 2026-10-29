import Foundation
import AppKit

/// 检查更新状态结果
public enum UpdateCheckResult: Equatable {
    case upToDate(currentVersion: AppVersion)
    case updateAvailable(latest: AppVersion, current: AppVersion, releaseNote: ReleaseNoteItem?, downloadUrl: URL?)
    case failed(error: String)

    public var isUpdateAvailable: Bool {
        if case .updateAvailable = self { return true }
        return false
    }

    public var statusDescription: String {
        switch self {
        case .upToDate(let curr):
            return "当前已是最新版本 (v\(curr.description))"
        case .updateAvailable(let latest, let curr, _, _):
            return "发现新版本 v\(latest.description) (当前: v\(curr.description))"
        case .failed(let err):
            return "检查更新失败: \(err)"
        }
    }
}

/// 远端更新清单数据结构 (用于 JSON 解析)
public struct UpdateManifest: Codable {
    public let version: String
    public let build: Int?
    public let releaseDate: String?
    public let title: String?
    public let summary: String?
    public let highlights: [String]?
    public let features: [String]?
    public let improvements: [String]?
    public let bugFixes: [String]?
    public let downloadUrl: String?
    public let minMacosVersion: String?

    enum CodingKeys: String, CodingKey {
        case version
        case build
        case releaseDate = "release_date"
        case title
        case summary
        case highlights
        case features
        case improvements
        case bugFixes = "bug_fixes"
        case downloadUrl = "download_url"
        case minMacosVersion = "min_macos_version"
    }

    public init(
        version: String,
        build: Int? = nil,
        releaseDate: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        highlights: [String]? = nil,
        features: [String]? = nil,
        improvements: [String]? = nil,
        bugFixes: [String]? = nil,
        downloadUrl: String? = nil,
        minMacosVersion: String? = nil
    ) {
        self.version = version
        self.build = build
        self.releaseDate = releaseDate
        self.title = title
        self.summary = summary
        self.highlights = highlights
        self.features = features
        self.improvements = improvements
        self.bugFixes = bugFixes
        self.downloadUrl = downloadUrl
        self.minMacosVersion = minMacosVersion
    }
}

/// 应用版本更新检测控制器
@MainActor
public final class AppUpdateChecker: ObservableObject {
    public static let shared = AppUpdateChecker()

    @Published public var isChecking: Bool = false
    @Published public var lastCheckDate: Date?
    @Published public var checkResult: UpdateCheckResult?
    @Published public var hasUpdate: Bool = false
    @Published public var latestVersion: AppVersion?
    @Published public var latestReleaseNote: ReleaseNoteItem?
    @Published public var downloadURL: URL?
    @Published public var errorMessage: String?

    /// 默认版本检查清单地址 (可由 AppSettings 自定义覆盖)
    public static let defaultManifestURL = "https://raw.githubusercontent.com/cduyzh/iTrans/main/Resources/version_manifest.json"
    public static let defaultProjectReleaseURL = "https://github.com/cduyzh/iTrans/releases"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
        // 从偏好加载上次检查时间与状态
        self.lastCheckDate = AppSettings.shared.lastUpdateCheckDate
        self.hasUpdate = AppSettings.shared.hasNewUpdateAvailable
        if let verStr = AppSettings.shared.latestAvailableVersion {
            self.latestVersion = AppVersion(string: verStr)
        }
    }

    /// 执行更新检查
    /// - Parameters:
    ///   - customUrlString: 可选的指定清单地址（通常用于测试）
    ///   - isManual: 是否为用户主动点击手动检查
    @discardableResult
    public func checkForUpdates(customUrlString: String? = nil, isManual: Bool = false) async -> UpdateCheckResult {
        isChecking = true
        errorMessage = nil

        let targetUrlStr = (customUrlString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? customUrlString!
            : Self.defaultManifestURL

        guard let url = URL(string: targetUrlStr) else {
            let res = UpdateCheckResult.failed(error: "无效的更新清单 URL: \(targetUrlStr)")
            applyResult(res)
            return res
        }

        let currentVer = AppVersion.current

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("cduyzhTranslator/\(currentVer.description) (macOS)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AppUpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "非法的网络响应"])
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "AppUpdateChecker", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP 错误: \(httpResponse.statusCode)"])
            }

            let decoder = JSONDecoder()
            let manifest = try decoder.decode(UpdateManifest.self, from: data)

            return evaluateManifest(manifest, currentVer: currentVer)
        } catch {
            // 若为离线或远端无法访问：检查本地内置版本库中是否存在比当前版本更新的 release
            if let localLatest = ChangelogManager.shared.latestRelease,
               let localLatestVer = AppVersion(string: localLatest.version, buildNumber: localLatest.buildNumber),
               localLatestVer > currentVer {
                let download = localLatest.downloadUrl.flatMap { URL(string: $0) } ?? URL(string: Self.defaultProjectReleaseURL)
                let res = UpdateCheckResult.updateAvailable(
                    latest: localLatestVer,
                    current: currentVer,
                    releaseNote: localLatest,
                    downloadUrl: download
                )
                applyResult(res)
                return res
            }

            // 若网络失败且本地也无更新，则报错或提示已是最新
            let errorDesc: String
            let nsErr = error as NSError
            if nsErr.domain == NSURLErrorDomain {
                if nsErr.code == NSURLErrorNotConnectedToInternet || nsErr.code == NSURLErrorCannotFindHost {
                    errorDesc = "无法连接至网络或服务器，请检查网络连接。"
                } else if nsErr.code == NSURLErrorTimedOut {
                    errorDesc = "网络请求超时，请检查网络或配置自定义镜像更新源。"
                } else {
                    errorDesc = error.localizedDescription
                }
            } else {
                errorDesc = error.localizedDescription
            }

            let res = UpdateCheckResult.failed(error: errorDesc)
            applyResult(res)
            return res
        }
    }

    /// 评估更新清单
    public func evaluateManifest(_ manifest: UpdateManifest, currentVer: AppVersion = AppVersion.current) -> UpdateCheckResult {
        guard let remoteVer = AppVersion(string: manifest.version, buildNumber: manifest.build) else {
            let res = UpdateCheckResult.failed(error: "更新清单中的版本格式无法解析: \(manifest.version)")
            applyResult(res)
            return res
        }

        let download = manifest.downloadUrl.flatMap { URL(string: $0) } ?? URL(string: Self.defaultProjectReleaseURL)
        let noteItem = ReleaseNoteItem(
            version: manifest.version,
            buildNumber: manifest.build ?? 0,
            releaseDate: manifest.releaseDate ?? "未知日期",
            title: manifest.title ?? "版本更新",
            summary: manifest.summary ?? "",
            highlights: manifest.highlights ?? [],
            features: manifest.features ?? [],
            improvements: manifest.improvements ?? [],
            bugFixes: manifest.bugFixes ?? [],
            downloadUrl: manifest.downloadUrl
        )

        // 注册到更新日志管理器
        ChangelogManager.shared.registerRemoteRelease(noteItem)

        if remoteVer > currentVer {
            let res = UpdateCheckResult.updateAvailable(
                latest: remoteVer,
                current: currentVer,
                releaseNote: noteItem,
                downloadUrl: download
            )
            applyResult(res)
            return res
        } else {
            let res = UpdateCheckResult.upToDate(currentVersion: currentVer)
            applyResult(res)
            return res
        }
    }

    /// 应用检查结果并同步偏好持久化
    private func applyResult(_ result: UpdateCheckResult) {
        self.isChecking = false
        self.checkResult = result
        self.lastCheckDate = Date()
        AppSettings.shared.lastUpdateCheckDate = self.lastCheckDate

        switch result {
        case .updateAvailable(let latest, _, let note, let download):
            self.hasUpdate = true
            self.latestVersion = latest
            self.latestReleaseNote = note
            self.downloadURL = download
            self.errorMessage = nil
            AppSettings.shared.hasNewUpdateAvailable = true
            AppSettings.shared.latestAvailableVersion = latest.description
        case .upToDate:
            self.hasUpdate = false
            self.latestVersion = nil
            self.latestReleaseNote = nil
            self.errorMessage = nil
            AppSettings.shared.hasNewUpdateAvailable = false
            AppSettings.shared.latestAvailableVersion = nil
        case .failed(let err):
            self.errorMessage = err
            // 失败时不清除上次可能已探查到的可用更新
        }
    }

    /// 在默认浏览器中打开下载或发布页面
    public func openDownloadPage() {
        let url = downloadURL ?? URL(string: Self.defaultProjectReleaseURL)!
        NSWorkspace.shared.open(url)
    }

    /// 应用启动或周期检查触发
    public func performAutoCheckIfNeeded() {
        guard AppSettings.shared.autoCheckUpdateEnabled else { return }

        // 若距离上次检查不足 6 小时且上次无报错，则跳过
        if let lastDate = AppSettings.shared.lastUpdateCheckDate {
            let hours = Date().timeIntervalSince(lastDate) / 3600.0
            if hours < 6.0 && checkResult != nil {
                return
            }
        }

        Task {
            await checkForUpdates(isManual: false)
        }
    }
}
