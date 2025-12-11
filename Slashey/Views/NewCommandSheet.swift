//
//  NewCommandSheet.swift
//  Slashey
//

import SwiftUI

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
        guard !name.isEmpty else { return false }
        // All characters must be letters, numbers, dashes, or underscores
        guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return false }
        // Name must start and end with a letter or number (not dash or underscore)
        guard let first = name.first, let last = name.last,
              (first.isLetter || first.isNumber),
              (last.isLetter || last.isNumber) else { return false }
        return true
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
                    TextField("", text: $name, prompt: Text("my-command"))
                        .textFieldStyle(.roundedBorder)

                    if !name.isEmpty && !isValid {
                        Label("Name must start and end with a letter or number, and contain only letters, numbers, dashes, or underscores", systemImage: "exclamationmark.triangle.fill")
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
                    TextField(
                        "",
                        text: $description,
                        prompt: Text("Brief description of what this command does"),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
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
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Enter your command prompt here...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
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
