import Foundation

public enum Formatting {
    public struct CountdownPart: Equatable {
        public let value: Int
        public let unit: String

        public init(value: Int, unit: String) {
            self.value = value
            self.unit = unit
        }
    }

    public static func money(_ n: Double) -> String {
        let fixed = String(format: "%.2f", abs(n))
        let parts = fixed.split(separator: ".")
        let sign = n < 0 ? "-" : ""
        return "\(sign)¥\(grouped(parts[0])).\(parts[1])"
    }

    static func grouped(_ digits: some StringProtocol) -> String {
        var result = ""
        let chars = Array(digits)
        for (i, c) in chars.enumerated() {
            if i > 0 && (chars.count - i) % 3 == 0 { result.append(",") }
            result.append(c)
        }
        return result
    }

    public static func countdownParts(_ totalSeconds: Int) -> [CountdownPart] {
        let s = max(0, totalSeconds)
        if s >= 3600 {
            return [CountdownPart(value: s / 3600, unit: "时"),
                    CountdownPart(value: (s % 3600) / 60, unit: "分")]
        }
        let m = s > 0 ? max(1, s / 60) : 0
        return [CountdownPart(value: m, unit: "分")]
    }

    public static func formatCountdown(_ totalSeconds: Int) -> String {
        countdownParts(totalSeconds).map { "\($0.value)\($0.unit)" }.joined(separator: " ")
    }

    /// 顶栏日期：「10月9日 · 周五」
    public static func headDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weeks = ["日", "一", "二", "三", "四", "五", "六"]
        return "\(c.month!)月\(c.day!)日 · 周\(weeks[c.weekday! - 1])"
    }

    /// 分钟数 → 「09:00」
    public static func hhmm(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
