import Foundation
import ServiceManagement

/// Starts the app at login through `SMAppService`. This only works from a built `.app`,
/// so it quietly does nothing for `swift run` and the like.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var message = ""

    var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    init() { refresh() }

    func apply(enabled: Bool) {
        guard isAvailable else { return refresh() }
        let service = SMAppService.mainApp
        do {
            switch (enabled, service.status) {
            case (true, .notRegistered), (true, .notFound):
                try service.register()
            case (false, .enabled), (false, .requiresApproval):
                try service.unregister()
            default:
                break
            }
        } catch {
            message = "Could not change the login item: \(error.localizedDescription)"
            return
        }
        refresh()
    }

    func refresh() {
        guard isAvailable else {
            message = "Only available in the built MiniPlayer.app"
            return
        }
        switch SMAppService.mainApp.status {
        case .enabled: message = "Starts at login"
        case .notRegistered: message = "Off"
        case .requiresApproval: message = "Needs approval in System Settings > General > Login Items"
        case .notFound: message = "Not found by macOS yet"
        @unknown default: message = "Unknown"
        }
    }
}
