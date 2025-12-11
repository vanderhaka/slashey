//
//  Service.swift
//  Slashey
//

import SwiftUI

enum Service: String, CaseIterable, Codable, Identifiable {
    case claudeCode = "claude"
    case cursor = "cursor"
    case windsurf = "windsurf"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .cursor: return "Cursor"
        case .windsurf: return "Windsurf"
        }
    }

    var iconName: String {
        switch self {
        case .claudeCode: return "terminal"
        case .cursor: return "cursorarrow"
        case .windsurf: return "wind"
        }
    }

    var color: Color {
        switch self {
        case .claudeCode: return .orange
        case .cursor: return .blue
        case .windsurf: return .teal
        }
    }

    var fileExtension: String {
        switch self {
        case .claudeCode: return "md"
        case .cursor: return "mdc"
        case .windsurf: return "md"
        }
    }
}

enum CommandScope: String, CaseIterable, Codable {
    case user = "user"
    case project = "project"

    var displayName: String {
        switch self {
        case .user: return "User"
        case .project: return "Project"
        }
    }

    var icon: String {
        switch self {
        case .user: return "person"
        case .project: return "folder"
        }
    }
}

enum ActivationMode: String, CaseIterable, Codable {
    case always = "always"
    case manual = "manual"
    case autoAttach = "auto_attach"
    case modelDecision = "model_decision"

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .manual: return "Manual"
        case .autoAttach: return "Auto-attach"
        case .modelDecision: return "AI Decides"
        }
    }
}
