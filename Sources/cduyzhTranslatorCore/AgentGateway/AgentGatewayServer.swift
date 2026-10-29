import Foundation
import Network

/// 嵌入式本地 Agent 网关服务器 (基于 Apple 原生 Network.framework)
/// 监听 127.0.0.1:11899，为外部 Agent (Cursor、Claude Desktop、终端脚本、Python Agent 等) 提供统一服务
public final class AgentGatewayServer: ObservableObject {
    public static let shared = AgentGatewayServer()
    
    @Published public var isRunning: Bool = false
    @Published public var port: UInt16 = 11899
    
    private var listener: NWListener?
    private var contextCleanupTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.cduyzh.agentGateway", qos: .userInitiated)
    
    private init() {}
    
    public func start(port: UInt16 = 11899) {
        self.port = port
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let parameters = NWParameters.tcp
                let nwPort = NWEndpoint.Port(rawValue: port)!
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: nwPort)
                self.listener = try NWListener(using: parameters)
                
                self.listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleConnection(connection)
                }
                
                self.listener?.stateUpdateHandler = { state in
                    DispatchQueue.main.async {
                        switch state {
                        case .ready:
                            self.isRunning = true
                            print("[AgentGateway] 本地 Agent 网关服务已启动: http://127.0.0.1:\(port)")
                        case .failed(let err):
                            self.isRunning = false
                            print("[AgentGateway] 网关启动失败: \(err.localizedDescription)")
                        case .cancelled:
                            self.isRunning = false
                        default:
                            break
                        }
                    }
                }
                
                self.listener?.start(queue: self.queue)
                self.contextCleanupTimer?.cancel()
                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now() + 3_600, repeating: 3_600)
                timer.setEventHandler {
                    Task { @MainActor in
                        AgentTranslationContextStore.shared.pruneExpired(
                            retentionDays: AppSettings.shared.agentContextRetentionDays
                        )
                    }
                }
                timer.resume()
                self.contextCleanupTimer = timer
                Task { @MainActor in
                    AgentTranslationContextStore.shared.pruneExpired(
                        retentionDays: AppSettings.shared.agentContextRetentionDays
                    )
                }
            } catch {
                print("[AgentGateway] 初始化失败: \(error)")
            }
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        contextCleanupTimer?.cancel()
        contextCleanupTimer = nil
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readRequest(connection: connection, accumulatedData: Data())
    }
    
    private func readRequest(connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }
            guard let data = data, !data.isEmpty else {
                if !accumulatedData.isEmpty, let requestString = String(data: accumulatedData, encoding: .utf8) {
                    self.processHttpRequest(requestString: requestString, connection: connection)
                } else {
                    connection.cancel()
                }
                return
            }

            var currentData = accumulatedData
            currentData.append(data)

            guard let requestString = String(data: currentData, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // 检查 Header 是否接收完成 (直接基于字节特征查找 \r\n\r\n)
            let delimiter = Data([0x0D, 0x0A, 0x0D, 0x0A])
            if let headerEndRange = currentData.range(of: delimiter) {
                let headerData = currentData.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = currentData.subdata(in: headerEndRange.upperBound..<currentData.count)

                let headerString = String(data: headerData, encoding: .utf8) ?? ""
                var expectedContentLength = 0
                for line in headerString.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        let valStr = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        expectedContentLength = Int(valStr) ?? 0
                        break
                    }
                }

                if bodyData.count >= expectedContentLength {
                    if let fullRequestString = String(data: currentData, encoding: .utf8) {
                        self.processHttpRequest(requestString: fullRequestString, connection: connection)
                    } else {
                        connection.cancel()
                    }
                    return
                }
            }

            if isComplete {
                self.processHttpRequest(requestString: requestString, connection: connection)
                return
            }

            // 数据未接收完，继续接收
            self.readRequest(connection: connection, accumulatedData: currentData)
        }
    }
    
    private func processHttpRequest(requestString: String, connection: NWConnection) {
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Bad Request\"}")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Bad Request\"}")
            return
        }
        
        let method = parts[0].uppercased()
        let components = URLComponents(string: "http://127.0.0.1" + parts[1])
        let path = components?.path ?? parts[1]
        let query = components?.queryItems ?? []

        let requestHeaders = lines.dropFirst().prefix { !$0.isEmpty }
        if let originHeader = requestHeaders.first(where: { $0.lowercased().hasPrefix("origin:") }) {
            let origin = originHeader.dropFirst("origin:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !["http://127.0.0.1:\(port)", "http://localhost:\(port)"].contains(origin) {
                sendResponse(connection: connection, statusCode: 403, body: "{\"error\":\"Cross-origin browser access is not allowed\"}")
                return
            }
        }
        
        // 提取 Body 数据
        var bodyString = ""
        if let bodyIndex = requestString.range(of: "\r\n\r\n") {
            bodyString = String(requestString[bodyIndex.upperBound...])
        }
        
        Task {
            do {
                if path == "/health" {
                    let response = "{\"status\":\"ok\",\"service\":\"cduyzhTranslator-agent-gateway\"}"
                    self.sendResponse(connection: connection, statusCode: 200, body: response)
                    return
                }
                
                if path == "/v1/stats" && method == "GET" {
                    let stats = await UsageStatisticsManager.shared.stats
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let json = (try? encoder.encode(stats)) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }
                
                if path == "/v1/memory" && method == "GET" {
                    let memoryJson = await PersonalTranslationMemoryManager.shared.exportJSON()
                    self.sendResponse(connection: connection, statusCode: 200, body: memoryJson)
                    return
                }

                if path == "/v1/knowledge-base" && method == "GET" {
                    let result = await MainActor.run { () -> [String: Any] in
                        let kb = DomainKnowledgeBaseManager.shared
                        let settings = AppSettings.shared
                        let categories = kb.categories.map { cat -> [String: Any] in
                            let count = kb.items.filter { $0.categoryId == cat.id }.count
                            let enabledCount = kb.items.filter { $0.categoryId == cat.id && $0.isEnabled }.count
                            return [
                                "id": cat.id,
                                "name": cat.name,
                                "description": cat.description,
                                "is_enabled": cat.isEnabled,
                                "total_terms": count,
                                "enabled_terms": enabledCount
                            ]
                        }
                        return [
                            "enabled": settings.knowledgeBaseEnabled,
                            "max_terms_per_translation": settings.knowledgeBaseMaxTerms,
                            "max_characters_per_translation": settings.knowledgeBaseMaxCharacters,
                            "total_categories": kb.categories.count,
                            "total_terms": kb.items.count,
                            "enabled_terms": kb.items.filter { item in
                                kb.categories.first(where: { $0.id == item.categoryId })?.isEnabled == true && item.isEnabled
                            }.count,
                            "categories": categories
                        ]
                    }
                    let json = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/knowledge-base/terms" && method == "GET" {
                    let categoryId = query.first(where: { $0.name == "category_id" })?.value
                    let result = await MainActor.run { () -> [String: Any] in
                        let kb = DomainKnowledgeBaseManager.shared
                        let items = kb.items.filter { categoryId == nil || $0.categoryId == categoryId }
                        let termList = items.map { item -> [String: Any] in
                            [
                                "id": item.id,
                                "category_id": item.categoryId,
                                "source": item.sourceTerm,
                                "target": item.preferredTranslation,
                                "source_lang": item.sourceLang,
                                "target_lang": item.targetLang,
                                "notes": item.notes,
                                "is_enabled": item.isEnabled
                            ]
                        }
                        return ["terms": termList, "count": termList.count]
                    }
                    let json = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/knowledge-base/toggle" && method == "POST" {
                    guard let bodyData = bodyString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
                          let categoryId = json["category_id"] as? String,
                          let isEnabled = json["is_enabled"] as? Bool else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Missing 'category_id' or 'is_enabled'\"}")
                        return
                    }
                    let success = await MainActor.run { () -> Bool in
                        do {
                            try DomainKnowledgeBaseManager.shared.setCategoryEnabled(id: categoryId, isEnabled: isEnabled)
                            return true
                        } catch {
                            return false
                        }
                    }
                    self.sendResponse(connection: connection, statusCode: success ? 200 : 404, body: success ? "{\"status\":\"ok\"}" : "{\"error\":\"Category not found\"}")
                    return
                }

                if path == "/v1/knowledge-base/import" && method == "POST" {
                    guard let bodyData = bodyString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid JSON body\"}")
                        return
                    }

                    let categoryName = (json["category"] as? String) ?? (json["category_name"] as? String) ?? "通用专业词汇"
                    let categoryDesc = (json["category_description"] as? String) ?? ""
                    let termsArray = json["terms"] as? [[String: Any]] ?? []

                    let importResult = await MainActor.run { () -> [String: Any] in
                        let kb = DomainKnowledgeBaseManager.shared
                        do {
                            let cat = try kb.addCategory(name: categoryName, description: categoryDesc)
                            var added = 0
                            var updated = 0
                            var skipped = 0

                            for termDict in termsArray {
                                guard let src = (termDict["source"] as? String) ?? (termDict["source_term"] as? String),
                                      let tgt = (termDict["target"] as? String) ?? (termDict["preferred_translation"] as? String),
                                      !src.trimmingCharacters(in: .whitespaces).isEmpty,
                                      !tgt.trimmingCharacters(in: .whitespaces).isEmpty else {
                                    skipped += 1
                                    continue
                                }
                                let sLang = (termDict["source_lang"] as? String) ?? "auto"
                                let tLang = (termDict["target_lang"] as? String) ?? "zh-CN"
                                let notes = (termDict["notes"] as? String) ?? ""
                                let isEnabled = (termDict["is_enabled"] as? Bool) ?? true

                                let exists = kb.items.contains {
                                    $0.categoryId == cat.id && DomainKnowledgeBaseManager.normalized($0.sourceTerm) == DomainKnowledgeBaseManager.normalized(src)
                                }
                                try kb.upsertItem(
                                    categoryId: cat.id,
                                    sourceTerm: src,
                                    preferredTranslation: tgt,
                                    sourceLang: sLang,
                                    targetLang: tLang,
                                    notes: notes,
                                    isEnabled: isEnabled
                                )
                                if exists { updated += 1 } else { added += 1 }
                            }
                            return [
                                "status": "ok",
                                "category_id": cat.id,
                                "category_name": cat.name,
                                "added": added,
                                "updated": updated,
                                "skipped": skipped,
                                "total_in_category": kb.items.filter { $0.categoryId == cat.id }.count
                            ]
                        } catch {
                            return ["status": "error", "message": error.localizedDescription]
                        }
                    }
                    let respData = (try? JSONSerialization.data(withJSONObject: importResult, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: respData, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/knowledge-base/reset" && method == "POST" {
                    await MainActor.run {
                        try? DomainKnowledgeBaseManager.shared.resetToSeeds()
                    }
                    self.sendResponse(connection: connection, statusCode: 200, body: "{\"status\":\"ok\",\"message\":\"Knowledge base reset to seed defaults\"}")
                    return
                }

                if path == "/v1/knowledge-base/agent-chat" && method == "POST" {
                    guard let bodyData = bodyString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid JSON body\"}")
                        return
                    }

                    guard let prompt = json["prompt"] as? String, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Missing required field: prompt\"}")
                        return
                    }

                    // 商业化权限核验：仅 Pro 用户或试用期内可用
                    let isPro = await MainActor.run { LicenseManager.shared.isPro }
                    if !isPro {
                        self.sendResponse(connection: connection, statusCode: 402, body: "{\"status\":\"payment_required\",\"error\":\"AI Agent 对话功能为 TransBar Pro 专享功能。升级 Pro 解锁无限制 AI 知识库构建与多轮调用。\",\"upgrade_url\":\"https://auth.cduyzh.top\"}")
                        return
                    }

                    let autoCommit = (json["auto_commit"] as? Bool) ?? true
                    let categoryName = (json["category_name"] as? String) ?? (json["category"] as? String)
                    let categoryId = json["category_id"] as? String

                    let result = await Self.handleAgentChat(
                        prompt: prompt,
                        categoryName: categoryName,
                        categoryId: categoryId,
                        autoCommit: autoCommit
                    )

                    let statusCode = (result["status"] as? String) == "ok" ? 200 : 500
                    let respData = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: statusCode, body: String(data: respData, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/knowledge-base/agent-enrich" && method == "POST" {
                    guard let bodyData = bodyString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid JSON body\"}")
                        return
                    }

                    guard let term = (json["term"] as? String) ?? (json["source_term"] as? String),
                          !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Missing required field: term\"}")
                        return
                    }

                    let preferredCatName = json["category_name"] as? String

                    let result = await Self.handleAgentEnrich(term: term, preferredCatName: preferredCatName)

                    let statusCode = (result["status"] as? String) == "ok" ? 200 : 500
                    let respData = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: statusCode, body: String(data: respData, encoding: .utf8) ?? "{}")
                    return
                }
                
                if (path == "/v1/prompt" || path == "/v1/memory/prompt") && method == "GET" {
                    let settings = AppSettings.shared
                    let sourceLang = query.first(where: { $0.name == "source_lang" })?.value ?? settings.lastSourceLanguage
                    let targetLang = query.first(where: { $0.name == "target_lang" })?.value ?? settings.lastTargetLanguage
                    let text = query.first(where: { $0.name == "text" })?.value
                    let sessionID = query.first(where: { $0.name == "session_id" })?.value
                    let history = await MainActor.run { () -> AgentTranslationContextSnapshot in
                        guard settings.agentContextEnabled, let sessionID else { return AgentTranslationContextSnapshot() }
                        return AgentTranslationContextStore.shared.snapshot(
                            sessionID: sessionID, sourceLang: sourceLang, targetLang: targetLang,
                            maxTurns: settings.agentContextMaxTurns,
                            maxCharacters: settings.agentContextMaxCharacters,
                            retentionDays: settings.agentContextRetentionDays
                        )
                    }
                    let kbInfo = await MainActor.run { () -> [String: Any] in
                        let kb = DomainKnowledgeBaseManager.shared
                        if let text, settings.knowledgeBaseEnabled {
                            let match = kb.queryContext(
                                text: text,
                                sourceLang: sourceLang,
                                targetLang: targetLang,
                                maxTerms: settings.knowledgeBaseMaxTerms,
                                maxCharacters: settings.knowledgeBaseMaxCharacters
                            )
                            return [
                                "enabled": true,
                                "matched_terms": match.matchedItems.count,
                                "suppressed_terms": match.suppressedCount,
                                "estimated_characters_saved": match.estimatedCharactersSaved
                            ]
                        } else {
                            return [
                                "enabled": settings.knowledgeBaseEnabled,
                                "matched_terms": 0,
                                "total_terms": kb.items.count
                            ]
                        }
                    }
                    let prompt = await AgentTranslationContext.currentPrompt(
                        text: text, sourceLang: sourceLang, targetLang: targetLang, historyContext: history.text
                    )
                    let result: [String: Any] = [
                        "prompt": prompt,
                        "source_lang": sourceLang,
                        "target_lang": targetLang,
                        "context": [
                            "enabled": settings.agentContextEnabled,
                            "included": history.turnCount > 0,
                            "turns": history.turnCount,
                            "characters": history.characterCount
                        ],
                        "knowledge_base": kbInfo
                    ]
                    let json = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }
                
                if path == "/v1/models" && method == "GET" {
                    let models = AppSettings.shared.availableModels
                    let result = ["models": models, "selected": AppSettings.shared.selectedModel] as [String : Any]
                    let json = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/version" && method == "GET" {
                    let curr = AppVersion.current
                    let info: [String: Any] = [
                        "app_name": AppVersion.appName,
                        "version": curr.description,
                        "build": curr.buildNumber ?? 1,
                        "has_update": AppSettings.shared.hasNewUpdateAvailable,
                        "latest_version": AppSettings.shared.latestAvailableVersion ?? curr.description
                    ]
                    let json = (try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }

                if path == "/v1/changelog" && method == "GET" {
                    let changelogJson = ChangelogManager.shared.exportAsJSON()
                    self.sendResponse(connection: connection, statusCode: 200, body: changelogJson)
                    return
                }

                if path == "/v1/check-update" && (method == "POST" || method == "GET") {
                    let checkResult = await AppUpdateChecker.shared.checkForUpdates(isManual: true)
                    let respDict: [String: Any]
                    switch checkResult {
                    case .upToDate(let curr):
                        respDict = [
                            "status": "up_to_date",
                            "current_version": curr.description,
                            "has_update": false
                        ]
                    case .updateAvailable(let latest, let curr, let note, let download):
                        respDict = [
                            "status": "update_available",
                            "has_update": true,
                            "current_version": curr.description,
                            "latest_version": latest.description,
                            "title": note?.title ?? "",
                            "summary": note?.summary ?? "",
                            "download_url": download?.absoluteString ?? ""
                        ]
                    case .failed(let err):
                        respDict = [
                            "status": "error",
                            "has_update": false,
                            "error": err
                        ]
                    }
                    let json = (try? JSONSerialization.data(withJSONObject: respDict, options: [.prettyPrinted])) ?? Data()
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: json, encoding: .utf8) ?? "{}")
                    return
                }
                
                if path == "/v1/translate" && method == "POST" {
                    guard let bodyData = bodyString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
                          let text = json["text"] as? String else {
                        self.sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Missing 'text' field in JSON body\"}")
                        return
                    }
                    
                    let targetLang = (json["target_lang"] as? String) ?? AppSettings.shared.lastTargetLanguage
                    let sourceLang = (json["source_lang"] as? String) ?? AppSettings.shared.lastSourceLanguage
                    let sessionID = json["session_id"] as? String
                    let settings = AppSettings.shared
                    let engineStr = json["engine"] as? String
                    let engineType: TranslationEngineType
                    if let engineStr {
                        guard let parsed = TranslationEngineType(rawValue: engineStr) else {
                            self.sendResponse(connection: connection, statusCode: 400,
                                              body: "{\"error\":\"Unsupported engine. Use google or deepseek.\"}")
                            return
                        }
                        engineType = parsed
                    } else {
                        engineType = settings.selectedEngine
                    }
                    let contextSnapshot = await MainActor.run { () -> AgentTranslationContextSnapshot in
                        guard engineType == .deepseek, settings.agentContextEnabled, let sessionID else {
                            return AgentTranslationContextSnapshot()
                        }
                        return AgentTranslationContextStore.shared.snapshot(
                            sessionID: sessionID, sourceLang: sourceLang, targetLang: targetLang,
                            maxTurns: settings.agentContextMaxTurns,
                            maxCharacters: settings.agentContextMaxCharacters,
                            retentionDays: settings.agentContextRetentionDays
                        )
                    }
                    
                    let result = try await TranslationCoordinator.shared.translate(
                        text: text,
                        sourceLang: sourceLang,
                        targetLang: targetLang,
                        engine: engineType,
                        historyContext: contextSnapshot.text
                    )

                    let savedToContext = await MainActor.run { () -> Bool in
                        guard engineType == .deepseek, settings.agentContextEnabled, let sessionID else { return false }
                        return AgentTranslationContextStore.shared.append(
                            sessionID: sessionID,
                            sourceText: result.sourceText,
                            targetText: result.targetText,
                            sourceLang: sourceLang,
                            targetLang: targetLang,
                            maxCharacters: settings.agentContextMaxCharacters,
                            retentionDays: settings.agentContextRetentionDays
                        )
                    }
                    
                    let kbInfo: [String: Any] = await MainActor.run {
                        if engineType == .deepseek && settings.knowledgeBaseEnabled {
                            let match = DomainKnowledgeBaseManager.shared.queryContext(
                                text: text,
                                sourceLang: sourceLang,
                                targetLang: targetLang,
                                maxTerms: settings.knowledgeBaseMaxTerms,
                                maxCharacters: settings.knowledgeBaseMaxCharacters
                            )
                            return [
                                "enabled": true,
                                "matched_terms": match.matchedItems.count,
                                "suppressed_terms": match.suppressedCount,
                                "estimated_characters_saved": match.estimatedCharactersSaved
                            ]
                        } else {
                            return [
                                "enabled": engineType == .deepseek ? settings.knowledgeBaseEnabled : false,
                                "matched_terms": 0,
                                "supported": engineType == .deepseek
                            ]
                        }
                    }

                    let respDict: [String: Any] = [
                        "source_text": result.sourceText,
                        "target_text": result.targetText,
                        "source_lang": result.detectedSourceLang,
                        "target_lang": result.targetLang,
                        "engine": result.engineUsed,
                        "from_memory": result.fromMemory,
                        "latency_ms": result.latencyMs,
                        "context": [
                            "enabled": settings.agentContextEnabled,
                            "included_turns": contextSnapshot.turnCount,
                            "included_characters": contextSnapshot.characterCount,
                            "saved_current_turn": savedToContext
                        ],
                        "knowledge_base": kbInfo,
                        "tokens": [
                            "prompt": result.promptTokens,
                            "completion": result.completionTokens,
                            "reasoning": result.reasoningTokens,
                            "total": result.totalTokens
                        ]
                    ]
                    
                    let respData = try JSONSerialization.data(withJSONObject: respDict, options: [.prettyPrinted])
                    self.sendResponse(connection: connection, statusCode: 200, body: String(data: respData, encoding: .utf8) ?? "{}")
                    return
                }
                
                self.sendResponse(connection: connection, statusCode: 404, body: "{\"error\":\"Endpoint not found\"}")
            } catch {
                let data = (try? JSONSerialization.data(withJSONObject: ["error": error.localizedDescription])) ?? Data()
                self.sendResponse(connection: connection, statusCode: 500, body: String(decoding: data, as: UTF8.self))
            }
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : "Error")
        let responseHeader = "HTTP/1.1 \(statusCode) \(statusText)\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
        let fullResponse = responseHeader + body
        
        if let data = fullResponse.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        } else {
            connection.cancel()
        }
    }

    // MARK: - Agent 智能建词与富化处理

    @MainActor
    private static func handleAgentChat(
        prompt: String,
        categoryName: String?,
        categoryId: String?,
        autoCommit: Bool
    ) async -> [String: Any] {
        let assistant = AgentGlossaryAssistant.shared
        let kb = DomainKnowledgeBaseManager.shared
        do {
            let drafts = try await assistant.chatAndGenerate(
                prompt: prompt,
                contextCategoryName: categoryName,
                existingCategories: kb.categories
            )

            var committedCount = 0
            var impactedCategories: [String] = []

            if autoCommit && !drafts.isEmpty {
                let commitRes = try assistant.commitToKnowledgeBase(
                    drafts: drafts,
                    defaultCategoryId: categoryId,
                    manager: kb
                )
                committedCount = commitRes.savedCount
                impactedCategories = Array(commitRes.categoryNames)
            }

            let termsData = drafts.map { draft in
                [
                    "source_term": draft.sourceTerm,
                    "preferred_translation": draft.preferredTranslation,
                    "source_lang": draft.sourceLang,
                    "target_lang": draft.targetLang,
                    "suggested_category": draft.suggestedCategoryName,
                    "notes": draft.notes
                ]
            }

            return [
                "status": "ok",
                "generated_count": drafts.count,
                "committed": autoCommit,
                "committed_count": committedCount,
                "impacted_categories": impactedCategories,
                "terms": termsData
            ]
        } catch {
            return [
                "status": "error",
                "message": error.localizedDescription
            ]
        }
    }

    @MainActor
    private static func handleAgentEnrich(term: String, preferredCatName: String?) async -> [String: Any] {
        let assistant = AgentGlossaryAssistant.shared
        let kb = DomainKnowledgeBaseManager.shared
        do {
            let enriched = try await assistant.analyzeAndEnrichTerm(
                term: term,
                preferredCategoryName: preferredCatName,
                existingCategories: kb.categories
            )

            return [
                "status": "ok",
                "source_term": enriched.sourceTerm,
                "preferred_translation": enriched.preferredTranslation,
                "source_lang": enriched.sourceLang,
                "target_lang": enriched.targetLang,
                "suggested_category": enriched.suggestedCategoryName,
                "notes": enriched.notes
            ]
        } catch {
            return [
                "status": "error",
                "message": error.localizedDescription
            ]
        }
    }
}
