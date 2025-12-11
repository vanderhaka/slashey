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
    @State private var editableCommand: SlasheyCommand?

    let serviceDetector: ServiceDetector
    let commandStore: CommandStore
    let syncEngine: SyncEngine

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
                commandStore: commandStore
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            if let command = selectedCommand {
                CommandEditorView(
                    command: command,
                    commandStore: commandStore,
                    syncEngine: syncEngine,
                    serviceDetector: serviceDetector
                )
                .id(command.id) // Force view refresh when command changes
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

                Button {
                    Task {
                        await commandStore.loadAllCommands()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
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
                scope: selectedScope
            )
        }
        .task {
            await commandStore.loadAllCommands()
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Command")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                TextField("Name", text: $name)

                TextField("Description", text: $description)

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

                Section("Content") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    Task { await createCommand() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 480, height: 520)
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
            dismiss()
        } catch {
            print("Error creating command: \(error)")
        }

        isSaving = false
    }
}

#Preview {
    let detector = ServiceDetector()
    let store = CommandStore(serviceDetector: detector)
    let sync = SyncEngine(commandStore: store)

    ContentView(
        serviceDetector: detector,
        commandStore: store,
        syncEngine: sync
    )
}
