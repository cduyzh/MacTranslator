import Foundation

/// 待导入的单条词条载体
public struct ImportableGlossaryTerm: Codable, Equatable, Sendable {
    public var source: String
    public var target: String
    public var sourceLang: String?
    public var targetLang: String?
    public var notes: String?

    public init(source: String, target: String, sourceLang: String? = nil, targetLang: String? = nil, notes: String? = nil) {
        self.source = source
        self.target = target
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case source, target, notes
        case sourceLang = "source_lang"
        case targetLang = "target_lang"
    }
}

/// 导入结果统计
public struct GlossaryImportResult: Codable, Equatable, Sendable {
    public var totalProcessed: Int
    public var addedCount: Int
    public var updatedCount: Int
    public var skippedCount: Int
    public var categoryId: String
    public var categoryName: String

    public init(totalProcessed: Int = 0, addedCount: Int = 0, updatedCount: Int = 0, skippedCount: Int = 0, categoryId: String = "", categoryName: String = "") {
        self.totalProcessed = totalProcessed
        self.addedCount = addedCount
        self.updatedCount = updatedCount
        self.skippedCount = skippedCount
        self.categoryId = categoryId
        self.categoryName = categoryName
    }
}

/// 行业知识库多格式导入与导出解析器
public enum DomainKnowledgeBaseImporter {

