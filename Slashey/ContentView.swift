//
//  ContentView.swift
//  Slashey
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedService: Service?
    @State private var selectedScope: CommandScope = .user
    @State private var selectedCommand: SlasheyCommand?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingNewCommand = false
    @State private var isLoading = false
    @State private var didResizeWindow = false

    let serviceDetector: ServiceDetector
    let commandStore: CommandStore
    let syncEngine: SyncEngine
    @Bindable var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedService: $selectedService,
                selectedScope: $selectedScope,
                serviceDetector: serviceDetector,
                commandStore: commandStore
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            CommandListView(
                service: selectedService,
                scope: selectedScope,
                selectedCommand: $selectedCommand,
                searchText: $searchText,
                commandStore: commandStore,
                installedServices: serviceDetector.installedServices,
                isLoading: isLoading,
                onCreateCommand: { showingNewCommand = true }
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            if let command = selectedCommand {
                CommandEditorView(
                    command: command,
                    commandStore: commandStore,
                    syncEngine: syncEngine,
                    serviceDetector: serviceDetector,
                    appState: appState
                ) { updatedCommand in
                    selectedCommand = updatedCommand
                } onDelete: { deletedCommand in
                    if selectedCommand?.id == deletedCommand.id {
                        selectedCommand = nil
                    }
                }
                .id(command.id)
            } else {
                EmptyEditorView()
            }
        }
        .searchable(text: $searchText, prompt: "Search commands")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingNewCommand = true
                } label: {
                    Label("New Command", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    Task { await refreshCommands() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isLoading)
            }

            ToolbarItem(placement: .automatic) {
                SyncStatusIndicator(syncEngine: syncEngine)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                serviceDetector: serviceDetector,
                syncEngine: syncEngine
            )
        }
        .sheet(isPresented: $showingNewCommand) {
            NewCommandSheet(
                commandStore: commandStore,
                serviceDetector: serviceDetector,
                scope: selectedScope,
                appState: appState
            )
        }
        .toast($appState.toast)
        .alert(appState.alertTitle, isPresented: $appState.showAlert) {
            Button("OK") { }
        } message: {
            Text(appState.alertMessage)
        }
        .background(
            WindowAccessor { window in
                guard !didResizeWindow, let window else { return }
                didResizeWindow = true

                guard let screen = window.screen ?? NSScreen.main else {
                    // No screen available; skip resize
                    return
                }
                let targetFrame = screen.visibleFrame
                window.setFrame(targetFrame, display: true, animate: true)
            }
        )
        .task {
            await refreshCommands()
        }
    }

    private func refreshCommands() async {
        isLoading = true
        await commandStore.loadAllCommands()
        isLoading = false

        if commandStore.commands.isEmpty {
            // First time user - will see empty state with guidance
        } else {
            appState.showInfo("Loaded \(commandStore.commands.count) commands")
        }
    }
}

#Preview {
    let detector = ServiceDetector()
    let store = CommandStore(serviceDetector: detector)
    let sync = SyncEngine(commandStore: store)
    let appState = AppState()

    ContentView(
        serviceDetector: detector,
        commandStore: store,
        syncEngine: sync,
        appState: appState
    )
}
