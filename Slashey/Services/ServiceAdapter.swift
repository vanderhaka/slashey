//
//  ServiceAdapter.swift
//  Slashey
//

import Foundation

protocol ServiceAdapter {
    var service: Service { get }

    func loadUserCommands() async throws -> [SlasheyCommand]
    func loadProjectCommands(from project: URL) async throws -> [SlasheyCommand]
    func saveCommand(_ command: SlasheyCommand) async throws
    func deleteCommand(_ command: SlasheyCommand) async throws
}

// MARK: - Claude Code Adapter

final class ClaudeCodeAdapter: ServiceAdapter {
    let service: Service = .claudeCode
    private let pathManager = PathManager.shared
    private let fileManager = FileManager.default

    func loadUserCommands() async throws -> [SlasheyCommand] {
        let path = pathManager.claudeCodeUserCommandsPath
        return try await loadCommands(from: path, scope: .user)
    }

    func loadProjectCommands(from project: URL) async throws -> [SlasheyCommand] {
        let path = pathManager.claudeCodeProjectCommandsPath(for: project)
        return try await loadCommands(from: path, scope: .project, projectPath: project.path)
    }

    private func loadCommands(from directory: URL, scope: CommandScope, projectPath: String? = nil) async throws -> [SlasheyCommand] {
        guard pathManager.exists(directory) else { return [] }

        var commands: [SlasheyCommand] = []
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])

        for fileURL in contents where fileURL.pathExtension == "md" {
            let command = try parseClaudeCodeFile(at: fileURL, scope: scope, projectPath: projectPath)
            commands.append(command)
        }

        return commands
    }

    private func parseClaudeCodeFile(at url: URL, scope: CommandScope, projectPath: String?) throws -> SlasheyCommand {
        let content = try String(contentsOf: url, encoding: .utf8)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let modDate = attributes[.modificationDate] as? Date ?? Date()

        let name = url.deletingPathExtension().lastPathComponent
        var description = ""
        var body = content

        // Parse frontmatter if present
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                body = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

                for line in frontmatter.components(separatedBy: .newlines) {
                    if line.hasPrefix("description:") {
                        description = line.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        return SlasheyCommand(
            name: name,
            description: description,
            content: body,
            scope: scope,
            activationMode: .manual,
            sourceService: .claudeCode,
            lastModified: modDate,
            projectPath: projectPath,
            filePath: url.path
        )
    }

    func saveCommand(_ command: SlasheyCommand) async throws {
        let directory: URL
        if command.scope == .project, let projectPath = command.projectPath {
            directory = pathManager.claudeCodeProjectCommandsPath(for: URL(fileURLWithPath: projectPath))
        } else {
            directory = pathManager.claudeCodeUserCommandsPath
        }

        try pathManager.createDirectoryIfNeeded(directory)

        let fileURL = directory.appendingPathComponent("\(command.name).md")
        var output = ""

        if !command.description.isEmpty {
            output = """
            ---
            description: \(command.description)
            ---

            """
        }

        output += command.content

        try output.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func deleteCommand(_ command: SlasheyCommand) async throws {
        guard let filePath = command.filePath else { return }
        try fileManager.removeItem(atPath: filePath)
    }
}

// MARK: - Cursor Adapter

final class CursorAdapter: ServiceAdapter {
    let service: Service = .cursor
    private let pathManager = PathManager.shared
    private let fileManager = FileManager.default

    func loadUserCommands() async throws -> [SlasheyCommand] {
        let path = pathManager.cursorUserCommandsPath
        guard pathManager.exists(path) else { return [] }

        var commands: [SlasheyCommand] = []
        let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [.contentModificationDateKey])

        for fileURL in contents where fileURL.pathExtension == "md" || fileURL.pathExtension == "mdc" {
            let command = try parseCursorFile(at: fileURL, scope: .user, projectPath: nil)
            commands.append(command)
        }

        return commands
    }

    func loadProjectCommands(from project: URL) async throws -> [SlasheyCommand] {
        var commands: [SlasheyCommand] = []

        // Check modern .cursor/rules/ directory
        let rulesDir = pathManager.cursorProjectRulesPath(for: project)
        if pathManager.exists(rulesDir) {
            let contents = try fileManager.contentsOfDirectory(at: rulesDir, includingPropertiesForKeys: [.contentModificationDateKey])
            for fileURL in contents where fileURL.pathExtension == "mdc" || fileURL.pathExtension == "md" {
                let command = try parseCursorFile(at: fileURL, scope: .project, projectPath: project.path)
                commands.append(command)
            }
        }

        // Check legacy .cursorrules file
        let legacyPath = pathManager.cursorLegacyRulesPath(for: project)
        if pathManager.exists(legacyPath) {
            let command = try parseCursorFile(at: legacyPath, scope: .project, projectPath: project.path)
            commands.append(command)
        }

        return commands
    }

    private func parseCursorFile(at url: URL, scope: CommandScope, projectPath: String?) throws -> SlasheyCommand {
        let content = try String(contentsOf: url, encoding: .utf8)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let modDate = attributes[.modificationDate] as? Date ?? Date()

        let name = url.deletingPathExtension().lastPathComponent
        var description = ""
        var globs: [String]?
        var alwaysApply = false
        var body = content

        // Parse MDC frontmatter if present
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                body = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

                for line in frontmatter.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("description:") {
                        description = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("alwaysApply:") {
                        alwaysApply = trimmed.contains("true")
                    } else if trimmed.hasPrefix("- \"") || trimmed.hasPrefix("- '") {
                        let glob = trimmed
                            .replacingOccurrences(of: "- ", with: "")
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        if globs == nil { globs = [] }
                        globs?.append(glob)
                    }
                }
            }
        }

        let activationMode: ActivationMode
        if alwaysApply {
            activationMode = .always
        } else if globs != nil && !globs!.isEmpty {
            activationMode = .autoAttach
        } else if !description.isEmpty {
            activationMode = .modelDecision
        } else {
            activationMode = .manual
        }

        return SlasheyCommand(
            name: name,
            description: description,
            content: body,
            scope: scope,
            globs: globs,
            activationMode: activationMode,
            sourceService: .cursor,
            lastModified: modDate,
            projectPath: projectPath,
            filePath: url.path
        )
    }

    func saveCommand(_ command: SlasheyCommand) async throws {
        let directory: URL
        let fileExtension: String

        if command.scope == .project, let projectPath = command.projectPath {
            directory = pathManager.cursorProjectRulesPath(for: URL(fileURLWithPath: projectPath))
            fileExtension = "mdc"
        } else {
            directory = pathManager.cursorUserCommandsPath
            fileExtension = "md"
        }

        try pathManager.createDirectoryIfNeeded(directory)

        let fileURL = directory.appendingPathComponent("\(command.name).\(fileExtension)")

        var output = "---\n"
        output += "description: \(command.description)\n"

        if let globs = command.globs, !globs.isEmpty {
            output += "globs:\n"
            for glob in globs {
                output += "  - \"\(glob)\"\n"
            }
        }

        output += "alwaysApply: \(command.activationMode == .always)\n"
        output += "---\n\n"
        output += command.content

        try output.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func deleteCommand(_ command: SlasheyCommand) async throws {
        guard let filePath = command.filePath else { return }
        try fileManager.removeItem(atPath: filePath)
    }
}

