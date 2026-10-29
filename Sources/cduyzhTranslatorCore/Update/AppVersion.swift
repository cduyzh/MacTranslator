import Foundation

/// 语义化版本号结构体，支持灵活的版本解析、大小比对与格式化输出
public struct AppVersion: Comparable, Equatable, Hashable, CustomStringConvertible, Codable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let buildNumber: Int?
    public let rawString: String

    public var description: String {
        var str = "\(major).\(minor).\(patch)"
        if let pre = prerelease, !pre.isEmpty {
            str += "-\(pre)"
        }
        return str
    }

    public var fullDisplayString: String {
        if let build = buildNumber, build > 0 {
            return "v\(description) (Build \(build))"
        }
        return "v\(description)"
    }

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil, buildNumber: Int? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.buildNumber = buildNumber
        var raw = "\(major).\(minor).\(patch)"
        if let pre = prerelease, !pre.isEmpty {
            raw += "-\(pre)"
        }
        self.rawString = raw
    }

    /// 从字符串解析语义化版本号 (例如 "1.0.0", "v1.1.2", "2.0.0-beta.1")
    public init?(string: String, buildNumber: Int? = nil) {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !clean.isEmpty else { return nil }

        self.rawString = string

        let preParts = clean.components(separatedBy: "-")
        let versionMain = preParts[0]
        let prereleasePart = preParts.count > 1 ? preParts.dropFirst().joined(separator: "-") : nil

        let digits = versionMain.components(separatedBy: ".").compactMap { Int($0) }
        guard !digits.isEmpty else { return nil }

        self.major = digits.count > 0 ? digits[0] : 0
        self.minor = digits.count > 1 ? digits[1] : 0
        self.patch = digits.count > 2 ? digits[2] : 0
        self.prerelease = prereleasePart
        self.buildNumber = buildNumber
    }

    // MARK: - Comparable
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        // 预发布版本比正式版小 (例如 1.0.0-beta < 1.0.0)
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            break
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (let pre1?, let pre2?):
            if pre1 != pre2 {
                return pre1 < pre2
            }
        }

        // 若主次补丁号均相等，且包含 buildNumber，则比对 buildNumber
        if let b1 = lhs.buildNumber, let b2 = rhs.buildNumber, b1 != b2 {
            return b1 < b2
        }

        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease &&
               lhs.buildNumber == rhs.buildNumber
    }

    // MARK: - 当前应用版本信息
    public static var current: AppVersion {
        let info = Bundle.main.infoDictionary
        let versionString = info?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        let buildStr = info?["CFBundleVersion"] as? String
        let buildNum = buildStr.flatMap { Int($0) } ?? 3
        return AppVersion(string: versionString, buildNumber: buildNum) ?? AppVersion(major: 1, minor: 1, patch: 0, buildNumber: buildNum)
    }

    public static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String) ?? "译栏 TransBar"
    }
}
