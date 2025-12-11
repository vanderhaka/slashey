//
//  BackupManager.swift
//  Slashey
//

import Foundation

final class BackupManager {
    static let shared = BackupManager()

    private let fileManager = FileManager.default
    private let backupDirectory: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDirectory = appSupport.appendingPathComponent("Slashey/Backups")
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    /// Creates a backup of a file before modifying it
    /// Returns the backup URL if successful
    @discardableResult
    func backupFile(at url: URL) throws -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            // No file to backup, that's okay
            return url
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let fileName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        let backupName = "\(fileName)_\(timestamp).\(ext)"
        let backupURL = backupDirectory.appendingPathComponent(backupName)

        try fileManager.copyItem(at: url, to: backupURL)

        // Clean up old backups (keep last 10 per file prefix)
        cleanupOldBackups(forPrefix: fileName)

        return backupURL
    }

    /// Restores a file from the most recent backup
    func restoreFromBackup(originalURL: URL) throws {
        let fileName = originalURL.deletingPathExtension().lastPathComponent

        let backups = try getBackups(forPrefix: fileName)
        guard let mostRecent = backups.first else {
            throw BackupError.noBackupFound
        }

        // Backup the current state before restoring
        if fileManager.fileExists(atPath: originalURL.path) {
            try fileManager.removeItem(at: originalURL)
        }

        try fileManager.copyItem(at: mostRecent, to: originalURL)
    }

    /// Gets all backups for a file, sorted by date (newest first)
    func getBackups(forPrefix prefix: String) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )

        return contents
            .filter { $0.lastPathComponent.hasPrefix(prefix + "_") }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return date1 > date2
            }
    }

    /// Removes old backups, keeping only the most recent N
    private func cleanupOldBackups(forPrefix prefix: String, keepCount: Int = 10) {
        guard let backups = try? getBackups(forPrefix: prefix) else { return }

        for backup in backups.dropFirst(keepCount) {
            try? fileManager.removeItem(at: backup)
        }
    }

    /// Returns the total size of all backups
    func totalBackupSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    /// Clears all backups
    func clearAllBackups() throws {
        let contents = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        for file in contents {
            try fileManager.removeItem(at: file)
        }
    }

    enum BackupError: LocalizedError {
        case noBackupFound

        var errorDescription: String? {
            switch self {
            case .noBackupFound:
                return "No backup found for this file"
            }
        }
    }
}
