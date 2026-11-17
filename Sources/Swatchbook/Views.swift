import SwiftUI
import AppKit

// MARK: - Theme (colors adapt automatically to Light / Dark)

extension NSColor {
    convenience init(hexString: String) {
        let v = Hex.rgb(hexString)
        self.init(srgbRed: CGFloat(v.r), green: CGFloat(v.g), blue: CGFloat(v.b), alpha: 1)
    }
}

extension Color {
    static func adaptive(dark: String, light: String) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hexString: isDark ? dark : light)
        }))
    }
}

extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

enum Theme {
    static let bg = Color.adaptive(dark: "121214", light: "F6F6F8")
    static let sidebar = Color.adaptive(dark: "0D0D0F", light: "ECECF0")
    static let card = Color.adaptive(dark: "1A1A1D", light: "FFFFFF")
    static let cardHover = Color.adaptive(dark: "232327", light: "EEEEF3")
    static let toast = Color.adaptive(dark: "2A2A2F", light: "FFFFFF")
    static let panel = Color.adaptive(dark: "1C1C20", light: "FFFFFF")
    static let stroke = Color.primary.opacity(0.10)
    static let accent = Color(hex: "FF6363")      // Raycast-style red
    static let text2 = Color.primary.opacity(0.5)
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(prominent ? Theme.accent : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct IconButtonStyle: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(active ? Color.white : Color.primary.opacity(0.8))
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(active ? Theme.accent
                                     : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ZStack(alignment: .bottom) {
            if store.compact {
                CompactView()
            } else {
                HStack(spacing: 0) {
                    SidebarView().frame(width: 250)
                    DetailView()
                }
            }
            if store.showPalette && !store.compact {
                CommandPaletteView()
                    .transition(.opacity)
            }
            if let t = store.toast {
                ToastView(text: t)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.toast)
        .animation(.easeOut(duration: 0.12), value: store.showPalette)
        .onAppear {
            store.applyAppearance()
            store.undoManager = undoManager
        }
        .background(WindowAccessor { window in store.attach(window: window) })
        .sheet(item: $store.editor) { target in
            ColorEditorSheet(target: target)
        }
        .confirmationDialog(
            "Delete this palette?",
            isPresented: Binding(
                get: { store.pendingDelete != nil },
                set: { if !$0 { store.pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = store.pendingDelete { store.deletePalette(id) }
                store.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { store.pendingDelete = nil }
        }
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Theme.toast))
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

// MARK: - Settings window (⌘,)

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            DataSettings()
                .tabItem { Label("Backup & Data", systemImage: "externaldrive") }
        }
        .frame(width: 620, height: 540)
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Picker("Appearance", selection: $store.appearance) {
                ForEach(AppearanceMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Picker("Click a color to copy as", selection: $store.copyFormat) {
                ForEach(CopyFormat.allCases) { f in
                    Text(f.label).tag(f)
                }
            }

            Toggle("Keep window on top of other apps", isOn: $store.keepOnTop)
            Toggle("Suggest color names automatically", isOn: $store.autoNames)
            Toggle("Show Swatchbook in the menu bar", isOn: $store.menuBarEnabled)
            Toggle("Add colors picked from the menu bar to the selected palette", isOn: $store.menuBarAddsColor)
                .disabled(!store.menuBarEnabled)
        }
        .padding(28)
    }
}

struct ShortcutSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ShortcutAction.allCases) { action in
                HStack {
                    Text(action.label)
                        .font(.system(size: 15))
                    Spacer()
                    ShortcutRecorder(action: action)
                }
            }

            Spacer()

            HStack(alignment: .top) {
                Text("Click a shortcut, then press the new keys. Esc cancels.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Restore Defaults") { store.resetShortcuts() }
            }
        }
        .padding(28)
    }
}

