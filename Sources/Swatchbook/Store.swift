import SwiftUI
import AppKit

// MARK: - Hex / color helpers

enum Hex {
    /// Accepts "#7435c7", "7435C7", "#fff" ... returns "7435C7" or nil if invalid.
    static func normalize(_ input: String) -> String? {
        var t = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("#") { t.removeFirst() }
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        guard t.count == 6, t.allSatisfy({ $0.isHexDigit }) else { return nil }
        return t
    }

    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let v = UInt64(hex, radix: 16) ?? 0
        return (Double((v >> 16) & 255) / 255,
                Double((v >> 8) & 255) / 255,
                Double(v & 255) / 255)
    }

    static func from(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

extension Color {
    init(hex: String) {
        let v = Hex.rgb(hex)
        self.init(.sRGB, red: v.r, green: v.g, blue: v.b, opacity: 1)
    }
}

// MARK: - Models

struct SwatchColor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hex: String          // "RRGGBB", no "#"

    var displayName: String { name.isEmpty ? "#" + hex : name }
}

struct Palette: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colors: [SwatchColor] = []
    var notes: String = ""
    var locked: Bool = false
    var pinned: Bool = false
    var lastOpened: Date? = nil

    init(name: String, colors: [SwatchColor] = [], notes: String = "", locked: Bool = false) {
        self.name = name
        self.colors = colors
        self.notes = notes
        self.locked = locked
    }

    enum CodingKeys: String, CodingKey { case id, name, colors, notes, locked, pinned, lastOpened }

    // Custom decoding so palettes saved by older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        colors = try c.decodeIfPresent([SwatchColor].self, forKey: .colors) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        lastOpened = try c.decodeIfPresent(Date.self, forKey: .lastOpened)
    }
}

enum CopyFormat: String, CaseIterable, Identifiable {
    case hex, hexPlain, rgb, hsl
    var id: String { rawValue }

    var label: String {
        switch self {
        case .hex: return "HEX  #7435C7"
        case .hexPlain: return "HEX  7435C7"
        case .rgb: return "RGB  rgb(116, 53, 199)"
        case .hsl: return "HSL  hsl(269, 58%, 49%)"
        }
    }

    var shortLabel: String {
        switch self {
        case .hex: return "#HEX"
        case .hexPlain: return "HEX"
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        }
    }

