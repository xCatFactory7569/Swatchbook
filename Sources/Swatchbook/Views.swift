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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.primary.opacity(0.8))
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08)))
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                SidebarView().frame(width: 250)
                DetailView()
            }
            if let t = store.toast {
                ToastView(text: t)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.toast)
        .onAppear { store.applyAppearance() }
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
        }
        .padding(24)
        .frame(width: 440)
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
                Button { store.addPalette() } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle())
                    .help("New Palette (⌘N)")
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

            VStack(alignment: .leading, spacing: 10) {
                Picker("Appearance", selection: $store.appearance) {
                    ForEach(AppearanceMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("⌘N palette  ·  ⇧⌘N color  ·  ⇧⌘P eyedropper")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text2.opacity(0.8))
            }
            .padding(14)
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if palette.locked {
                    Text(palette.name.isEmpty ? "Untitled" : palette.name)
                        .font(.system(size: 28, weight: .bold))
                        .textSelection(.enabled)
                } else {
                    TextField("Palette name", text: store.nameBinding(palette.id))
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .bold))
                }
                Text("\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")  ·  click a color to copy"
                     + (palette.locked ? "  ·  locked" : ""))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text2)
            }
            Spacer()
            HStack(spacing: 8) {
                Menu {
                    Picker("Copy format", selection: $store.copyFormat) {
                        ForEach(CopyFormat.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text("Copy as \(store.copyFormat.shortLabel)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if !palette.locked {
                    Button { store.pickIntoSelected() } label: {
                        Label("Pick", systemImage: "eyedropper")
                    }
                    .buttonStyle(PillButtonStyle())
                    .help("Pick a color from anywhere on screen (⇧⌘P)")

                    Button { store.addColorToSelected() } label: {
                        Label("Add Color", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                }

                Button { store.toggleLock(palette.id) } label: {
                    Label(palette.locked ? "Locked" : "Lock",
                          systemImage: palette.locked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(PillButtonStyle())
                .help(palette.locked ? "Unlock this palette to edit it" : "Lock this palette so it can't be edited")

                if !palette.locked {
                    Button { store.pendingDelete = palette.id } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(PillButtonStyle())
                    .help("Delete palette")
                }
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
                TextField("e.g. Work calendar", text: $name)
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
        .frame(width: 380)
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
