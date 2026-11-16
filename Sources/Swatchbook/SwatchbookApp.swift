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
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Add Color…") { store.addColorToSelected() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Pick Color from Screen") { store.pickIntoSelected() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
