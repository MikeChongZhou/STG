import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

/// ScreenGuardian DeviceActivityMonitor Extension
/// Monitors device screen time and triggers eye rest / posture change reminders
/// using ManagedSettings Shield overlays.
///
/// Trigger flow:
///   20 min → Shield: eye rest
///   40 min → Shield: posture change + eye rest
///   60 min → Shield: eye rest
///   80 min → Shield: posture change + eye rest
///   ... repeats every 20 min, alternating

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    static let eyeRestInterval: TimeInterval = 20 * 60
    static let combinedInterval: TimeInterval = 40 * 60
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

        saveEvent(type: isCombinedActivity(activity) ? "combined" : "eye_rest", action: "ended")

        // Schedule next reminder
        scheduleNextReminder()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        log("intervalWillStartWarning: \(activity.rawValue)")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        log("intervalWillEndWarning: \(activity.rawValue)")
    }

    // MARK: - Shield Reminder
    //
    // iOS 16 ManagedSettings Shield API:
    //   store.shield.applications = .all   → block all apps
    //   store.shield.webDomains = .all     → block all web domains
    //
    // Note: Custom shield text (header/subtitle/buttons) requires
    // a ShieldConfigurationExtension, not set here.

    func showShieldReminder(isCombined: Bool) {
        let store = ManagedSettingsStore()

        // Apply shield to all applications and web domains
        store.shield.applications = .all
        store.shield.webDomains = .all

        saveEvent(type: isCombined ? "combined" : "eye_rest", action: "shown")
        log("Shield applied: \(isCombined ? "combined (posture+eye)" : "eye_rest")")
    }

    // MARK: - Schedule Management

    func scheduleNextReminder() {
        let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
        let newCount = count + 1
        sharedDefaults?.set(newCount, forKey: "triggerCount")

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
