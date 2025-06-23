import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var taskStore = TaskStore()
    var hotkeyEventMonitor: Any?
    private var updaterController: UpdaterController?
    
    let taskReminderCategoryId = "TASK_REMINDER_CATEGORY"

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = UpdaterController()
        configureUserNotifications()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Gentask")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        updatePopoverContent()

        registerHotkey()
        showWelcomeMessageIfNeeded()
    }
    
    func registerHotkey() {
        hotkeyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.modifierFlags.contains(.shift) && event.keyCode == 9 {
                self?.togglePopover(nil)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let monitor = hotkeyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func showWelcomeMessageIfNeeded() {
        let defaults = UserDefaults.standard
        let hasLaunchedBeforeKey = "hasLaunchedBefore"

        if !defaults.bool(forKey: hasLaunchedBeforeKey) {
            let alert = NSAlert()
            alert.messageText = "Welcome to Gentask!"
            alert.informativeText = "Gentask lives in your menu bar.\n\nClick the checkmark icon to see your tasks, or use the global hotkey:\nOption + Shift + G"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got it!")
            alert.runModal()
            
            defaults.set(true, forKey: hasLaunchedBeforeKey)
        }
    }
    
    func configureUserNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let completeAction = UNNotificationAction(identifier: "COMPLETE_ACTION", title: "Mark as Complete", options: [])
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Snooze", options: [])

        let category = UNNotificationCategory(
            identifier: taskReminderCategoryId,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Failed to request notification authorization: \(error.localizedDescription)")
                return
            }
            if granted {
                print("✅ Notification permission granted.")
            } else {
                print("⚠️ Notification permission denied.")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        togglePopover(nil)

        let taskID = response.notification.request.identifier
        if let uuid = UUID(uuidString: taskID) {
            switch response.actionIdentifier {
            case "COMPLETE_ACTION":
                taskStore.withTask(withId: uuid) { task in
                    task.isCompleted = true
                }
                print("✅ Task \(taskID) marked as complete via notification.")
            case "SNOOZE_ACTION":
                print("Snooze action for task \(taskID) selected.")
            default:
                break
            }
        }
        completionHandler()
    }

    func updatePopoverContent() {
        let contentView = TaskListView()
            .environmentObject(taskStore)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                updatePopoverContent()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func showTaskDetailWindow(for taskBinding: Binding<Task>) {
        let detailView = TaskDetailView(task: taskBinding)
        let hosting = NSHostingController(rootView: detailView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Task Details"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