struct DataSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                // Import / export
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import & export").font(.headline)
                    Text("Import palettes from Swatchbook (.json), Adobe (.ase), macOS (.clr) or any text/CSS file with #hex colors.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Import Palettes…") { store.importPalettes() }
                        Menu("Export All Palettes…") {
                            ForEach(ExportFormat.allCases) { f in
                                Button(f.label) { store.exportPalettes(all: true, format: f) }
                            }
                        }
                        .fixedSize()
                    }
                }

                Divider()

                // Backups
                VStack(alignment: .leading, spacing: 10) {
                    Text("Automatic backups").font(.headline)
                    Text("Each time you edit your palettes, a backup copy is saved in the folder you choose. Once you pass the limit below, the oldest copies are deleted.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(store.backupFolderPath.isEmpty ? "No folder chosen" : store.backupFolderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(store.backupFolderPath.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button("Choose Folder…") { store.chooseBackupFolder() }
                        Button("Show") { store.revealBackupFolder() }
                            .disabled(store.backupFolderPath.isEmpty)
                    }

                    Toggle("Back up automatically", isOn: $store.backupEnabled)
                        .disabled(store.backupFolderPath.isEmpty)

                    Stepper("Keep the last \(store.backupKeep) backups",
                            value: $store.backupKeep, in: 5...200, step: 5)

                    HStack {
                        Button("Back Up Now") { store.backUpNow() }
                            .disabled(store.backupFolderPath.isEmpty)
                        Button("Restore from Backup…") { store.restoreFromBackup() }
                        if let d = store.lastBackup {
                            Text("Last backup: " + d.formatted(date: .omitted, time: .shortened))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // System color picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("macOS color picker").font(.headline)
                    Toggle("Show my palettes in the macOS color picker", isOn: $store.syncSystemColors)
                    Text("Your palettes appear as color lists (named “Swatchbook – …”) in the Color Palettes tab of every app's color panel. If a list doesn't show up, close and reopen the color panel.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Palettes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text2)
                Spacer()
                HStack(spacing: 6) {
                    Button { store.showPalette = true } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(IconButtonStyle())
                        .help(store.helpText("Browse palettes", .commandPalette))
                    Button { store.addPalette() } label: { Image(systemName: "plus") }
                        .buttonStyle(IconButtonStyle())
                        .help(store.helpText("New palette", .newPalette))
                }
            }
            .padding(.top, 42)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.palettes) { p in
                        PaletteRow(palette: p, isSelected: p.id == store.selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedID = p.id }
                            .contextMenu {
                                Button(p.locked ? "Unlock" : "Lock") { store.toggleLock(p.id) }
                                Button("Duplicate") { store.duplicatePalette(p.id) }
                                Divider()
                                Button("Delete…") { store.pendingDelete = p.id }
                                    .disabled(p.locked)
                            }
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer().frame(height: 12)
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
        .overlay(Rectangle().fill(Theme.stroke).frame(width: 1), alignment: .trailing)
    }
}

struct PaletteRow: View {
    let palette: Palette
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                if palette.colors.isEmpty {
                    Color.primary.opacity(0.1)
                } else {
                    ForEach(Array(palette.colors.prefix(4))) { c in
                        Color(hex: c.hex)
                    }
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(palette.name.isEmpty ? "Untitled" : palette.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text2)
            }
            Spacer()
            if palette.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
        )
    }
}

// MARK: - Detail

struct DetailView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Group {
            if let p = store.selected {
                PaletteDetail(palette: p).id(p.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.text2)
                    Text("No palette selected")
                        .font(.system(size: 15, weight: .semibold))
                    Button("New Palette") { store.addPalette() }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            WindowControls()
                .padding(.top, 10)
                .padding(.trailing, 16)
        }
    }
}

