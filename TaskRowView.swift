import SwiftUI

struct TaskRowView: View {
    @Binding var task: Task
    @EnvironmentObject var taskStore: TaskStore

    @FocusState private var isEditingFieldFocused: Bool

    private var isEditing: Bool {
        taskStore.editingTaskId == task.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: toggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)

                if isEditing {
                    TextField("Task Title", text: $task.title)
                        .textFieldStyle(.plain)
                        .focused($isEditingFieldFocused)
                        .onSubmit { taskStore.editingTaskId = nil }
                        .onExitCommand { taskStore.editingTaskId = nil }
                } else {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : colorForDeadline(task.deadline))
                        .textSelection(.disabled)
                }

                if task.notes?.isEmpty == false {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .help("This task has notes.")
                }

                Spacer()

                DeadlineButton(task: $task)

                Button(action: addSubtask) { Image(systemName: "plus") }
                    .buttonStyle(.plain)
                    .help("Add Subtask")
            }
            .padding(.vertical, 8)

            if !task.subtasks.isEmpty {
                DisclosureGroup(isExpanded: .constant(true)) {
                    ForEach($task.subtasks) { $subtask in
                        TaskRowView(task: $subtask)
                    }
                    .padding(.leading, 20)
                } label: { EmptyView() }
                .disclosureGroupStyle(EmptyDisclosureGroupStyle())
            }

            Divider().padding(.leading, 20)
        }
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.5 : 1.0)
        .onChange(of: isEditing) { oldValue, newValue in
            if newValue == true {
                isEditingFieldFocused = true
            }
        }
        .onChange(of: task) { oldValue, newValue in
            taskStore.scheduleNotification(for: newValue)
        }
        .contextMenu {
            Button("Edit Task") {
                taskStore.editingTaskId = task.id
            }

            Button("Delete Task", role: .destructive) {
                withAnimation {
                    taskStore.deleteTask(withId: task.id)
                }
            }
        }
        .onHover { isHovering in
            if isHovering {
                NSCursor.arrow.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func toggleCompletion() {
        withAnimation(.easeOut(duration: 0.2)) {
            taskStore.toggleCompletion(for: task, isComplete: !task.isCompleted)
        }
    }

    private func addSubtask() {
        let subtask = Task(title: "New Subtask", isCompleted: false, creationDate: Date())
        task.subtasks.append(subtask)
        taskStore.editingTaskId = subtask.id
    }
}

struct EmptyDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

func colorForDeadline(_ deadline: Date?) -> Color {
    guard let deadline = deadline else {
        return .primary
    }

    let now = Date()
    if deadline < now {
        return .red
    }

    if let days = Calendar.current.dateComponents([.day], from: now, to: deadline).day, days <= 2 {
        return .yellow
    }

    return .green
}
