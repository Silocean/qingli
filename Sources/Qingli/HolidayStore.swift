import Foundation

public struct Holiday: Equatable, Sendable {
    public var name: String
    public var isOffDay: Bool
}

public struct HolidayYear: Equatable, Sendable {
    public var year: Int
    public var days: [String: Holiday]
}

public enum HolidayStore {
    private static let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = shanghai
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func key(_ date: Date) -> String {
        iso.string(from: date)
    }

    public static func parse(_ data: Data) throws -> HolidayYear {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        var days: [String: Holiday] = [:]
        days.reserveCapacity(payload.days.count)
        for item in payload.days {
            days[item.date] = Holiday(name: item.name, isOffDay: item.isOffDay)
        }
        return HolidayYear(year: payload.year, days: days)
    }

    public static func local(year: Int) -> HolidayYear? {
        if let cached = cached(year) { return cached }
        if year == 2026, let data = fallback2026.data(using: .utf8) {
            return try? parse(data)
        }
        return nil
    }

    public static func fetch(year: Int) async throws -> HolidayYear {
        let urls = [
            URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!,
            URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!,
        ]
        var last: Error = URLError(.badURL)
        for url in urls {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 { continue }
                let parsed = try parse(data)
                cache(year, data)
                return parsed
            } catch {
                last = error
            }
        }
        if let cached = cached(year) { return cached }
        if year == 2026, let data = fallback2026.data(using: .utf8) {
            return try parse(data)
        }
        throw last
    }

    private static func cacheDir() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Qingli", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func cache(_ year: Int, _ data: Data) {
        try? data.write(to: cacheDir().appendingPathComponent("\(year).json"), options: .atomic)
    }

    private static func cached(_ year: Int) -> HolidayYear? {
        let url = cacheDir().appendingPathComponent("\(year).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? parse(data)
    }
}

enum HolidayCheck {
    static func run() {
        let data = Data(#"{"year":2026,"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true},{"name":"元旦","date":"2026-01-04","isOffDay":false}]}"#.utf8)
        let y = try! HolidayStore.parse(data)
        precondition(y.days["2026-01-01"]?.isOffDay == true)
        precondition(y.days["2026-01-04"]?.isOffDay == false)
        let cal = ChinaCal.gregorian
        let chuxi = cal.date(from: DateComponents(year: 2026, month: 2, day: 16))!
        precondition(Lunar.folk(chuxi) == "除夕")
        let chunjie = cal.date(from: DateComponents(year: 2026, month: 2, day: 17))!
        precondition(Lunar.folk(chunjie) == "春节")
        precondition(Lunar.cell(chunjie) == "正月")
        let grid = ChinaCal.daysInMonth(year: 2026, month: 9)
        precondition(cal.component(.weekday, from: grid[0]) == 2)
    }
}

private struct Payload: Decodable {
    var year: Int
    var days: [Item]
    struct Item: Decodable {
        var name: String
        var date: String
        var isOffDay: Bool
    }
}

// ponytail: 仅内置当年国务院安排；跨年以网络为准，源挂了才回落到缓存。
private let fallback2026 = #"{"year":2026,"days":[{"name":"元旦","date":"2026-01-01","isOffDay":true},{"name":"元旦","date":"2026-01-02","isOffDay":true},{"name":"元旦","date":"2026-01-03","isOffDay":true},{"name":"元旦","date":"2026-01-04","isOffDay":false},{"name":"春节","date":"2026-02-14","isOffDay":false},{"name":"春节","date":"2026-02-15","isOffDay":true},{"name":"春节","date":"2026-02-16","isOffDay":true},{"name":"春节","date":"2026-02-17","isOffDay":true},{"name":"春节","date":"2026-02-18","isOffDay":true},{"name":"春节","date":"2026-02-19","isOffDay":true},{"name":"春节","date":"2026-02-20","isOffDay":true},{"name":"春节","date":"2026-02-21","isOffDay":true},{"name":"春节","date":"2026-02-22","isOffDay":true},{"name":"春节","date":"2026-02-23","isOffDay":true},{"name":"春节","date":"2026-02-28","isOffDay":false},{"name":"清明节","date":"2026-04-04","isOffDay":true},{"name":"清明节","date":"2026-04-05","isOffDay":true},{"name":"清明节","date":"2026-04-06","isOffDay":true},{"name":"劳动节","date":"2026-05-01","isOffDay":true},{"name":"劳动节","date":"2026-05-02","isOffDay":true},{"name":"劳动节","date":"2026-05-03","isOffDay":true},{"name":"劳动节","date":"2026-05-04","isOffDay":true},{"name":"劳动节","date":"2026-05-05","isOffDay":true},{"name":"劳动节","date":"2026-05-09","isOffDay":false},{"name":"端午节","date":"2026-06-19","isOffDay":true},{"name":"端午节","date":"2026-06-20","isOffDay":true},{"name":"端午节","date":"2026-06-21","isOffDay":true},{"name":"国庆节","date":"2026-09-20","isOffDay":false},{"name":"中秋节","date":"2026-09-25","isOffDay":true},{"name":"中秋节","date":"2026-09-26","isOffDay":true},{"name":"中秋节","date":"2026-09-27","isOffDay":true},{"name":"国庆节","date":"2026-10-01","isOffDay":true},{"name":"国庆节","date":"2026-10-02","isOffDay":true},{"name":"国庆节","date":"2026-10-03","isOffDay":true},{"name":"国庆节","date":"2026-10-04","isOffDay":true},{"name":"国庆节","date":"2026-10-05","isOffDay":true},{"name":"国庆节","date":"2026-10-06","isOffDay":true},{"name":"国庆节","date":"2026-10-07","isOffDay":true},{"name":"国庆节","date":"2026-10-10","isOffDay":false}]}"#
