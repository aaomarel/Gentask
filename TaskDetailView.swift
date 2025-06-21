import SwiftUI

struct TaskDetailView: View {
    @Binding var task: Task
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Task")
                .font(.headline)

            TextField("Title", text: $task.title)
                .textFieldStyle(.roundedBorder)

            DatePicker(
                "Deadline:",
                selection: Binding($task.deadline, default: Date()),
                displayedComponents: [.date, .hourAndMinute]
            )

            Picker("Priority:", selection: $task.priority) {
                ForEach(TaskPriority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.segmented)

            Text("Notes:")
                .font(.subheadline)

            TextEditor(text: Binding($task.notes, default: ""))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3))
                )

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
