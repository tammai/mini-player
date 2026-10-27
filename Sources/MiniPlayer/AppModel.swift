import Foundation
import MiniPlayerCore

enum AdapterStatus: Equatable {
    case starting
    case ready
    case unavailable(String)
}

/// Holds now-playing state and derives what the card should do.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var display: DisplayState = .idle
    @Published private(set) var adapterStatus: AdapterStatus = .starting
    @Published private(set) var hidden: Bool

    private var store = NowPlayingStore()
    private var machine = DisplayStateMachine()
    private var wakeUp: Timer?

    private static let hiddenKey = "widgetHidden"

    init() {
        hidden = UserDefaults.standard.bool(forKey: Self.hiddenKey)
    }

    var editMode: Bool { machine.editMode }

    /// What the window should be doing: shown only when there is something to show.
    var cardVisible: Bool { display == .edit || (!hidden && display != .idle) }

    func handle(line: String) {
        let before = store.info
        guard store.apply(line: line) else { return }
        guard store.info != before else { return }
        machine.apply(info: store.info, now: .now)
        info = store.info
        refresh()
    }

    func setAdapterStatus(_ status: AdapterStatus) { adapterStatus = status }

    func setEditMode(_ on: Bool) {
        if on { setHidden(false) }
        machine.editMode = on
        refresh()
    }

    func setHidden(_ value: Bool) {
        hidden = value
        UserDefaults.standard.set(value, forKey: Self.hiddenKey)
    }

    private func refresh() {
        display = machine.state(at: .now)
        wakeUp?.invalidate()
        wakeUp = nil
        if let deadline = machine.nextTransition(after: .now) {
            wakeUp = Timer.scheduledTimer(withTimeInterval: deadline.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }
}
