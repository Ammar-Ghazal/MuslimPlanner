import SwiftUI
import SwiftData

// MARK: - Layout constants
private let kHourHeight: CGFloat = 64
private let kRulerWidth: CGFloat = 48
private let kTaskInset: CGFloat  = 4
private let kRightPad: CGFloat   = 16

struct TimelineView: View {
    @ObservedObject var viewModel: DayPlanViewModel
    let settings: AppSettings

    @Query private var allTasks: [PlanTask]
    @Environment(\.modelContext) private var ctx

    @State private var showEditor  = false
    @State private var editingTask: PlanTask?

    // Drag state — only one task dragged at a time
    @State private var draggingID: PersistentIdentifier? = nil
    @State private var dragOffset: CGFloat = 0

    // MARK: - Derived

    private var dayStart: Date {
        Calendar.current.startOfDay(for: viewModel.selectedDate)
    }

    private var dayTasks: [PlanTask] {
        allTasks.filter { Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
    }

    private var timedTasks: [PlanTask] {
        dayTasks.filter { $0.startTime != nil }
    }

    private func yFor(_ date: Date) -> CGFloat {
        let seconds = date.timeIntervalSince(dayStart)
        return max(0, CGFloat(seconds / 3600) * kHourHeight)
    }

    private func taskHeight(_ task: PlanTask) -> CGFloat {
        let mins = CGFloat(task.durationMinutes ?? 30)
        return max(40, mins / 60 * kHourHeight)
    }

    private var canvasHeight: CGFloat {
        let bottom = timedTasks.compactMap { t -> CGFloat? in
            guard let s = t.startTime else { return nil }
            return yFor(s) + taskHeight(t)
        }.max() ?? 0
        return max(24 * kHourHeight, bottom + 120)
    }

    // MARK: - Body

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
                            // GeometryReader lets task cards stretch to full available width
                            GeometryReader { geo in
                                let taskW = geo.size.width - kRulerWidth - kTaskInset - kRightPad
                                ForEach(timedTasks) { task in
                                    taskCard(task, width: taskW)
                                }
                            }
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
            ForEach(0..<25, id: \.self) { hour in
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

    // MARK: - Prayer layer (fixed markers, no tasks)

    private var prayerLayer: some View {
        ForEach(viewModel.prayerTimes) { prayer in
            PrayerAnchorRow(prayer: prayer)
                .padding(.leading, kRulerWidth + kTaskInset)
                .padding(.trailing, kRightPad)
                .offset(y: yFor(prayer.time) - 9)
        }
    }

    // MARK: - Task cards with drag

    @ViewBuilder
    private func taskCard(_ task: PlanTask, width: CGFloat) -> some View {
        let isDragging = draggingID == task.persistentModelID
        let yBase = yFor(task.startTime!)
        let yPos  = yBase + (isDragging ? dragOffset : 0)

        TimedTaskCard(task: task) {
            editingTask = task
            showEditor  = true
        }
        .frame(width: max(60, width), height: taskHeight(task))
        .offset(x: kRulerWidth + kTaskInset, y: yPos)
        .zIndex(isDragging ? 1 : 0)
        .shadow(
            color: .black.opacity(isDragging ? 0.18 : 0),
            radius: isDragging ? 10 : 0,
            y: isDragging ? 4 : 0
        )
        .scaleEffect(isDragging ? 1.02 : 1.0, anchor: .center)
        .animation(.interactiveSpring(response: 0.25), value: isDragging)
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { val in
                    draggingID  = task.persistentModelID
                    dragOffset  = val.translation.height
                }
                .onEnded { val in
                    commitDrag(task: task, pixelOffset: val.translation.height)
                    draggingID  = nil
                    dragOffset  = 0
                }
        )
    }

    private func commitDrag(task: PlanTask, pixelOffset: CGFloat) {
        let secondsPerPixel = 3600.0 / Double(kHourHeight)
        let delta = (Double(pixelOffset) * secondsPerPixel / 300).rounded() * 300
        guard let current = task.startTime else { return }
        var newStart = current.addingTimeInterval(delta)
        let start = dayStart
        let end   = start.addingTimeInterval(86399)
        newStart = min(max(newStart, start), end)
        task.startTime   = newStart
        task.prayerBlock = viewModel.prayerBlock(containing: newStart)
    }

    // MARK: - Date header

    private var dateHeader: some View {
        HStack {
            Button {
                viewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: -1, to: viewModel.selectedDate)!
            } label: {
                Image(systemName: "chevron.left").font(.title3).padding(8)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.headline)
                if let countdown = viewModel.countdownText() {
                    Text(countdown).font(.caption).foregroundStyle(.secondary)
                }
                if !viewModel.locationService.cityName.isEmpty {
                    Text(viewModel.locationService.cityName)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                viewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: 1, to: viewModel.selectedDate)!
            } label: {
                Image(systemName: "chevron.right").font(.title3).padding(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - FAB

    private var addButton: some View {
        Button {
            editingTask = nil
            showEditor  = true
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
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.caption)
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

// MARK: - Task card view

struct TimedTaskCard: View {
    @Bindable var task: PlanTask
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let start = task.startTime {
                    let dur    = Double((task.durationMinutes ?? 30) * 60)
                    let end    = start.addingTimeInterval(dur)
                    Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let cat = task.category {
                    Label(cat.name, systemImage: cat.symbolName)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: cat.colorHex).opacity(0.15))
                        .foregroundStyle(Color(hex: cat.colorHex))
                        .clipShape(Capsule())
                }
            }
            .padding(6)

            Spacer(minLength: 0)

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 6)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accentColor.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var accentColor: Color {
        Color(hex: task.category?.colorHex ?? "007AFF")
    }
}
