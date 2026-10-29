import AppKit
import ApplicationServices

/// Reads a selection through Accessibility and offers a button without modifying the pasteboard.
/// The only translation callback is the user's explicit click on that button.
@MainActor
public final class SelectionTranslationManager {
    public static let shared = SelectionTranslationManager()

    public var onTranslateSelection: ((String) -> Void)?
    public private(set) var isMonitoring = false

    private var isStarted = false
    private var enabled = true
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var terminationObserver: NSObjectProtocol?
    private var selectionTask: Task<Void, Never>?
    private var dismissalTask: Task<Void, Never>?
    private var panel: SelectionTranslationPanel?
    private var selection: SelectionSnapshot?
    private var mouseDownPoint: NSPoint?
    private var mouseDownPID: pid_t?
    private var didDrag = false

    private init() {}

    /// Start once during application startup; this never requests Accessibility permission.
    public func start() {
        isStarted = true
        installMonitorsIfNeeded()
    }

    /// Reapply after changing the setting or returning from macOS Accessibility settings.
    public func updateEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled {
            installMonitorsIfNeeded()
        } else {
            removeMonitors()
        }
    }

    /// Remove only the event monitors, observers and panel owned by this manager.
    public func stop() {
        isStarted = false
        removeMonitors()
    }

    /// Used by the explicit “翻译选中文字” menu item. No clipboard fallback is performed.
    public static func currentSelection() -> String? {
        SelectionAccessibilityReader.read()?.text
    }

    private func installMonitorsIfNeeded() {
        guard isStarted, enabled, !isMonitoring, AXIsProcessTrusted() else { return }
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseDragged, .leftMouseUp,
            .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleGlobalEvent(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleLocalEvent(event) }
            return event
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.dismiss() }
            })
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // AppKit posts termination notifications on the main thread. Synchronous cleanup
            // avoids leaving the panel alive while an asynchronous task is waiting to run.
            MainActor.assumeIsolated { self?.stop() }
        }
        isMonitoring = globalMonitor != nil
        if !isMonitoring { removeMonitors() }
    }

    private func removeMonitors() {
        dismiss()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        terminationObserver = nil
        panel?.close()
        panel = nil
        isMonitoring = false
    }

    private func handleLocalEvent(_ event: NSEvent) {
        guard isStarted, enabled else { return }
        // The nonactivating button must retain its selection until its mouse-up action.
        if event.window === panel, event.type != .scrollWheel, event.type != .keyDown { return }
        dismiss()
    }

    private func handleGlobalEvent(_ event: NSEvent) {
        guard isStarted, enabled else { return }
        switch event.type {
        case .leftMouseDown:
            dismiss()
            guard let source = NSWorkspace.shared.frontmostApplication,
                  source.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            mouseDownPoint = NSEvent.mouseLocation
            mouseDownPID = source.processIdentifier
        case .leftMouseDragged:
            guard let mouseDownPoint else { return }
            let location = NSEvent.mouseLocation
            if hypot(location.x - mouseDownPoint.x, location.y - mouseDownPoint.y) >= 3 { didDrag = true }
        case .leftMouseUp:
            guard let sourcePID = mouseDownPID,
                  SelectionTranslationPolicy.shouldOffer(didDrag: didDrag, clickCount: event.clickCount) else {
                resetGesture()
                return
            }
            let anchor = NSEvent.mouseLocation
            resetGesture()
            selectionTask?.cancel()
            selectionTask = Task { @MainActor [weak self] in
                // AppKit and Chromium commit the final selection after dispatching mouse-up.
                do { try await Task.sleep(nanoseconds: 70_000_000) } catch { return }
                guard let self, !Task.isCancelled, self.isStarted, self.enabled,
                      let snapshot = SelectionAccessibilityReader.read(expectedPID: sourcePID) else { return }
                self.show(snapshot, near: anchor)
            }
        case .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown:
            dismiss()
        default:
            break
        }
    }

    private func show(_ snapshot: SelectionSnapshot, near anchor: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else { return }
        selection = snapshot
        let floatingPanel: SelectionTranslationPanel
        if let panel {
            floatingPanel = panel
        } else {
            floatingPanel = SelectionTranslationPanel(
                translate: { [weak self] in self?.translateSelection() },
                close: { [weak self] in self?.dismiss() }
            )
            panel = floatingPanel
        }
        let origin = SelectionTranslationPolicy.panelOrigin(
            anchor: anchor, panelSize: floatingPanel.frame.size, visibleFrame: screen.visibleFrame
        )
        floatingPanel.setFrameOrigin(origin)
        floatingPanel.orderFrontRegardless()
        dismissalTask?.cancel()
        dismissalTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
            self?.dismiss()
        }
    }

    private func translateSelection() {
        guard let snapshot = selection,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.processIdentifier else {
            dismiss()
            return
        }
        // Recheck the selection so a stale or secure field can never send captured text.
        guard let current = SelectionAccessibilityReader.read(expectedPID: snapshot.processIdentifier),
              current.text == snapshot.text else {
            dismiss()
            return
        }
        let text = snapshot.text
        dismiss()
        onTranslateSelection?(text)
    }

    private func dismiss() {
        selectionTask?.cancel()
        selectionTask = nil
        dismissalTask?.cancel()
        dismissalTask = nil
        selection = nil
        panel?.orderOut(nil)
        resetGesture()
    }

    private func resetGesture() {
        mouseDownPoint = nil
        mouseDownPID = nil
        didDrag = false
    }
}

