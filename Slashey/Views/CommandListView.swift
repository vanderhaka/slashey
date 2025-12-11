//
//  CommandListView.swift
//  Slashey
//

import SwiftUI

struct CommandListView: View {
    let service: Service?
    let scope: CommandScope
    @Binding var selectedCommand: SlasheyCommand?
    @Binding var searchText: String
    let commandStore: CommandStore
    let installedServices: Set<Service>
    var isLoading: Bool = false
    var onCreateCommand: (() -> Void)?

    var filteredCommands: [SlasheyCommand] {
        var commands = commandStore.commands(for: service, scope: scope)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            commands = commands.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.content.lowercased().contains(query)
            }
        }
        return commands.sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading commands...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredCommands.isEmpty {
                emptyStateView
            } else {
                List(selection: $selectedCommand) {
                    ForEach(filteredCommands) { command in
                        CommandRowView(
                            command: command,
                            showService: service == nil,
                            linkedServices: commandStore.syncedServices(for: command),
                            installedServices: installedServices
                        )
                            .tag(command)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(navigationTitle)
        .onChange(of: filteredCommands) { _, newCommands in
            // Clear selection if the selected command is no longer in the filtered list
            if let selected = selectedCommand,
               !newCommands.contains(where: { $0.id == selected.id }) {
                selectedCommand = nil
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if !searchText.isEmpty {
            // Search with no results
            ContentUnavailableView.search(text: searchText)
        } else if scope == .project {
            // No project commands
            ContentUnavailableView {
                Label("No Project Commands", systemImage: "folder")
            } description: {
                Text("Project commands are stored in individual project folders.\n\nOpen a project to see its commands.")
            }
        } else if service != nil {
            // Specific service with no commands
            ContentUnavailableView {
                Label("No Commands", systemImage: service!.iconName)
            } description: {
                Text("No user commands found for \(service!.displayName)")
            } actions: {
                Button {
                    onCreateCommand?()
                } label: {
                    Label("Create Command", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            // No commands at all - first time user
            ContentUnavailableView {
                Label("Welcome to Slashey", systemImage: "terminal.fill")
            } description: {
                VStack(spacing: 8) {
                    Text("Sync commands between Claude Code, Cursor, and Windsurf")

                    Text("Get started by creating your first command, or import existing commands from your installed services.")
                        .foregroundStyle(.secondary)
                }
            } actions: {
                Button {
                    onCreateCommand?()
                } label: {
                    Label("Create Your First Command", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var navigationTitle: String {
        if let service = service {
            return service.displayName
        }
        return "All Commands"
    }
}

struct CommandRowView: View {
    let command: SlasheyCommand
    var showService: Bool = false
    let linkedServices: [Service]
    let installedServices: Set<Service>

    /// All services this command exists in (source + linked)
    var allServices: [Service] {
        let services = Set([command.sourceService] + linkedServices)
        return services.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(command.fullName)
                    .font(.headline)

                Spacer()

                // Show service badges
                if showService {
                    serviceBadges
                }
            }

            if !command.description.isEmpty {
                Text(command.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Label(command.activationMode.displayName, systemImage: activationIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(activationTooltip)

                if let globs = command.globs, !globs.isEmpty {
                    Label("\(globs.count) patterns", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("File patterns that trigger this command")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var activationTooltip: String {
        switch command.activationMode {
        case .always:
            return "Always: Automatically included in every conversation"
        case .manual:
            return "Manual: Invoke with /\(command.name)"
        case .autoAttach:
            return "Auto-attach: Included when matching files are open"
        case .modelDecision:
            return "AI Decides: The AI decides when to use this based on its description"
        }
    }

    @ViewBuilder
    private var serviceBadges: some View {
        if isFullyCovered {
            // All services - green "All" badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("All")
            }
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())
            .help("Available in all installed services")
        } else {
            // Show each service as a full badge (icon + name)
            HStack(spacing: 4) {
                ForEach(allServices, id: \.self) { service in
                    ServiceBadge(service: service)
                }
            }
        }
    }

    private var isFullyCovered: Bool {
        !installedServices.isEmpty && Set(allServices) == installedServices
    }

    private var activationIcon: String {
        switch command.activationMode {
        case .always: return "bolt.fill"
        case .manual: return "hand.tap"
        case .autoAttach: return "doc.on.doc"
        case .modelDecision: return "brain"
        }
    }
}

struct ServiceBadge: View {
    let service: Service

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: service.iconName)
            Text(service.displayName)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(service.color.opacity(0.15))
        .foregroundStyle(service.color)
        .clipShape(Capsule())
    }
}
