//
//  ContentView.swift
//  Slashey
//

import SwiftUI

struct ContentView: View {
    @State private var selectedService: Service?
    @State private var selectedScope: CommandScope = .user
    @State private var selectedCommand: SlasheyCommand?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingNewCommand = false
    @State private var isLoading = false

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
                )
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

struct SyncStatusIndicator: View {
    let syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: 6) {
            if syncEngine.isSyncing {
                ProgressView()
                    .controlSize(.small)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastSync = syncEngine.lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewCommandSheet: View {
    let commandStore: CommandStore
    let serviceDetector: ServiceDetector
    let scope: CommandScope
    let appState: AppState

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var content = ""
    @State private var selectedService: Service = .claudeCode
    @State private var activationMode: ActivationMode = .manual
    @State private var isSaving = false

    var availableServices: [Service] {
        Service.allCases.filter { serviceDetector.isInstalled($0) }
    }

    var isValid: Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Command")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Command name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    if !name.isEmpty && !isValid {
                        Label("Name can only contain letters, numbers, dashes, and underscores", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Name")
                } footer: {
                    Text("This will be the filename (e.g., \(name.isEmpty ? "my-command" : name).md)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Section("Description") {
                    TextField("Brief description of what this command does", text: $description)
                }

                Section {
                    Picker("Service", selection: $selectedService) {
                        ForEach(availableServices) { service in
                            Label(service.displayName, systemImage: service.iconName)
                                .tag(service)
                        }
                    }

                    Picker("Activation", selection: $activationMode) {
                        ForEach(ActivationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text(activationModeDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await createCommand() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Create")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isSaving)
            }
            .padding()
        }
        .frame(width: 500, height: 580)
        .onAppear {
            // Default to first available service
            if let first = availableServices.first {
                selectedService = first
            }
        }
    }

    private var activationModeDescription: String {
        switch activationMode {
        case .always:
            return "Command is always active in context"
        case .manual:
            return "Invoke with /\(name.isEmpty ? "command-name" : name)"
        case .autoAttach:
            return "Automatically included when matching files are open"
        case .modelDecision:
            return "AI decides when to use based on description"
        }
    }

    private func createCommand() async {
        isSaving = true

        let command = SlasheyCommand(
            name: name,
            description: description,
            content: content,
            scope: scope,
            activationMode: activationMode,
            sourceService: selectedService
        )

        do {
            try await commandStore.addCommand(command)
            appState.showSuccess("Command '\(name)' created")
            dismiss()
        } catch {
            appState.showErrorAlert(
                title: "Failed to Create Command",
                message: error.localizedDescription
            )
        }

        isSaving = false
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
