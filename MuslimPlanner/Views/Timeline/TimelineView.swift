import SwiftUI
import SwiftData

// MARK: - Layout constants
private let kHourHeight: CGFloat = 64
private let kRulerWidth: CGFloat = 48
private let kTaskInset: CGFloat  = 4

struct TimelineView: View {
    @ObservedObject var viewModel: DayPlanViewModel
    let settings: AppSettings

    @Query private var allTasks: [PlanTask]
    @Environment(\.modelContext) private var ctx

    @State private var showEditor = false
    @State private var editingTask: PlanTask?
    @State private var preselectedBlock = ""

    // MARK: Derived data

    private var dayStart: Date {
        Calendar.current.startOfDay(for: viewModel.selectedDate)
    }

    private var dayTasks: [PlanTask] {
        allTasks.filter { Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
    }

    private var timedTasks: [PlanTask]   { dayTasks.filter { $0.startTime != nil } }
    private var untimedTasks: [PlanTask] { dayTasks.filter { $0.startTime == nil } }

    private func untimedInBlock(_ blockName: String) -> [PlanTask] {
        untimedTasks.filter { $0.prayerBlock == blockName }
    }

    private func yFor(_ date: Date) -> CGFloat {
        let seconds = date.timeIntervalSince(dayStart)
        return max(0, CGFloat(seconds / 3600) * kHourHeight)
    }

    private var canvasHeight: CGFloat {
        var base: CGFloat = 24 * kHourHeight
        for prayer in viewModel.prayerTimes {
            let taskCount = CGFloat(untimedInBlock(prayer.blockName).count)
            let bottom = yFor(prayer.time) + 44 + taskCount * 48
            base = max(base, bottom + 80)
        }
        return base
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                Divider()

                if let err = viewModel.prayerError {
                    errorBanner(err)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            hourGrid
                            currentTimeLine
                            prayerLayer
                            timedTaskLayer
                            Color.clear.frame(width: 1, height: canvasHeight)
                        }
                        .frame(maxWidth: .infinity, minHeight: canvasHeight)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            proxy.scrollTo("now", anchor: .center)
                        }
                    }
                    .onChange(of: viewModel.selectedDate) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            proxy.scrollTo("now", anchor: .center)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditor) {
            TaskEditorSheet(
                task: editingTask,
                date: viewModel.selectedDate,
                prayerBlock: preselectedBlock,
                prayerTimes: viewModel.prayerTimes
            )
            .onDisappear { editingTask = nil }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
    }

    // MARK: - Hour grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 25, id: \.self) { hour in
                HStack(spacing: 6) {
                    Text(hourLabel(hour % 24))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: kRulerWidth - 6, alignment: .trailing)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                }
                .frame(height: hour < 24 ? kHourHeight : 0, alignment: .top)
            }
        }
    }

    // MARK: - Current time line

    @ViewBuilder
    private var currentTimeLine: some View {
        if Calendar.current.isDateInToday(viewModel.selectedDate) {
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: kRulerWidth - 4)
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1.5)
            }
            .offset(y: yFor(Date()))
            .id("now")
        }
    }

    // MARK: - Prayer layer

    private var prayerLayer: some View {
        ForEach(viewModel.prayerTimes) { prayer in
            VStack(alignment: .leading, spacing: 0) {
                PrayerAnchorRow(prayer: prayer) {
                    preselectedBlock = prayer.blockName
                    editingTask = nil
                    showEditor = true
                }
                ForEach(untimedInBlock(prayer.blockName)) { task in
                    UntimedTaskRow(task: task) {
                        editingTask = task
                        preselectedBlock = task.prayerBlock
                        showEditor = true
                    }
                }
            }
            .padding(.leading, kRulerWidth + kTaskInset)
            .offset(y: yFor(prayer.time))
        }
    }

    // MARK: - Timed task layer

    private var timedTaskLayer: some View {
        ForEach(timedTasks) { task in
            TimedTaskCard(task: task) {
                editingTask = task
                preselectedBlock = task.prayerBlock
                showEditor = true
            }
            .frame(width: 200, height: taskHeight(task))
            .offset(x: kRulerWidth + kTaskInset, y: yFor(task.startTime!))
        }
    }

    private func taskHeight(_ task: PlanTask) -> CGFloat {
        let mins = CGFloat(task.durationMinutes ?? 30)
        return max(40, mins / 60 * kHourHeight)
    }

    // MARK: - Date header

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(8)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.headline)
                if let countdown = viewModel.countdownText() {
                    Text(countdown)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.locationService.cityName.isEmpty {
                    Text(viewModel.locationService.cityName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Add FAB

    private var addButton: some View {
        Button {
            preselectedBlock = viewModel.prayerBlock(containing: Date())
            editingTask = nil
            showEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.green))
                .shadow(radius: 4, y: 2)
        }
        .padding(24)
    }

    // MARK: - Error banner

    private func errorBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(msg)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Helpers

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0:  return "12 AM"
        case 12: return "12 PM"
        default: return h < 12 ? "\(h) AM" : "\(h - 12) PM"
        }
    }
}

// MARK: - Untimed task row

struct UntimedTaskRow: View {
    @Bindable var task: PlanTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Button {
                    task.isCompleted.toggle()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                if let cat = task.category {
                    Label(cat.name, systemImage: cat.symbolName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: cat.colorHex).opacity(0.15))
                        .foregroundStyle(Color(hex: cat.colorHex))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timed task card

struct TimedTaskCard: View {
    @Bindable var task: PlanTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.caption.bold())
                        .lineLimit(2)
                    if let start = task.startTime {
                        Text(start.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(accentColor.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        Color(hex: task.category?.colorHex ?? "007AFF")
    }
}
