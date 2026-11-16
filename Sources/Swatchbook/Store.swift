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

    init(name: String, colors: [SwatchColor] = [], notes: String = "", locked: Bool = false) {
        self.name = name
        self.colors = colors
        self.notes = notes
        self.locked = locked
    }

    enum CodingKeys: String, CodingKey { case id, name, colors, notes, locked }

    // Custom decoding so palettes saved by the older version (without notes/locked) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        colors = try c.decodeIfPresent([SwatchColor].self, forKey: .colors) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
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

struct EditorTarget: Identifiable {
    let id = UUID()
    let paletteID: UUID
    let colorID: UUID?       // nil = adding a new color
}

// MARK: - Store (saves to a local JSON file, nothing else)

final class Store: ObservableObject {
    @Published var palettes: [Palette] = [] { didSet { save() } }
    @Published var selectedID: UUID?
    @Published var toast: String?
    @Published var editor: EditorTarget?
    @Published var pendingDelete: UUID?
    @Published var copyFormat: CopyFormat = .hex {
        didSet { UserDefaults.standard.set(copyFormat.rawValue, forKey: "copyFormat") }
    }
    @Published var appearance: AppearanceMode = .dark {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }

    private let fileURL: URL
    private let sampler = NSColorSampler()
    private var toastWork: DispatchWorkItem?

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Swatchbook", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("palettes.json")

        if let raw = UserDefaults.standard.string(forKey: "copyFormat"),
           let f = CopyFormat(rawValue: raw) {
            copyFormat = f
        }
        if let raw = UserDefaults.standard.string(forKey: "appearance"),
           let a = AppearanceMode(rawValue: raw) {
            appearance = a
        }

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

    // MARK: Palette actions

    func addPalette() {
        let p = Palette(name: "New Palette")
        palettes.append(p)
        selectedID = p.id
    }

    func duplicatePalette(_ id: UUID) {
        guard let p = palettes.first(where: { $0.id == id }) else { return }
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

    func deletePalette(_ id: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == id }),
              !palettes[i].locked else { return }
        palettes.remove(at: i)
        if selectedID == id {
            selectedID = palettes.isEmpty ? nil : palettes[min(i, palettes.count - 1)].id
        }
    }

    // MARK: Color actions (all refuse to touch a locked palette)

    func addColor(to paletteID: UUID, hex: String, name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked else { return }
        palettes[i].colors.append(SwatchColor(name: name, hex: hex))
    }

    func updateColor(in paletteID: UUID, colorID: UUID, hex: String, name: String) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked,
              let j = palettes[i].colors.firstIndex(where: { $0.id == colorID }) else { return }
        palettes[i].colors[j].hex = hex
        palettes[i].colors[j].name = name
    }

    func removeColor(in paletteID: UUID, colorID: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked else { return }
        palettes[i].colors.removeAll { $0.id == colorID }
    }

    func moveColor(in paletteID: UUID, moving: UUID, onto target: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == paletteID }),
              !palettes[i].locked,
              let from = palettes[i].colors.firstIndex(where: { $0.id == moving }),
              let to = palettes[i].colors.firstIndex(where: { $0.id == target }),
              from != to else { return }
        let item = palettes[i].colors.remove(at: from)
        palettes[i].colors.insert(item, at: to)
    }

    // MARK: Editor / eyedropper

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
}