struct PaletteDetail: View {
    let palette: Palette
    @EnvironmentObject var store: Store

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                // Combined strip preview
                if !palette.colors.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(palette.colors) { c in
                            Color(hex: c.hex)
                        }
                    }
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.10)))
                }

                // Color grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(palette.colors) { c in
                        ColorCard(paletteID: palette.id, color: c, locked: palette.locked)
                    }
                    if !palette.locked {
                        AddTile()
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.text2)
                    NotesBox(palette: palette)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 44)
            .padding(.bottom, 28)
        }
    }

    // MARK: Header (adapts to the window width)

    private var subtitle: String {
        "\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")  ·  click a color to copy"
            + (palette.locked ? "  ·  locked" : "")
    }

    /// Palette name + subtitle. Flexible in width, but reports a sensible ideal width
    /// so `ViewThatFits` below can tell which layout fits.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if palette.locked {
                Text(palette.name.isEmpty ? "Untitled" : palette.name)
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else {
                TextField("Palette name", text: store.nameBinding(palette.id))
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold))
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
        }
        .frame(minWidth: 120, idealWidth: 260, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pillLabel(_ title: String, _ icon: String, iconOnly: Bool) -> some View {
        if iconOnly {
            Image(systemName: icon)
        } else {
            Label(title, systemImage: icon)
        }
    }

    private func actionButtons(iconOnly: Bool) -> some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Copy format", selection: $store.copyFormat) {
                    ForEach(CopyFormat.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Text(iconOnly ? store.copyFormat.shortLabel : "Copy as \(store.copyFormat.shortLabel)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if !palette.locked {
                Button { store.pickIntoSelected() } label: {
                    pillLabel("Pick", "eyedropper", iconOnly: iconOnly)
                }
                .buttonStyle(PillButtonStyle())
                .fixedSize()
                .help(store.helpText("Pick a color from anywhere on screen", .eyedropper))

                Button { store.addColorToSelected() } label: {
                    pillLabel("Add Color", "plus", iconOnly: iconOnly)
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .fixedSize()
                .help(store.helpText("Add a color", .addColor))
            }

            Button { store.toggleLock(palette.id) } label: {
                pillLabel(palette.locked ? "Locked" : "Lock",
                          palette.locked ? "lock.fill" : "lock.open",
                          iconOnly: iconOnly)
            }
            .buttonStyle(PillButtonStyle())
            .fixedSize()
            .help(palette.locked ? "Unlock this palette to edit it" : "Lock this palette so it can't be edited")

            if !palette.locked {
                Button { store.pendingDelete = palette.id } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(PillButtonStyle())
                .fixedSize()
                .help("Delete palette")
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            // 1. Wide window: everything on one row
            HStack(alignment: .top, spacing: 12) {
                titleBlock
                actionButtons(iconOnly: false)
            }
            // 2. Narrower: buttons move under the title
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                actionButtons(iconOnly: false)
            }
            // 3. Very narrow: icon-only buttons under the title
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                actionButtons(iconOnly: true)
            }
        }
    }
}

struct NotesBox: View {
    let palette: Palette
    @EnvironmentObject var store: Store

    var body: some View {
        Group {
            if palette.locked {
                Text(palette.notes.isEmpty ? "No notes." : palette.notes)
                    .font(.system(size: 13))
                    .foregroundColor(palette.notes.isEmpty ? Theme.text2 : Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .frame(minHeight: 80, alignment: .topLeading)
            } else {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: store.notesBinding(palette.id))
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 13))
                        .padding(6)
                    if palette.notes.isEmpty {
                        Text("Where do you use this palette? Add any notes here…")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.text2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 110)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke))
    }
}

struct AddTile: View {
    @EnvironmentObject var store: Store
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
            Text("Add color").font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(hover ? Color.primary : Theme.text2)
        .frame(maxWidth: .infinity)
        .frame(height: 134)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(hover ? 0.3 : 0.15),
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { store.addColorToSelected() }
    }
}

struct ColorCard: View {
    let paletteID: UUID
    let color: SwatchColor
    let locked: Bool
    @EnvironmentObject var store: Store
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: color.hex))
                .frame(height: 84)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(color.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("#" + color.hex)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.text2)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(hover ? Theme.cardHover : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { store.copy(color.hex) }
        .contextMenu {
            Button("Copy #HEX") { store.copy(color.hex, as: .hex) }
            Button("Copy RGB") { store.copy(color.hex, as: .rgb) }
            Button("Copy HSL") { store.copy(color.hex, as: .hsl) }
            if !locked {
                Divider()
                Button("Edit…") {
                    store.editor = EditorTarget(paletteID: paletteID, colorID: color.id)
                }
                Button("Delete") { store.removeColor(in: paletteID, colorID: color.id) }
            }
        }
        .applyIf(!locked) { view in
            view.draggable(color.id.uuidString)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let moving = UUID(uuidString: s) else { return false }
            store.moveColor(in: paletteID, moving: moving, onto: color.id)
            return true
        }
    }
}