// MARK: - Windsurf Adapter

final class WindsurfAdapter: ServiceAdapter {
    let service: Service = .windsurf
    private let pathManager = PathManager.shared
    private let fileManager = FileManager.default

    func loadUserCommands() async throws -> [SlasheyCommand] {
        let path = pathManager.windsurfUserRulesPath
        guard pathManager.exists(path) else { return [] }

        let content = try String(contentsOf: path, encoding: .utf8)
        let attributes = try fileManager.attributesOfItem(atPath: path.path)
        let modDate = attributes[.modificationDate] as? Date ?? Date()

        let command = SlasheyCommand(
            name: "global_rules",
            description: "Windsurf global rules",
            content: content,
            scope: .user,
            activationMode: .always,
            sourceService: .windsurf,
            lastModified: modDate,
            filePath: path.path
        )

        return [command]
    }

    func loadProjectCommands(from project: URL) async throws -> [SlasheyCommand] {
        var commands: [SlasheyCommand] = []

        // Check .windsurfrules file
        let rulesFile = pathManager.windsurfProjectRulesPath(for: project)
        if pathManager.exists(rulesFile) {
            let command = try parseWindsurfFile(at: rulesFile, scope: .project, projectPath: project.path)
            commands.append(command)
        }

        // Check .windsurf/rules/ directory
        let rulesDir = pathManager.windsurfProjectRulesDirectoryPath(for: project)
        if pathManager.exists(rulesDir) {
            let contents = try fileManager.contentsOfDirectory(at: rulesDir, includingPropertiesForKeys: [.contentModificationDateKey])
            for fileURL in contents where fileURL.pathExtension == "md" {
                let command = try parseWindsurfFile(at: fileURL, scope: .project, projectPath: project.path)
                commands.append(command)
            }
        }

        return commands
    }

    private func parseWindsurfFile(at url: URL, scope: CommandScope, projectPath: String?) throws -> SlasheyCommand {
        let content = try String(contentsOf: url, encoding: .utf8)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let modDate = attributes[.modificationDate] as? Date ?? Date()

        let name = url.deletingPathExtension().lastPathComponent

        return SlasheyCommand(
            name: name,
            description: "Windsurf rule",
            content: content,
            scope: scope,
            activationMode: .always,
            sourceService: .windsurf,
            lastModified: modDate,
            projectPath: projectPath,
            filePath: url.path
        )
    }

    func saveCommand(_ command: SlasheyCommand) async throws {
        let fileURL: URL

        if command.scope == .project, let projectPath = command.projectPath {
            let directory = pathManager.windsurfProjectRulesDirectoryPath(for: URL(fileURLWithPath: projectPath))
            try pathManager.createDirectoryIfNeeded(directory)
            fileURL = directory.appendingPathComponent("\(command.name).md")
        } else {
            let parentDir = pathManager.windsurfUserRulesPath.deletingLastPathComponent()
            try pathManager.createDirectoryIfNeeded(parentDir)
            fileURL = pathManager.windsurfUserRulesPath
        }

        try command.content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func deleteCommand(_ command: SlasheyCommand) async throws {
        guard let filePath = command.filePath else { return }
        try fileManager.removeItem(atPath: filePath)
    }
}
