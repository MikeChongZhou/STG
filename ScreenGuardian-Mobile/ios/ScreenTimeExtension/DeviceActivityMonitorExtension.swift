import DeviceActivity
import ManagedSettings
import FamilyControls

/// ScreenGuardian DeviceActivityMonitor Extension
/// Monitors device screen time and triggers eye rest / posture change reminders
/// using ManagedSettings Shield overlays (iOS native full-screen UI).
///
/// Trigger flow:
///   20 min → Shield: eye rest (look 20ft away for 20s)
///   40 min → Shield: posture change + eye rest (2 min)
///   60 min → Shield: eye rest
///   80 min → Shield: posture change + eye rest
///   ... repeats every 20 min, alternating eye-only and combined

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // Thresholds in seconds
    static let eyeRestInterval: TimeInterval = 20 * 60        // 20 min
    static let combinedInterval: TimeInterval = 40 * 60        // 40 min

    // Shared UserDefaults for communication with main app
    static let appGroupID = "group.com.timbertrail.screenguardian"
    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    // MARK: - Lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart: \(activity.rawValue)")

        let isCombined = (activity.rawValue == "combinedReminder")
        showShieldReminder(isCombined: isCombined)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd: \(activity.rawValue)")

        // Remove shield
        let store = ManagedSettingsStore()
        store.clearAllSettings()

        // Save event for main app to read
        saveEvent(type: isCombinedActivity(activity) ? "combined" : "eye_rest", action: "ended")

        // Schedule next reminder
        scheduleNextReminder()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        // 5-second warning before the interval starts
        log("intervalWillStartWarning: \(activity.rawValue)")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        log("intervalWillEndWarning: \(activity.rawValue)")
    }

    // MARK: - Shield Reminder

    func showShieldReminder(isCombined: Bool) {
        let store = ManagedSettingsStore()

        if isCombined {
            // Combined: posture change + eye rest
            store.shield.applications?.insert(.all)
            store.shield.webDomains?.insert(.all)

            // Custom shield text
            store.shield.applications?.update(
                with: ShieldSettings.Application(
                    header: .text("🧘 + 👁️ 姿势切换 + 用眼休息"),
                    subtitle: .text("请切换坐姿/站姿，并看向 20 英尺外 20 秒"),
                    primaryButton: .text("知道了"),
                    secondaryButton: .text("稍后提醒")
                )
            )
        } else {
            // Eye rest only
            store.shield.applications?.insert(.all)
            store.shield.webDomains?.insert(.all)

            store.shield.applications?.update(
                with: ShieldSettings.Application(
                    header: .text("👁️ 用眼休息"),
                    subtitle: .text("请看向 20 英尺（约 6 米）外的物体，持续 20 秒"),
                    primaryButton: .text("知道了"),
                    secondaryButton: .text("稍后提醒")
                )
            )
        }

        saveEvent(type: isCombined ? "combined" : "eye_rest", action: "shown")
        log("Shield shown: \(isCombined ? "combined" : "eye_rest")")
    }

    // MARK: - Schedule Management

    func scheduleNextReminder() {
        // Read trigger count from shared defaults
        let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
        let newCount = count + 1
        sharedDefaults?.set(newCount, forKey: "triggerCount")

        // Every 2nd trigger = combined (posture + eye rest)
        let isCombined = (newCount % 2 == 0)
        let interval: TimeInterval = isCombined ? Self.combinedInterval : Self.eyeRestInterval

        let activityName = DeviceActivityName(isCombined ? "combinedReminder" : "eyeRestReminder")

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(second: 0),
            intervalEnd: DateComponents(second: Int(interval)),
            repeats: false
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring([activityName], during: schedule)
            log("Scheduled next: \(activityName.rawValue) in \(Int(interval))s (trigger #\(newCount))")
        } catch {
            log("Failed to schedule: \(error)")
        }
    }

    // MARK: - Helpers

    func isCombinedActivity(_ activity: DeviceActivityName) -> Bool {
        return activity.rawValue == "combinedReminder"
    }

    func saveEvent(type: String, action: String) {
        var events = sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? []
        events.append([
            "type": type,
            "action": action,
            "time": ISO8601DateFormatter().string(from: Date())
        ])
        // Keep only last 100 events
        if events.count > 100 {
            events = Array(events.suffix(100))
        }
        sharedDefaults?.set(events, forKey: "reminderEvents")
    }

    func log(_ message: String) {
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)"
        var logs = sharedDefaults?.array(forKey: "extensionLogs") as? [String] ?? []
        logs.append(entry)
        if logs.count > 50 {
            logs = Array(logs.suffix(50))
        }
        sharedDefaults?.set(logs, forKey: "extensionLogs")
    }
}
