//
//  CommandEditorView.swift
//  Slashey
//

import SwiftUI

struct CommandEditorView: View {
    let command: SlasheyCommand
    let commandStore: CommandStore
    let syncEngine: SyncEngine
    let serviceDetector: ServiceDetector
    let appState: AppState

    @State private var showingSyncSheet = false
    @State private var isSaving = false
    @State private var editedContent: String
    @State private var editedDescription: String

    init(command: SlasheyCommand, commandStore: CommandStore, syncEngine: SyncEngine, serviceDetector: ServiceDetector, appState: AppState) {
        self.command = command
        self.commandStore = commandStore
        self.syncEngine = syncEngine
        self.serviceDetector = serviceDetector
        self.appState = appState
        self._editedContent = State(initialValue: command.content)
        self._editedDescription = State(initialValue: command.description)
    }

    var hasUnsavedChanges: Bool {
        editedContent != command.content || editedDescription != command.description
    }

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent {
                    Text(command.name)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } label: {
                    Text("Name")
                }
                .help("The command's filename (without extension). Used to invoke the command with /\(command.name)")

                LabeledContent {
                    ServiceBadge(service: command.sourceService)
                } label: {
                    Text("Service")
                }
                .help("The AI coding tool where this command is stored")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .foregroundStyle(.secondary)
                        .font(.callout)

                    TextEditor(text: $editedDescription)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                }
                .help("A brief description of what this command does. Used by AI to decide when to apply the command automatically.")

                LabeledContent {
                    Label(command.scope.displayName, systemImage: command.scope.icon)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Scope")
                }
                .help(scopeTooltip)

                LabeledContent {
                    Text(command.activationMode.displayName)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Activation")
                }
                .help(activationTooltip)

                if let globs = command.globs, !globs.isEmpty {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(globs, id: \.self) { glob in
                                Text(glob)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    } label: {
                        Text("File Patterns")
                    }
                    .help("Glob patterns that trigger this command. When files matching these patterns are open, the command may be automatically included.")
                }
            }

            Section {
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 250)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Content")
            } footer: {
                Text("The actual prompt/instructions that will be sent to the AI")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Info") {
                LabeledContent {
                    Text(command.lastModified, style: .relative)
                        .foregroundStyle(.secondary)
                } label: {
                    Text("Last Modified")
                }
                .help("When this command file was last changed")

                if let path = command.filePath {
                    LabeledContent {
                        Button {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        } label: {
                            HStack {
                                Text(abbreviatedPath(path))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } label: {
                        Text("File")
                    }
                    .help("Click to reveal this file in Finder. Path: \(path)")
                }
            }

            Section {
                Button {
                    showingSyncSheet = true
                } label: {
                    Label("Sync to Other Services...", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!serviceDetector.installedServices.contains(where: { $0 != command.sourceService }))
                .help("Copy this command to other AI coding tools (Cursor, Claude Code, or Windsurf)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(command.name + (hasUnsavedChanges ? " •" : ""))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if hasUnsavedChanges {
                    Button("Revert") {
                        revertChanges()
                    }
                    .foregroundStyle(.secondary)
                    .help("Discard all unsaved changes")
                }

                Button {
                    Task { await saveCommand() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isSaving || !hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save changes to this command (⌘S)")
            }
        }
        .sheet(isPresented: $showingSyncSheet) {
            SyncSheet(
                command: command,
                syncEngine: syncEngine,
                serviceDetector: serviceDetector,
                appState: appState
            )
        }
    }

    private var scopeTooltip: String {
        switch command.scope {
        case .user:
            return "User scope: This command is available globally across all your projects"
        case .project:
            return "Project scope: This command is only available within a specific project folder"
        }
    }

    private var activationTooltip: String {
        switch command.activationMode {
        case .always:
            return "Always: This command is automatically included in every conversation"
        case .manual:
            return "Manual: Invoke this command explicitly with /\(command.name)"
        case .autoAttach:
            return "Auto-attach: Automatically included when files matching the patterns are open"
        case .modelDecision:
            return "AI Decides: The AI model decides when to use this command based on its description"
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    private func revertChanges() {
        withAnimation {
            editedContent = command.content
            editedDescription = command.description
        }
        appState.showInfo("Changes reverted")
    }

    private func saveCommand() async {
        isSaving = true

        var updatedCommand = command
        updatedCommand.content = editedContent
        updatedCommand.description = editedDescription

        do {
            // Backup before saving
            if let filePath = command.filePath {
                try BackupManager.shared.backupFile(at: URL(fileURLWithPath: filePath))
            }

            try await commandStore.updateCommand(updatedCommand)
            appState.showSuccess("Command saved")
        } catch {
            appState.showErrorAlert(
                title: "Save Failed",
                message: error.localizedDescription
            )
        }

        isSaving = false
    }
}

struct SyncSheet: View {
    let command: SlasheyCommand
    let syncEngine: SyncEngine
    let serviceDetector: ServiceDetector
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var selectedServices: Set<Service> = []
    @State private var showConfirmation = false

    var availableServices: [Service] {
        Service.allCases.filter {
            $0 != command.sourceService && serviceDetector.isInstalled($0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)

                Text("Sync Command")
                    .font(.headline)

                Text("Select services to sync \"\(command.name)\" to:")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            Divider()

            // Service list
            if availableServices.isEmpty {
                ContentUnavailableView {
                    Label("No Other Services", systemImage: "app.dashed")
                } description: {
                    Text("Install Cursor or Windsurf to sync commands between services")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(availableServices, selection: $selectedServices) { service in
                    HStack {
                        Image(systemName: service.iconName)
                            .foregroundStyle(service.color)
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text(service.displayName)
                            Text(servicePath(for: service))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Warning banner
            if !selectedServices.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This will overwrite existing commands in selected services")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.1))
            }

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Sync \(selectedServices.count > 0 ? "(\(selectedServices.count))" : "")") {
                    showConfirmation = true
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedServices.isEmpty || syncEngine.isSyncing)
            }
            .padding()
        }
        .frame(width: 360, height: 420)
        .confirmationDialog(
            "Sync to \(selectedServices.count) service\(selectedServices.count == 1 ? "" : "s")?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sync", role: .destructive) {
                performSync()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Existing commands with the same name will be backed up and overwritten.")
        }
    }

    private func servicePath(for service: Service) -> String {
        switch service {
        case .claudeCode:
            return "~/.claude/commands/"
        case .cursor:
            return "~/.cursor/commands/"
        case .windsurf:
            return "~/.codeium/windsurf/memories/"
        }
    }

    private func performSync() {
        Task {
            await syncEngine.syncCommand(command, to: selectedServices)

            if let error = syncEngine.syncError {
                appState.showError("Sync failed: \(error)")
            } else {
                appState.showSuccess("Synced to \(selectedServices.count) service\(selectedServices.count == 1 ? "" : "s")")
            }

            dismiss()
        }
    }
}

struct EmptyEditorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Select a Command", systemImage: "terminal")
        } description: {
            Text("Choose a command from the list to view or edit")
        }
    }
}
