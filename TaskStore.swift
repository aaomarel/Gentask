import Foundation
import SwiftUI

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
    
    func addTask(title: String) {
        let newTask = Task(title: title, isCompleted: false)
        tasks.append(newTask)
        editingTaskId = newTask.id
    }

    // Atomic implementation prevents race conditions and crashes.
    func deleteTask(withId taskId: UUID) {

        func removing(id: UUID, from taskList: [Task]) -> [Task] {
            var newTaskList = [Task]()
            for var task in taskList {
                // If the current task is the one we want to delete, we just skip it.
                if task.id == id {
                    continue
                }
                // For every task we keep, we must also run this function on its subtasks.
                task.subtasks = removing(id: id, from: task.subtasks)
                newTaskList.append(task)
            }
            return newTaskList
        }

        // Call the recursive helper and assign its result back to the main tasks array.
        // This creates a single, clean update for SwiftUI.
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
}
