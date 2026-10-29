import XCTest
import CryptoKit
@testable import cduyzhTranslatorCore

@MainActor
final class TransBarLicensingSecurityTests: XCTestCase {

    func testHardwareIdentifierIsNonEmpty() {
        let uuid = HardwareIdentifier.uuid
        XCTAssertFalse(uuid.isEmpty, "硬件唯一指纹不应为空")
    }

    func testFakeSignatureIsRejected() {
        // 生成随机构造的假签名
        let sampleData = "fake_payload_data".data(using: .utf8)!
        let fakeSignature = Data(repeating: 0xAA, count: 64)

        let isValid = CryptoVerifier.verify(data: sampleData, signatureData: fakeSignature)
        XCTAssertFalse(isValid, "任意伪造的 64 字节签名必须被 Ed25519 拒绝")
    }

    func testValidEd25519KeyPairRoundtrip() throws {
        // 使用临时生成的 Ed25519 密钥对验证验签逻辑
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let pubBase64 = publicKey.rawRepresentation.base64EncodedString()

        let message = "hello_transbar".data(using: .utf8)!
        let signature = try privateKey.signature(for: message)

        let isValid = CryptoVerifier.verify(data: message, signatureData: signature, publicKeyBase64: pubBase64)
        XCTAssertTrue(isValid, "合法私钥生成的签名必须通过验签")
    }

    func testProductMismatchRejection() throws {
        // 构造一个属于 snapscreen 的合法私钥签名，尝试在 transbar 下解析
        let privateKey = Curve25519.Signing.PrivateKey()

        let payload = LicensePayload(
            product: "snapscreen", // 属于截屏应用
            licenseId: "SNAP_TEST_001",
            email: "test@example.com",
            tier: .lifetime,
            deviceUuid: nil,
            issuedAt: Date().timeIntervalSince1970,
            expiresAt: Date().timeIntervalSince1970 + 86400 * 365
        )

        let payloadData = try JSONEncoder().encode(payload)
        let payloadBase64 = payloadData.base64EncodedString()
        let signature = try privateKey.signature(for: payloadBase64.data(using: .utf8)!)
        let sigBase64 = signature.base64EncodedString()

        let rawToken = "\(payloadBase64).\(sigBase64)"

        // 验证：在 transbar 预期下解析必须返回 nil (防御跨应用串货)
        let parsed = LicenseToken.parse(from: rawToken, expectedProductId: "transbar")
        XCTAssertNil(parsed, "属于 snapscreen 的许可绝对不可在 transbar 下生效")
    }

    func testExpiredLicenseIsRejected() throws {
        let pastDate = Date().timeIntervalSince1970 - 1000 // 已经过期
        let payload = LicensePayload(
            product: "transbar",
            licenseId: "TRANS_EXPIRED_001",
            email: "expired@example.com",
            tier: .monthly,
            deviceUuid: nil,
            issuedAt: pastDate - 86400 * 30,
            expiresAt: pastDate
        )

        XCTAssertTrue(payload.isExpired, "过去的时间戳必须判定为已过期")
    }
}
