import SwiftUI
import UserNotifications

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @State private var newTaskTitle: String = ""
    @FocusState private var isNewTaskFieldFocused: Bool
    
    enum SortMode: String, CaseIterable, Identifiable {
        case smart, deadline, priority
        var id: String { rawValue }
        var label: String { self.rawValue.capitalized }
    }
    @State private var sortMode: SortMode = .smart

    @AppStorage("notificationLeadTime") private var notificationLeadTime: TimeInterval = 60 * 10
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

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
    
    // Helper to get the app version and build number for display.
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

            // --- FOOTER SECTION ---
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
                            Text("10 min").tag(60.0 * 10)
                            Text("30 min").tag(60.0 * 30)
                            Text("1 hour").tag(60.0 * 60)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Spacer()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Gentask")
                }
                
                // App version and feedback link for beta testing.
                HStack {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Link("Provide Feedback", destination: URL(string: "https://forms.gle/sktPJa4GkUHk2VVv7")!)
                }
            }
            .font(.system(size: 11)) // Adjusted font size for footer
            .padding(.horizontal)
            .padding(.vertical, 8)
            // --- END FOOTER ---

        }
        .frame(width: 280, height: 350)
        .onAppear {
            if taskStore.tasks.isEmpty {
                isNewTaskFieldFocused = true
            }
        }
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        taskStore.addTask(title: trimmed)
        if let newTask = taskStore.tasks.last, notificationsEnabled {
            scheduleNotification(for: newTask)
        }
        newTaskTitle = ""
    }

    private func scheduleNotification(for task: Task) {
        guard let deadline = task.deadline, !task.isCompleted else { return }
        
        let fireDate = deadline.addingTimeInterval(-notificationLeadTime)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Task"
        content.body = "“\(task.title)” is due soon."
        content.sound = .default
        content.categoryIdentifier = (NSApplication.shared.delegate as! AppDelegate).taskReminderCategoryId

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule: \(error.localizedDescription)")
            }
        }
    }
}