    func string(for hex: String) -> String {
        let c = Hex.rgb(hex)
        switch self {
        case .hex: return "#" + hex
        case .hexPlain: return hex
        case .rgb:
            return "rgb(\(Int((c.r * 255).rounded())), \(Int((c.g * 255).rounded())), \(Int((c.b * 255).rounded())))"
        case .hsl:
            let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
            let l = (mx + mn) / 2
            var h = 0.0, s = 0.0
            if mx != mn {
                let d = mx - mn
                s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
                if mx == c.r { h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0) }
                else if mx == c.g { h = (c.b - c.r) / d + 2 }
                else { h = (c.r - c.g) / d + 4 }
                h /= 6
            }
            return "hsl(\(Int((h * 360).rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

struct ShortcutSpec: Codable, Equatable {
    var key: String                 // single lowercase character
    var command = false
    var shift = false
    var option = false
    var control = false

    var keyEquivalent: KeyEquivalent? {
        key.first.map { KeyEquivalent($0) }
    }

    var modifiers: EventModifiers {
        var m: EventModifiers = []
        if control { m.insert(.control) }
        if option { m.insert(.option) }
        if shift { m.insert(.shift) }
        if command { m.insert(.command) }
        return m
    }

    var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key.uppercased()
    }

    /// Same as `display` but with a space between every symbol (easier to read).
    var spacedDisplay: String {
        display.map { String($0) }.joined(separator: " ")
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable, Codable {
    case newPalette, addColor, eyedropper, commandPalette, keepOnTop, compactView
    var id: String { rawValue }

    var label: String {
        switch self {
        case .newPalette: return "New palette"
        case .addColor: return "Add color"
        case .eyedropper: return "Pick color from screen"
        case .commandPalette: return "Browse palettes"
        case .keepOnTop: return "Keep on top"
        case .compactView: return "Compact view"
        }
    }

    static var defaults: [ShortcutAction: ShortcutSpec] {
        [
            .newPalette: ShortcutSpec(key: "n", command: true),
            .addColor: ShortcutSpec(key: "n", command: true, option: true),
            .eyedropper: ShortcutSpec(key: "e", command: true, option: true),
            .commandPalette: ShortcutSpec(key: "k", command: true),
            .keepOnTop: ShortcutSpec(key: "t", command: true, option: true),
            .compactView: ShortcutSpec(key: "c", command: true, option: true)
        ]
    }
}

struct EditorTarget: Identifiable {
    let id = UUID()
    let paletteID: UUID
    let colorID: UUID?       // nil = adding a new color
}

// MARK: - Store (saves to local files only, nothing else)

final class Store: ObservableObject {
    @Published var palettes: [Palette] = [] {
        didSet {
            save()
            scheduleSideEffects()
        }
    }
    @Published var selectedID: UUID? {
        didSet { markOpened(selectedID) }
    }
    @Published var toast: String?
    @Published var editor: EditorTarget?
    @Published var pendingDelete: UUID?
    @Published var showPalette = false

    @Published var copyFormat: CopyFormat = .hex {
        didSet { UserDefaults.standard.set(copyFormat.rawValue, forKey: "copyFormat") }
    }
    @Published var shortcuts: [ShortcutAction: ShortcutSpec] = ShortcutAction.defaults {
        didSet { saveShortcuts() }
    }
    @Published var appearance: AppearanceMode = .dark {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }
    @Published var autoNames = true {
        didSet { UserDefaults.standard.set(autoNames, forKey: "autoNames") }
    }

    // Window behavior
    @Published var keepOnTop = false {
        didSet {
            UserDefaults.standard.set(keepOnTop, forKey: "keepOnTop")
            applyWindowState()
        }
    }
    @Published var compact = false {
        didSet {
            showPalette = false
            applyCompact()
        }
    }

    // System color picker
    @Published var syncSystemColors = true {
        didSet {
            UserDefaults.standard.set(syncSystemColors, forKey: "syncSystemColors")
            lastColorSignature = ""
            syncColorLists()
        }
    }

    // Backups
    @Published var backupEnabled = false {
        didSet {
            UserDefaults.standard.set(backupEnabled, forKey: "backupEnabled")
            if backupEnabled { runBackupIfNeeded(force: true) }
        }
    }
    @Published var backupFolderPath = "" {
        didSet { UserDefaults.standard.set(backupFolderPath, forKey: "backupFolder") }
    }
    @Published var backupKeep = 20 {
        didSet { UserDefaults.standard.set(backupKeep, forKey: "backupKeep") }
    }
    @Published var lastBackup: Date?

    weak var undoManager: UndoManager?
    weak var mainWindow: NSWindow?

    private let fileURL: URL
    private let sampler = NSColorSampler()
    private var toastWork: DispatchWorkItem?
    private var sideEffectWork: DispatchWorkItem?
    private var lastBackupData: Data?
    private var lastColorSignature = ""
    private var expandedSize: NSSize?
    private var pasteMonitor: Any?

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Swatchbook", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("palettes.json")

        let d = UserDefaults.standard
        if let raw = d.string(forKey: "copyFormat"), let f = CopyFormat(rawValue: raw) { copyFormat = f }
        if let raw = d.string(forKey: "appearance"), let a = AppearanceMode(rawValue: raw) { appearance = a }
        if d.object(forKey: "autoNames") != nil { autoNames = d.bool(forKey: "autoNames") }
        if d.object(forKey: "syncSystemColors") != nil { syncSystemColors = d.bool(forKey: "syncSystemColors") }
        keepOnTop = d.bool(forKey: "keepOnTop")
        backupEnabled = d.bool(forKey: "backupEnabled")
        backupFolderPath = d.string(forKey: "backupFolder") ?? ""
        let keep = d.integer(forKey: "backupKeep")
        if keep > 0 { backupKeep = keep }
        loadShortcuts()

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode([Palette].self, from: data) {
                palettes = decoded
            }
        } else {
            // First launch: a starter palette with your two calendar colors.
            palettes = [
                Palette(name: "Calendar", colors: [
                    SwatchColor(name: "Purple Heart", hex: "7435C7"),
                    SwatchColor(name: "New Car", hex: "2C50D0")
                ])
            ]
            save()
        }
        selectedID = palettes.first?.id
        applyAppearance()

        installPasteMonitor()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.runBackupIfNeeded()
        }
        DispatchQueue.main.async { [weak self] in self?.syncColorLists() }
    }

