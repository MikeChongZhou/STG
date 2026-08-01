import Foundation
import ManagedSettings
import UIKit

/// ShieldConfigurationExtension - Customizes the Shield overlay appearance
/// Shows different messages for eye rest vs combined (posture + eye rest)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    static let appGroupID = "group.com.timbertrail.screenguardian"

    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    func configuration(shielding application: Application) -> ShieldConfiguration {
        return makeConfiguration()
    }

    func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return makeConfiguration()
    }

    func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let events = sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? []
        let lastEvent = events.last
        let isCombined = lastEvent?["type"] == "combined"

        let headerText: ShieldConfiguration.Label.Text
        let subtitleText: ShieldConfiguration.Label.Text
        let buttonText: String

        if isCombined {
            headerText = .text("🧘 + 👁️ 姿势切换 + 用眼休息")
            subtitleText = .text("请切换坐姿/站姿，并看向 20 英尺外 20 秒")
            buttonText = "知道了"
        } else {
            headerText = .text("👁️ 用眼休息")
            subtitleText = .text("请看向 20 英尺（约 6 米）外的物体，持续 20 秒")
            buttonText = "知道了"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .regular,
            backgroundColor: UIColor(red: 0.102, green: 0.137, blue: 0.494, alpha: 1.0), // #1A237E
            icon: UIImage(systemName: "eye.fill"),
            title: headerText,
            subtitle: subtitleText,
            primaryButton: ShieldConfiguration.Button(label: .text(buttonText), isEnabled: true),
            secondaryButtonLabel: nil
        )
    }
}
