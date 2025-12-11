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

    /// Cache for syncedServices lookups to avoid O(n^2) performance when rendering lists
    private var syncedServicesCache: [String: [Service]] = [:]

    init(serviceDetector: ServiceDetector) {
        self.serviceDetector = serviceDetector
    }

    /// Invalidates the synced services cache. Call after any mutation to commands array.
    private func invalidateSyncedServicesCache() {
        syncedServicesCache.removeAll()
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
        invalidateSyncedServicesCache()
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
                if !newCommands.isEmpty {
                    invalidateSyncedServicesCache()
                }
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
        invalidateSyncedServicesCache()
    }

    func updateCommand(_ command: SlasheyCommand) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        guard let index = commands.firstIndex(where: { $0.id == command.id }) else {
            throw NSError(domain: "Slashey", code: 3, userInfo: [NSLocalizedDescriptionKey: "Command not found in local store"])
        }

        try await adapter.saveCommand(command)
        commands[index] = command
        invalidateSyncedServicesCache()
    }

    func deleteCommand(_ command: SlasheyCommand) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        try await adapter.deleteCommand(command)
        commands.removeAll { $0.id == command.id }
        invalidateSyncedServicesCache()
    }

    func renameCommand(_ command: SlasheyCommand, to newName: String) async throws {
        guard let adapter = adapters[command.sourceService] else {
            throw NSError(domain: "Slashey", code: 2, userInfo: [NSLocalizedDescriptionKey: "No adapter for service"])
        }

        // Delete the old file first
        try await adapter.deleteCommand(command)

        // Create updated command with new name
        var renamedCommand = command
        renamedCommand.name = newName

        // Save the new file
        try await adapter.saveCommand(renamedCommand)

        // Update in-memory list
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = renamedCommand
        }
        invalidateSyncedServicesCache()
    }

    // MARK: - Helpers

    func syncedServices(for command: SlasheyCommand) -> [Service] {
        // Use cache key based on command identity
        let cacheKey = "\(command.id.uuidString)-\(command.sourceService.rawValue)"

        if let cached = syncedServicesCache[cacheKey] {
            return cached
        }

        let matches = commands.compactMap { other -> Service? in
            guard other.id != command.id,
                  other.name == command.name,
                  other.scope == command.scope,
                  other.namespace == command.namespace,
                  other.sourceService != command.sourceService else { return nil }

            if command.scope == .project && other.projectPath != command.projectPath {
                return nil
            }

            return other.sourceService
        }

        let result = Array(Set(matches)).sorted { $0.displayName < $1.displayName }
        syncedServicesCache[cacheKey] = result
        return result
    }

    // MARK: - Sync

    func syncCommand(_ command: SlasheyCommand, to targetServices: Set<Service>) async throws {
        for targetService in targetServices where targetService != command.sourceService {
            guard let adapter = adapters[targetService] else { continue }

            var convertedCommand = command
            convertedCommand.sourceService = targetService

            try await adapter.saveCommand(convertedCommand)

            // Update in-memory list so UI reflects new/updated copies immediately
            if let existingIndex = commands.firstIndex(where: {
                $0.name == convertedCommand.name &&
                $0.scope == convertedCommand.scope &&
                $0.namespace == convertedCommand.namespace &&
                $0.sourceService == targetService &&
                (convertedCommand.scope != .project || $0.projectPath == convertedCommand.projectPath)
            }) {
                // Update existing synced copy with new content
                commands[existingIndex] = convertedCommand
            } else {
                // Append new synced copy
                commands.append(convertedCommand)
            }
        }
        invalidateSyncedServicesCache()
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
