import SwiftUI
import AppKit

@main
struct QingliApp: App {
    init() {
        HolidayCheck.run()
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowChrome())
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 920, height: 640)
    }
}

@MainActor
@Observable
final class Board {
    var cursor: Date
    var selected: Date
    var today: Date
    var years: [Int: HolidayYear] = [:]

    init() {
        let cal = ChinaCal.gregorian
        let now = Date()
        let day = cal.startOfDay(for: now)
        today = day
        cursor = day
        selected = day
        if let local = HolidayStore.local(year: cal.component(.year, from: day)) {
            years[cal.component(.year, from: day)] = local
        }
    }

    var year: Int { ChinaCal.gregorian.component(.year, from: cursor) }
    var month: Int { ChinaCal.gregorian.component(.month, from: cursor) }

    func holiday(_ date: Date) -> Holiday? {
        years[ChinaCal.gregorian.component(.year, from: date)]?.days[HolidayStore.key(date)]
    }

    func shiftMonth(_ delta: Int) {
        cursor = ChinaCal.gregorian.date(byAdding: .month, value: delta, to: cursor) ?? cursor
    }

    func jump(year: Int, month: Int) {
        let cal = ChinaCal.gregorian
        let y = min(max(year, 2007), 2035)
        let m = min(max(month, 1), 12)
        let same = y == cal.component(.year, from: today) && m == cal.component(.month, from: today)
        let day = same ? cal.component(.day, from: today) : 1
        guard let d = cal.date(from: DateComponents(year: y, month: m, day: day)) else { return }
        cursor = d
        selected = d
    }

    func goToday() {
        cursor = today
        selected = today
    }

    func tick() {
        let day = ChinaCal.gregorian.startOfDay(for: Date())
        if day != today { today = day }
    }

    func refresh() async {
        for y in [year - 1, year, year + 1] {
            if years[y] == nil, let local = HolidayStore.local(year: y) {
                years[y] = local
            }
        }
        for y in [year - 1, year, year + 1] {
            if let fetched = try? await HolidayStore.fetch(year: y) {
                years[y] = fetched
            }
        }
    }

    func nextOfficial(from date: Date) -> (Date, Holiday)? {
        let cal = ChinaCal.gregorian
        let start = cal.startOfDay(for: date)
        for i in 0..<400 {
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { continue }
            if let h = holiday(d), h.isOffDay { return (d, h) }
        }
        return nil
    }
}

private enum Palette {
    static let cinnabar = Color(red: 0.74, green: 0.20, blue: 0.16)
    static let work = Color(red: 0.28, green: 0.38, blue: 0.48)
}

