import Foundation

public enum PersonalTranslationMemoryKind: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case term
    case example

    public var id: String { rawValue }
    public var displayName: String { self == .term ? "个人术语" : "修正样例" }
}

/// 仅保存用户主动创建、确认或由旧版人工修正记录迁移的偏好。
public struct PersonalTranslationMemoryItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var sourceTerm: String
    public var preferredTranslation: String
    public var sourceLang: String
    public var targetLang: String
    public var notes: String
    public var isEnabled: Bool
    public var kind: PersonalTranslationMemoryKind
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceTerm: String,
        preferredTranslation: String,
        sourceLang: String = "auto",
        targetLang: String = "zh-CN",
        notes: String = "",
        isEnabled: Bool = true,
        kind: PersonalTranslationMemoryKind = .term,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.preferredTranslation = preferredTranslation
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.notes = notes
        self.isEnabled = isEnabled
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 译文差异只能确认目标文字；缺乏词对齐证据时 sourceTerm 留空，交由用户选取。
public struct CorrectionSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { "\(sourceTerm)\u{0}\(preferredTranslation)" }
    public let sourceTerm: String
    public let preferredTranslation: String
    public let originalTranslation: String
    public let kind: PersonalTranslationMemoryKind
    public var requiresSourceSelection: Bool { sourceTerm.isEmpty }

    public init(sourceTerm: String, preferredTranslation: String, originalTranslation: String, kind: PersonalTranslationMemoryKind = .term) {
        self.sourceTerm = sourceTerm
        self.preferredTranslation = preferredTranslation
        self.originalTranslation = originalTranslation
        self.kind = kind
    }
}

/// 纯函数：单词原文允许建议完整映射；句子内的译文变更仅建议目标词，不猜测源词。
public func suggestTerms(sourceText: String, originalTranslation: String, correctedTranslation: String) -> [CorrectionSuggestion] {
    personalCorrectionSuggestions(sourceText: sourceText, originalTranslation: originalTranslation, correctedTranslation: correctedTranslation)
}

func personalCorrectionSuggestions(sourceText: String, originalTranslation: String, correctedTranslation: String) -> [CorrectionSuggestion] {
    let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    let original = originalTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
    let corrected = correctedTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty, !corrected.isEmpty, original != corrected else { return [] }
    let sentencePunctuation = CharacterSet(charactersIn: ".!?。！？;；\n\r")
    let sourceIsSingleTerm = source.count <= 32 && source.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'’").contains($0) } && source.rangeOfCharacter(from: .letters) != nil
    let targetIsShort = corrected.count <= 80 && corrected.split(whereSeparator: { $0.isWhitespace }).count <= 8 && corrected.rangeOfCharacter(from: sentencePunctuation) == nil
    if sourceIsSingleTerm && targetIsShort {
        return [CorrectionSuggestion(sourceTerm: source, preferredTranslation: corrected, originalTranslation: original)]
    }
    // For a single word or acronym, preserve the user's complete correction even
    // when it contains a short explanation or punctuation.
    if sourceIsSingleTerm && corrected.count <= 160 {
        return [CorrectionSuggestion(sourceTerm: source, preferredTranslation: corrected, originalTranslation: original)]
    }
    let old = Array(original)
    let new = Array(corrected)
    var prefix = 0
    while prefix < min(old.count, new.count), old[prefix] == new[prefix] { prefix += 1 }
    var suffix = 0
    while suffix < min(old.count - prefix, new.count - prefix), old[old.count - suffix - 1] == new[new.count - suffix - 1] { suffix += 1 }
    var end = new.count - suffix
    // Latin 词尾/词中修改扩展到完整目标词，不生成 "s" 之类的伪术语。
    func latinWord(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'’-" ).contains($0) }
    }
    while prefix > 0, prefix < new.count, latinWord(new[prefix - 1]), latinWord(new[prefix]) { prefix -= 1 }
    while end < new.count, end > 0, latinWord(new[end - 1]), latinWord(new[end]) { end += 1 }
    let preferred = String(new[prefix..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !preferred.isEmpty, preferred.rangeOfCharacter(from: .letters) != nil else { return [] }
    let oldEnd = max(prefix, old.count - suffix)
    let oldPart = prefix <= old.count ? String(old[prefix..<min(oldEnd, old.count)]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
    return [CorrectionSuggestion(sourceTerm: "", preferredTranslation: preferred, originalTranslation: oldPart)]
}
