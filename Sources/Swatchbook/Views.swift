import SwiftUI
import AppKit

// MARK: - Theme

enum Theme {
    static let bg = Color(hex: "121214")
    static let sidebar = Color(hex: "0D0D0F")
    static let card = Color.white.opacity(0.05)
    static let stroke = Color.white.opacity(0.08)
    static let accent = Color(hex: "FF6363")      // Raycast-style red
    static let text2 = Color.white.opacity(0.5)
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(prominent ? Theme.accent : Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.8))
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08)))
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
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.toast)
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
        .background(Capsule().fill(Color(hex: "26262A")))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
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
                                Button("Duplicate") { store.duplicatePalette(p.id) }
                                Button("Delete…") { store.pendingDelete = p.id }
                            }
                    }
                }
                .padding(.horizontal, 10)
            }

            Text("⌘N palette  ·  ⇧⌘N color  ·  ⇧⌘P eyedropper")
                .font(.system(size: 10))
                .foregroundColor(Theme.text2.opacity(0.7))
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
                    Color.white.opacity(0.1)
                } else {
                    ForEach(Array(palette.colors.prefix(4))) { c in
                        Color(hex: c.hex)
                    }
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(palette.name.isEmpty ? "Untitled" : palette.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text2)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
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
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Palette name", text: store.nameBinding(palette.id))
                            .textFieldStyle(.plain)
                            .font(.system(size: 28, weight: .bold))
                        Text("\(palette.colors.count) color\(palette.colors.count == 1 ? "" : "s")  ·  click a color to copy")
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

                        Button { store.pickIntoSelected() } label: {
                            Label("Pick", systemImage: "eyedropper")
                        }
                        .buttonStyle(PillButtonStyle())
                        .help("Pick a color from anywhere on screen (⇧⌘P)")

                        Button { store.addColorToSelected() } label: {
                            Label("Add Color", systemImage: "plus")
                        }
                        .buttonStyle(PillButtonStyle(prominent: true))

                        Button { store.pendingDelete = palette.id } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(PillButtonStyle())
                        .help("Delete palette")
                    }
                }

                // Combined strip preview
                if !palette.colors.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(palette.colors) { c in
                            Color(hex: c.hex)
                        }
                    }
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.10)))
                }

                // Color grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(palette.colors) { c in
                        ColorCard(paletteID: palette.id, color: c)
                    }
                    AddTile()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 44)
            .padding(.bottom, 28)
        }
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
        .foregroundColor(hover ? .white : Theme.text2)
        .frame(maxWidth: .infinity)
        .frame(height: 134)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(hover ? 0.3 : 0.15),
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
    @EnvironmentObject var store: Store
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: color.hex))
                .frame(height: 84)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.12)))
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
        .background(RoundedRectangle(cornerRadius: 14).fill(hover ? Color.white.opacity(0.09) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { store.copy(color.hex) }
        .contextMenu {
            Button("Copy #HEX") { store.copy(color.hex, as: .hex) }
            Button("Copy RGB") { store.copy(color.hex, as: .rgb) }
            Button("Copy HSL") { store.copy(color.hex, as: .hsl) }
            Divider()
            Button("Edit…") {
                store.editor = EditorTarget(paletteID: paletteID, colorID: color.id)
            }
            Button("Delete") { store.removeColor(in: paletteID, colorID: color.id) }
        }
        .draggable(color.id.uuidString)
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
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12)))

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
                    .opacity(valid == nil ? 0.4 : 1)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
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
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke))
        }
    }
}