    /// 解析文本内容（支持 JSON, CSV/TSV, TXT 键值对）并提取词条列表
    public static func parse(content: String, defaultSourceLang: String = "auto", defaultTargetLang: String = "zh-CN") -> [ImportableGlossaryTerm] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 尝试以 JSON 解析
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let terms = parseJSON(trimmed, defaultSourceLang: defaultSourceLang, defaultTargetLang: defaultTargetLang), !terms.isEmpty {
                return terms
            }
        }

        // 尝试逐行解析（支持 CSV/TSV 以及 "source = target" / "source -> target" / "source: target"）
        return parseLineBased(trimmed, defaultSourceLang: defaultSourceLang, defaultTargetLang: defaultTargetLang)
    }

    private static func parseJSON(_ jsonString: String, defaultSourceLang: String, defaultTargetLang: String) -> [ImportableGlossaryTerm]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        // 格式 1: 标准 ImportableGlossaryTerm 数组
        if let directArray = try? decoder.decode([ImportableGlossaryTerm].self, from: data) {
            return directArray.filter { !$0.source.trimmingCharacters(in: .whitespaces).isEmpty && !$0.target.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        // 格式 2: 包装对象 {"terms": [...]}
        struct Wrapper: Codable {
            let terms: [ImportableGlossaryTerm]
        }
        if let wrapped = try? decoder.decode(Wrapper.self, from: data) {
            return wrapped.terms.filter { !$0.source.trimmingCharacters(in: .whitespaces).isEmpty && !$0.target.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        // 格式 3: 简单键值对字典 {"zero-shot": "零样本", "fine-tuning": "微调"}
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return dict.map { key, value in
                ImportableGlossaryTerm(
                    source: key.trimmingCharacters(in: .whitespacesAndNewlines),
                    target: value.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceLang: defaultSourceLang,
                    targetLang: defaultTargetLang,
                    notes: ""
                )
            }.filter { !$0.source.isEmpty && !$0.target.isEmpty }
        }

        return nil
    }

    private static func parseLineBased(_ text: String, defaultSourceLang: String, defaultTargetLang: String) -> [ImportableGlossaryTerm] {
        var terms: [ImportableGlossaryTerm] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { continue }

            // 1. 尝试以箭头 "->" 或 "=>" 切割
            if trimmed.contains("->") || trimmed.contains("=>") {
                let sep = trimmed.contains("->") ? "->" : "=>"
                let parts = trimmed.components(separatedBy: sep)
                if parts.count >= 2 {
                    let src = parts[0].trimmingCharacters(in: .whitespaces)
                    let tgt = parts[1].trimmingCharacters(in: .whitespaces)
                    if !src.isEmpty && !tgt.isEmpty {
                        terms.append(ImportableGlossaryTerm(source: src, target: tgt, sourceLang: defaultSourceLang, targetLang: defaultTargetLang))
                        continue
                    }
                }
            }

            // 2. 尝试以等号 "=" 切割
            if trimmed.contains("=") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let src = parts[0].trimmingCharacters(in: .whitespaces)
                    let tgt = parts[1].trimmingCharacters(in: .whitespaces)
                    if !src.isEmpty && !tgt.isEmpty {
                        terms.append(ImportableGlossaryTerm(source: src, target: tgt, sourceLang: defaultSourceLang, targetLang: defaultTargetLang))
                        continue
                    }
                }
            }

            // 3. 尝试以冒号 ":" 或 "：" 切割
            if trimmed.contains(":") || trimmed.contains("：") {
                let sep = trimmed.contains(":") ? ":" : "："
                let parts = trimmed.components(separatedBy: sep)
                if parts.count >= 2 {
                    let src = parts[0].trimmingCharacters(in: .whitespaces)
                    let tgt = parts[1].trimmingCharacters(in: .whitespaces)
                    if !src.isEmpty && !tgt.isEmpty {
                        terms.append(ImportableGlossaryTerm(source: src, target: tgt, sourceLang: defaultSourceLang, targetLang: defaultTargetLang))
                        continue
                    }
                }
            }

            // 4. 尝试以制表符 "\t" 或逗号 ","（CSV/TSV）切割
            let delimiter: Character = trimmed.contains("\t") ? "\t" : (trimmed.contains(",") ? "," : ";")
            let csvParts = trimmed.split(separator: delimiter, omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }

            if csvParts.count >= 2 {
                let src = csvParts[0]
                let tgt = csvParts[1]
                let note = csvParts.count >= 3 ? csvParts[2] : ""

                // 排除表头行（如 source, target / 原文, 译文）
                if isHeader(src: src, tgt: tgt) {
                    continue
                }

                if !src.isEmpty && !tgt.isEmpty {
                    terms.append(ImportableGlossaryTerm(
                        source: src,
                        target: tgt,
                        sourceLang: defaultSourceLang,
                        targetLang: defaultTargetLang,
                        notes: note
                    ))
                }
            }
        }

        return terms
    }

    private static func isHeader(src: String, tgt: String) -> Bool {
        let lowSrc = src.lowercased()
        let lowTgt = tgt.lowercased()
        return (lowSrc == "source" || lowSrc == "source_term" || lowSrc == "原文" || lowSrc == "term")
            && (lowTgt == "target" || lowTgt == "translation" || lowTgt == "译文" || lowTgt == "目标")
    }

    // MARK: - 导出格式

    /// 导出为结构化 JSON 格式
    public static func exportJSON(items: [DomainGlossaryItem], category: DomainGlossaryCategory?) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        struct ExportPayload: Codable {
            let category: String
            let totalCount: Int
            let terms: [DomainGlossaryItem]
        }

        let payload = ExportPayload(
            category: category?.name ?? "全部知识库",
            totalCount: items.count,
            terms: items
        )

        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// 导出为 CSV 格式 (UTF-8 带 BOM，防止 Excel 乱码)
    public static func exportCSV(items: [DomainGlossaryItem]) -> String {
        var lines: [String] = ["\u{FEFF}原文 (Source),首选译文 (Target),源语言,目标语言,备注,启用状态"]
        for item in items {
            let src = escapeCSV(item.sourceTerm)
            let tgt = escapeCSV(item.preferredTranslation)
            let sl = escapeCSV(item.sourceLang)
            let tl = escapeCSV(item.targetLang)
            let notes = escapeCSV(item.notes)
            let enabled = item.isEnabled ? "启用" : "停用"
            lines.append("\(src),\(tgt),\(sl),\(tl),\(notes),\(enabled)")
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return str
    }
}
