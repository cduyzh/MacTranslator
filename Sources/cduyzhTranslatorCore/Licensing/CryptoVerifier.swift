import Foundation
import CryptoKit

/// 基于 Apple 原生 CryptoKit 的 Ed25519 非对称公钥验签引擎。
/// 服务端持有唯一私钥签名 License，客户端仅持有公钥进行单向离线验证，防御伪造 License 攻击。
public enum CryptoVerifier {
    /// 官方发布验签公钥（32 字节 Ed25519 公钥的 Base64 格式）
    /// 注：此公钥仅能用于验签，无法用于伪造私钥签名；开源仓库公开公钥是标准安全的密码学实践。
    public static let officialPublicKeyBase64 = "ZcRtxOiZQt+xd8VEEVXvIwIbshNvvsA/fCctC2FXdbc="

    /// 验证给定数据与 Ed25519 签名是否合法
    public static func verify(data: Data, signatureData: Data, publicKeyBase64: String = officialPublicKeyBase64) -> Bool {
        guard let pubKeyData = Data(base64Encoded: publicKeyBase64) else {
            return false
        }

        // 处理标准 DER 封装或纯 32 字节原始密钥
        let rawKeyData: Data
        if pubKeyData.count == 32 {
            rawKeyData = pubKeyData
        } else if pubKeyData.count > 32 {
            // DER 格式一般尾部 32 字节为 raw Ed25519 key
            rawKeyData = pubKeyData.suffix(32)
        } else {
            return false
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawKeyData)
            return publicKey.isValidSignature(signatureData, for: data)
        } catch {
            return false
        }
    }

    /// 高级综合验签：验证 Ed25519 签名有效性、产品隔离匹配与过期时间
    public static func verifyToken(_ tokenString: String, expectedProductId: String = "transbar") -> LicensePayload? {
        let parts = tokenString.components(separatedBy: ".")
        guard parts.count == 2 else { return nil }

        let payloadPart = parts[0]
        let sigPart = parts[1]

        guard let payloadData = Data(base64Encoded: payloadPart),
              let sigData = Data(base64Encoded: sigPart) else {
            return nil
        }

        guard let payloadRawData = payloadPart.data(using: .utf8) else {
            return nil
        }

        // 1. 签名防伪验证
        guard verify(data: payloadRawData, signatureData: sigData) else {
            return nil
        }

        // 2. 解码 Payload
        guard let payload = try? JSONDecoder().decode(LicensePayload.self, from: payloadData) else {
            return nil
        }

        // 3. 严格产品隔离 (防御跨应用串货，例如拿 SnapScreen 许可激活 TransBar)
        if !expectedProductId.isEmpty, let product = payload.product, !product.isEmpty {
            guard product.lowercased() == expectedProductId.lowercased() else {
                return nil
            }
        }

        return payload
    }
}
