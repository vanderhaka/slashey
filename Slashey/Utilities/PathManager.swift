//
//  PathManager.swift
//  Slashey
//

import Foundation

struct PathManager {
    static let shared = PathManager()

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    // MARK: - Claude Code Paths

    var claudeCodeUserCommandsPath: URL {
        homeDirectory.appendingPathComponent(".claude/commands")
    }

    var claudeCodeConfigPath: URL {
        homeDirectory.appendingPathComponent(".claude")
    }

    func claudeCodeProjectCommandsPath(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".claude/commands")
    }

    // MARK: - Cursor Paths

    var cursorAppPath: URL {
        URL(fileURLWithPath: "/Applications/Cursor.app")
    }

    var cursorSupportPath: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/Cursor")
    }

    var cursorConfigPath: URL {
        homeDirectory.appendingPathComponent(".cursor")
    }

    var cursorUserCommandsPath: URL {
        homeDirectory.appendingPathComponent(".cursor/commands")
    }

    func cursorProjectRulesPath(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".cursor/rules")
    }

    func cursorLegacyRulesPath(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".cursorrules")
    }

    // MARK: - Windsurf Paths

    var windsurfAppPath: URL {
        URL(fileURLWithPath: "/Applications/Windsurf.app")
    }

    var windsurfConfigPath: URL {
        homeDirectory.appendingPathComponent(".codeium")
    }

    var windsurfUserRulesPath: URL {
        homeDirectory.appendingPathComponent(".codeium/windsurf/memories/global_rules.md")
    }

    func windsurfProjectRulesPath(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".windsurfrules")
    }

    func windsurfProjectRulesDirectoryPath(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".windsurf/rules")
    }

    // MARK: - Helpers

    func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func createDirectoryIfNeeded(_ url: URL) throws {
        if !exists(url) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func expandTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