// MARK: - Add / edit color sheet

struct ColorEditorSheet: View {
    let target: EditorTarget
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hex = "7435C7"
    @State private var picked = Color(hex: "7435C7")

    private var valid: String? { Hex.normalize(hex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(target.colorID == nil ? "Add Color" : "Edit Color")
                .font(.system(size: 17, weight: .semibold))

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: valid ?? "000000"))
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))

            field("Name (optional)") {
                TextField(store.autoNames ? ColorNamer.name(for: valid ?? "000000") : "e.g. Work calendar", text: $name)
                    .textFieldStyle(.plain)
            }

            field("Hex") {
                HStack(spacing: 8) {
                    Text("#").foregroundColor(Theme.text2)
                    TextField("7435C7", text: $hex)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                    ColorPicker("", selection: $picked, supportsOpacity: false)
                        .labelsHidden()
                    Button {
                        store.pick { newHex in hex = newHex }
                    } label: {
                        Image(systemName: "eyedropper")
                    }
                    .buttonStyle(.plain)
                    .help("Pick a color from the screen")
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(PillButtonStyle())
                Button(target.colorID == nil ? "Add" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(valid == nil)
            }
        }
        .padding(22)
        .frame(width: 340)
        .background(Theme.bg)
        .onAppear { loadExisting() }
        .onChange(of: picked) { newColor in
            let h = Hex.from(NSColor(newColor))
            if h != valid { hex = h }
        }
        .onChange(of: hex) { _ in
            if let v = valid { picked = Color(hex: v) }
        }
    }

    private func loadExisting() {
        guard let cid = target.colorID,
              let p = store.palettes.first(where: { $0.id == target.paletteID }),
              let c = p.colors.first(where: { $0.id == cid }) else { return }
        name = c.name
        hex = c.hex
        picked = Color(hex: c.hex)
    }

    private func save() {
        guard let h = valid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cid = target.colorID {
            store.updateColor(in: target.paletteID, colorID: cid, hex: h, name: trimmed)
        } else {
            store.addColor(to: target.paletteID, hex: h, name: trimmed)
        }
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.text2)
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke))
        }
    }
}

// MARK: - Menu shortcut helper

extension View {
    /// Applies a user-customizable keyboard shortcut (or none, if it was cleared).
    @ViewBuilder
    func appShortcut(_ spec: ShortcutSpec?) -> some View {
        if let spec = spec, let key = spec.keyEquivalent {
            self.keyboardShortcut(key, modifiers: spec.modifiers)
        } else {
            self
        }
    }
}

// MARK: - Shortcut recorder (used in Settings)

