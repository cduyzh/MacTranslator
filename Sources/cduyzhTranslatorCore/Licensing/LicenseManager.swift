import Foundation
import Combine

public enum LicenseError: LocalizedError {
    case invalidFormat
    case signatureVerificationFailed
    case productMismatch
    case deviceMismatch
    case expired
    case clockTampered

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "许可证格式无效，请检查是否复制完整。"
        case .signatureVerificationFailed:
            return "许可证签名校验未通过，无法确认官方有效性。"
        case .productMismatch:
            return "许可证产品不匹配，该授权属于其他 cduyzh 应用。"
        case .deviceMismatch:
            return "此许可证已被绑定至其他 Mac 设备，无法在此电脑使用。"
        case .expired:
            return "此许可证已到期，请续费升级。"
        case .clockTampered:
            return "检测到系统时钟异常，已暂时锁定试用权益。请校准时间后重试。"
        }
    }
}

/// TransBar 商业化许可与设备试用管理器
/// 本地优先架构：绝不调用全局钥匙串 SecItem（杜绝代码签名变更时弹出系统授权密码弹窗）
/// 状态持久化采用 ~/Library/Application Support/cduyzhTranslator/license_state.json (0600) + UserDefaults
@MainActor
public final class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()

    /// 当前 Mac 应用产品标识
    public let currentProductId: String = "transbar"

    // MARK: - Keys
    private let kSavedLicenseToken = "cduyzh.transbar.license.token"
    private let kTrialStartDate = "cduyzh.transbar.trial.start_date"
    private let kHighestKnownTime = "cduyzh.transbar.trial.highest_known_time"

    // MARK: - Published States
    @Published public private(set) var currentTier: LicenseTier = .free
    @Published public private(set) var isPro: Bool = false
    @Published public private(set) var trialDaysRemaining: Int = 0
    @Published public private(set) var activeEmail: String? = nil
    @Published public private(set) var expirationDate: Date? = nil
    @Published public private(set) var activeLicense: LicenseToken? = nil

    private let storeFileURL: URL

    private struct LocalLicenseState: Codable {
        var token: String?
        var trialStart: TimeInterval
        var highestKnownTime: TimeInterval
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cduyzhTranslator", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.storeFileURL = appSupport.appendingPathComponent("license_state.json")

        refreshState()
    }

    /// 重新计算与刷新当前授权与试用状态
    public func refreshState() {
        let localState = loadLocalState()

        // 1. 优先校验已保存的官方 License Token (严格匹配当前产品 transbar)
        let tokenStr = localState.token ?? UserDefaults.standard.string(forKey: kSavedLicenseToken)
        if let tokenStr = tokenStr, !tokenStr.isEmpty {
            if let token = LicenseToken.parse(from: tokenStr, expectedProductId: currentProductId) {
                if !token.payload.isExpired {
                    self.activeLicense = token
                    self.currentTier = token.payload.tier
                    self.isPro = true
                    self.activeEmail = token.payload.email
                    self.expirationDate = Date(timeIntervalSince1970: token.payload.expiresAt)
                    self.trialDaysRemaining = 0
                    return
                }
            }
            // Token 无效或过期，清空
            self.activeLicense = nil
        }

        // 2. 检查 7 天免费试用状态
        evaluateTrialStatus(localState: localState)
        checkDeviceTrialOnline()
    }

    /// 异步向服务器核验设备硬件指纹（防卸载重装双保险，按产品独立）
    public func checkDeviceTrialOnline() {
        Task {
            let body: [String: Any] = [
                "product_id": currentProductId,
                "device_uuid": HardwareIdentifier.uuid
            ]
            guard let (data, response) = try? await AuthSessionManager.shared.sendRequest(path: "/api/trial/claim", method: "POST", body: body),
                  response.statusCode == 200 else {
                return
            }

            struct TrialClaimResponse: Decodable {
                let status: String // "ACTIVE", "EXPIRED"
                let expiresAt: TimeInterval
                let token: String?
            }

            if let res = try? JSONDecoder().decode(TrialClaimResponse.self, from: data) {
                await MainActor.run {
                    if res.status == "EXPIRED" {
                        // 现阶段全面开放免费，不降级为限制状态
                    } else if let token = res.token, self.currentTier == .free {
                        self.activate(tokenString: token)
                    }
                }
            }
        }
    }

    /// 评估 7 天试用期
    private func evaluateTrialStatus(localState: LocalLicenseState) {
        let now = Date().timeIntervalSince1970
        let highest = max(localState.highestKnownTime, UserDefaults.standard.double(forKey: kHighestKnownTime))

        // 防时钟倒拨检测 (允许 5 分钟网络/休眠漂移)
        if highest > 0 && now < (highest - 300) {
            self.currentTier = .free
            self.isPro = false
            self.trialDaysRemaining = 0
            self.activeEmail = nil
            self.expirationDate = nil
            return
        }

        // 更新历史最高时间
        let newHighest = max(now, highest)
        UserDefaults.standard.set(newHighest, forKey: kHighestKnownTime)

        var trialStart = localState.trialStart > 0 ? localState.trialStart : UserDefaults.standard.double(forKey: kTrialStartDate)

        if trialStart <= 0 {
            trialStart = now
            UserDefaults.standard.set(trialStart, forKey: kTrialStartDate)
        }

        saveLocalState(token: localState.token, trialStart: trialStart, highest: newHighest)

        // 现阶段全面开放免费全功能体验：
        // 1. 无需试用天数限制，所有用户默认无感知享受全功能 (isPro = true)
        // 2. 不展示试用倒计时，不阻断核心功能
        // 3. 完整保留 Ed25519 签名验证、设备指纹绑定与 License 持久化底层代码，未来按需平滑启用
        self.currentTier = .free
        self.isPro = true
        self.trialDaysRemaining = 0
        self.activeEmail = nil
        self.expirationDate = nil
    }

    /// 激活 License Token
    @discardableResult
    public func activate(tokenString: String) -> Result<LicensePayload, LicenseError> {
        let trimmed = tokenString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = LicenseToken.parse(from: trimmed, expectedProductId: currentProductId) else {
            // 细分是否为跨应用串货
            if let looseToken = LicenseToken.parse(from: trimmed, expectedProductId: "") {
                if let prod = looseToken.payload.product, prod.lowercased() != currentProductId.lowercased() {
                    return .failure(.productMismatch)
                }
            }
            return .failure(.invalidFormat)
        }

        if token.payload.isExpired {
            return .failure(.expired)
        }

        if let bound = token.payload.deviceUuid, !bound.isEmpty, bound != HardwareIdentifier.uuid {
            return .failure(.deviceMismatch)
        }

        // 保存并生效
        UserDefaults.standard.set(trimmed, forKey: kSavedLicenseToken)
        let state = loadLocalState()
        saveLocalState(token: trimmed, trialStart: state.trialStart, highest: state.highestKnownTime)
        refreshState()
        return .success(token.payload)
    }

    /// 解除激活
    public func deactivate() {
        UserDefaults.standard.removeObject(forKey: kSavedLicenseToken)
        let state = loadLocalState()
        saveLocalState(token: nil, trialStart: state.trialStart, highest: state.highestKnownTime)
        refreshState()
    }

    // MARK: - 本地持久化 (0600 安全文件)
    private func loadLocalState() -> LocalLicenseState {
        guard let data = try? Data(contentsOf: storeFileURL),
              let state = try? JSONDecoder().decode(LocalLicenseState.self, from: data) else {
            let udToken = UserDefaults.standard.string(forKey: kSavedLicenseToken)
            let udStart = UserDefaults.standard.double(forKey: kTrialStartDate)
            let udHighest = UserDefaults.standard.double(forKey: kHighestKnownTime)
            return LocalLicenseState(token: udToken, trialStart: udStart, highestKnownTime: udHighest)
        }
        return state
    }

    private func saveLocalState(token: String?, trialStart: TimeInterval, highest: TimeInterval) {
        let state = LocalLicenseState(token: token, trialStart: trialStart, highestKnownTime: highest)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storeFileURL, options: .atomic)
            // 确保 0600 权限
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storeFileURL.path)
        }
    }
}
