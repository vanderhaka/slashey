//
//  SyncEngine.swift
//  Slashey
//

import Foundation

enum SyncStrategy: String, CaseIterable, Codable {
    case manual = "manual"
    case onChange = "on_change"
}

enum ConflictResolution: String, CaseIterable, Codable {
    case newerWins = "newer_wins"
    case sourceWins = "source_wins"
    case askUser = "ask_user"

    var displayName: String {
        switch self {
        case .newerWins: return "Newer Wins"
        case .sourceWins: return "Source Wins"
        case .askUser: return "Ask Me"
        }
    }
}

@Observable
final class SyncEngine {
    var syncStrategy: SyncStrategy = .manual
    var conflictResolution: ConflictResolution = .newerWins
    var enabledServices: Set<Service> = Set(Service.allCases)

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private let commandStore: CommandStore

    init(commandStore: CommandStore) {
        self.commandStore = commandStore
    }

    // MARK: - Sync Operations

    func syncCommand(_ command: SlasheyCommand, to services: Set<Service>) async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        do {
            let targetServices = services.intersection(enabledServices).subtracting([command.sourceService])
            try await commandStore.syncCommand(command, to: targetServices)
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    func syncAll(from source: Service, to target: Service) async {
        guard !isSyncing else { return }
        guard enabledServices.contains(source), enabledServices.contains(target) else { return }

        isSyncing = true
        syncError = nil

        do {
            try await commandStore.syncAllToService(target, from: source)
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    func toggleService(_ service: Service, enabled: Bool) {
        if enabled {
            enabledServices.insert(service)
        } else {
            enabledServices.remove(service)
        }
    }
}
