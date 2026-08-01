import Flutter
import UIKit
import FamilyControls
import DeviceActivity
import ManagedSettings

/// ScreenTime Plugin - Flutter ↔ ScreenTime API bridge
/// Handles authorization, schedule management, and usage data retrieval
public class ScreenTimePlugin: NSObject, FlutterPlugin {

    static let appGroupID = "group.com.timbertrail.screenguardian"
    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.timbertrail.screenguardian/screentime",
            binaryMessenger: registrar.messenger()
        )
        let instance = ScreenTimePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            requestAuthorization(result: result)
        case "getAuthorizationStatus":
            getAuthorizationStatus(result: result)
        case "startMonitoring":
            startMonitoring(result: result)
        case "stopMonitoring":
            stopMonitoring(result: result)
        case "getTriggerCount":
            getTriggerCount(result: result)
        case "setTriggerCount":
            if let args = call.arguments as? [String: Any],
               let count = args["count"] as? Int {
                setTriggerCount(count: count, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "count required", details: nil))
            }
        case "getReminderEvents":
            getReminderEvents(result: result)
        case "getExtensionLogs":
            getExtensionLogs(result: result)
        case "clearShields":
            clearShields(result: result)
        case "getDeviceUsageToday":
            getDeviceUsageToday(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    func requestAuthorization(result: @escaping FlutterResult) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "AUTH_FAILED",
                        message: "ScreenTime authorization failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    func getAuthorizationStatus(result: @escaping FlutterResult) {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .notDetermined:
            result("notDetermined")
        case .denied:
            result("denied")
        case .approved:
            result("approved")
        @unknown default:
            result("unknown")
        }
    }

    // MARK: - Monitoring

    func startMonitoring(result: @escaping FlutterResult) {
        // Schedule the first reminder (20 min = eye rest)
        let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
        let isCombined = (count % 2 == 1) // next trigger is combined if count is odd
        let interval: TimeInterval = isCombined ? 40 * 60 : 20 * 60
        let activityName = DeviceActivityName(isCombined ? "combinedReminder" : "eyeRestReminder")

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(second: 0),
            intervalEnd: DateComponents(second: Int(interval)),
            repeats: false
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring([activityName], during: schedule)
            result(true)
        } catch {
            result(FlutterError(
                code: "MONITOR_FAILED",
                message: "Failed to start monitoring: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    func stopMonitoring(result: @escaping FlutterResult) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        result(true)
    }

    // MARK: - Trigger Count

    func getTriggerCount(result: @escaping FlutterResult) {
        let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
        result(count)
    }

    func setTriggerCount(count: Int, result: @escaping FlutterResult) {
        sharedDefaults?.set(count, forKey: "triggerCount")
        result(true)
    }

    // MARK: - Events & Logs

    func getReminderEvents(result: @escaping FlutterResult) {
        let events = sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? []
        result(events)
    }

    func getExtensionLogs(result: @escaping FlutterResult) {
        let logs = sharedDefaults?.array(forKey: "extensionLogs") as? [String] ?? []
        result(logs)
    }

    // MARK: - Shield Control

    func clearShields(result: @escaping FlutterResult) {
        let store = ManagedSettingsStore()
        store.clearAllSettings()
        result(true)
    }

    // MARK: - Device Usage

    func getDeviceUsageToday(result: @escaping FlutterResult) {
        // Read usage data saved by the extension
        // The extension can save cumulative usage to shared defaults
        let totalSeconds = sharedDefaults?.integer(forKey: "todayUsageSeconds") ?? 0
        let lastUpdated = sharedDefaults?.string(forKey: "todayUsageUpdated") ?? ""
        result([
            "totalSeconds": totalSeconds,
            "lastUpdated": lastUpdated
        ])
    }
}
