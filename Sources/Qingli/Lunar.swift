import Foundation

enum Lunar {
    private static let cal: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    private static let greg: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    private static let days = [
        "", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
    ]
    private static let months = [
        "", "正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月",
    ]
    static func cell(_ date: Date) -> String {
        let c = cal.dateComponents([.month, .day], from: date)
        let d = c.day ?? 1
        if d == 1 { return monthName(date) }
        return days.indices.contains(d) ? days[d] : ""
    }

    private static let yearFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .chinese)
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "U"
        return f
    }()

    static func full(_ date: Date) -> String {
        let year = yearFmt.string(from: date)
        let prefix = year.hasSuffix("年") ? String(year.dropLast()) : year
        let day = cal.component(.day, from: date)
        let dayName = days.indices.contains(day) ? days[day] : ""
        return "\(prefix)年\(monthName(date))\(dayName)"
    }

    static func folk(_ date: Date) -> String? {
        let next = greg.date(byAdding: .day, value: 1, to: date)!
        let n = cal.dateComponents([.month, .day], from: next)
        if n.month == 1, n.day == 1, n.isLeapMonth != true { return "除夕" }
        let c = cal.dateComponents([.month, .day], from: date)
        guard c.isLeapMonth != true else { return nil }
        switch (c.month ?? 0, c.day ?? 0) {
        case (1, 1): return "春节"
        case (1, 15): return "元宵"
        case (2, 2): return "龙抬头"
        case (5, 5): return "端午"
        case (7, 7): return "七夕"
        case (8, 15): return "中秋"
        case (9, 9): return "重阳"
        case (12, 8): return "腊八"
        case (12, 23): return "小年"
        default: return nil
        }
    }

    private static func monthName(_ date: Date) -> String {
        let c = cal.dateComponents([.month], from: date)
        let name = months[c.month ?? 1]
        return c.isLeapMonth == true ? "闰\(name)" : name
    }
}

enum ChinaCal {
    static var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        c.firstWeekday = 2
        return c
    }

    static func daysInMonth(year: Int, month: Int) -> [Date] {
        let cal = gregorian
        var comps = DateComponents(year: year, month: month, day: 1)
        let start = cal.date(from: comps)!
        let count = cal.range(of: .day, in: .month, for: start)!.count
        let weekday = cal.component(.weekday, from: start)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        comps.day = 1 - leading
        let gridStart = cal.date(from: comps)!
        let cells = max(42, leading + count)
        return (0..<cells).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
}
