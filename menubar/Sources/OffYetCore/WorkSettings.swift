import Foundation

public struct WorkSettings: Codable, Equatable {
    /// 「每月最后一个工作日」哨兵值；工作日口径 = 只跳过周六日（与网页版一致，不含法定节假日）
    public static let payDayLastWorkday = 0

    public var startMin: Int
    public var endMin: Int
    public var monthlySalary: Double
    public var workDaysPerMonth: Double
    public var payDay: Int
    public var retirementDate: String

    public init(startMin: Int = 540, endMin: Int = 1080,
                monthlySalary: Double = 20000, workDaysPerMonth: Double = 21.75,
                payDay: Int = 20, retirementDate: String = "2050-01-01") {
        self.startMin = startMin
        self.endMin = endMin
        self.monthlySalary = monthlySalary
        self.workDaysPerMonth = workDaysPerMonth
        self.payDay = payDay
        self.retirementDate = retirementDate
    }

    public static let standard = WorkSettings()

    public var isValid: Bool {
        // NaN 参与 > 比较恒为 false，天然覆盖非法输入；.infinity 能通过 > 0，
        // 需 isFinite 显式守卫（对齐 web engine.js 的 Number.isFinite），否则 money 渲染越界
        endMin > startMin && monthlySalary > 0 && monthlySalary.isFinite
            && workDaysPerMonth > 0 && workDaysPerMonth.isFinite
    }
}
