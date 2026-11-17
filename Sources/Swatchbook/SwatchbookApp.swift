import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// With the menu bar item on, closing the window keeps the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menuBarOn = UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? true
        return !menuBarOn
    }
}

@main
struct SwatchbookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: store.compact ? 300 : 820,
                       minHeight: store.compact ? 260 : 520)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Palette") { store.addPalette() }
                    .appShortcut(store.shortcuts[.newPalette])
                Button("Add Color…") { store.addColorToSelected() }
                    .appShortcut(store.shortcuts[.addColor])
                Button("Pick Color from Screen") { store.pickIntoSelected() }
                    .appShortcut(store.shortcuts[.eyedropper])
                Button("Browse Palettes…") { store.showPalette.toggle() }
                    .appShortcut(store.shortcuts[.commandPalette])

                Divider()

                Button("Import Palettes…") { store.importPalettes() }
                Menu("Export Selected Palette") {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.label) { store.exportPalettes(all: false, format: format) }
                    }
                }
                Menu("Export All Palettes") {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.label) { store.exportPalettes(all: true, format: format) }
                    }
                }
            }

            CommandGroup(after: .toolbar) {
                Toggle("Keep on Top", isOn: $store.keepOnTop)
                    .appShortcut(store.shortcuts[.keepOnTop])
                Toggle("Compact View", isOn: $store.compact)
                    .appShortcut(store.shortcuts[.compactView])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
