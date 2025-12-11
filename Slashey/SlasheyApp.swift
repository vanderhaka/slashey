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
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

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
                syncEngine: syncEngine,
                appState: appState
            )
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    serviceDetector: serviceDetector,
                    syncEngine: syncEngine
                ) {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                }
            }
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
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
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Show Onboarding...") {
                    showOnboarding = true
                }
            }

            CommandGroup(replacing: .help) {
                Button("Slashey Help") {
                    if let url = URL(string: "https://github.com/vanderhaka/slashey") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("Open Backups Folder...") {
                    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let backups = appSupport.appendingPathComponent("Slashey/Backups")
                    NSWorkspace.shared.open(backups)
                }
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
