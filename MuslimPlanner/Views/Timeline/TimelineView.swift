import SwiftUI
import SwiftData

// MARK: - Layout constants
private let kHourHeight: CGFloat      = 64
private let kRulerWidth: CGFloat      = 48
private let kTaskInset: CGFloat       = 4
private let kRightPad: CGFloat        = 16
private let kRevealWidth: CGFloat     = 72
private let kDeleteThreshold: CGFloat = 120

struct TimelineView: View {
    @ObservedObject var viewModel: DayPlanViewModel
    let settings: AppSettings

    @Query private var allTasks: [PlanTask]
    @Environment(\.modelContext) private var ctx

    private enum Sheet: Identifiable {
        case editTask(PlanTask), typePicker, settings, calendar
        var id: String {
            switch self {
            case .editTask(let t): return "task-\(ObjectIdentifier(t).hashValue)"
            case .typePicker:     return "typePicker"
            case .settings:       return "settings"
            case .calendar:       return "calendar"
            }
        }
    }

    @State private var activeSheet: Sheet?
    @State private var calendarMonth = Calendar.current.startOfDay(for: Date())

    // Vertical drag state
    @State private var draggingID: PersistentIdentifier? = nil
    @State private var dragOffset: CGFloat = 0

    // Swipe-to-delete state
    @State private var swipeOffsets: [PersistentIdentifier: CGFloat] = [:]
    @State private var revealedSwipes: Set<PersistentIdentifier> = []
    @State private var swipeDragDirections: [PersistentIdentifier: Bool] = [:]

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
        return max(44, mins / 60 * kHourHeight)
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
        VStack(spacing: 0) {
            calendarHeader
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
        .sheet(item: $activeSheet, onDismiss: {
            viewModel.reapplyAdjustments(settings: settings)
        }) { sheet in
            switch sheet {
            case .editTask(let task):
                TaskEditorSheet(task: task, date: viewModel.selectedDate, prayerTimes: viewModel.prayerTimes)
            case .typePicker:
                TaskTypePickerSheet(date: viewModel.selectedDate, prayerTimes: viewModel.prayerTimes)
            case .settings:
                SettingsView(settings: settings, rawPrayerTimes: viewModel.rawPrayerTimes)
                    .environmentObject(viewModel.locationService)
            case .calendar:
                MiniCalendarSheet(selectedDate: $viewModel.selectedDate, displayMonth: $calendarMonth, allTasks: allTasks)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
    }

    // MARK: - Calendar header (month/year row + week strip)

    private var calendarHeader: some View {
        VStack(spacing: 0) {
            // Top row: month/year + nav arrows + gear
            HStack(spacing: 6) {
                Button {
                    calendarMonth = viewModel.selectedDate
                    activeSheet = .calendar
                } label: {
                    Text(viewModel.selectedDate.formatted(.dateTime.month(.wide).year()))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button { shiftWeek(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)

                Button { shiftWeek(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Button { activeSheet = .settings } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Week strip
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    weekDayCell(day)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    // Mon–Sun of the week containing selectedDate
    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: viewModel.selectedDate)
        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: viewModel.selectedDate) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    @ViewBuilder
    private func weekDayCell(_ date: Date) -> some View {
        let cal = Calendar.current
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: viewModel.selectedDate)
        let dayNum     = cal.component(.day, from: date)
        let dayName    = date.formatted(.dateTime.weekday(.abbreviated))

        Button {
            viewModel.selectedDate = cal.startOfDay(for: date)
        } label: {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ZStack {
                    if isToday {
                        Circle().fill(Color.yellow).frame(width: 32, height: 32)
                    } else if isSelected {
                        Circle().fill(Color.primary.opacity(0.18)).frame(width: 32, height: 32)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 15, weight: isToday || isSelected ? .semibold : .regular))
                        .foregroundStyle(isToday ? Color.black : .primary)
                }
                .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func shiftWeek(_ direction: Int) {
        let cal = Calendar.current
        if let shifted = cal.date(byAdding: .weekOfYear, value: direction, to: viewModel.selectedDate) {
            viewModel.selectedDate = cal.startOfDay(for: shifted)
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

    // MARK: - Prayer layer

    private var prayerLayer: some View {
        ForEach(viewModel.prayerTimes) { prayer in
            PrayerAnchorRow(prayer: prayer)
                .padding(.leading, kRulerWidth + kTaskInset)
                .padding(.trailing, kRightPad)
                .offset(y: yFor(prayer.time) - 9)
        }
    }

    // MARK: - Task cards with swipe-to-delete and vertical drag

    @ViewBuilder
    private func taskCard(_ task: PlanTask, width: CGFloat) -> some View {
        let id         = task.persistentModelID
        let isDragging = draggingID == id
        let yBase      = yFor(task.startTime!)
        let yPos       = yBase + (isDragging ? dragOffset : 0)
        let swipeX     = swipeOffsets[id] ?? 0
        let isRevealed = revealedSwipes.contains(id)
        let cardW      = max(60, width)
        let h          = taskHeight(task)

        // Red delete background — sits behind the card, revealed as card slides left
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.red)
            .overlay(alignment: .trailing) {
                Button {
                    withAnimation(.easeIn(duration: 0.22)) {
                        swipeOffsets[id] = -(cardW + 20)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        ctx.delete(task)
                        try? ctx.save()
                        swipeOffsets.removeValue(forKey: id)
                        revealedSwipes.remove(id)
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: kRevealWidth, height: h)
                }
                .buttonStyle(.plain)
            }
            .frame(width: cardW, height: h)
            .offset(x: kRulerWidth + kTaskInset, y: yPos)
            .opacity(swipeX < -6 || isRevealed ? 1 : 0)

        // The sliding card
        TimedTaskCard(task: task) {
            if isRevealed {
                withAnimation(.spring(response: 0.3)) {
                    swipeOffsets[id] = 0
                    revealedSwipes.remove(id)
                }
            } else {
                activeSheet = .editTask(task)
            }
        }
        .frame(width: cardW, height: h)
        .offset(x: kRulerWidth + kTaskInset + swipeX, y: yPos)
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
                    if swipeDragDirections[id] == nil {
                        swipeDragDirections[id] = abs(val.translation.width) > abs(val.translation.height)
                    }
                    if swipeDragDirections[id] == true {
                        // Horizontal — only allow left swipe
                        let base: CGFloat = isRevealed ? -kRevealWidth : 0
                        swipeOffsets[id] = min(0, base + val.translation.width)
                    } else if !isRevealed {
                        // Vertical — reposition in time
                        draggingID = id
                        dragOffset = val.translation.height
                    }
                }
                .onEnded { val in
                    let wasHoriz = swipeDragDirections[id] == true
                    swipeDragDirections[id] = nil

                    if wasHoriz {
                        let offset = swipeOffsets[id] ?? 0
                        if abs(offset) >= kDeleteThreshold {
                            // Past halfway — delete
                            withAnimation(.easeIn(duration: 0.22)) {
                                swipeOffsets[id] = -(cardW + 20)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                                ctx.delete(task)
                                try? ctx.save()
                                swipeOffsets.removeValue(forKey: id)
                                revealedSwipes.remove(id)
                            }
                        } else if abs(offset) > 20 {
                            // Partial swipe — reveal trash button
                            withAnimation(.spring(response: 0.3)) {
                                swipeOffsets[id] = -kRevealWidth
                                revealedSwipes.insert(id)
                            }
                        } else {
                            // Tiny movement — snap back
                            withAnimation(.spring(response: 0.3)) {
                                swipeOffsets[id] = 0
                                revealedSwipes.remove(id)
                            }
                        }
                    } else {
                        if isRevealed {
                            // Close reveal on any vertical gesture
                            withAnimation(.spring(response: 0.3)) {
                                swipeOffsets[id] = 0
                                revealedSwipes.remove(id)
                            }
                        } else {
                            commitDrag(task: task, pixelOffset: val.translation.height)
                        }
                        draggingID = nil
                        dragOffset = 0
                    }
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

    // MARK: - FAB

    private var addButton: some View {
        Button { activeSheet = .typePicker } label: {
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

// MARK: - Mini calendar sheet

private struct MiniCalendarSheet: View {
    @Binding var selectedDate: Date
    @Binding var displayMonth: Date
    let allTasks: [PlanTask]

    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current
    private let weekdayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation row
            HStack(spacing: 14) {
                Text(displayMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())

                Spacer()

                Button("Today") {
                    let today = cal.startOfDay(for: Date())
                    selectedDate = today
                    displayMonth = today
                    dismiss()
                }
                .font(.callout)
                .foregroundStyle(.blue)
                .buttonStyle(.plain)

                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Day-of-week header row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { name in
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                }

                // Date cells (nil = empty leading/trailing pad)
                ForEach(Array(calendarDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarCell(date)
                    } else {
                        Color.clear.frame(height: 50)
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func calendarCell(_ date: Date) -> some View {
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let dayNum     = cal.component(.day, from: date)
        let dots       = taskColors(for: date)

        Button {
            selectedDate = cal.startOfDay(for: date)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isToday {
                        Circle().fill(Color.yellow).frame(width: 32, height: 32)
                    } else if isSelected {
                        Circle().fill(Color.primary.opacity(0.2)).frame(width: 32, height: 32)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                        .foregroundStyle(isToday ? Color.black : .primary)
                }
                .frame(width: 32, height: 32)

                HStack(spacing: 3) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func shiftMonth(_ direction: Int) {
        if let shifted = cal.date(byAdding: .month, value: direction, to: displayMonth) {
            displayMonth = shifted
        }
    }

    // Returns nil-padded array aligned to Monday-start grid
    private var calendarDates: [Date?] {
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        let firstWeekday = cal.component(.weekday, from: firstDay)
        let leadingEmpties = (firstWeekday - 2 + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: displayMonth)!.count

        var dates: [Date?] = Array(repeating: nil, count: leadingEmpties)
        for offset in 0..<daysInMonth {
            dates.append(cal.date(byAdding: .day, value: offset, to: firstDay))
        }
        while dates.count % 7 != 0 { dates.append(nil) }
        return dates
    }

    // Up to 3 colored dots representing task types on that day
    private func taskColors(for date: Date) -> [Color] {
        let colors = allTasks
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .compactMap { $0.taskType.map { Color(hex: $0.colorHex) } }
        return Array(colors.prefix(3))
    }
}

// MARK: - Task card view (3-panel layout)

struct TimedTaskCard: View {
    @Bindable var task: PlanTask
    let onTap: () -> Void

    @Environment(\.modelContext) private var ctx
    @State private var showTypePicker = false

    private var hasAlternatives: Bool {
        guard let t = task.taskType else { return false }
        return !t.root.subtasks.isEmpty
    }

    var body: some View {
        let stroke = task.color.opacity(task.isCompleted ? 0.15 : 0.3)

        HStack(spacing: 0) {

            // ── Left panel: icon + name + time ───────────────────────────────
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(task.color)
                    .frame(width: 4)

                if task.taskType != nil {
                    Image(systemName: task.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(task.color.opacity(0.85))
                        .frame(width: 26)
                        .padding(.leading, 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

                    if let start = task.startTime {
                        let end = start.addingTimeInterval(Double((task.durationMinutes ?? 30) * 60))
                        Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, task.taskType != nil ? 4 : 8)
                .padding(.vertical, 4)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            Rectangle().fill(stroke).frame(width: 0.5)

            // ── Middle panel: switch subtype ──────────────────────────────────
            Button {
                showTypePicker = true
            } label: {
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hasAlternatives
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(Color.secondary.opacity(0.2)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(!hasAlternatives)

            Rectangle().fill(stroke).frame(width: 0.5)

            // ── Right panel: completion toggle ────────────────────────────────
            Button {
                task.isCompleted.toggle()
                try? ctx.save()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(task.isCompleted
                        ? AnyShapeStyle(Color.green)
                        : AnyShapeStyle(task.color.opacity(0.45)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(task.isCompleted ? 0.55 : 1.0)
        .background(task.color.opacity(task.isCompleted ? 0.05 : 0.10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .sheet(isPresented: $showTypePicker) {
            CardTypePickerSheet(task: task)
        }
    }
}

// MARK: - Card type picker (constrained to current root's family)

private struct CardTypePickerSheet: View {
    @Bindable var task: PlanTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    private var currentRoot: TaskTemplate? { task.taskType?.root }
    private var currentID: PersistentIdentifier? { task.taskType?.persistentModelID }
    private var rootTemplates: [TaskTemplate] { allTemplates.filter(\.isRoot) }

    var body: some View {
        NavigationStack {
            List {
                if let root = currentRoot {
                    let alternatives = root.sortedSubtasks.filter {
                        $0.persistentModelID != currentID
                    }

                    if !alternatives.isEmpty {
                        Section {
                            ForEach(alternatives) { sub in
                                Button { pick(sub) } label: { templateRow(sub) }
                            }
                        }
                    }

                    if currentID != root.persistentModelID {
                        Section {
                            Button { pick(root) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: root.symbolName)
                                        .foregroundStyle(Color(hex: root.colorHex).opacity(0.55))
                                        .frame(width: 24)
                                    Text("No subtype – just \(root.name)")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(root.durationMinutes)m")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(rootTemplates) { t in
                        if t.subtasks.isEmpty {
                            Button { pick(t) } label: { templateRow(t) }
                        } else {
                            NavigationLink {
                                subtaskList(for: t)
                            } label: { templateRow(t) }
                        }
                    }
                }
            }
            .navigationTitle(currentRoot.map { "Switch \($0.name)" } ?? "Set Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func subtaskList(for parent: TaskTemplate) -> some View {
        List {
            Section {
                ForEach(parent.sortedSubtasks) { sub in
                    Button { pick(sub) } label: { templateRow(sub) }
                }
            }
            Section {
                Button { pick(parent) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: parent.symbolName)
                            .foregroundStyle(Color(hex: parent.colorHex).opacity(0.55))
                            .frame(width: 24)
                        Text("No subtype – just \(parent.name)").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(parent.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(parent.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func templateRow(_ t: TaskTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: t.symbolName)
                .foregroundStyle(Color(hex: t.colorHex))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.displayTitle).foregroundStyle(.primary)
                if t.parent != nil {
                    Text(t.path).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(t.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func pick(_ template: TaskTemplate) {
        task.taskType = template
        task.title = template.displayTitle
        try? ctx.save()
        dismiss()
    }
}