struct ShortcutRecorder: View {
    let action: ShortcutAction
    @EnvironmentObject var store: Store
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if recording { stop() } else { start() }
            } label: {
                Text(recording ? "Type shortcut…" : (store.shortcuts[action]?.spacedDisplay ?? "None"))
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(recording ? 0 : 5)
                    .frame(minWidth: 190, minHeight: 30)
            }
            .controlSize(.large)

            if store.shortcuts[action] != nil && !recording {
                Button {
                    store.setShortcut(nil, for: action)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Clear this shortcut")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels
            if event.keyCode == 53 {
                stop()
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
            guard hasModifier,
                  let chars = event.charactersIgnoringModifiers?.lowercased(),
                  let scalar = chars.unicodeScalars.first,
                  !(0xF700...0xF8FF).contains(Int(scalar.value)) else {
                return nil   // ignore keys without a modifier, arrows, etc.
            }
            let spec = ShortcutSpec(key: String(chars.prefix(1)),
                                    command: flags.contains(.command),
                                    shift: flags.contains(.shift),
                                    option: flags.contains(.option),
                                    control: flags.contains(.control))
            store.setShortcut(spec, for: action)
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        recording = false
    }
}

// MARK: - Command palette (browse palettes)

struct CommandPaletteView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var highlighted = 0
    @State private var monitor: Any?
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ p: Palette, _ q: String) -> Bool {
        if p.name.lowercased().contains(q) { return true }
        if p.notes.lowercased().contains(q) { return true }
        let hexQ = q.replacingOccurrences(of: "#", with: "")
        for c in p.colors {
            if c.name.lowercased().contains(q) { return true }
            if !hexQ.isEmpty && c.hex.lowercased().contains(hexQ) { return true }
        }
        return false
    }

    private var results: [Palette] {
        let q = trimmed.lowercased()
        let ranked = store.rankedPalettes
        if q.isEmpty { return ranked }
        return ranked.filter { matches($0, q) }
    }

    private var createName: String? {
        guard !trimmed.isEmpty else { return nil }
        let exists = store.palettes.contains { $0.name.lowercased() == trimmed.lowercased() }
        return exists ? nil : trimmed
    }

    private var rowCount: Int { results.count + (createName == nil ? 0 : 1) }

    var body: some View {
        ZStack(alignment: .top) {
            // Invisible layer: clicking outside the panel closes it
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                TextField("Search for palettes…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($focused)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack {
                    Text("Palettes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(results.count)/\(store.palettes.count) Palettes")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .help("↑ ↓ to move, Return to open, Esc to close. Pinned palettes stay at the top.")
                }
                .foregroundColor(Theme.text2)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, p in
                                PaletteResultRow(
                                    palette: p,
                                    isHighlighted: index == highlighted,
                                    isCurrent: p.id == store.selectedID,
                                    onPin: {
                                        store.togglePin(p.id)
                                        if let newIndex = results.firstIndex(where: { $0.id == p.id }) {
                                            highlighted = newIndex
                                        }
                                    },
                                    onDelete: {
                                        close()
                                        store.pendingDelete = p.id
                                    }
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    highlighted = index
                                    activate()
                                }
                            }
                            if let name = createName {
                                CreateResultRow(name: name, isHighlighted: highlighted == results.count)
                                    .id(results.count)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        highlighted = results.count
                                        activate()
                                    }
                            }
                            if rowCount == 0 {
                                Text("No palettes yet. Type a name to create one.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.text2)
                                    .padding(24)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .frame(height: min(330, max(CGFloat(rowCount), 1) * 58 + 12))
                    .onChange(of: highlighted) { newValue in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newValue)
                        }
                    }
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack(spacing: 14) {
                    Text("↵ Open")
                    Text("↑↓ Navigate")
                    Text("esc Close")
                    Spacer()
                }
                .font(.system(size: 11))
                .foregroundColor(Theme.text2)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
            .shadow(color: .black.opacity(0.30), radius: 28, y: 10)
            .padding(.top, 70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { start() }
        .onDisappear { stop() }
        .onChange(of: query) { _ in highlighted = 0 }
    }

    private func start() {
        DispatchQueue.main.async { focused = true }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: move(1); return nil          // down arrow
            case 126: move(-1); return nil         // up arrow
            case 36, 76: activate(); return nil    // return / enter
            case 53: close(); return nil           // escape
            default: return event
            }
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    private func move(_ delta: Int) {
        guard rowCount > 0 else { return }
        highlighted = max(0, min(rowCount - 1, highlighted + delta))
    }

    private func activate() {
        let r = results
        if highlighted < r.count {
            store.selectedID = r[highlighted].id
        } else if let name = createName {
            store.createPalette(named: name)
        }
        close()
    }

    private func close() {
        store.showPalette = false
    }
}

struct PaletteResultRow: View {
    let palette: Palette
    let isHighlighted: Bool
    let isCurrent: Bool
    let onPin: () -> Void
    let onDelete: () -> Void

    private var openedText: String {
        guard let d = palette.lastOpened else { return "Not opened yet" }
        if Date().timeIntervalSince(d) < 86_400 { return "Opened recently" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return "Opened " + f.localizedString(for: d, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                if palette.colors.isEmpty {
                    Color.primary.opacity(0.1)
                } else {
                    ForEach(Array(palette.colors.prefix(4))) { c in
                        Color(hex: c.hex)
                    }
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(palette.name.isEmpty ? "Untitled" : palette.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if isCurrent {
                        Circle().fill(Theme.accent).frame(width: 7, height: 7)
                        Text("Current")
                    } else {
                        Text(openedText)
                    }
                    Text("•")
                    Text("\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")")
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
            }

            Spacer()

            if palette.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text2)
            }

            if isHighlighted {
                Button(action: onPin) {
                    Image(systemName: palette.pinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .help(palette.pinned ? "Unpin" : "Pin to top")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(palette.locked)
                .opacity(palette.locked ? 0.3 : 1)
                .help(palette.locked ? "Unlock this palette to delete it" : "Delete palette")
            } else if palette.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text2)
            }
        }
        .font(.system(size: 14))
        .foregroundColor(Color.primary.opacity(0.75))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? Color.primary.opacity(0.10) : Color.clear)
        )
    }
}

