/// 自动读取剪贴板并翻译的唯一唤起入口。
enum PanelOpenOrigin: CaseIterable {
    case commandDoubleCopy
    case alternateHotkey
    case statusItem
    case contextMenu
    case applicationReopen

    var automaticallyTranslates: Bool { self == .commandDoubleCopy }
}
