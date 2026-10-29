import AppKit
import Foundation
import Combine
import CoreImage

// MARK: - Payment Channel
public enum PaymentChannel: String, CaseIterable, Identifiable {
    case wechat = "wechat"
    case alipay = "alipay"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wechat: return "微信支付"
        case .alipay: return "支付宝"
        }
    }

    public var iconName: String {
        switch self {
        case .wechat: return "message.fill"
        case .alipay: return "creditcard.fill"
        }
    }

    public var brandColor: NSColor {
        switch self {
        case .wechat: return NSColor(calibratedRed: 0.09, green: 0.73, blue: 0.35, alpha: 1.0)
        case .alipay: return NSColor(calibratedRed: 0.08, green: 0.49, blue: 0.98, alpha: 1.0)
        }
    }
}

// MARK: - Plan Item
public struct PaywallPlanItem: Identifiable, Equatable {
    public let id: LicenseTier
    public let title: String
    public let priceDisplay: String
    public let periodNote: String
    public let badge: String?
    public let isPopular: Bool
    public let features: [String]

    public static let standardPlans: [PaywallPlanItem] = [
        PaywallPlanItem(
            id: .monthly,
            title: "月度会员",
            priceDisplay: "¥9.9",
            periodNote: "/月",
            badge: nil,
            isPopular: false,
            features: [
                "解锁翻译历史无上限存储（告别 50 条限制）",
                "AI Agent 对话提取与智能知识库构建",
                "本地 Agent 网关多轮调用与上下文管理",
                "支持 2 台 Mac 设备绑定"
            ]
        ),
        PaywallPlanItem(
            id: .yearly,
            title: "年度会员",
            priceDisplay: "¥58",
            periodNote: "/年 (约 ¥4.8/月)",
            badge: "立省 52% · 强烈推荐",
            isPopular: true,
            features: [
                "包含月度会员全部特权",
                "历史记录永久保留与关键词智能检索",
                "行业词库自动化批量分析入库",
                "支持 3 台 Mac 设备绑定",
                "优先大版本功能迭代升级"
            ]
        ),
        PaywallPlanItem(
            id: .lifetime,
            title: "终身买断",
            priceDisplay: "¥99",
            periodNote: "一次付费 · 永久使用",
            badge: "终身授权",
            isPopular: false,
            features: [
                "永久解锁所有现有及未来 Pro 权益",
                "翻译历史与知识库无限制随心管理",
                "支持多设备灵活解绑与迁移",
                "尊贵 Pro 终身专属微光标识"
            ]
        )
    ]
}

// MARK: - Paywall State Machine
public enum PaywallCheckoutState: Equatable {
    case idle
    case requestingOrder
    case awaitingPayment(orderNo: String, qrCodeText: String, expiresAt: Date)
    case success(tier: LicenseTier)
    case failure(String)
}

// MARK: - QR Code Generator Utility
public enum QRCodeGenerator {
    public static func generateImage(from string: String, size: CGSize = CGSize(width: 180, height: 180)) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size.width / outputImage.extent.size.width
        let scaleY = size.height / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let rep = NSCIImageRep(ciImage: transformedImage)
        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
