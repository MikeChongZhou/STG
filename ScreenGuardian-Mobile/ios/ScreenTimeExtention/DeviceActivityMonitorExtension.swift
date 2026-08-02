import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    static let eyeRestInterval: TimeInterval = 20 * 60
    static let combinedInterval: TimeInterval = 40 * 60
    static let appGroupID = "group.com.timbertrail.screenguardian"

    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart: \(activity.rawValue)")
        showShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd: \(activity.rawValue)")
        let store = ManagedSettingsStore()
        store.clearAllSettings()
        saveEvent(type: activity.rawValue == "combinedReminder" ? "combined" : "eye_rest", action: "ended")
        scheduleNextReminder()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    func showShield() {
        let store = ManagedSettingsStore()
        store.shield.applications = Set()
        store.shield.webDomains = Set()
        saveEvent(type: "eye_rest", action: "shown")
        log("Shield applied")
    }

    func scheduleNextReminder() {
        let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
        let newCount = count + 1
        sharedDefaults?.set(newCount, forKey: "triggerCount")

        let isCombined = (newCount % 2 == 0)
        let interval: TimeInterval = isCombined ? Self.combinedInterval : Self.eyeRestInterval
        let name = DeviceActivityName(isCombined ? "combinedReminder" : "eyeRestReminder")

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(second: 0),
            intervalEnd: DateComponents(second: Int(interval)),
            repeats: false
        )

        do {
            try DeviceActivityCenter().startMonitoring([name], during: schedule)
            log("Scheduled: \(name.rawValue) in \(Int(interval))s (#\(newCount))")
        } catch {
            log("Schedule failed: \(error)")
        }
    }

    func saveEvent(type: String, action: String) {
        var events = sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? []
        events.append(["type": type, "action": action, "time": ISO8601DateFormatter().string(from: Date())])
        if events.count > 100 { events = Array(events.suffix(100)) }
        sharedDefaults?.set(events, forKey: "reminderEvents")
    }

    func log(_ message: String) {
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)"
        var logs = sharedDefaults?.array(forKey: "extensionLogs") as? [String] ?? []
        logs.append(entry)
        if logs.count > 50 { logs = Array(logs.suffix(50)) }
        sharedDefaults?.set(logs, forKey: "extensionLogs")
    }
}
