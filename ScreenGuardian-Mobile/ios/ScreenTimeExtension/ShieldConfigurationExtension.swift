import Foundation
import ManagedSettings
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    static let appGroupID = "group.com.timbertrail.screenguardian"

    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    func configuration(shielding application: Application) -> ShieldConfiguration {
        return makeConfig()
    }

    func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return makeConfig()
    }

    func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return makeConfig()
    }

    private func makeConfig() -> ShieldConfiguration {
        let events = sharedDefaults?.array(forKey: "reminderEvents") as? [[String: String]] ?? []
        let isCombined = events.last?["type"] == "combined"

        if isCombined {
            return ShieldConfiguration(
                backgroundBlurStyle: .regular,
                icon: UIImage(systemName: "figure.mind.and.body"),
                title: .text("🧘 + 👁️ 姿势切换 + 用眼休息"),
                subtitle: .text("请切换坐姿/站姿，并看向 20 英尺外 20 秒"),
                primaryButton: .init(label: .text("知道了"), isEnabled: true),
                secondaryButtonLabel: nil
            )
        } else {
            return ShieldConfiguration(
                backgroundBlurStyle: .regular,
                icon: UIImage(systemName: "eye.fill"),
                title: .text("👁️ 用眼休息"),
                subtitle: .text("请看向 20 英尺（约 6 米）外的物体，持续 20 秒"),
                primaryButton: .init(label: .text("知道了"), isEnabled: true),
                secondaryButtonLabel: nil
            )
        }
    }
}
