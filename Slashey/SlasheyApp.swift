//
//  SlasheyApp.swift
//  Slashey
//

import SwiftUI

@main
struct SlasheyApp: App {
    @State private var serviceDetector = ServiceDetector()
    @State private var commandStore: CommandStore
    @State private var syncEngine: SyncEngine

    init() {
        let detector = ServiceDetector()
        let store = CommandStore(serviceDetector: detector)
        let sync = SyncEngine(commandStore: store)

        _serviceDetector = State(initialValue: detector)
        _commandStore = State(initialValue: store)
        _syncEngine = State(initialValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                serviceDetector: serviceDetector,
                commandStore: commandStore,
                syncEngine: syncEngine
            )
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Command") {
                    NotificationCenter.default.post(name: .newCommand, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Button("Refresh Services") {
                    serviceDetector.refresh()
                    Task {
                        await commandStore.loadAllCommands()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView(
                serviceDetector: serviceDetector,
                syncEngine: syncEngine
            )
        }
    }
}

extension Notification.Name {
    static let newCommand = Notification.Name("newCommand")
}
