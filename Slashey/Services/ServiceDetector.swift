//
//  ServiceDetector.swift
//  Slashey
//

import Foundation

@Observable
final class ServiceDetector {
    private let pathManager = PathManager.shared
    private let fileManager = FileManager.default

    private(set) var installedServices: Set<Service> = []
    private(set) var serviceInfo: [Service: ServiceInfo] = [:]

    struct ServiceInfo {
        let isInstalled: Bool
        let userCommandsPath: URL?
        let userCommandCount: Int
    }

    init() {
        refresh()
    }

    func refresh() {
        for service in Service.allCases {
            let installed = checkInstalled(service)
            installedServices = installed ? installedServices.union([service]) : installedServices.subtracting([service])
            serviceInfo[service] = getServiceInfo(for: service)
        }
    }

    func isInstalled(_ service: Service) -> Bool {
        installedServices.contains(service)
    }

    private func checkInstalled(_ service: Service) -> Bool {
        switch service {
        case .claudeCode:
            return checkClaudeCodeInstalled()
        case .cursor:
            return checkCursorInstalled()
        case .windsurf:
            return checkWindsurfInstalled()
        }
    }

    private func checkClaudeCodeInstalled() -> Bool {
        // Check if config directory exists
        if pathManager.exists(pathManager.claudeCodeConfigPath) {
            return true
        }

        // Check common binary paths
        let binaryPaths = [
            pathManager.expandTilde("~/.claude/bin/claude"),
            pathManager.expandTilde("~/.local/bin/claude"),
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]

        return binaryPaths.contains { fileManager.fileExists(atPath: $0) }
    }

    private func checkCursorInstalled() -> Bool {
        pathManager.exists(pathManager.cursorAppPath) ||
        pathManager.exists(pathManager.cursorSupportPath) ||
        pathManager.exists(pathManager.cursorConfigPath)
    }

    private func checkWindsurfInstalled() -> Bool {
        pathManager.exists(pathManager.windsurfAppPath) ||
        pathManager.exists(pathManager.windsurfConfigPath)
    }

    private func getServiceInfo(for service: Service) -> ServiceInfo {
        let installed = isInstalled(service)
        var userPath: URL?
        var count = 0

        if installed {
            switch service {
            case .claudeCode:
                userPath = pathManager.claudeCodeUserCommandsPath
                count = countCommands(at: userPath, extension: "md")
            case .cursor:
                userPath = pathManager.cursorUserCommandsPath
                count = countCommands(at: userPath, extension: "md")
            case .windsurf:
                userPath = pathManager.windsurfUserRulesPath
                count = pathManager.exists(pathManager.windsurfUserRulesPath) ? 1 : 0
            }
        }

        return ServiceInfo(
            isInstalled: installed,
            userCommandsPath: userPath,
            userCommandCount: count
        )
    }

    private func countCommands(at url: URL?, extension ext: String) -> Int {
        guard let url = url, pathManager.exists(url) else { return 0 }
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return contents.filter { $0.pathExtension == ext }.count
        } catch {
            return 0
        }
    }
}
