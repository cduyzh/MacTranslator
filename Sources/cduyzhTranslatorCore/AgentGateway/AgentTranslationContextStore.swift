import Foundation

public struct AgentTranslationContextSnapshot: Equatable, Sendable {
    public let text: String
    public let turnCount: Int
    public let characterCount: Int

    public init(text: String = "", turnCount: Int = 0, characterCount: Int = 0) {
        self.text = text
        self.turnCount = turnCount
        self.characterCount = characterCount
    }
}

private struct StoredAgentTranslationTurn: Codable, Equatable {
    let sourceText: String
    let targetText: String
    let sourceLang: String
    let targetLang: String
    let createdAt: Date
}

private struct StoredAgentTranslationContexts: Codable {
    var version = 1
    var sessions: [String: [StoredAgentTranslationTurn]] = [:]
}

/// Opt-in, device-local short-term context for Agent Gateway translation sessions.
@MainActor
public final class AgentTranslationContextStore {
    public static let shared = AgentTranslationContextStore()
    public static let fileName = "agent-translation-context.json"

    public let storageFileURL: URL
    private let now: () -> Date
    private var storage = StoredAgentTranslationContexts()
    private var hasLoaded = false

    public init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
        self.now = now
        if let fileURL {
            self.storageFileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageFileURL = support
                .appendingPathComponent("cduyzhTranslator", isDirectory: true)
                .appendingPathComponent(Self.fileName)
        }
    }

    public func snapshot(sessionID: String, sourceLang: String, targetLang: String,
                         maxTurns: Int, maxCharacters: Int, retentionDays: Int) -> AgentTranslationContextSnapshot {
        loadIfNeeded()
        pruneExpired(retentionDays: retentionDays)
        guard let key = normalizedSessionID(sessionID), maxTurns > 0, maxCharacters > 0 else {
            return AgentTranslationContextSnapshot()
        }
        let matching = (storage.sessions[key] ?? []).filter {
            $0.sourceLang == sourceLang && $0.targetLang == targetLang
        }
        var selected: [StoredAgentTranslationTurn] = []
        var usedCharacters = 0
        for turn in matching.suffix(maxTurns).reversed() {
            let block = Self.render(turn)
            let nextCount = usedCharacters + block.count + (selected.isEmpty ? 0 : 2)
            guard nextCount <= maxCharacters else { break }
            selected.append(turn)
            usedCharacters = nextCount
        }
        let chronological = selected.reversed()
        let text = chronological.map(Self.render).joined(separator: "\n\n")
        return AgentTranslationContextSnapshot(text: text, turnCount: selected.count, characterCount: text.count)
    }

    /// Returns false when the turn is too large for the configured context budget or storage fails.
    @discardableResult
    public func append(sessionID: String, sourceText: String, targetText: String,
                       sourceLang: String, targetLang: String, maxCharacters: Int,
                       retentionDays: Int) -> Bool {
        loadIfNeeded()
        pruneExpired(retentionDays: retentionDays)
        guard let key = normalizedSessionID(sessionID), maxCharacters > 0 else { return false }
        let turn = StoredAgentTranslationTurn(sourceText: sourceText, targetText: targetText,
                                              sourceLang: sourceLang, targetLang: targetLang, createdAt: now())
        guard Self.render(turn).count <= maxCharacters else { return false }

        var turns = storage.sessions[key] ?? []
        turns.append(turn)
        storage.sessions[key] = Array(turns.suffix(20))
        if storage.sessions.count > 100 {
            let oldestKeys = storage.sessions.keys.sorted { lhs, rhs in
                (storage.sessions[lhs]?.last?.createdAt ?? .distantPast) <
                    (storage.sessions[rhs]?.last?.createdAt ?? .distantPast)
            }
            for oldKey in oldestKeys.prefix(storage.sessions.count - 100) { storage.sessions.removeValue(forKey: oldKey) }
        }
        return persist()
    }

    public func pruneExpired(retentionDays: Int) {
        loadIfNeeded()
        let cutoff = now().addingTimeInterval(-TimeInterval(max(1, retentionDays)) * 86_400)
        var didChange = false
        for key in Array(storage.sessions.keys) {
            let current = storage.sessions[key] ?? []
            let fresh = current.filter { $0.createdAt >= cutoff }
            if fresh != current {
                storage.sessions[key] = fresh
                didChange = true
            }
            if fresh.isEmpty {
                storage.sessions.removeValue(forKey: key)
                didChange = true
            }
        }
        if didChange {
            if storage.sessions.isEmpty {
                try? FileManager.default.removeItem(at: storageFileURL)
            } else {
                _ = persist()
            }
        }
    }

    public func clearAll() {
        storage = StoredAgentTranslationContexts()
        hasLoaded = true
        try? FileManager.default.removeItem(at: storageFileURL)
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let data = try? Data(contentsOf: storageFileURL),
              let decoded = try? JSONDecoder().decode(StoredAgentTranslationContexts.self, from: data),
              decoded.version == 1 else { return }
        storage = decoded
    }

    private func persist() -> Bool {
        do {
            let directory = storageFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(storage).write(to: storageFileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageFileURL.path)
            return true
        } catch {
            return false
        }
    }

    private func normalizedSessionID(_ sessionID: String) -> String? {
        let value = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return String(value.prefix(128))
    }

    private static func render(_ turn: StoredAgentTranslationTurn) -> String {
        "Previous source (\(turn.sourceLang)):\n<source>\n\(turn.sourceText)\n</source>\nPrevious translation (\(turn.targetLang)):\n<translation>\n\(turn.targetText)\n</translation>"
    }
}