    func applyAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(palettes) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Queries

    var selected: Palette? { palettes.first { $0.id == selectedID } }

    func isLocked(_ id: UUID) -> Bool {
        palettes.first { $0.id == id }?.locked ?? false
    }

    func nameBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { self.palettes.first { $0.id == id }?.name ?? "" },
            set: { newValue in
                if let i = self.palettes.firstIndex(where: { $0.id == id }),
                   !self.palettes[i].locked {
                    self.palettes[i].name = newValue
                }
            }
        )
    }

    func notesBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { self.palettes.first { $0.id == id }?.notes ?? "" },
            set: { newValue in
                if let i = self.palettes.firstIndex(where: { $0.id == id }),
                   !self.palettes[i].locked {
                    self.palettes[i].notes = newValue
                }
            }
        )
    }

    // MARK: Undo support (shows up in Edit ▸ Undo / Redo, ⌘Z / ⇧⌘Z)

    func registerColorsUndo(_ paletteID: UUID, _ name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }) else { return }
        let old = palettes[i].colors
        undoManager?.registerUndo(withTarget: self) { target in
            target.setColors(old, for: paletteID, name: name)
        }
        undoManager?.setActionName(name)
    }

    private func setColors(_ colors: [SwatchColor], for paletteID: UUID, name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }) else { return }
        registerColorsUndo(paletteID, name)      // registers the redo step
        palettes[i].colors = colors
    }

    func registerPalettesUndo(_ name: String) {
        let old = palettes
        let oldSelected = selectedID
        undoManager?.registerUndo(withTarget: self) { target in
            target.setPalettes(old, selected: oldSelected, name: name)
        }
        undoManager?.setActionName(name)
    }

    private func setPalettes(_ list: [Palette], selected: UUID?, name: String) {
        registerPalettesUndo(name)               // registers the redo step
        palettes = list
        selectedID = list.contains { $0.id == selected } ? selected : list.first?.id
    }

    // MARK: Palette actions

    func addPalette() {
        registerPalettesUndo("New Palette")
        let p = Palette(name: "New Palette")
        palettes.append(p)
        selectedID = p.id
    }

    func createPalette(named name: String) {
        registerPalettesUndo("New Palette")
        let p = Palette(name: name)
        palettes.append(p)
        selectedID = p.id
    }

    func duplicatePalette(_ id: UUID) {
        guard let p = palettes.first(where: { $0.id == id }) else { return }
        registerPalettesUndo("Duplicate Palette")
        var copy = Palette(name: p.name + " Copy", notes: p.notes)
        copy.colors = p.colors.map { SwatchColor(name: $0.name, hex: $0.hex) }
        palettes.append(copy)
        selectedID = copy.id
    }

    func toggleLock(_ id: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[i].locked.toggle()
        showToast(palettes[i].locked ? "Palette locked" : "Palette unlocked")
    }

    func togglePin(_ id: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[i].pinned.toggle()
    }

    func deletePalette(_ id: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == id }),
              !palettes[i].locked else { return }
        registerPalettesUndo("Delete Palette")
        palettes.remove(at: i)
        if selectedID == id {
            selectedID = palettes.isEmpty ? nil : palettes[min(i, palettes.count - 1)].id
        }
    }

    // MARK: Recents (used by the command palette)

    private func markOpened(_ id: UUID?) {
        guard let id = id, let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[i].lastOpened = Date()
    }

    /// Current palette first, then pinned, then most recently opened, then original order.
    var rankedPalettes: [Palette] {
        let indexed = Array(palettes.enumerated())
        let sorted = indexed.sorted { a, b in
            let aCurrent = a.element.id == selectedID
            let bCurrent = b.element.id == selectedID
            if aCurrent != bCurrent { return aCurrent }
            if a.element.pinned != b.element.pinned { return a.element.pinned }
            let aDate = a.element.lastOpened ?? Date.distantPast
            let bDate = b.element.lastOpened ?? Date.distantPast
            if aDate != bDate { return aDate > bDate }
            return a.offset < b.offset
        }
        return sorted.map { $0.element }
    }

    // MARK: Color actions (all refuse to touch a locked palette)

    func addColor(to paletteID: UUID, hex: String, name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked else { return }
        registerColorsUndo(paletteID, "Add Color")
        var finalName = name
        if finalName.isEmpty && autoNames { finalName = ColorNamer.name(for: hex) }
        palettes[i].colors.append(SwatchColor(name: finalName, hex: hex))
    }

    func updateColor(in paletteID: UUID, colorID: UUID, hex: String, name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked,
              let j = palettes[i].colors.firstIndex(where: { $0.id == colorID }) else { return }
        registerColorsUndo(paletteID, "Edit Color")
        var finalName = name
        if finalName.isEmpty && autoNames { finalName = ColorNamer.name(for: hex) }
        palettes[i].colors[j].hex = hex
        palettes[i].colors[j].name = finalName
    }

    func removeColor(in paletteID: UUID, colorID: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked else { return }
        registerColorsUndo(paletteID, "Delete Color")
        palettes[i].colors.removeAll { $0.id == colorID }
    }

    func moveColor(in paletteID: UUID, moving: UUID, onto target: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked,
              let from = palettes[i].colors.firstIndex(where: { $0.id == moving }),
              let to = palettes[i].colors.firstIndex(where: { $0.id == target }),
              from != to else { return }
        registerColorsUndo(paletteID, "Move Color")
        let item = palettes[i].colors.remove(at: from)
        palettes[i].colors.insert(item, at: to)
    }

    // MARK: Editor / eyedropper / paste

    func addColorToSelected() {
        guard let pid = selectedID else { return }
        if isLocked(pid) { showToast("Palette is locked"); return }
        editor = EditorTarget(paletteID: pid, colorID: nil)
    }

    func pick(_ completion: @escaping (String) -> Void) {
        sampler.show { color in
            guard let color = color else { return }
            DispatchQueue.main.async { completion(Hex.from(color)) }
        }
    }

    func pickIntoSelected() {
        guard let pid = selectedID else { return }
        if isLocked(pid) { showToast("Palette is locked"); return }
        pick { hex in
            self.addColor(to: pid, hex: hex, name: "")
            self.showToast("Added #\(hex)")
        }
    }

    /// Reads colors (#HEX, rgb(), hsl()) from the clipboard and adds them to the selected palette.
    @discardableResult
    func pasteColorsFromClipboard() -> Bool {
        guard let text = NSPasteboard.general.string(forType: .string) else { return false }
        let hexes = Array(ColorParser.extract(text).prefix(100))
        guard !hexes.isEmpty, let pid = selectedID else { return false }
        if isLocked(pid) { showToast("Palette is locked"); return true }
        for hex in hexes { addColor(to: pid, hex: hex, name: "") }
        showToast(hexes.count == 1 ? "Pasted #\(hexes[0])" : "Pasted \(hexes.count) colors")
        return true
    }

    private func installPasteMonitor() {
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command), !flags.contains(.shift),
                  !flags.contains(.option), !flags.contains(.control),
                  event.charactersIgnoringModifiers?.lowercased() == "v" else { return event }
            if self.showPalette || self.editor != nil { return event }
            if let window = NSApp.keyWindow, window.title.contains("Settings") { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }   // normal text paste
            return self.pasteColorsFromClipboard() ? nil : event
        }
    }

    // MARK: Clipboard + toast

    func copy(_ hex: String) {
        copy(hex, as: copyFormat)
    }

    func copy(_ hex: String, as format: CopyFormat) {
        let text = format.string(for: hex)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("Copied \(text)")
    }

    func showToast(_ text: String) {
        toast = text
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    // MARK: Shortcuts

    /// Assign (or clear, with nil) a shortcut. If another action already uses it, that one is cleared.
    func setShortcut(_ spec: ShortcutSpec?, for action: ShortcutAction) {
        var updated = shortcuts
        if let spec = spec {
            for (other, existing) in shortcuts where existing == spec && other != action {
                updated[other] = nil
            }
            updated[action] = spec
        } else {
            updated[action] = nil
        }
        shortcuts = updated
    }

    func resetShortcuts() {
        shortcuts = ShortcutAction.defaults
    }

    private func loadShortcuts() {
        let d = UserDefaults.standard
        guard let data = d.data(forKey: "shortcuts"),
              let raw = try? JSONDecoder().decode([String: ShortcutSpec].self, from: data) else { return }
        var loaded: [ShortcutAction: ShortcutSpec] = [:]
        for (k, v) in raw {
            if let a = ShortcutAction(rawValue: k) { loaded[a] = v }
        }
        // Actions added in newer versions get their default shortcut (unless it would clash).
        let known = Set(d.stringArray(forKey: "knownShortcutActions")
                        ?? ["newPalette", "addColor", "eyedropper", "commandPalette"])
        let defs = ShortcutAction.defaults
        for action in ShortcutAction.allCases where !known.contains(action.rawValue) {
            if let spec = defs[action], !loaded.values.contains(spec) { loaded[action] = spec }
        }
        shortcuts = loaded
    }

    private func saveShortcuts() {
        var raw: [String: ShortcutSpec] = [:]
        for (action, spec) in shortcuts { raw[action.rawValue] = spec }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: "shortcuts")
            UserDefaults.standard.set(ShortcutAction.allCases.map { $0.rawValue }, forKey: "knownShortcutActions")
        }
    }

    func helpText(_ text: String, _ action: ShortcutAction) -> String {
        if let s = shortcuts[action] { return "\(text) (\(s.display))" }
        return text
    }

    // MARK: Window: keep on top + compact view

    func attach(window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
        applyWindowState()
        if compact {
            applyCompact()
        } else if let content = window.contentView, content.frame.width < 800 {
            window.setContentSize(NSSize(width: 1000, height: 680))
        }
    }

    func applyWindowState() {
        guard let w = mainWindow else { return }
        w.level = keepOnTop ? .floating : .normal
        if keepOnTop {
            w.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
        } else {
            w.collectionBehavior.subtract([.canJoinAllSpaces, .fullScreenAuxiliary])
        }
    }

    private func applyCompact() {
        guard let w = mainWindow else { return }
        if compact {
            if let size = w.contentView?.frame.size, size.width > 500 { expandedSize = size }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainWindow?.setContentSize(NSSize(width: 360, height: 620))
            }
        } else {
            let size = expandedSize ?? NSSize(width: 1000, height: 680)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mainWindow?.setContentSize(size)
            }
        }
    }

    // MARK: Background work (backups + system color lists), debounced

    private func scheduleSideEffects() {
        sideEffectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.runBackupIfNeeded()
            self?.syncColorLists()
        }
        sideEffectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    // MARK: Backups

    var backupFolder: URL? {
        backupFolderPath.isEmpty ? nil : URL(fileURLWithPath: backupFolderPath, isDirectory: true)
    }

    /// JSON for backups. "Last opened" dates are left out so simply browsing doesn't create backups.
    private func backupData() -> Data? {
        var list = palettes
        for i in list.indices { list[i].lastOpened = nil }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(ExportFile(palettes: list))
    }

    func runBackupIfNeeded(force: Bool = false) {
        guard backupEnabled, let folder = backupFolder, let data = backupData() else { return }
        if !force && data == lastBackupData { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = folder.appendingPathComponent("Swatchbook-Backup-\(f.string(from: Date())).json")
        do {
            try data.write(to: url, options: .atomic)
            lastBackupData = data
            lastBackup = Date()
            pruneBackups(in: folder)
        } catch {
            showToast("Backup failed. Check the backup folder.")
        }
    }

    private func pruneBackups(in folder: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("Swatchbook-Backup-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }      // newest first
        if backups.count > backupKeep {
            for old in backups.dropFirst(backupKeep) { try? fm.removeItem(at: old) }
        }
    }

    func chooseBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose a folder for your Swatchbook backups"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        backupFolderPath = url.path
        backupEnabled = true          // also makes a first backup right away
        if backupEnabled { showToast("Backups will be saved there") }
    }

    func revealBackupFolder() {
        if let folder = backupFolder { NSWorkspace.shared.open(folder) }
    }

    func backUpNow() {
        guard backupFolder != nil else { showToast("Choose a backup folder first"); return }
        let wasEnabled = backupEnabled
        backupEnabled = true
        if wasEnabled { runBackupIfNeeded(force: true) }
        showToast("Backup saved")
    }

    func restoreFromBackup() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Swatchbook backup (.json) to restore"
        if let folder = backupFolder { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let list = Importer.decodeSwatchbook(data) else {
            showToast("That isn't a Swatchbook backup")
            return
        }
        let alert = NSAlert()
        alert.messageText = "Replace all palettes with this backup?"
        alert.informativeText = "\(list.count) palette\(list.count == 1 ? "" : "s") will replace your current ones. You can undo this with ⌘Z."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runBackupIfNeeded(force: true)           // safety copy of what you have right now
        registerPalettesUndo("Restore Backup")
        palettes = list
        selectedID = list.first?.id
        showToast("Backup restored")
    }

    // MARK: System color picker (writes color lists to ~/Library/Colors)

    func syncColorLists() {
        let fm = FileManager.default
        let d = UserDefaults.standard
        let dir = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Colors", isDirectory: true)
        let written = d.stringArray(forKey: "writtenColorLists") ?? []

        guard syncSystemColors else {
            for name in written { try? fm.removeItem(at: dir.appendingPathComponent(name + ".clr")) }
            d.set([String](), forKey: "writtenColorLists")
            return
        }

        var lists: [(name: String, palette: Palette)] = []
        var usedNames = Set<String>()
        for p in palettes where !p.colors.isEmpty {
            let base = ("Swatchbook – " + (p.name.isEmpty ? "Untitled" : p.name))
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            var name = base
            var n = 2
            while usedNames.contains(name) { name = "\(base) \(n)"; n += 1 }
            usedNames.insert(name)
            lists.append((name: name, palette: p))
        }

        let signature = lists.map { item in
            item.name + "|" + item.palette.colors.map { $0.displayName + $0.hex }.joined(separator: ",")
        }.joined(separator: ";")
        if signature == lastColorSignature { return }
        lastColorSignature = signature

        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for item in lists {
            let list = NSColorList(name: item.name)
            var keys = Set<String>()
            for (i, c) in item.palette.colors.enumerated() {
                var key = c.displayName
                var n = 2
                while keys.contains(key) { key = "\(c.displayName) \(n)"; n += 1 }
                keys.insert(key)
                let v = Hex.rgb(c.hex)
                let color = NSColor(srgbRed: CGFloat(v.r), green: CGFloat(v.g), blue: CGFloat(v.b), alpha: 1)
                list.insertColor(color, key: key, at: i)
            }
            try? list.write(to: dir.appendingPathComponent(item.name + ".clr"))
        }
        for name in written where !usedNames.contains(name) {
            try? fm.removeItem(at: dir.appendingPathComponent(name + ".clr"))
        }
        d.set(Array(usedNames).sorted(), forKey: "writtenColorLists")
    }
}
