import Foundation
import Darwin

protocol APIKeyStore {
    func load() throws -> String?
    func save(_ key: String) throws
}

/// An app-local credential file with owner-only directory/file permissions.
/// It does not access Security.framework or the login keychain.
struct LocalAPIKeyStore: APIKeyStore {
    private let fileURL: URL
    private let fileManager = FileManager.default

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("cduyzhTranslator", isDirectory: true)
            self.fileURL = support.appendingPathComponent("deepseek-api-key")
        }
    }

    func load() throws -> String? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        var info = stat()
        guard lstat(fileURL.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            throw LocalAPIKeyStoreError.invalidFile
        }
        let data = try Data(contentsOf: fileURL)
        guard let key = String(data: data, encoding: .utf8) else { throw LocalAPIKeyStoreError.invalidEncoding }
        return key
    }

    func save(_ key: String) throws {
        guard !key.isEmpty else {
            if fileManager.fileExists(atPath: fileURL.path) { try fileManager.removeItem(at: fileURL) }
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        // The shared app-data directory may have been created by an older release.
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let temporaryURL = directory.appendingPathComponent(".deepseek-api-key-\(UUID().uuidString)")
        guard fileManager.createFile(atPath: temporaryURL.path, contents: Data(key.utf8),
                                     attributes: [.posixPermissions: 0o600]) else {
            throw LocalAPIKeyStoreError.cannotCreateFile
        }
        defer { try? fileManager.removeItem(at: temporaryURL) }

        // Atomic same-directory rename keeps the previous key intact on a failed write.
        guard Darwin.rename(temporaryURL.path, fileURL.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

enum LocalAPIKeyStoreError: LocalizedError {
    case invalidFile
    case invalidEncoding
    case cannotCreateFile

    var errorDescription: String? {
        switch self {
        case .invalidFile: return "本机 API Key 文件不是普通文件；为保护数据，未读取它。"
        case .invalidEncoding: return "本机 API Key 文件编码无效；原文件已保留。"
        case .cannotCreateFile: return "无法创建本机 API Key 文件。"
        }
    }
}

enum APIKeyMigration {
    /// Migrate the former UserDefaults value only after the private-file write succeeds.
    static func load(defaults: UserDefaults, legacyKey: String, store: APIKeyStore) throws -> String {
        if let existing = try store.load(), !existing.isEmpty {
            defaults.removeObject(forKey: legacyKey)
            return existing
        }
        guard let legacy = defaults.string(forKey: legacyKey), !legacy.isEmpty else { return "" }
        try store.save(legacy)
        defaults.removeObject(forKey: legacyKey)
        return legacy
    }
}
