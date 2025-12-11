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

    var filteredCommands: [SlasheyCommand] {
        var commands = commandStore.commands(for: service, scope: scope)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            commands = commands.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }
        return commands.sorted { $0.name < $1.name }
    }

    var body: some View {
        List(selection: $selectedCommand) {
            if filteredCommands.isEmpty {
                ContentUnavailableView {
                    Label("No Commands", systemImage: "terminal")
                } description: {
                    if !searchText.isEmpty {
                        Text("No commands match your search")
                    } else if let service = service {
                        Text("No \(scope.displayName.lowercased()) commands for \(service.displayName)")
                    } else {
                        Text("No \(scope.displayName.lowercased()) commands found")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredCommands) { command in
                    CommandRowView(command: command, showService: service == nil)
                        .tag(command)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(navigationTitle)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(command.fullName)
                    .font(.headline)

                Spacer()

                if showService {
                    ServiceBadge(service: command.sourceService)
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
                    .foregroundStyle(.tertiary)

                if let globs = command.globs, !globs.isEmpty {
                    Label("\(globs.count) patterns", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
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
