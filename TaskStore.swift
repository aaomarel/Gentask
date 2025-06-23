import Foundation
import SwiftUI
import UserNotifications

class TaskStore: ObservableObject {
    @Published var tasks: [Task] = [] {
        didSet {
            saveTasks()
        }
    }
    
    @Published var editingTaskId: UUID? = nil

    private let tasksKey = "savedTasks_v2"

    init() {
        loadTasks()
    }
    
    // MARK: - Persistence
    
    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            print("❌ Failed to save tasks: \(error)")
        }
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey) else { return }
        do {
            tasks = try JSONDecoder().decode([Task].self, from: data)
        } catch {
            print("❌ Failed to load tasks: \(error)")
        }
    }
    
    // MARK: - Task Management
    
    func addTask(title: String) {
        // let newTask = Task(title: title, isCompleted: false, creationDate: Date())
        let newTask = Task(title: title, isCompleted: false)
        tasks.append(newTask)
        editingTaskId = newTask.id
        
        // Schedule a notification for the new task if it has a deadline.
        scheduleNotification(for: newTask)
    }

    func deleteTask(withId taskId: UUID) {
        func removing(id: UUID, from taskList: [Task]) -> [Task] {
            var newTaskList = [Task]()
            for var task in taskList {
                if task.id == id {
                    continue
                }
                task.subtasks = removing(id: id, from: task.subtasks)
                newTaskList.append(task)
            }
            return newTaskList
        }
        tasks = removing(id: taskId, from: tasks)
    }

    func toggleCompletion(for task: Task, isComplete: Bool) {
        withTask(withId: task.id) { taskToUpdate in
            func setCompletionRecursively(for currentTask: inout Task, status: Bool) {
                currentTask.isCompleted = status
                for i in 0..<currentTask.subtasks.count {
                    setCompletionRecursively(for: &currentTask.subtasks[i], status: status)
                }
            }
            setCompletionRecursively(for: &taskToUpdate, status: isComplete)
            
            // After updating completion, reschedule the notification.
            // This will remove the notification if the task is now complete.
            scheduleNotification(for: taskToUpdate)
        }
    }

    func withTask(withId taskId: UUID, _ action: (inout Task) -> Void) {
        var foundAndMutated = false
        
        func findAndMutate(in tasks: inout [Task]) {
            guard !foundAndMutated else { return }
            for i in 0..<tasks.count {
                if tasks[i].id == taskId {
                    action(&tasks[i])
                    foundAndMutated = true
                    return
                }
                findAndMutate(in: &tasks[i].subtasks)
            }
        }
        
        findAndMutate(in: &tasks)
        
        if foundAndMutated {
            objectWillChange.send()
        }
    }
    
    // MARK: - Notification Logic
    
    func scheduleNotification(for task: Task) {
        let center = UNUserNotificationCenter.current()
        
        center.removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        var leadTime = UserDefaults.standard.double(forKey: "notificationLeadTime")
        
        guard
            notificationsEnabled,
            !task.isCompleted,
            let deadline = task.deadline
        else { return }
        
        if leadTime == -1.0 {
            // This default can be replaced by reading another @AppStorage value for custom minutes.
            leadTime = 15 * 60
        }

        let fireDate = deadline.addingTimeInterval(-leadTime)
        
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Task"
        content.body = "“\(task.title)” is due soon."
        content.sound = .default
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            content.categoryIdentifier = appDelegate.taskReminderCategoryId
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification for task '\(task.title)': \(error.localizedDescription)")
            }
        }
    }
}
