//
//  CommandStore.swift
//  Slashey
//

import Foundation
import SwiftUI

@Observable
final class CommandStore {
    private(set) var commands: [SlasheyCommand] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let adapters: [Service: ServiceAdapter] = [
        .claudeCode: ClaudeCodeAdapter(),
        .cursor: CursorAdapter(),
        .windsurf: WindsurfAdapter()
    ]

    private let serviceDetector: ServiceDetector

    init(serviceDetector: ServiceDetector) {
        self.serviceDetector = serviceDetector
    }

    // MARK: - Loading

    func loadAllCommands() async {
        isLoading = true
        error = nil

        var allCommands: [SlasheyCommand] = []

        for service in Service.allCases {
            guard serviceDetector.isInstalled(service),
                  let adapter = adapters[service] else { continue }

            do {
                let userCommands = try await adapter.loadUserCommands()
                allCommands.append(contentsOf: userCommands)
            } catch {
                print("Error loading \(service) user commands: \(error)")
            }
        }

        commands = allCommands
        isLoading = false
    }

    func loadProjectCommands(from project: URL) async {
        for service in Service.allCases {
            guard serviceDetector.isInstalled(service),
                  let adapter = adapters[service] else { continue }

            do {
                let projectCommands = try await adapter.loadProjectCommands(from: project)
                // Merge with existing, removing duplicates by id
                let existingIds = Set(commands.map { $0.id })
                let newCommands = projectCommands.filter { !existingIds.contains($0.id) }
                commands.append(contentsOf: newCommands)
            } catch {
                print("Error loading \(service) project commands: \(error)")
            }
        }
    }

    // MARK: - Filtering

    func commands(for service: Service?, scope: CommandScope) -> [SlasheyCommand] {
        commands.filter { command in
            let matchesScope = command.scope == scope
            let matchesService = service == nil || command.sourceService == service
            return matchesScope && matchesService
        }
    }

    func searchCommands(_ query: String) -> [SlasheyCommand] {
        guard !query.isEmpty else { return commands }
        let lowercased = query.lowercased()
        return commands.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased) ||
            $0.content.lowercased().contains(lowercased)
        }
    }

    // MARK: - CRUD

    func addCommand(_ command: SlasheyCommand) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        try await adapter.saveCommand(command)
        commands.append(command)
    }

    func updateCommand(_ command: SlasheyCommand) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        try await adapter.saveCommand(command)

        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        }
    }

    func deleteCommand(_ command: SlasheyCommand) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        try await adapter.deleteCommand(command)
        commands.removeAll { $0.id == command.id }
    }

    // MARK: - Sync

    func syncCommand(_ command: SlasheyCommand, to targetServices: Set<Service>) async throws {
        for targetService in targetServices where targetService != command.sourceService {
            guard let adapter = adapters[targetService] else { continue }

            var convertedCommand = command
            convertedCommand.sourceService = targetService

            try await adapter.saveCommand(convertedCommand)
        }
    }

    func syncAllToService(_ targetService: Service, from sourceService: Service) async throws {
        guard let targetAdapter = adapters[targetService] else { return }

        let sourceCommands = commands.filter { $0.sourceService == sourceService }

        for command in sourceCommands {
            var converted = command
            converted.sourceService = targetService
            try await targetAdapter.saveCommand(converted)
        }
    }
}
