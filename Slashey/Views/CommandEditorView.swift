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
    let onUnsavedChangesChanged: ((Bool) -> Void)?
    let onUpdate: ((SlasheyCommand) -> Void)?
    let onDelete: ((SlasheyCommand) -> Void)?

    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var showUnsavedSyncWarning = false
    @State private var selectedSyncServices: Set<Service>
    @State private var baselineCommand: SlasheyCommand
    @State private var editedContent: String
    @State private var editedDescription: String
    @State private var editedName: String

    init(
        command: SlasheyCommand,
        commandStore: CommandStore,
        syncEngine: SyncEngine,
        serviceDetector: ServiceDetector,
        appState: AppState,
        onUnsavedChangesChanged: ((Bool) -> Void)? = nil,
        onUpdate: ((SlasheyCommand) -> Void)? = nil,
        onDelete: ((SlasheyCommand) -> Void)? = nil
    ) {
        self.command = command
        self.commandStore = commandStore
        self.syncEngine = syncEngine
        self.serviceDetector = serviceDetector
        self.appState = appState
        self.onUnsavedChangesChanged = onUnsavedChangesChanged
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._editedContent = State(initialValue: command.content)
        self._editedDescription = State(initialValue: command.description)
        self._editedName = State(initialValue: command.name)
        self._baselineCommand = State(initialValue: command)
        let preselected = Set(commandStore.syncedServices(for: command))
            .intersection(serviceDetector.installedServices)
        self._selectedSyncServices = State(initialValue: preselected)
    }

    var hasUnsavedChanges: Bool {
        editedContent != baselineCommand.content ||
        editedDescription != baselineCommand.description ||
        editedName != baselineCommand.name
    }

    var isNameValid: Bool {
        guard !editedName.isEmpty else { return false }
        guard editedName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return false }
        guard let first = editedName.first, let last = editedName.last,
              (first.isLetter || first.isNumber),
              (last.isLetter || last.isNumber) else { return false }
        return true
    }

    var body: some View {
        Form {
            Section("Details") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .foregroundStyle(.secondary)
                        .font(.callout)

                    TextField("Command name", text: $editedName)
                        .textFieldStyle(.roundedBorder)

                    if !editedName.isEmpty && !isNameValid {
                        Label("Name must start and end with a letter or number, and contain only letters, numbers, dashes, or underscores", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .help("The command's filename (without extension). Used to invoke the command with /\(editedName)")

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

            Section("Sync To") {
                if syncableTargets.isEmpty {
                    ContentUnavailableView {
                        Label("No Other Services", systemImage: "app.dashed")
                    } description: {
                        Text("Install another supported service to sync this command.")
                    }
                } else {
                    // Source service badge (non-interactive)
                    HStack(spacing: 8) {
                        Image(systemName: command.sourceService.iconName)
                            .foregroundStyle(command.sourceService.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.sourceService.displayName)
                            Text("Source")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Source")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(command.sourceService.color.opacity(0.15))
                            .foregroundStyle(command.sourceService.color)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)

                    Divider()

                    Toggle(isOn: Binding(
                        get: { allTargetsSelected },
                        set: { selectAll in
                            selectedSyncServices = selectAll ? Set(syncableTargets) : []
                        })
                    ) {
                        Label("Sync to all other services", systemImage: "checklist")
                    }

                    ForEach(syncableTargets, id: \.self) { service in
                        Toggle(isOn: Binding(
                            get: { selectedSyncServices.contains(service) },
                            set: { isOn in
                                if isOn {
                                    selectedSyncServices.insert(service)
                                } else {
                                    selectedSyncServices.remove(service)
                                }
                            })
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: service.iconName)
                                    .foregroundStyle(service.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.displayName)
                                    Text(service.userCommandsPath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        if hasUnsavedChanges {
                            showUnsavedSyncWarning = true
                        } else {
                            Task { await syncSelectedTargets() }
                        }
                    } label: {
                        if syncEngine.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Sync Selected", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(selectedSyncServices.isEmpty || syncEngine.isSyncing || isSaving || isDeleting)
                    .help("Sync this command to the selected services")
                }
            }
            .alert("Unsaved Changes", isPresented: $showUnsavedSyncWarning) {
                Button("Save & Sync") {
                    Task {
                        await saveCommand()
                        if !hasUnsavedChanges { // Only sync if save succeeded
                            await syncSelectedTargets()
                        }
                    }
                }
                Button("Sync Without Saving", role: .destructive) {
                    Task { await syncSelectedTargets() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Syncing now will use the current edited content, but the source file won't be updated until you save.")
            }

            Section {
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 250)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if editedContent.isEmpty {
                            Text("Enter your command prompt here...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text("Content")
            } footer: {
                Text("The actual prompt/instructions that will be sent to the AI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } label: {
                        Text("File")
                    }
                    .help("Click to reveal this file in Finder. Path: \(path)")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editedName + (hasUnsavedChanges ? " *" : ""))
        .onChange(of: hasUnsavedChanges) { _, newValue in
            onUnsavedChangesChanged?(newValue)
        }
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
                .disabled(isSaving || !hasUnsavedChanges || !isNameValid)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save changes to this command (Cmd+S)")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .disabled(isSaving || isDeleting)
                .help("Delete this command from disk")
            }
        }
        .confirmationDialog(
            "Delete \"\(command.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteCommand() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the command file from \(command.sourceService.displayName).")
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
            editedContent = baselineCommand.content
            editedDescription = baselineCommand.description
            editedName = baselineCommand.name
        }
        appState.showInfo("Changes reverted")
    }

    private func saveCommand() async {
        isSaving = true

        let isRename = editedName != command.name

        var updatedCommand = command
        updatedCommand.content = editedContent
        updatedCommand.description = editedDescription
        updatedCommand.name = editedName

        do {
            // Backup before saving
            if let filePath = command.filePath {
                try BackupManager.shared.backupFile(at: URL(fileURLWithPath: filePath))
            }

            if isRename {
                // For rename: delete old file and create new one
                try await commandStore.renameCommand(command, to: editedName)
                // Reload to get the updated command with new file path
                await commandStore.loadAllCommands()
                if let refreshed = commandStore.commands.first(where: {
                    $0.name == editedName && $0.sourceService == command.sourceService
                }) {
                    baselineCommand = refreshed
                    editedContent = refreshed.content
                    editedDescription = refreshed.description
                    editedName = refreshed.name
                    onUpdate?(refreshed)
                }
                appState.showSuccess("Command renamed and saved")
            } else {
                try await commandStore.updateCommand(updatedCommand)
                appState.showSuccess("Command saved")
                baselineCommand = updatedCommand
                editedContent = updatedCommand.content
                editedDescription = updatedCommand.description
                editedName = updatedCommand.name
                onUpdate?(updatedCommand)
            }
        } catch {
            appState.showErrorAlert(
                title: "Save Failed",
                message: error.localizedDescription
            )
        }

        isSaving = false
    }

    private func syncSelectedTargets() async {
        guard !selectedSyncServices.isEmpty else { return }

        var toSync = command
        toSync.content = editedContent
        toSync.description = editedDescription

        await syncEngine.syncCommand(toSync, to: selectedSyncServices)

        if let error = syncEngine.syncError {
            appState.showError("Sync failed: \(error)")
        } else {
            await commandStore.loadAllCommands()
            // Match on both id AND sourceService to find the original source command,
            // not a synced copy with the same id but different service
            if let refreshed = commandStore.commands.first(where: {
                $0.id == command.id && $0.sourceService == command.sourceService
            }) {
                baselineCommand = refreshed
                editedContent = refreshed.content
                editedDescription = refreshed.description
                onUpdate?(refreshed)
            }

            let refreshedSelections = Set(commandStore.syncedServices(for: baselineCommand))
                .intersection(serviceDetector.installedServices)
            selectedSyncServices = refreshedSelections

            appState.showSuccess("Synced to \(selectedSyncServices.count) service\(selectedSyncServices.count == 1 ? "" : "s")")
        }
    }

    private func deleteCommand() async {
        isDeleting = true

        do {
            try await commandStore.deleteCommand(command)
            appState.showSuccess("Command deleted")
            onDelete?(command)
        } catch {
            appState.showErrorAlert(
                title: "Delete Failed",
                message: error.localizedDescription
            )
        }

        isDeleting = false
    }

    private var syncableTargets: [Service] {
        serviceDetector.installedServices
            .filter { $0 != command.sourceService }
            .sorted { $0.displayName < $1.displayName }
    }

    private var allTargetsSelected: Bool {
        !syncableTargets.isEmpty && selectedSyncServices.count == syncableTargets.count
    }
}

struct EmptyEditorView: View {
    var onCreateCommand: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Select a Command", systemImage: "terminal")
        } description: {
            Text("Choose a command from the list to view or edit")
        } actions: {
            if let onCreateCommand = onCreateCommand {
                Button {
                    onCreateCommand()
                } label: {
                    Label("Create New Command", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