struct ContentView: View {
    @State private var board = Board()
    @State private var showJump = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            monthPane
            Divider().overlay(Color.primary.opacity(0.08))
            detailPane.frame(width: 268)
        }
        .frame(width: 920, height: 640)
        .background(paper)
        .task(id: board.year) { await board.refresh() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            board.tick()
        }
    }

    private var paper: Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.10, blue: 0.09)
            : Color(red: 0.98, green: 0.96, blue: 0.92)
    }

    private var monthPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            weekdayRow
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(ChinaCal.daysInMonth(year: board.year, month: board.month), id: \.self) { date in
                    DayCell(date: date, board: board)
                }
            }
            Spacer(minLength: 0)
            legend
        }
        .padding(28)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button { showJump.toggle() } label: {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "\(board.year)年")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(verbatim: "\(board.month)")
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                            Text("月")
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showJump, arrowEdge: .bottom) {
                JumpPicker(board: board, isPresented: $showJump)
            }
            .accessibilityLabel("选择年月")
            Spacer()
            HStack(spacing: 8) {
                IconButton(symbol: "chevron.left") { board.shiftMonth(-1) }
                Button("今天") { board.goToday() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.cinnabar.opacity(board.month == ChinaCal.gregorian.component(.month, from: board.today) && board.year == ChinaCal.gregorian.component(.year, from: board.today) ? 1 : 0.12), in: Capsule())
                    .foregroundStyle(
                        board.month == ChinaCal.gregorian.component(.month, from: board.today)
                            && board.year == ChinaCal.gregorian.component(.year, from: board.today)
                            ? Color.white : Palette.cinnabar
                    )
                IconButton(symbol: "chevron.right") { board.shiftMonth(1) }
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                Text(w)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(w == "日" || w == "六" ? Palette.cinnabar.opacity(0.85) : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            LabelChip("休", color: Palette.cinnabar, text: "法定放假")
            LabelChip("班", color: Palette.work, text: "调休上班")
            Spacer()
            Text("国务院安排 · 启动时更新")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var detailPane: some View {
        let cal = ChinaCal.gregorian
        let date = board.selected
        let holiday = board.holiday(date)
        let folk = Lunar.folk(date)
        let weekday = cal.component(.weekday, from: date)
        let weekNames = ["", "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(weekNames[weekday])
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(cal.component(.month, from: date))月\(cal.component(.day, from: date))日")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                Text("农历\(Lunar.full(date))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            statusCard(holiday: holiday, folk: folk, date: date)

            if let next = board.nextOfficial(from: cal.date(byAdding: .day, value: 1, to: date) ?? date) {
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: next.0).day ?? 0
                Text("距\(next.1.name)还有 \(days) 天")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.cinnabar)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("本月安排")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                if monthMarks.isEmpty {
                    Text("本月暂无法定放假或调休")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(monthMarks, id: \.0) { item in
                        HStack {
                            Text("\(cal.component(.day, from: item.0))日")
                                .font(.system(size: 13, design: .monospaced))
                                .frame(width: 36, alignment: .leading)
                            Text(item.1.name)
                                .font(.system(size: 13, design: .rounded))
                            Spacer()
                            Text(item.1.isOffDay ? "休" : "班")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(item.1.isOffDay ? Palette.cinnabar : Palette.work)
                        }
                        .foregroundStyle(cal.isDate(item.0, inSameDayAs: date) ? .primary : .secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(28)
        .background(
            scheme == .dark
                ? Color.white.opacity(0.03)
                : Color(red: 0.95, green: 0.91, blue: 0.85).opacity(0.55)
        )
    }

    private var monthMarks: [(Date, Holiday)] {
        let cal = ChinaCal.gregorian
        return ChinaCal.daysInMonth(year: board.year, month: board.month).compactMap { date in
            guard cal.component(.month, from: date) == board.month, let h = board.holiday(date) else { return nil }
            return (date, h)
        }
    }

    @ViewBuilder
    private func statusCard(holiday: Holiday?, folk: String?, date: Date) -> some View {
        let cal = ChinaCal.gregorian
        let weekend = [1, 7].contains(cal.component(.weekday, from: date))
        let (title, subtitle, tint): (String, String, Color) = {
            if let holiday, holiday.isOffDay {
                return ("放假", holiday.name, Palette.cinnabar)
            }
            if let holiday, !holiday.isOffDay {
                return ("调休上班", holiday.name, Palette.work)
            }
            if weekend {
                return ("周末", folk ?? "休息", Palette.cinnabar.opacity(0.8))
            }
            return ("工作日", folk ?? " ", Palette.work.opacity(0.7))
        }()

        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
            if !subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DayCell: View {
    let date: Date
    @Bindable var board: Board
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let cal = ChinaCal.gregorian
        let inMonth = cal.component(.month, from: date) == board.month
        let holiday = board.holiday(date)
        let selected = cal.isDate(date, inSameDayAs: board.selected)
        let today = cal.isDate(date, inSameDayAs: board.today)
        let weekend = [1, 7].contains(cal.component(.weekday, from: date))
        let numberColor: Color = {
            if holiday?.isOffDay == true || (weekend && holiday?.isOffDay != false) { return Palette.cinnabar }
            if holiday?.isOffDay == false { return Palette.work }
            return .primary
        }()

        Button {
            board.selected = date
            if !inMonth {
                board.cursor = date
            }
        } label: {
            VStack(spacing: 2) {
                HStack {
                    Spacer(minLength: 0)
                    if let holiday {
                        Text(holiday.isOffDay ? "休" : "班")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(holiday.isOffDay ? Palette.cinnabar : Palette.work)
                    } else {
                        Text(" ").font(.system(size: 9))
                    }
                }
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 18, weight: today ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(today && !selected ? Color.white : numberColor)
                    .frame(width: 32, height: 32)
                    .background {
                        if today && !selected {
                            Circle().fill(Palette.cinnabar)
                        } else if selected {
                            Circle().stroke(Palette.cinnabar, lineWidth: 1.4)
                        }
                    }
                Text(Lunar.cell(date))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                selected
                    ? Palette.cinnabar.opacity(scheme == .dark ? 0.14 : 0.08)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(inMonth ? 1 : 0.32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessLabel(holiday: holiday, cal: cal))
    }

    private func accessLabel(holiday: Holiday?, cal: Calendar) -> String {
        var s = "\(cal.component(.month, from: date))月\(cal.component(.day, from: date))日 \(Lunar.full(date))"
        if let holiday {
            s += holiday.isOffDay ? " \(holiday.name)放假" : " \(holiday.name)调休上班"
        }
        return s
    }
}

private struct JumpPicker: View {
    @Bindable var board: Board
    @Binding var isPresented: Bool
    private static let years = Array(2007...2035)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconButton(symbol: "chevron.left") { board.jump(year: board.year - 1, month: board.month) }
                Picker("年份", selection: yearBind) {
                    ForEach(Self.years, id: \.self) { y in
                        Text(verbatim: "\(y)年").tag(String(y))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                IconButton(symbol: "chevron.right") { board.jump(year: board.year + 1, month: board.month) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    Button {
                        board.jump(year: board.year, month: m)
                        isPresented = false
                    } label: {
                        Text(verbatim: "\(m)月")
                            .font(.system(size: 13, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .foregroundStyle(m == board.month ? Color.white : .primary)
                            .background(
                                m == board.month ? Palette.cinnabar : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 268)
    }

    private var yearBind: Binding<String> {
        Binding(
            get: { String(board.year) },
            set: { board.jump(year: Int($0) ?? board.year, month: board.month) }
        )
    }
}

private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct IconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct LabelChip: View {
    let symbol: String
    let color: Color
    let text: String

    init(_ symbol: String, color: Color, text: String) {
        self.symbol = symbol
        self.color = color
        self.text = text
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
