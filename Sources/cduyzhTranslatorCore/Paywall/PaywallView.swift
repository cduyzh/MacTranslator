import SwiftUI
import AppKit

public struct PaywallView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @ObservedObject private var authManager = AuthSessionManager.shared

    @State private var selectedTier: LicenseTier = .yearly
    @State private var selectedChannel: PaymentChannel = .wechat
    @State private var checkoutState: PaywallCheckoutState = .idle
    @State private var showManualTokenInput: Bool = false
    @State private var manualToken: String = ""
    @State private var manualTokenError: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isCodeFocused: Bool
    @State private var showEmailAuthSheet: Bool = false
    @State private var inputEmail: String = ""
    @State private var inputCode: String = ""
    @State private var isSendingCode: Bool = false
    @State private var authErrorMessage: String? = nil
    @State private var codeSentSuccess: Bool = false
    @State private var countdownSeconds: Int = 0
    @State private var countdownTimer: Timer? = nil

    @State private var activeOrderNo: String? = nil
    @State private var activeQrImage: NSImage? = nil
    @State private var activeQrRawText: String? = nil
    @State private var pollingTimer: Timer? = nil
    @State private var isSandboxProcessing: Bool = false
    @State private var isPennyTestMode: Bool = false

    var onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // 背景渐变：Quiet Native / Ink Signal
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏 / 关闭按钮
                headerBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 1. Pro 品牌标题与当前试用状态
                        heroSection

                        // 2. 三套定价方案选择卡片
                        plansSection

                        // 3. 核心功能权益清单 (为什么升级 Pro)
                        featuresGrid

                        // 4. 国内支付结账区域 (微信/支付宝 + 动态二维码 + 沙箱模拟)
                        checkoutSection

                        // 5. 底部保障与手动兑换
                        footerSection
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }

            // 手动激活弹窗
            if showManualTokenInput {
                manualTokenOverlay
            }

            // 邮箱登录验证弹窗
            if showEmailAuthSheet {
                emailAuthOverlay
            }
        }
        .frame(width: 660, height: 740)
        .onAppear {
            if let email = authManager.currentEmail {
                inputEmail = email
            }
            startCheckoutFlow()
        }
        .onDisappear {
            stopPolling()
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    // MARK: - 1. 顶部栏
    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.30, green: 0.65, blue: 1.0) : Color(red: 0.0, green: 0.45, blue: 0.90))
                Text("TransBar Pro")
                    .font(.system(size: 13, weight: .bold))
                Text("· 商业许可")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                onDismiss?()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }

    // MARK: - 2. 英雄区
    private var heroSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    )
                    .shadow(color: Color.blue.opacity(0.25), radius: 8, y: 3)

                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("升级 TransBar Pro")
                .font(.system(size: 20, weight: .bold))

            Text("解锁翻译历史无上限存储，畅享 AI Agent 智能词条构建与全场景特权")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 当前状态胶囊
            HStack(spacing: 6) {
                Circle()
                    .fill(licenseManager.isPro ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                if licenseManager.currentTier == .trial {
                    Text("当前处于 7天试用期（剩余 \(licenseManager.trialDaysRemaining) 天）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else if licenseManager.isPro {
                    Text("当前已激活 Pro 会员（\(licenseManager.currentTier.title)）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Text("当前为免费版（历史记录上限 50 条，Agent 功能受限）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())
        }
        .padding(.top, 4)
    }

    // MARK: - 3. 价格方案卡片
    private var plansSection: some View {
        HStack(spacing: 12) {
            ForEach(PaywallPlanItem.standardPlans) { plan in
                let isSelected = (selectedTier == plan.id)
                Button(action: {
                    selectedTier = plan.id
                    startCheckoutFlow()
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(plan.title)
                                .font(.system(size: 13, weight: .bold))

                            Spacer()

                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(plan.isPopular ? Color.orange : Color.blue.opacity(0.2))
                                    .foregroundColor(plan.isPopular ? .white : .blue)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(isPennyTestMode ? "¥0.01" : plan.priceDisplay)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(isSelected ? .accentColor : .primary)

                            Text(isPennyTestMode ? " (真金测试)" : plan.periodNote)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(plan.features, id: \.self) { feat in
                                HStack(alignment: .top, spacing: 5) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                        .padding(.top, 2)

                                    Text(feat)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(height: 195)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.6 : 0.8)
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.12) : Color.clear, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 4. 权益清单
    private var featuresGrid: some View {
        HStack(spacing: 12) {
            featureItem(icon: "clock.arrow.circlepath", title: "无上限历史记录", desc: "打破 50 条上限，永久安全保存全部翻译上下文与记录")
            featureItem(icon: "sparkles", title: "AI Agent 词库提纯", desc: "对话式一键提取行业专业词汇，智能注入翻译前置语境")
            featureItem(icon: "network", title: "本地 Agent 网关", desc: "无缝对接外部 AI 工具，多轮对话上下文精准翻译")
            featureItem(icon: "laptopcomputer.and.iphone", title: "多设备授权", desc: "支持多台 Mac 设备绑定，本地优先，零数据上传")
        }
    }

    private func featureItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 5. 结账区域与沙箱模拟
    private var checkoutSection: some View {
        VStack(spacing: 14) {
            // 支付渠道选择与真金测试切换
            HStack {
                HStack(spacing: 12) {
                    ForEach(PaymentChannel.allCases) { channel in
                        Button(action: {
                            selectedChannel = channel
                            startCheckoutFlow()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: channel.iconName)
                                    .foregroundColor(Color(channel.brandColor))
                                Text(channel.title)
                                    .font(.system(size: 12, weight: selectedChannel == channel ? .bold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedChannel == channel ? Color.primary.opacity(0.06) : Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(selectedChannel == channel ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // 一分钱真金测试开关
                Toggle(isOn: $isPennyTestMode) {
                    Text("1分钱真实测试")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                .onChange(of: isPennyTestMode) { _ in
                    startCheckoutFlow()
                }
            }

            // 二维码收银台主卡片
            HStack(spacing: 24) {
                // 二维码卡片
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 170, height: 170)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )

                    if let img = activeQrImage {
                        Image(nsImage: img)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在生成安全收银台...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 结账状态与沙箱快速通道
                VStack(alignment: .leading, spacing: 8) {
                    if let orderNo = activeOrderNo {
                        HStack {
                            Text("订单号：")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(orderNo)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }

                    Text("请使用手机 \(selectedChannel.title) 扫码完成支付")
                        .font(.system(size: 12, weight: .medium))

                    Text("支付成功后系统将在 1~3 秒内自动签发 Ed25519 离线许可并即时激活。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)

                    Divider().padding(.vertical, 2)

                    // 核心沙箱测试按钮（无需真金白银，极速验证闭环）
                    VStack(alignment: .leading, spacing: 5) {
                        Text("🧪 开发者与测试沙箱通道")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)

                        Button(action: {
                            performSandboxMockComplete()
                        }) {
                            HStack(spacing: 6) {
                                if isSandboxProcessing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("沙箱一键模拟支付（签发真实 License 测试）")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSandboxProcessing || activeOrderNo == nil)

                        Text("无需掏真金白银，直接向云端中台调用 mock-complete，签发 TransBar 官方 Ed25519 验签许可并完成激活。")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Color.primary.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 6. 底部保障与手动兑换
    private var footerSection: some View {
        HStack {
            Button(action: {
                showEmailAuthSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.badge")
                    if let email = authManager.currentEmail {
                        Text("已关联账户: \(email)")
                    } else {
                        Text("登录已有账户同步授权")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: {
                showManualTokenInput = true
            }) {
                Text("手动输入激活码")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - 业务逻辑与网络通信

    private func startCheckoutFlow() {
        stopPolling()
        activeQrImage = nil
        activeOrderNo = nil

        Task {
            let amountInCents = isPennyTestMode ? 1 : (selectedTier == .monthly ? 990 : (selectedTier == .yearly ? 5800 : 9900))
            let body: [String: Any] = [
                "product_id": "transbar",
                "tier": selectedTier.rawValue,
                "channel": selectedChannel.rawValue,
                "amount": amountInCents,
                "email": authManager.currentEmail ?? "anonymous@cduyzh.top",
                "device_uuid": HardwareIdentifier.uuid
            ]

            guard let (data, response) = try? await AuthSessionManager.shared.sendRequest(path: "/api/payment/create-order", method: "POST", body: body),
                  response.statusCode == 200 else {
                return
            }

            struct OrderResponse: Decodable {
                let success: Bool
                let orderNo: String
                let qrCodeText: String
            }

            if let order = try? JSONDecoder().decode(OrderResponse.self, from: data) {
                await MainActor.run {
                    self.activeOrderNo = order.orderNo
                    self.activeQrRawText = order.qrCodeText
                    self.activeQrImage = QRCodeGenerator.generateImage(from: order.qrCodeText)
                    self.startPollingPayment(orderNo: order.orderNo)
                }
            }
        }
    }

    private func startPollingPayment(orderNo: String) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                guard let (data, response) = try? await AuthSessionManager.shared.sendRequest(path: "/api/payment/check-order?order_no=\(orderNo)"),
                      response.statusCode == 200 else {
                    return
                }

                struct CheckResponse: Decodable {
                    let status: String
                    let licenseToken: String?
                }

                if let res = try? JSONDecoder().decode(CheckResponse.self, from: data), res.status == "PAID" {
                    await MainActor.run {
                        self.stopPolling()
                        if let token = res.licenseToken {
                            LicenseManager.shared.activate(tokenString: token)
                            self.onDismiss?()
                        }
                    }
                }
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func performSandboxMockComplete() {
        guard let orderNo = activeOrderNo else { return }
        isSandboxProcessing = true

        Task {
            let body = ["order_no": orderNo]
            guard let (data, response) = try? await AuthSessionManager.shared.sendRequest(path: "/api/payment/mock-complete", method: "POST", body: body),
                  response.statusCode == 200 else {
                await MainActor.run { isSandboxProcessing = false }
                return
            }

            struct MockResponse: Decodable {
                let success: Bool
                let licenseToken: String?
            }

            if let res = try? JSONDecoder().decode(MockResponse.self, from: data), let token = res.licenseToken {
                await MainActor.run {
                    self.isSandboxProcessing = false
                    self.stopPolling()
                    let result = LicenseManager.shared.activate(tokenString: token)
                    switch result {
                    case .success:
                        self.onDismiss?()
                    case .failure(let err):
                        self.manualTokenError = err.localizedDescription
                    }
                }
            } else {
                await MainActor.run { isSandboxProcessing = false }
            }
        }
    }

    // MARK: - 手动输入激活码弹窗
    private var manualTokenOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("手动激活许可证")
                    .font(.system(size: 14, weight: .bold))

                Text("请输入由 cduyzh 官方签发的 TransBar 许可证代码")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                TextEditor(text: $manualToken)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 70)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

                if let err = manualTokenError {
                    Text(err)
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button("取消") {
                        showManualTokenInput = false
                        manualTokenError = nil
                    }
                    .buttonStyle(.plain)

                    Button("激活并验证") {
                        let result = LicenseManager.shared.activate(tokenString: manualToken)
                        switch result {
                        case .success:
                            showManualTokenInput = false
                            manualTokenError = nil
                            onDismiss?()
                        case .failure(let err):
                            manualTokenError = err.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 16)
        }
    }

    // MARK: - 邮箱登录弹窗
    private var emailAuthOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("登录 cduyzh 账户")
                    .font(.system(size: 14, weight: .bold))

                Text("输入邮箱接收 6 位验证码，登录后自动同步 TransBar 许可证")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("your-email@example.com", text: $inputEmail)
                        .textFieldStyle(.roundedBorder)

                    Button(isSendingCode ? "发送中..." : (countdownSeconds > 0 ? "\(countdownSeconds)s" : "获取验证码")) {
                        sendEmailCode()
                    }
                    .disabled(isSendingCode || countdownSeconds > 0 || inputEmail.isEmpty)
                }

                if codeSentSuccess {
                    TextField("6 位数字验证码", text: $inputCode)
                        .textFieldStyle(.roundedBorder)
                        .focused($isCodeFocused)
                }

                if let err = authErrorMessage {
                    Text(err)
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button("取消") {
                        showEmailAuthSheet = false
                        authErrorMessage = nil
                    }
                    .buttonStyle(.plain)

                    Button("验证并登录") {
                        verifyAndLogin()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputCode.count < 4)
                }
            }
            .padding(20)
            .frame(width: 380)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 16)
        }
    }

    private func sendEmailCode() {
        isSendingCode = true
        authErrorMessage = nil
        Task {
            do {
                try await authManager.sendCode(email: inputEmail)
                await MainActor.run {
                    self.isSendingCode = false
                    self.codeSentSuccess = true
                    self.countdownSeconds = 60
                    self.startCountdown()
                }
            } catch {
                await MainActor.run {
                    self.isSendingCode = false
                    self.authErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.countdownSeconds > 0 {
                self.countdownSeconds -= 1
            } else {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
            }
        }
    }

    private func verifyAndLogin() {
        authErrorMessage = nil
        Task {
            do {
                _ = try await authManager.verifyCode(email: inputEmail, code: inputCode)
                await MainActor.run {
                    self.showEmailAuthSheet = false
                    self.onDismiss?()
                }
            } catch {
                await MainActor.run {
                    self.authErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
