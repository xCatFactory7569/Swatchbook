import SwiftUI
import AppKit

// MARK: - Menu bar item (icon = eyedropper, arrow = palettes panel)

final class MenuBarController: NSObject {
    private weak var store: Store?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var resetWork: DispatchWorkItem?

    static let defaultTip = "Click the icon to pick a color. Click the arrow to open your palettes."

    init(store: Store) {
        self.store = store
        super.init()
        popover.behavior = .transient
        popover.animates = true
    }

    func setVisible(_ visible: Bool) {
        if visible { install() } else { remove() }
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.makeImage(checkmark: false)
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = Self.defaultTip
        }
        statusItem = item
    }

    private func remove() {
        popover.performClose(nil)
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
    }

    // MARK: Clicks

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Right-click (or control-click): small menu
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(sender)
            return
        }

        // Left side of the item = eyedropper, right side (the arrow) = palettes panel
        let point = sender.convert(event.locationInWindow, from: nil)
        if point.x > sender.bounds.width * 0.6 {
            togglePopover(relativeTo: sender)
        } else {
            popover.performClose(nil)
            store?.pickFromMenuBar()
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let store = store else { return }
        let host = NSHostingController(rootView: MenuBarPanel().environmentObject(store))
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.appearance = store.appearance.nsAppearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()
        let pick = menu.addItem(withTitle: "Pick Color", action: #selector(menuPick), keyEquivalent: "")
        pick.target = self
        let open = menu.addItem(withTitle: "Open Swatchbook", action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: "")
        settings.target = self
        let quit = menu.addItem(withTitle: "Quit Swatchbook", action: #selector(menuQuit), keyEquivalent: "")
        quit.target = self

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuPick() { store?.pickFromMenuBar() }
    @objc private func menuOpen() { store?.showMainWindow() }
    @objc private func menuSettings() { store?.showSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: Feedback

    /// Briefly swaps the icon for a check mark after a color was picked.
    func flash(_ hex: String) {
        guard let button = statusItem?.button else { return }
        button.image = Self.makeImage(checkmark: true)
        button.toolTip = "Picked #\(hex)"
        resetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.statusItem?.button?.image = Self.makeImage(checkmark: false)
            self?.statusItem?.button?.toolTip = Self.defaultTip
        }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    // MARK: Icon (drawn in code, adapts to light/dark menu bars)

    private static func cornerPath(_ r: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.minX + bl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - br, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY),
                 tangent2End: CGPoint(x: r.maxX, y: r.minY + br), radius: br)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - tr))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY),
                 tangent2End: CGPoint(x: r.maxX - tr, y: r.maxY), radius: tr)
        p.addLine(to: CGPoint(x: r.minX + tl, y: r.maxY))
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY),
                 tangent2End: CGPoint(x: r.minX, y: r.maxY - tl), radius: tl)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + bl))
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY),
                 tangent2End: CGPoint(x: r.minX + bl, y: r.minY), radius: bl)
        p.closeSubpath()
        return p
    }

    static func makeImage(checkmark: Bool) -> NSImage {
        let size = NSSize(width: 38, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            if checkmark {
                ctx.setStrokeColor(NSColor.black.cgColor)
                ctx.setLineWidth(2.2)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.move(to: CGPoint(x: 4.5, y: 9.5))
                ctx.addLine(to: CGPoint(x: 8.5, y: 5))
                ctx.addLine(to: CGPoint(x: 16, y: 14))
                ctx.strokePath()
            } else {
                // Four-part swatch: darker = more opaque
                let c: CGFloat = 7.5
                let x0: CGFloat = 3
                let y0: CGFloat = 1.5
                func fill(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat, _ alpha: CGFloat) {
                    ctx.addPath(cornerPath(rect, tl: tl, tr: tr, br: br, bl: bl))
                    ctx.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
                    ctx.fillPath()
                }
                fill(CGRect(x: x0 + c, y: y0, width: c, height: c), tl: 0, tr: 0, br: c, bl: 0, 0.45)
                fill(CGRect(x: x0, y: y0, width: c, height: c), tl: 0, tr: 0, br: 0, bl: c, 0.65)
                fill(CGRect(x: x0 + c, y: y0 + c, width: c, height: c), tl: 0, tr: c, br: 0, bl: 0, 0.8)
                fill(CGRect(x: x0, y: y0 + c, width: c, height: c), tl: 1.8, tr: 0, br: 0, bl: 0, 1.0)

                // Small dot punched out of the top-left quarter
                ctx.setBlendMode(.clear)
                ctx.fillEllipse(in: CGRect(x: x0 + 1.9, y: y0 + 2 * c - 5.1, width: 3.2, height: 3.2))
                ctx.setBlendMode(.normal)
            }

            // Down arrow (opens the palettes panel)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
            ctx.move(to: CGPoint(x: 25, y: 10.5))
            ctx.addLine(to: CGPoint(x: 33, y: 10.5))
            ctx.addLine(to: CGPoint(x: 29, y: 6))
            ctx.closePath()
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - The panel that opens from the arrow

struct MenuBarPanel: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button { store.pickFromMenuBar() } label: { Image(systemName: "eyedropper") }
                        .buttonStyle(IconButtonStyle())
                        .help("Pick a color from the screen")

                    Menu {
                        Picker("Copy format", selection: $store.copyFormat) {
                            ForEach(CopyFormat.allCases) { f in
                                Text(f.label).tag(f)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Text("Copy as \(store.copyFormat.shortLabel)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    Button { store.showMainWindow() } label: { Image(systemName: "macwindow") }
                        .buttonStyle(IconButtonStyle())
                        .help("Open the Swatchbook window")

                    Button { store.showSettings() } label: { Image(systemName: "gearshape") }
                        .buttonStyle(IconButtonStyle())
                        .help("Settings")
                }
                .padding(12)

                Rectangle().fill(Theme.stroke).frame(height: 1)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(store.palettes) { p in
                            CompactPaletteRow(palette: p,
                                              isCurrent: p.id == store.selectedID,
                                              showsAddColor: false)
                        }
                        if store.palettes.isEmpty {
                            Text("No palettes yet. Open Swatchbook to create one.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.text2)
                                .padding(.top, 30)
                        }
                    }
                    .padding(14)
                }
            }

            if let t = store.toast {
                ToastView(text: t)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 340, height: 520)
        .background(Theme.bg)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.toast)
    }
}
