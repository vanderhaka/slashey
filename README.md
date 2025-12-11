# Slashey

A native macOS app that synchronizes custom slash commands between AI coding assistants.

Keep your workflows consistent across **Claude Code**, **Cursor**, and **Windsurf** without manually copying files between tools.

## Table of Contents

- [The Problem](#the-problem)
- [Features](#features)
- [Supported Services](#supported-services)
- [Installation](#installation)
- [Usage](#usage)
  - [First Launch](#first-launch)
  - [Viewing Commands](#viewing-commands)
  - [Creating Commands](#creating-commands)
  - [Syncing Commands](#syncing-commands)
  - [Keyboard Shortcuts](#keyboard-shortcuts)
- [Command Activation Modes](#command-activation-modes)
- [Settings](#settings)
- [Backups](#backups)
- [File Format Reference](#file-format-reference)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [License](#license)
- [Contributing](#contributing)

## The Problem

Modern AI coding assistants let you create custom slash commands (like `/review`, `/refactor`, `/test`) that supercharge your workflow. But if you use multiple tools, keeping these commands in sync is tedious:

- Claude Code stores commands in `~/.claude/commands/`
- Cursor uses `~/.cursor/commands/` and `.cursor/rules/`
- Windsurf keeps rules in `~/.codeium/windsurf/memories/`

Each service has different file formats, frontmatter schemas, and activation modes. Slashey handles all of this automatically.

## Features

- **Unified View** - See all your commands from every service in one place
- **Cross-Service Sync** - Push any command to other services with one click
- **Smart Format Conversion** - Automatically converts between `.md` and `.mdc` formats with proper frontmatter
- **Create & Edit** - Full editor with syntax highlighting for command content
- **Automatic Backups** - Files are backed up before any modification (last 10 versions kept)
- **Service Detection** - Automatically detects which AI tools you have installed
- **Native macOS App** - Built with SwiftUI, feels right at home on your Mac

## Supported Services

| Service | User Commands | Project Commands | File Format |
|---------|--------------|------------------|-------------|
| Claude Code | `~/.claude/commands/*.md` | `.claude/commands/*.md` | Markdown with YAML frontmatter |
| Cursor | `~/.cursor/commands/*.md` | `.cursor/rules/*.mdc` | MDC (Markdown Components) |
| Windsurf | `~/.codeium/windsurf/memories/global_rules.md` | `.windsurfrules`, `.windsurf/rules/*.md` | Plain Markdown |

## Installation

### Download

Download the latest release from the [Releases](https://github.com/vanderhaka/slashey/releases) page.

### Build from Source

Requirements:
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

```bash
git clone https://github.com/vanderhaka/slashey.git
cd slashey
open Slashey.xcodeproj
```

Build and run with `Cmd+R` in Xcode.

## Usage

### First Launch

On first launch, Slashey will:
1. Detect which AI coding tools you have installed
2. Guide you through selecting which services to sync
3. Load all existing commands from your enabled services

### Viewing Commands

The sidebar lets you filter commands by:
- **Service** - Claude Code, Cursor, Windsurf, or All
- **Scope** - User (global) or Project (per-repository)

Click any command to view its details and edit its content.

### Creating Commands

1. Press `Cmd+N` or click the **+** button
2. Enter a name (letters, numbers, dashes, underscores only)
3. Add a description (used by AI to understand when to invoke it)
4. Choose the target service and activation mode
5. Write your command content
6. Click **Create**

### Syncing Commands

To push a command to other services:

1. Select the command you want to sync
2. Click **Sync to Other Services...**
3. Select which services to sync to
4. Confirm the sync

Slashey will:
- Back up any existing command with the same name
- Convert the format as needed (frontmatter, file extension)
- Write the command to the correct location for each service

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Command | `Cmd+N` |
| Save Changes | `Cmd+S` |
| Refresh | `Cmd+R` |
| Refresh Services | `Cmd+Shift+R` |

## Command Activation Modes

Different services handle command activation differently. Slashey normalizes these into four modes:

| Mode | Description | Behavior |
|------|-------------|----------|
| **Manual** | Invoke with `/command-name` | Default for most commands |
| **Always** | Always active in context | Cursor's `alwaysApply: true` |
| **Auto-attach** | Active when matching files open | Cursor's `globs` patterns |
| **AI Decides** | AI chooses based on description | Cursor's model-decision mode |

## Settings

Access settings via the menu bar or `Cmd+,`:

### General
- Launch at Login

### Services
- View detected services and their installation status
- Refresh detection

### Sync
- **Sync Strategy**: Manual only, or on file change
- **Conflict Resolution**: Newer wins, source wins, or ask
- **Enabled Services**: Toggle which services participate in sync

## Backups

Slashey automatically backs up files before modifying them. Backups are stored in:

```
~/Library/Application Support/Slashey/Backups/
```

Access backups via **Help > Open Backups Folder...**

Each file keeps up to 10 timestamped versions. Format: `commandname_2025-01-15T10-30-00Z.md`

## File Format Reference

### Claude Code (`.md`)

```markdown
---
description: Brief description of command
---

Your command content here...
```

### Cursor (`.mdc`)

```markdown
---
description: Brief description of command
globs:
  - "**/*.ts"
  - "**/*.tsx"
alwaysApply: false
---

Your command content here...
```

### Windsurf (`.md`)

Plain markdown, no frontmatter required.

## Architecture

Slashey is built with:
- **SwiftUI** for the UI
- **Swift Observation** for reactive state management
- **Service Adapters** that handle format conversion per-service
- **PathManager** for cross-platform path handling

Key components:
- `ServiceDetector` - Finds installed AI tools
- `CommandStore` - Loads, saves, and syncs commands
- `SyncEngine` - Coordinates sync operations
- `BackupManager` - Handles automatic backups
- `ServiceAdapter` - Protocol implemented per-service for format conversion

## Requirements

- macOS 14.0 (Sonoma) or later
- At least one supported AI coding assistant installed

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

## Acknowledgments

Built for developers who use multiple AI coding assistants and want their custom commands everywhere.
