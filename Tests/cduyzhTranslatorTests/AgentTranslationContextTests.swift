import XCTest
@testable import cduyzhTranslatorCore

@MainActor
final class AgentTranslationContextTests: XCTestCase {
    func testSharedPromptBuilderInjectsDynamicLanguagesAndOptionalContext() {
        let prompt = TranslationPromptBuilder.render(
            sharedPrompt: "Keep product names unchanged.",
            instructions: "Use a concise tone.",
            sourceLang: "en",
            targetLang: "ja",
            personalMemory: "product => 製品",
            historyContext: "Previous translation: product launch => 製品の発売"
        )
        XCTAssertTrue(prompt.contains("Source language: English."))
        XCTAssertTrue(prompt.contains("Target language: Japanese."))
        XCTAssertTrue(prompt.contains("Keep product names unchanged."))
        XCTAssertTrue(prompt.contains("Use a concise tone."))
        XCTAssertTrue(prompt.contains("product => 製品"))
        XCTAssertTrue(prompt.contains("Previous translation: product launch => 製品の発売"))
    }

    func testSingleTermPromptAddsInterpretationModeOnlyForStandaloneTokens() {
        let termPrompt = TranslationPromptBuilder.render(
            sharedPrompt: TranslationPromptDefaults.standard,
            instructions: "",
            sourceLang: "en",
            targetLang: "zh-CN",
            personalMemory: "",
            sourceText: "WTF"
        )
        XCTAssertTrue(TranslationPromptBuilder.isSingleTerm("WTF"))
        XCTAssertTrue(termPrompt.contains("## Single-term interpretation mode"))
        XCTAssertTrue(termPrompt.contains("internet slang"))
        XCTAssertTrue(termPrompt.contains("possible expansion or origin"))

        let sentencePrompt = TranslationPromptBuilder.render(
            sharedPrompt: TranslationPromptDefaults.standard,
            instructions: "",
            sourceLang: "en",
            targetLang: "zh-CN",
            personalMemory: "",
            sourceText: "WTF happened"
        )
        XCTAssertFalse(TranslationPromptBuilder.isSingleTerm("WTF happened"))
        XCTAssertFalse(sentencePrompt.contains("## Single-term interpretation mode"))
    }

    func testChineseTargetUsesCuratedHYWInterpretationBeforeModelExplanation() {
        let entry = ChineseInternetMemeGlossary.entry(for: "HYW")
        XCTAssertEqual(entry?.preferredTranslation, "何意味")
        XCTAssertTrue(entry?.meaning.contains("这到底是什么意思") == true)

        let prompt = TranslationPromptBuilder.render(
            sharedPrompt: TranslationPromptDefaults.standard,
            instructions: "",
            sourceLang: "en",
            targetLang: "zh-CN",
            personalMemory: "",
            sourceText: "HYW"
        )
        XCTAssertTrue(prompt.contains("## Verified Chinese internet-meme glossary"))
        XCTAssertTrue(prompt.contains("preferred Chinese rendering \"何意味\""))
        XCTAssertTrue(prompt.contains("伪日语表达“何の意味”"))
        XCTAssertTrue(prompt.contains("不要将其解释为无关的英文缩写") || prompt.contains("unrelated English abbreviation"))

        let nonChinesePrompt = TranslationPromptBuilder.render(
            sharedPrompt: TranslationPromptDefaults.standard,
            instructions: "",
            sourceLang: "en",
            targetLang: "ja",
            personalMemory: "",
            sourceText: "HYW"
        )
        XCTAssertFalse(nonChinesePrompt.contains("## Verified Chinese internet-meme glossary"))
    }

    func testAgentReceivesUserInstructionsAndOnlyEnabledRelevantTerms() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = PersonalTranslationMemoryManager(directoryURL: directory, migrateLegacy: false)
        try manager.upsert(sourceTerm: "Sparxie", preferredTranslation: "火花", sourceLang: "en", targetLang: "zh-CN")
        let disabled = try manager.upsert(sourceTerm: "Banner", preferredTranslation: "卡池", sourceLang: "en", targetLang: "zh-CN", isEnabled: false)
        let prompt = AgentTranslationContext.prompt(instructions: "Use game terminology; keep names consistent.", memory: manager,
                                                    text: "Sparxie Banner", sourceLang: "en", targetLang: "zh-CN")
        XCTAssertTrue(prompt.contains("Use game terminology"))
        XCTAssertTrue(prompt.contains("Sparxie"))
        XCTAssertTrue(prompt.contains("火花"))
        XCTAssertFalse(prompt.contains("卡池"))
        try manager.setEnabled(id: disabled.id, enabled: true)
        XCTAssertTrue(AgentTranslationContext.prompt(instructions: "", memory: manager).contains("卡池"))
    }
}
