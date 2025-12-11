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

    @State private var showingSyncSheet = false
    @State private var isSaving = false
    @State private var editedContent: String

    init(command: SlasheyCommand, commandStore: CommandStore, syncEngine: SyncEngine, serviceDetector: ServiceDetector) {
        self.command = command
        self.commandStore = commandStore
        self.syncEngine = syncEngine
        self.serviceDetector = serviceDetector
        self._editedContent = State(initialValue: command.content)
    }

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name") {
                    Text(command.name)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Service") {
                    ServiceBadge(service: command.sourceService)
                }

                if !command.description.isEmpty {
                    LabeledContent("Description") {
                        Text(command.description)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Scope") {
                    Label(command.scope.displayName, systemImage: command.scope.icon)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Activation") {
                    Text(command.activationMode.displayName)
                        .foregroundStyle(.secondary)
                }

                if let globs = command.globs, !globs.isEmpty {
                    LabeledContent("File Patterns") {
                        VStack(alignment: .trailing) {
                            ForEach(globs, id: \.self) { glob in
                                Text(glob)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Content") {
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
            }

            Section("Sync") {
                LabeledContent("Last Modified") {
                    Text(command.lastModified, style: .relative)
                        .foregroundStyle(.secondary)
                }

                if let path = command.filePath {
                    LabeledContent("File") {
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Button {
                    showingSyncSheet = true
                } label: {
                    Label("Sync to Other Services", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(command.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
                .disabled(isSaving)
            }
        }
        .sheet(isPresented: $showingSyncSheet) {
            SyncSheet(
                command: command,
                syncEngine: syncEngine,
                serviceDetector: serviceDetector
            )
        }
    }

    private func saveCommand() async {
        isSaving = true
        var updatedCommand = command
        updatedCommand.content = editedContent
        do {
            try await commandStore.updateCommand(updatedCommand)
        } catch {
            print("Error saving: \(error)")
        }
        isSaving = false
    }
}

struct SyncSheet: View {
    let command: SlasheyCommand
    let syncEngine: SyncEngine
    let serviceDetector: ServiceDetector

    @Environment(\.dismiss) private var dismiss
    @State private var selectedServices: Set<Service> = []

    var availableServices: [Service] {
        Service.allCases.filter {
            $0 != command.sourceService && serviceDetector.isInstalled($0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Sync Command")
                    .font(.headline)

                Text("Select services to sync \"\(command.name)\" to:")
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            List(availableServices, selection: $selectedServices) { service in
                Label(service.displayName, systemImage: service.iconName)
                    .foregroundStyle(service.color)
            }
            .listStyle(.plain)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Sync") {
                    Task {
                        await syncEngine.syncCommand(command, to: selectedServices)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedServices.isEmpty || syncEngine.isSyncing)
            }
            .padding()
        }
        .frame(width: 320, height: 360)
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
