import Foundation

/// Curated Chinese internet-meme interpretations used before the model fills in context.
/// The user's personal translation memory is always allowed to override these defaults.
public struct ChineseInternetMemeEntry: Equatable, Sendable {
    public let token: String
    public let preferredTranslation: String
    public let meaning: String
    public let tone: String
    public let usage: String
    public let alternatives: [String]

    public init(token: String, preferredTranslation: String, meaning: String, tone: String, usage: String, alternatives: [String]) {
        self.token = token
        self.preferredTranslation = preferredTranslation
        self.meaning = meaning
        self.tone = tone
        self.usage = usage
        self.alternatives = alternatives
    }
}

public enum ChineseInternetMemeGlossary {
    private static let entries: [String: ChineseInternetMemeEntry] = [
        "hyw": ChineseInternetMemeEntry(
            token: "hyw",
            preferredTranslation: "何意味",
            meaning: "中文网络语境里对“这到底是什么意思 / 你什么意思啊”的戏谑式说法，源自伪日语表达“何の意味”。",
            tone: "通常表示困惑、看不懂、吐槽或轻微调侃；多数时候是反问，不是真的在查词典。",
            usage: "看到荒诞、莫名其妙或难以理解的言行时使用，常见于群聊、游戏社区、弹幕和表情包语境。",
            alternatives: ["这什么意思", "你什么意思啊", "这是什么鬼"]
        ),
        "wtf": ChineseInternetMemeEntry(
            token: "wtf",
            preferredTranslation: "什么鬼 / 搞什么",
            meaning: "英语粗俗感叹 What the fuck 的缩写，用来表达震惊、困惑、不满或难以置信。",
            tone: "粗俗、强烈；中文译法需根据上下文在“什么鬼”“搞什么”“我去”等表达之间选择。",
            usage: "聊天、评论和游戏语境中的即时反应；正式文本不建议直译为网络梗。",
            alternatives: ["什么鬼", "搞什么", "我去"]
        ),
        "bruh": ChineseInternetMemeEntry(
            token: "bruh",
            preferredTranslation: "不是吧 / 无语",
            meaning: "英语网络反应词，常用于面对离谱、尴尬或令人无语的事情。",
            tone: "口语、吐槽、无奈；不一定是在称呼兄弟。",
            usage: "根据上下文可译为“不是吧”“哥们”“无语了”等。",
            alternatives: ["不是吧", "哥们", "无语了"]
        ),
        "sus": ChineseInternetMemeEntry(
            token: "sus",
            preferredTranslation: "可疑 / 不对劲",
            meaning: "suspicious 的网络缩写，表示某人或某事看起来可疑。",
            tone: "轻松、调侃，常带游戏和社交媒体语气。",
            usage: "尤其常见于《Among Us》及其衍生的怀疑语境。",
            alternatives: ["可疑", "有点不对劲", "像内鬼"]
        )
    ]

    public static func entry(for text: String) -> ChineseInternetMemeEntry? {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries[key]
    }

    public static func prompt(for text: String) -> String? {
        guard let entry = entry(for: text) else { return nil }
        let alternatives = entry.alternatives.joined(separator: "、")
        return """
        ## Verified Chinese internet-meme glossary
        The source token "\(entry.token)" has a curated Chinese internet-meme interpretation. For a Chinese target, put the preferred Chinese rendering "\(entry.preferredTranslation)" first unless matching personal translation memory explicitly overrides it.
        Meaning: \(entry.meaning)
        Tone: \(entry.tone)
        Usage: \(entry.usage)
        Candidate alternatives: \(alternatives)
        Do not reinterpret this token as an unrelated English abbreviation. Do not present every alternative as equally preferred; choose based on the source context and explain uncertainty briefly.
        """
    }
}
