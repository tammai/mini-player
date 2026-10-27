import AppKit
import MiniPlayerCore
import SwiftUI

/// Settings. Every control edits the config directly, and the desktop widget updates as you drag.
struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var login: LoginItemController
    /// The clock's tint and the card accent's tint, each sampled from its own patch of wallpaper.
    @ObservedObject var clockTint: WallpaperTint
    @ObservedObject var accentTint: WallpaperTint

    private static let fontFamilies = NSFontManager.shared.availableFontFamilies

    private enum Page: String, CaseIterable, Identifiable {
        case card = "Card", elements = "Elements", waves = "Waves", clock = "Clock", position = "Position", general = "General"
        var id: String { rawValue }
    }

    /// `MINIPLAYER_SETTINGS_PAGE=Position` opens Settings on that page. Handy for checking one page.
    @State private var page = Page(rawValue: ProcessInfo.processInfo.environment["MINIPLAYER_SETTINGS_PAGE"] ?? "") ?? .card
    /// The page picker's natural width: as wide as its six labels need. The window is sized from it.
    @State private var tabsWidth: CGFloat = 0

    private static let sidePadding: CGFloat = 24

    // A segmented picker over a plain form, not a TabView: the TabView drew its own gray panel,
    // cut off against the title bar, with no room above the tabs.
    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()  // natural width, not stretched to the window
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { tabsWidth = $0 }
            .padding(.top, 22)
            .padding(.bottom, 14)
            .padding(.horizontal, Self.sidePadding)

            Group {
                switch page {
                case .card: cardTab
                case .elements: elementsTab
                case .waves: wavesTab
                case .clock: clockTab
                case .position: positionTab
                case .general: generalTab
                }
            }
            .scrollContentBackground(.hidden)
        }
        // The window is exactly as wide as the tab bar plus its side padding. Until the picker has been
        // measured (the first layout pass) a sensible width keeps the form from collapsing.
        .frame(width: tabsWidth > 0 ? tabsWidth + 2 * Self.sidePadding : 480, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Tabs

    private var cardTab: some View {
        Form {
            Section("Size and shape") {
                SliderRow("Scale", $store.config.card.scale, 0.5...2.5, format: "%.2f×")
                SliderRow("Corner radius", $store.config.card.cornerRadius, 0...60, format: "%.0f pt")
            }
            Section("Background") {
                Picker("Type", selection: $store.config.background.kind) {
                    Text("Liquid Glass").tag(BackgroundKind.glass)
                    Text("Frosted blur").tag(BackgroundKind.frosted)
                    Text("None (transparent)").tag(BackgroundKind.none)
                }
                if store.config.background.kind != .none {
                    SliderRow("Opacity", $store.config.background.opacity, 0...1, format: "%.2f")
                }
                if store.config.background.kind == .glass {
                    Picker("Glass style", selection: $store.config.background.style) {
                        ForEach(GlassStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                if store.config.background.kind == .frosted {
                    Picker("Blur material", selection: $store.config.background.frost) {
                        Text("Under window").tag(FrostMaterial.underWindow)
                        Text("Sidebar").tag(FrostMaterial.sidebar)
                        Text("Menu").tag(FrostMaterial.menu)
                        Text("Popover").tag(FrostMaterial.popover)
                        Text("Header").tag(FrostMaterial.header)
                        Text("HUD (strongest)").tag(FrostMaterial.hud)
                    }
                }
                if store.config.background.kind != .none {
                    Toggle("Tint", isOn: tintEnabled)
                    if store.config.background.tintHex != nil {
                        ColorPicker("Tint color", selection: colorBinding(tintHex), supportsOpacity: false)
                        SliderRow("Tint strength", $store.config.background.tintOpacity, 0...1, format: "%.2f")
                    }
                }
            }
            Section("Artwork") {
                Picker("Side", selection: $store.config.card.artworkSide) {
                    ForEach(ArtworkSide.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Fit", selection: $store.config.card.artworkFit) {
                    Text("Whole image").tag(ArtworkFit.fit)
                    Text("Fill a square (crop)").tag(ArtworkFit.fill)
                }
                SliderRow("Size", $store.config.card.artworkSize, 60...200, format: "%.0f pt")
            }
            Section("Color") {
                Picker("Accent", selection: $store.config.accent.mode) {
                    Text("From the artwork").tag(AccentMode.auto)
                    Text("Tinted from the wallpaper").tag(AccentMode.wallpaper)
                    Text("Custom color").tag(AccentMode.manual)
                    Text("Plain (system)").tag(AccentMode.system)
                }
                if store.config.accent.mode == .wallpaper {
                    tintStatus(accentTint, behind: "card")
                }
                if store.config.accent.mode == .manual || (store.config.accent.mode == .wallpaper && accentTint.color == nil) {
                    ColorPicker(store.config.accent.mode == .manual ? "Accent color" : "Fallback color",
                                selection: colorBinding($store.config.accent.hex), supportsOpacity: false)
                }
            }
            Section("Text") {
                Picker("Font", selection: fontBinding($store.config.text.fontName)) {
                    Text("System").tag("")
                    ForEach(Self.fontFamilies, id: \.self) { Text($0).tag($0) }
                }
                SliderRow("Title size", $store.config.text.titleSize, 10...40, format: "%.0f pt")
                SliderRow("Artist size", $store.config.text.artistSize, 8...30, format: "%.0f pt")
            }
            Section {
                Button("Reset Appearance to Defaults", role: .destructive) { store.resetAppearance() }
            } footer: {
                Text("Keeps the card's position and the General settings.")
            }
        }
        .formStyle(.grouped)
    }

    private var elementsTab: some View {
        Form {
            Section("Show on the card") {
                Toggle("Artwork", isOn: $store.config.elements.artwork)
                Toggle("Artist", isOn: $store.config.elements.artist)
                Toggle("Progress bar", isOn: $store.config.elements.progress)
                Toggle("Elapsed and remaining time", isOn: $store.config.elements.times)
                Toggle("Wave bars", isOn: $store.config.elements.waves)
            }
            Section { Text("The title is always shown.").foregroundStyle(.secondary) }
        }
        .formStyle(.grouped)
    }

    private var wavesTab: some View {
        Form {
            Section("Shape") {
                Picker("Style", selection: $store.config.waves.shape) {
                    Text("Bars").tag(WaveShape.bars)
                    Text("Mirrored bars").tag(WaveShape.mirrored)
                    Text("Dots").tag(WaveShape.dots)
                }
                SliderRow("Count", intBinding($store.config.waves.count), 4...48, format: "%.0f")
                SliderRow("Thickness", $store.config.waves.thickness, 2...14, format: "%.0f pt")
                SliderRow("Gap", $store.config.waves.gap, 0...14, format: "%.0f pt")
                SliderRow("Height", $store.config.waves.maxHeight, 8...48, format: "%.0f pt")
                SliderRow("Roundness", $store.config.waves.roundness, 0...1, format: "%.2f")
                Picker("Baseline", selection: $store.config.waves.baseline) {
                    ForEach(WaveBaseline.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            Section("Placement") {
                Picker("Anchor", selection: $store.config.waves.anchor) {
                    Text("In the text column").tag(WaveAnchor.row)
                    Text("Top right of the card").tag(WaveAnchor.topRight)
                    Text("Bottom right of the card").tag(WaveAnchor.bottomRight)
                }
                SliderRow("Offset →", $store.config.waves.offsetX, -200...200, format: "%.0f pt")
                SliderRow("Offset ↓", $store.config.waves.offsetY, -200...200, format: "%.0f pt")
            }
            Section("Color") {
                Picker("Color", selection: $store.config.waves.color) {
                    Text("Follows the accent").tag(WaveColor.accent)
                    Text("Plain (system)").tag(WaveColor.primary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var clockTab: some View {
        Form {
            Section {
                Toggle("Show the clock", isOn: $store.config.clock.enabled)
                Picker("Time format", selection: $store.config.clock.format) {
                    Text("Follow the system").tag(ClockFormat.system)
                    Text("12 hour").tag(ClockFormat.h12)
                    Text("24 hour").tag(ClockFormat.h24)
                }
            } footer: {
                Text("The clock stays on the desktop when nothing is playing.")
            }
            Section {
                SliderRow("Size", $store.config.clock.size, 24...300, format: "%.0f pt")
                Picker("Color", selection: $store.config.clock.colorMode) {
                    Text("Tinted from the wallpaper").tag(ClockColorMode.wallpaper)
                    Text("Custom color").tag(ClockColorMode.custom)
                }
                if store.config.clock.colorMode == .wallpaper {
                    tintStatus(clockTint, behind: "clock")
                }
                if store.config.clock.colorMode == .custom || clockTint.color == nil {
                    ColorPicker(store.config.clock.colorMode == .custom ? "Color" : "Fallback color",
                                selection: colorBinding($store.config.clock.colorHex), supportsOpacity: false)
                }
                SliderRow("Opacity", $store.config.clock.opacity, 0.1...1, format: "%.2f")
                Picker("Font", selection: fontBinding($store.config.clock.fontName)) {
                    Text("System (compressed)").tag("")
                    ForEach(Self.fontFamilies, id: \.self) { Text($0).tag($0) }
                }
            } header: {
                Text("Look")
            } footer: {
                Text("The clock never grows past the player's width or height. A larger size is scaled down to fit.")
            }
            Section("Date") {
                Toggle("Show the date", isOn: $store.config.clock.showDate)
                if store.config.clock.showDate {
                    Picker("Placement", selection: $store.config.clock.datePlacement) {
                        Text("Above the time").tag(ClockDatePlacement.above)
                        Text("Below the time").tag(ClockDatePlacement.below)
                    }
                    .pickerStyle(.segmented)
                    Picker("Alignment", selection: $store.config.clock.dateAlignment) {
                        Text("Left").tag(ClockDateAlignment.left)
                        Text("Center").tag(ClockDateAlignment.center)
                        Text("Right").tag(ClockDateAlignment.right)
                    }
                    .pickerStyle(.segmented)
                    SliderRow("Distance from time", $store.config.clock.dateGap, -100...100, format: "%.0f pt")
                    SliderRow("Shift →", $store.config.clock.dateOffsetX, -200...200, format: "%.0f pt")
                }
            }
            Section("Position around the player") {
                Picker("Anchor", selection: $store.config.clock.anchor) {
                    Section("Left of the card") { anchorOption(.leftTop); anchorOption(.leftCenter); anchorOption(.leftBottom) }
                    Section("Right of the card") { anchorOption(.rightTop); anchorOption(.rightCenter); anchorOption(.rightBottom) }
                    Section("Above the card") { anchorOption(.topLeft); anchorOption(.topCenter); anchorOption(.topRight) }
                    Section("Below the card") { anchorOption(.bottomLeft); anchorOption(.bottomCenter); anchorOption(.bottomRight) }
                }
                SliderRow("Gap", $store.config.clock.gap, 0...200, format: "%.0f pt")
                SliderRow("Offset →", $store.config.clock.offsetX, -400...400, format: "%.0f pt")
                SliderRow("Offset ↓", $store.config.clock.offsetY, -400...400, format: "%.0f pt")
            }
        }
        .formStyle(.grouped)
    }

    private var positionTab: some View {
        Form {
            Section("Place the card") {
                HStack(alignment: .center, spacing: 22) {
                    PositionGrid(selection: positionSelection)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.config.position.anchor?.menuTitle ?? "Custom")
                            .font(.headline)
                        Text(store.config.position.anchor == nil
                             ? "Wherever you dropped it. Drag the card to move it."
                             : "The center of the player and the clock together sits on this point of the rule-of-thirds grid. Pick another point, or choose Custom and drag the card anywhere.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Custom (drag the card)") { store.makePositionCustom() }
                            .disabled(store.config.position.anchor == nil)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
            Section {
                Picker("Display", selection: $store.config.position.display) {
                    Text("Main display").tag(String?.none)
                    ForEach(Self.screens, id: \.uuid) { Text($0.name).tag(Optional($0.uuid)) }
                }
            } footer: {
                Text("Settings opens Edit mode, so the card floats above your windows and can be dragged anywhere.")
            }
            Section("Snapping and edges") {
                Toggle("Snap to a grid point when dropped close to one", isOn: $store.config.position.snap)
                SliderRow("Least distance from the edge", $store.config.position.margin, 0...200, format: "%.0f pt")
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Start at login", isOn: $store.config.general.launchAtLogin)
                Text(login.message).font(.callout).foregroundStyle(.secondary)
            }
            Section {
                SliderRow("Fade out after pause", $store.config.general.pauseTimeout, 5...300, format: "%.0f s")
            } footer: {
                Text("How long a paused track stays on the desktop before the card fades away.")
            }
            Section("Config file") {
                Text(store.fileURL.path).font(.callout).textSelection(.enabled).foregroundStyle(.secondary)
                if let problem = store.problem {
                    Label("\(problem). Using defaults; the original is kept as config.json.bak.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Button("Show in Finder") { store.revealInFinder() }
            }
        }
        .formStyle(.grouped)
        .onAppear { login.refresh() }
    }

    /// What a wallpaper tint is doing, and what to do when it cannot work.
    @ViewBuilder private func tintStatus(_ tint: WallpaperTint, behind subject: String) -> some View {
        switch tint.state {
        case .idle:
            Text("Looking at the wallpaper behind the \(subject)…").font(.callout).foregroundStyle(.secondary)
        case .tinted(let color):
            HStack(spacing: 8) {
                Circle().fill(Color(nsColor: color.nsColor)).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                Text("Tinted \(color.hex) from the wallpaper behind the \(subject)").font(.callout).foregroundStyle(.secondary)
            }
        case .needsPermission:
            VStack(alignment: .leading, spacing: 6) {
                Text("To see the wallpaper behind the \(subject), mini-player needs the Screen Recording permission. It only looks at the wallpaper, never at your windows. After allowing it, quit and reopen mini-player. Until then the fallback color is used.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Privacy Settings") { tint.openPrivacySettings() }
            }
        case .failed(let message):
            Text("Could not read the wallpaper (\(message)). The fallback color is used.")
                .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Helpers

    private func anchorOption(_ anchor: ClockAnchor) -> some View {
        Text(anchor.title).tag(anchor)
    }

    private struct ScreenChoice { let uuid: String; let name: String }

    private static var screens: [ScreenChoice] {
        NSScreen.screens.compactMap { screen in screen.displayUUID.map { ScreenChoice(uuid: $0, name: screen.localizedName) } }
    }

    /// The grid sets a named place. (Custom is its own button, because it has to keep the card where it is.)
    private var positionSelection: Binding<ScreenAnchor?> {
        Binding(get: { store.config.position.anchor },
                set: { if let anchor = $0 { store.config.position.anchor = anchor } })
    }

    private var tintHex: Binding<String> {
        Binding(get: { store.config.background.tintHex ?? "#FFFFFF" }, set: { store.config.background.tintHex = $0 })
    }

    private var tintEnabled: Binding<Bool> {
        Binding(get: { store.config.background.tintHex != nil },
                set: { store.config.background.tintHex = $0 ? "#FFFFFF" : nil })
    }

    private func intBinding(_ source: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(source.wrappedValue) }, set: { source.wrappedValue = Int($0.rounded()) })
    }

    private func fontBinding(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" }, set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: (RGB(hex: hex.wrappedValue) ?? RGB(r: 1, g: 1, b: 1)).nsColor) },
            set: {
                guard let c = NSColor($0).usingColorSpace(.sRGB) else { return }
                hex.wrappedValue = RGB(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent)).hex
            })
    }
}

/// A label, a slider, and its current value.
private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    init(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, format: String) {
        self.title = title
        _value = value
        self.range = range
        self.format = format
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range)
                Text(String(format: format, value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .trailing)
            }
            .frame(maxWidth: 270)
        }
    }
}

extension RawRepresentable where RawValue == String {
    /// `leftCenter` -> `Left center`.
    var title: String {
        var out = ""
        for ch in rawValue {
            if ch.isUppercase { out += " " + ch.lowercased() } else { out.append(ch) }
        }
        return out.prefix(1).uppercased() + out.dropFirst()
    }
}


/// A small map of the screen with the rule-of-thirds lines and the nine points on them. The chosen point shows a
/// little card centered on it: the center of the player and the clock together lands there.
private struct PositionGrid: View {
    @Binding var selection: ScreenAnchor?

    private let width: CGFloat = 220
    private let height: CGFloat = 138

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.quaternary.opacity(0.55))
            RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.quaternary)

            // The two vertical and two horizontal rule-of-thirds lines.
            Path { path in
                for f in [CGFloat(1) / 3, CGFloat(2) / 3] {
                    path.move(to: CGPoint(x: width * f, y: 0))
                    path.addLine(to: CGPoint(x: width * f, y: height))
                    path.move(to: CGPoint(x: 0, y: height * f))
                    path.addLine(to: CGPoint(x: width, y: height * f))
                }
            }
            .stroke(Color.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            ForEach(ScreenAnchor.allCases, id: \.self) { anchor in
                point(anchor)
            }
        }
        .frame(width: width, height: height)
    }

    private func point(_ anchor: ScreenAnchor) -> some View {
        let selected = selection == anchor
        // Row 0 is the top of the screen. `fraction.y` counts from the bottom, so flip it for drawing.
        let f = anchor.fraction
        let x = width * f.x
        let y = height * (1 - f.y)
        return Button { selection = anchor } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 58, height: 22)
                }
                Circle()
                    .fill(selected ? Color.white : Color.secondary.opacity(0.7))
                    .frame(width: selected ? 7 : 9, height: selected ? 7 : 9)
            }
            .frame(width: 64, height: 30)  // a generous click target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .help(anchor.menuTitle)
        .accessibilityLabel(anchor.menuTitle)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
