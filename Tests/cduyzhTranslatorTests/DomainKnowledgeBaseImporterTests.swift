import XCTest
@testable import cduyzhTranslatorCore

final class DomainKnowledgeBaseImporterTests: XCTestCase {

    func testParseJSONDirectArray() {
        let json = """
        [
            {"source": "gradient descent", "target": "梯度下降", "notes": "优化算法"},
            {"source": "backpropagation", "target": "反向传播", "source_lang": "en", "target_lang": "zh-CN"}
        ]
        """
        let terms = DomainKnowledgeBaseImporter.parse(content: json)
        XCTAssertEqual(terms.count, 2)
        XCTAssertEqual(terms[0].source, "gradient descent")
        XCTAssertEqual(terms[0].target, "梯度下降")
        XCTAssertEqual(terms[0].notes, "优化算法")
        XCTAssertEqual(terms[1].source, "backpropagation")
        XCTAssertEqual(terms[1].target, "反向传播")
    }

    func testParseJSONDictionary() {
        let json = """
        {
            "overfitting": "过拟合",
            "underfitting": "欠拟合"
        }
        """
        let terms = DomainKnowledgeBaseImporter.parse(content: json)
        XCTAssertEqual(terms.count, 2)
        let sources = Set(terms.map(\.source))
        XCTAssertTrue(sources.contains("overfitting"))
        XCTAssertTrue(sources.contains("underfitting"))
    }

    func testParseCSVWithHeaderAndQuotes() {
        let csv = """
        "source","target","notes"
        "learning rate","学习率","步长超参数"
        "loss function","损失函数","评估目标"
        """
        let terms = DomainKnowledgeBaseImporter.parse(content: csv)
        XCTAssertEqual(terms.count, 2)
        XCTAssertEqual(terms[0].source, "learning rate")
        XCTAssertEqual(terms[0].target, "学习率")
        XCTAssertEqual(terms[0].notes, "步长超参数")
        XCTAssertEqual(terms[1].source, "loss function")
    }

    func testParseTSV() {
        let tsv = """
        epoch\t轮次\t全数据集训练一次
        batch size\t批大小\t单次前向样本数
        """
        let terms = DomainKnowledgeBaseImporter.parse(content: tsv)
        XCTAssertEqual(terms.count, 2)
        XCTAssertEqual(terms[0].source, "epoch")
        XCTAssertEqual(terms[0].target, "轮次")
    }

    func testParseKeyValueText() {
        let text = """
        # 机器学习词条注释
        // 这一行也应被忽略
        reinforcement learning = 强化学习
        supervised learning -> 监督学习
        unsupervised learning => 无监督学习
        transfer learning: 迁移学习
        """
        let terms = DomainKnowledgeBaseImporter.parse(content: text)
        XCTAssertEqual(terms.count, 4)
        XCTAssertEqual(terms[0].source, "reinforcement learning")
        XCTAssertEqual(terms[0].target, "强化学习")
        XCTAssertEqual(terms[1].source, "supervised learning")
        XCTAssertEqual(terms[1].target, "监督学习")
        XCTAssertEqual(terms[2].source, "unsupervised learning")
        XCTAssertEqual(terms[2].target, "无监督学习")
        XCTAssertEqual(terms[3].source, "transfer learning")
        XCTAssertEqual(terms[3].target, "迁移学习")
    }

    func testExportCSVAndJSON() {
        let item = DomainGlossaryItem(
            categoryId: "test-cat",
            sourceTerm: "transformer",
            preferredTranslation: "变形金刚 / Transformer",
            sourceLang: "en",
            targetLang: "zh-CN",
            notes: "NLP 模型"
        )
        let csv = DomainKnowledgeBaseImporter.exportCSV(items: [item])
        XCTAssertTrue(csv.contains("transformer"))
        XCTAssertTrue(csv.contains("变形金刚 / Transformer"))

        let category = DomainGlossaryCategory(name: "AI")
        let json = DomainKnowledgeBaseImporter.exportJSON(items: [item], category: category)
        XCTAssertTrue(json.contains("transformer"))
        XCTAssertTrue(json.contains("AI"))
    }
}
