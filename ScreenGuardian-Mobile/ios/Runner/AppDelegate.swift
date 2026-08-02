import Flutter
import UIKit
import FamilyControls
import DeviceActivity
import ManagedSettings

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    static let appGroupID = "group.com.timbertrail.screenguardian"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Register ScreenTime method channel
        let messenger = engineBridge.binaryMessenger
        let channel = FlutterMethodChannel(
            name: "com.timbertrail.screenguardian/screentime",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleScreenTime(call: call, result: result)
        }
    }

    // MARK: - ScreenTime Method Channel Handler

    private func handleScreenTime(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let sharedDefaults = UserDefaults(suiteName: AppDelegate.appGroupID)

        switch call.method {

        case "requestAuthorization":
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    DispatchQueue.main.async { result(true) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "AUTH_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "getAuthorizationStatus":
            let status = AuthorizationCenter.shared.authorizationStatus
            switch status {
            case .notDetermined: result("notDetermined")
            case .denied: result("denied")
            case .approved: result("approved")
            @unknown default: result("unknown")
            }

        case "startMonitoring":
            let count = sharedDefaults?.integer(forKey: "triggerCount") ?? 0
            let isCombined = (count % 2 == 1)
            let interval: TimeInterval = isCombined ? 40 * 60 : 20 * 60
            let activityName = DeviceActivityName(isCombined ? "combinedReminder" : "eyeRestReminder")
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(second: 0),
                intervalEnd: DateComponents(second: Int(interval)),
                repeats: false
            )
            do {
                try DeviceActivityCenter().startMonitoring(activityName, during: schedule)
                result(true)
            } catch {
                result(FlutterError(code: "MONITOR_FAILED", message: error.localizedDescription, details: nil))
            }

        case "stopMonitoring":
            DeviceActivityCenter().stopMonitoring()
            result(true)

        case "getTriggerCount":
            result(sharedDefaults?.integer(forKey: "triggerCount") ?? 0)

        case "setTriggerCount":
            if let args = call.arguments as? [String: Any], let count = args["count"] as? Int {
                sharedDefaults?.set(count, forKey: "triggerCount")
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "count required", details: nil))
            }

        case "getReminderEvents":
            result(sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? [])

        case "getExtensionLogs":
            result(sharedDefaults?.array(forKey: "extensionLogs") as? [String] ?? [])

        case "clearShields":
            ManagedSettingsStore().clearAllSettings()
            result(true)

        case "getDeviceUsageToday":
            let totalSeconds = sharedDefaults?.integer(forKey: "todayUsageSeconds") ?? 0
            let lastUpdated = sharedDefaults?.string(forKey: "todayUsageUpdated") ?? ""
            result(["totalSeconds": totalSeconds, "lastUpdated": lastUpdated])

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
