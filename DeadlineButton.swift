import SwiftUI

struct DeadlineButton: View {
    @Binding var task: Task
    @State private var showingPopover = false

    init(task: Binding<Task>) {
        self._task = task
    }

    var body: some View {
        Button(action: {
            showingPopover.toggle()
        }) {
            Image(systemName: "calendar")
                .foregroundStyle(task.deadline == nil ? .gray : .blue)
        }
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set Deadline")
                    .font(.headline)

                DatePicker(
                    "",
                    selection: Binding($task.deadline, default: Date()),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                HStack {
                    Button("Clear Deadline") {
                        task.deadline = nil
                        showingPopover = false
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Done") {
                        showingPopover = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 250)
        }
        .buttonStyle(.plain)
    }
}
