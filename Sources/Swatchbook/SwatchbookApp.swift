import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SwatchbookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 820, minHeight: 520)
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
                Divider()
                Button("Browse Palettes…") { store.showPalette.toggle() }
                    .appShortcut(store.shortcuts[.commandPalette])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
