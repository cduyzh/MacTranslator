import Foundation

// MARK: - License Tier
public enum LicenseTier: String, Codable, CaseIterable {
    case free = "free"
    case trial = "trial"
    case monthly = "monthly"
    case yearly = "yearly"
    case lifetime = "lifetime"

    public var title: String {
        switch self {
        case .free: return "免费版"
        case .trial: return "7天免费试用"
        case .monthly: return "月度订阅"
        case .yearly: return "年度订阅 (推荐)"
        case .lifetime: return "终身买断"
        }
    }

    public var isPro: Bool {
        return self != .free
    }
}

// MARK: - License Payload
public struct LicensePayload: Codable, Equatable {
    public let product: String?
    public let licenseId: String
    public let email: String
    public let tier: LicenseTier
    public let deviceUuid: String?
    public let issuedAt: TimeInterval
    public let expiresAt: TimeInterval

    public init(
        product: String? = "transbar",
        licenseId: String,
        email: String,
        tier: LicenseTier,
        deviceUuid: String?,
        issuedAt: TimeInterval,
        expiresAt: TimeInterval
    ) {
        self.product = product
        self.licenseId = licenseId
        self.email = email
        self.tier = tier
        self.deviceUuid = deviceUuid
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    /// 检查是否过期
    public var isExpired: Bool {
        let now = Date().timeIntervalSince1970
        return now > expiresAt
    }
}

// MARK: - License Token Container
public struct LicenseToken: Codable, Equatable {
    public let rawToken: String
    public let payload: LicensePayload
    public let signature: String

    public static func parse(from rawToken: String, expectedProductId: String = "transbar") -> LicenseToken? {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: ".")
        guard parts.count == 2 else { return nil }

        guard let payloadData = Data(base64Encoded: parts[0]),
              let signatureData = Data(base64Encoded: parts[1]),
              let payload = try? JSONDecoder().decode(LicensePayload.self, from: payloadData) else {
            return nil
        }

        // 进行 Ed25519 签名验证
        let payloadStringData = parts[0].data(using: .utf8) ?? payloadData
        let isSignatureValid = CryptoVerifier.verify(data: payloadStringData, signatureData: signatureData)
            || CryptoVerifier.verify(data: payloadData, signatureData: signatureData)

        guard isSignatureValid else {
            return nil
        }

        // 严格产品隔离 (防御跨应用串货，例如拿 SnapScreen 许可激活 TransBar)
        if let product = payload.product, !product.isEmpty {
            guard product.lowercased() == expectedProductId.lowercased() else {
                return nil
            }
        }

        // 设备锁定时检验硬件 UUID
        if let boundUuid = payload.deviceUuid, !boundUuid.isEmpty {
            let currentUuid = HardwareIdentifier.uuid
            if boundUuid != currentUuid {
                return nil // 硬件不匹配，拒绝跨机盗用
            }
        }

        return LicenseToken(rawToken: trimmed, payload: payload, signature: parts[1])
    }
}