struct CreateResultRow: View {
    let name: String
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Theme.accent)
                .frame(width: 34, height: 34)
            Text("Create palette “\(name)”")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? Color.primary.opacity(0.10) : Color.clear)
        )
    }
}

// MARK: - Window helpers (keep on top, compact view)

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let w = view.window { onWindow(w) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { onWindow(w) }
        }
    }
}

struct WindowControls: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 6) {
            Button { store.keepOnTop.toggle() } label: {
                Image(systemName: store.keepOnTop ? "pin.fill" : "pin")
            }
            .buttonStyle(IconButtonStyle(active: store.keepOnTop))
            .help(store.helpText(store.keepOnTop ? "Stop keeping on top" : "Keep on top of other apps", .keepOnTop))

            Button { store.compact.toggle() } label: {
                Image(systemName: store.compact
                      ? "arrow.up.left.and.arrow.down.right"
                      : "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(IconButtonStyle())
            .help(store.helpText(store.compact ? "Back to full view" : "Compact view", .compactView))
        }
    }
}

// MARK: - Compact view (small panel to keep next to other apps)

struct CompactView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer().frame(width: 62)          // room for the window buttons

                Button { store.pickIntoSelected() } label: { Image(systemName: "eyedropper") }
                    .buttonStyle(IconButtonStyle())
                    .help(store.helpText("Pick a color from the screen", .eyedropper))

                Button { store.addColorToSelected() } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle())
                    .help(store.helpText("Add a color to the selected palette", .addColor))

                Spacer()

                Menu {
                    Picker("Copy format", selection: $store.copyFormat) {
                        ForEach(CopyFormat.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text(store.copyFormat.shortLabel)
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                WindowControls()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Rectangle().fill(Theme.stroke).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(store.palettes) { p in
                        CompactPaletteRow(palette: p, isCurrent: p.id == store.selectedID)
                    }
                    if store.palettes.isEmpty {
                        Button("New Palette") { store.addPalette() }
                            .buttonStyle(PillButtonStyle(prominent: true))
                            .padding(.top, 30)
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CompactPaletteRow: View {
    let palette: Palette
    let isCurrent: Bool
    var showsAddColor = true
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: isCurrent ? "circle.inset.filled" : "circle")
                    .font(.system(size: 11))
                    .foregroundColor(isCurrent ? Theme.accent : Theme.text2)
                Text(palette.name.isEmpty ? "Untitled" : palette.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if palette.locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.text2)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { store.selectedID = palette.id }

            HStack(spacing: 0) {
                if palette.colors.isEmpty {
                    Text("No colors yet")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    ForEach(palette.colors) { c in
                        CompactSwatch(color: c)
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.stroke))
        }
        .contextMenu {
            if showsAddColor {
                Button("Add Color…") {
                    store.selectedID = palette.id
                    store.addColorToSelected()
                }
            }
            Button(palette.locked ? "Unlock" : "Lock") { store.toggleLock(palette.id) }
            Button("Duplicate") { store.duplicatePalette(palette.id) }
        }
    }
}

struct CompactSwatch: View {
    let color: SwatchColor
    @EnvironmentObject var store: Store
    @State private var hover = false

    var body: some View {
        Color(hex: color.hex)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(Color.white.opacity(hover ? 0.18 : 0))
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture { store.copy(color.hex) }
            .help("\(color.displayName)  #\(color.hex)")
            .contextMenu {
                Button("Copy #HEX") { store.copy(color.hex, as: .hex) }
                Button("Copy RGB") { store.copy(color.hex, as: .rgb) }
                Button("Copy HSL") { store.copy(color.hex, as: .hsl) }
            }
    }
}
