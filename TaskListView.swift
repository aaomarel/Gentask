import SwiftUI
import UserNotifications

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var newTaskTitle: String = ""
    @FocusState private var isNewTaskFieldFocused: Bool
    
    @State private var sortMode: SortMode = .smart
    
    @AppStorage("notificationLeadTime") private var notificationLeadTime: TimeInterval = 60 * 10
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var customLeadTimeMinutes: String = "15"
    
    private let updaterController = UpdaterController()

    enum SortMode: String, CaseIterable, Identifiable {
        case smart, deadline, priority
        var id: String { rawValue }
        var label: String { self.rawValue.capitalized }
    }

    private var sortedTasks: [Task] {
        return taskStore.tasks.sorted { (taskA, taskB) -> Bool in
            let dateA = taskA.creationDate ?? .distantPast
            let dateB = taskB.creationDate ?? .distantPast

            switch sortMode {
            case .smart:
                if taskA.isCompleted != taskB.isCompleted { return !taskA.isCompleted }
                switch (taskA.deadline, taskB.deadline) {
                    case let (d1?, d2?): if abs(d1.timeIntervalSince(d2)) > 1 { return d1 < d2 }
                    case (_?, nil): return true
                    case (nil, _?): return false
                    case (nil, nil): break
                }
                return dateA > dateB

            case .deadline:
                switch (taskA.deadline, taskB.deadline) {
                case let (d1?, d2?): return d1 < d2
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return dateA > dateB
                }
            case .priority:
                if taskA.priority.sortOrder != taskB.priority.sortOrder {
                    return taskA.priority.sortOrder < taskB.priority.sortOrder
                }
                return dateA > dateB
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (Build \(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {
                Text("Gentask").font(.headline)
                Spacer()

                Picker("Sort by", selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text("Sort by \(mode.label)").tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 25)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                if sortedTasks.isEmpty {
                    Text("No tasks yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedTasks) { task in
                            if let taskIndex = taskStore.tasks.firstIndex(where: { $0.id == task.id }) {
                                TaskRowView(task: $taskStore.tasks[taskIndex])
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .zIndex(1)

            Divider()

            TextField("New task...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($isNewTaskFieldFocused)
                .onSubmit(addTask)
                .padding(.horizontal)
                .frame(height: 35)
                .onChange(of: taskStore.editingTaskId) { oldValue, newValue in
                    if newValue != nil {
                        isNewTaskFieldFocused = true
                    }
                }

            VStack(spacing: 8) {
                HStack {
                    Toggle(isOn: $notificationsEnabled) {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    }
                    .foregroundColor(notificationsEnabled ? .accentColor : .secondary)
                    .toggleStyle(.button)
                    .help(notificationsEnabled ? "Disable Notifications" : "Enable Notifications")

                    if notificationsEnabled {
                        Picker("Notify me before", selection: $notificationLeadTime) {
                            Text("5 min").tag(60.0 * 5)
                            Text("10 min").tag(60.0 * 10)
                            Text("30 min").tag(60.0 * 30)
                            Text("1 hour").tag(60.0 * 60)
                            Text("Custom").tag(-1.0)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        
                        if notificationLeadTime == -1.0 {
                            HStack {
                                TextField("Minutes", text: $customLeadTimeMinutes)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 40)
                                Text("min before")
                            }
                        }
                    }

                    Spacer()
                }
                
                HStack {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    
                    Link("Provide Feedback", destination: URL(string: "https://forms.gle/sktPJa4GkUHk2VVv7")!)
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 350, maxHeight: 700)
        .onAppear {
            if taskStore.tasks.isEmpty {
                isNewTaskFieldFocused = true
            }
        }
        .onChange(of: notificationsEnabled) { _, _ in
            taskStore.tasks.forEach { taskStore.scheduleNotification(for: $0) }
        }
        .onChange(of: notificationLeadTime) { _, _ in
            taskStore.tasks.forEach { taskStore.scheduleNotification(for: $0) }
        }
        .onChange(of: customLeadTimeMinutes) { _, _ in
            taskStore.tasks.forEach { taskStore.scheduleNotification(for: $0) }
        }
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        taskStore.addTask(title: trimmed)
        newTaskTitle = ""
    }
}
