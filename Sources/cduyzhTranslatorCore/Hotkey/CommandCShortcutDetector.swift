import Foundation

/// 识别按住 Command 时连续两次按下 C 的时序状态机。
/// 只消费按键时间，真正触发翻译仍在快捷键管理器中完成，便于稳定单元测试。
struct CommandCShortcutDetector {
    let interval: TimeInterval
    private(set) var lastPressTime: TimeInterval?

    init(interval: TimeInterval = 0.45) {
        self.interval = interval
    }

    /// 返回 true 表示本次按键完成了双击；触发器随即清空，等待下一组按键。
    mutating func registerPress(at time: TimeInterval, isRepeat: Bool = false) -> Bool {
        guard !isRepeat else { return false }

        guard let previous = lastPressTime else {
            lastPressTime = time
            return false
        }

        let elapsed = time - previous
        if elapsed >= 0, elapsed <= interval {
            lastPressTime = nil
            return true
        }

        // 超时后的按键作为下一次双击的起点。
        lastPressTime = time
        return false
    }

    mutating func reset() {
        lastPressTime = nil
    }
}
