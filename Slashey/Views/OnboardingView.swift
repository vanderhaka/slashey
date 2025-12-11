//
//  OnboardingView.swift
//  Slashey
//

import SwiftUI

struct OnboardingView: View {
    let serviceDetector: ServiceDetector
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                ServicesPage(serviceDetector: serviceDetector)
                    .tag(1)

                HowItWorksPage()
                    .tag(2)

                ReadyPage()
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

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
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
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 540, height: 440)
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

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Detected Services")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(Service.allCases) { service in
                    HStack(spacing: 16) {
                        Image(systemName: service.iconName)
                            .font(.title)
                            .foregroundStyle(service.color)
                            .frame(width: 40)

                        VStack(alignment: .leading) {
                            Text(service.displayName)
                                .font(.headline)

                            Text(servicePath(for: service))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if serviceDetector.isInstalled(service) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        } else {
                            Text("Not found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 40)

            if serviceDetector.installedServices.count < 2 {
                Label("Install at least 2 services to sync commands between them", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding()
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

                Text("Start syncing your commands")
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
    OnboardingView(serviceDetector: ServiceDetector()) {
        print("Complete")
    }
}
