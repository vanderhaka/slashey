//
//  SlasheyCommand.swift
//  Slashey
//

import Foundation

struct SlasheyCommand: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var content: String
    var scope: CommandScope
    var namespace: String?
    var globs: [String]?
    var activationMode: ActivationMode
    var sourceService: Service
    var lastModified: Date
    var projectPath: String?
    var filePath: String?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        content: String = "",
        scope: CommandScope = .user,
        namespace: String? = nil,
        globs: [String]? = nil,
        activationMode: ActivationMode = .manual,
        sourceService: Service,
        lastModified: Date = Date(),
        projectPath: String? = nil,
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.scope = scope
        self.namespace = namespace
        self.globs = globs
        self.activationMode = activationMode
        self.sourceService = sourceService
        self.lastModified = lastModified
        self.projectPath = projectPath
        self.filePath = filePath
    }

    var fullName: String {
        if let namespace = namespace {
            return "\(namespace):\(name)"
        }
        return name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SlasheyCommand, rhs: SlasheyCommand) -> Bool {
        lhs.id == rhs.id
    }
}
