//
//  OnboardingView.swift
//  Slashey
//

import SwiftUI

struct OnboardingView: View {
    let serviceDetector: ServiceDetector
    let syncEngine: SyncEngine
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                ServicesPage(
                    serviceDetector: serviceDetector,
                    syncEngine: syncEngine
                )
                .tag(1)

                HowItWorksPage()
                    .tag(2)

                ReadyPage(enabledCount: syncEngine.enabledServices.count)
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                // Page indicators (clickable)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                withAnimation { currentPage = index }
                            }
                    }
                }

                Spacer()

                if currentPage < 3 {
                    Button("Continue") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentPage == 1 && syncEngine.enabledServices.count < 2)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 540, height: 480)
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Welcome to Slashey")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Keep your AI coding commands in sync")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Slashey synchronizes custom commands between Claude Code, Cursor, and Windsurf—so you can use the same workflows everywhere.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

struct ServicesPage: View {
    let serviceDetector: ServiceDetector
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 4) {
                Text("Choose Your Services")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select which services to include in sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(Service.allCases) { service in
                    ServiceToggleRow(
                        service: service,
                        isInstalled: serviceDetector.isInstalled(service),
                        isEnabled: syncEngine.enabledServices.contains(service),
                        onToggle: { enabled in
                            syncEngine.toggleService(service, enabled: enabled)
                        }
                    )
                }
            }
            .padding(.horizontal, 40)

            // Status message
            Group {
                if syncEngine.enabledServices.count == 0 {
                    Label("Enable at least one service to continue", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if syncEngine.enabledServices.count == 1 {
                    Label("Enable 2+ services to sync between them", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Label("\(syncEngine.enabledServices.count) services enabled for sync", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
    }
}

struct ServiceToggleRow: View {
    let service: Service
    let isInstalled: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Service icon
            Image(systemName: service.iconName)
                .font(.title2)
                .foregroundStyle(isEnabled ? service.color : .secondary)
                .frame(width: 32)

            // Service info
            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName)
                    .font(.headline)
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                Text(servicePath(for: service))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status / Toggle
            if isInstalled {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            } else {
                Text("Not installed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(isEnabled ? service.color.opacity(0.08) : Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isEnabled ? service.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func servicePath(for service: Service) -> String {
        switch service {
        case .claudeCode: return "~/.claude/commands/"
        case .cursor: return "~/.cursor/commands/"
        case .windsurf: return "~/.codeium/windsurf/memories/"
        }
    }
}

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "doc.on.doc",
                    title: "View All Commands",
                    description: "See commands from all your AI tools in one place"
                )

                FeatureRow(
                    icon: "pencil",
                    title: "Edit & Create",
                    description: "Modify commands or create new ones with a simple editor"
                )

                FeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Sync Anywhere",
                    description: "Push commands to other services with one click"
                )

                FeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Automatic Backups",
                    description: "Your files are backed up before any changes"
                )
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ReadyPage: View {
    let enabledCount: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(enabledCount) service\(enabledCount == 1 ? "" : "s") ready to sync")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Label("Press ⌘N to create a new command", systemImage: "keyboard")
                Label("Press ⌘R to refresh all commands", systemImage: "arrow.clockwise")
                Label("Press ⌘S to save changes", systemImage: "square.and.arrow.down")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    let detector = ServiceDetector()
    let store = CommandStore(serviceDetector: detector)
    let sync = SyncEngine(commandStore: store)

    OnboardingView(serviceDetector: detector, syncEngine: sync) {
        print("Complete")
    }
}
