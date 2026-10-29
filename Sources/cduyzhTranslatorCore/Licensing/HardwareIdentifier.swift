import Foundation
import IOKit

/// 读取 Mac 硬件唯一标识符，用于 License 节点锁定（Node-Locking），防止单一激活码多机滥用。
/// 免辅助功能权限，纯原生 IOKit 硬件级读取。
public enum HardwareIdentifier {
    /// 获取当前 Mac 的 IOPlatformUUID
    public static var uuid: String {
        let matching = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard platformExpert != 0 else {
            return fallbackHardwareIdentifier()
        }
        defer { IOObjectRelease(platformExpert) }

        if let serialAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return serialAsCFString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return fallbackHardwareIdentifier()
    }

    /// 后备设备指纹（如果 IOKit 读取失败，回退到结合机型特征的持久化指纹）
    private static func fallbackHardwareIdentifier() -> String {
        let key = "cduyzh.transbar.fallback.device_fingerprint"
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