private struct SelectionSnapshot {
    let text: String
    let processIdentifier: pid_t
}

@MainActor
private enum SelectionAccessibilityReader {
    static func read(expectedPID: pid_t? = nil) -> SelectionSnapshot? {
        guard AXIsProcessTrusted(),
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              expectedPID == nil || expectedPID == application.processIdentifier else { return nil }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        // Limit the cost of an application whose Accessibility service is unresponsive.
        AXUIElementSetMessagingTimeout(appElement, 0.12)
        guard let focused = elementAttribute(appElement, kAXFocusedUIElementAttribute) else { return nil }
        AXUIElementSetMessagingTimeout(focused, 0.12)
        guard !isProtected(focused) else { return nil }
        if let rangeValue = attribute(focused, kAXSelectedTextRangeAttribute),
           CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            let value = unsafeBitCast(rangeValue, to: AXValue.self)
            if AXValueGetType(value) == .cfRange {
                var range = CFRange()
                if AXValueGetValue(value, .cfRange, &range),
                   (range.location == kCFNotFound || range.length <= 0 ||
                    range.length > SelectionTranslationPolicy.maximumSelectionLength) { return nil }
            }
        }
        guard let rawText = attribute(focused, kAXSelectedTextAttribute) as? String,
              let text = SelectionTranslationPolicy.normalizedSelection(rawText) else { return nil }
        return SelectionSnapshot(text: text, processIdentifier: application.processIdentifier)
    }

    private static func isProtected(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let candidate = current else { break }
            if attribute(candidate, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole as String { return true }
            if attribute(candidate, "AXProtectedContent") as? Bool == true { return true }
            if (attribute(candidate, "AXDOMInputType") as? String)?.lowercased() == "password" { return true }
            current = elementAttribute(candidate, kAXParentAttribute)
        }
        return false
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
}

/// Pure selection/placement rules, shared with focused regression tests.
enum SelectionTranslationPolicy {
    static let maximumSelectionLength = 10_000

    static func shouldOffer(didDrag: Bool, clickCount: Int) -> Bool {
        didDrag || clickCount >= 2
    }

    static func normalizedSelection(_ text: String) -> String? {
        guard text.utf16.count <= maximumSelectionLength else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !cleaned.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\r" && $0 != "\t" }) else { return nil }
        return cleaned
    }

    static func panelOrigin(anchor: NSPoint, panelSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let inset: CGFloat = 8
        let minX = visibleFrame.minX + inset
        let minY = visibleFrame.minY + inset
        let maxX = max(minX, visibleFrame.maxX - panelSize.width - inset)
        let maxY = max(minY, visibleFrame.maxY - panelSize.height - inset)
        let below = anchor.y - panelSize.height - 12
        let desiredY = below >= minY ? below : anchor.y + 12
        return NSPoint(x: min(max(anchor.x + 10, minX), maxX), y: min(max(desiredY, minY), maxY))
    }
}

@MainActor
private final class SelectionTranslationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(translate: @escaping () -> Void, close: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 114, height: 34),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .utilityWindow
        contentView = SelectionTranslationButtonView(translate: translate, close: close)
        setAccessibilityLabel("划词翻译")
    }
}

@MainActor
private final class SelectionTranslationButtonView: NSVisualEffectView {
    private let translateAction: () -> Void
    private let closeAction: () -> Void

    init(translate: @escaping () -> Void, close: @escaping () -> Void) {
        translateAction = translate
        closeAction = close
        super.init(frame: NSRect(x: 0, y: 0, width: 114, height: 34))
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor

        let translateButton = SelectionActionButton(title: "翻译", target: self, action: #selector(translatePressed))
        translateButton.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: nil)
        translateButton.imagePosition = .imageLeading
        translateButton.imageScaling = .scaleProportionallyDown
        translateButton.font = .systemFont(ofSize: 13, weight: .medium)
        translateButton.contentTintColor = .labelColor
        translateButton.toolTip = "翻译选中的文字"
        translateButton.setAccessibilityLabel("翻译选中的文字")
        addSubview(translateButton)

        let closeButton = SelectionActionButton(title: "", target: self, action: #selector(closePressed))
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭")
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.toolTip = "关闭划词翻译"
        closeButton.setAccessibilityLabel("关闭划词翻译")
        addSubview(closeButton)

        translateButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            translateButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            translateButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            translateButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            translateButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func translatePressed() { translateAction() }
    @objc private func closePressed() { closeAction() }
}

@MainActor
private final class SelectionActionButton: NSButton {
    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .inline
        focusRingType = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
