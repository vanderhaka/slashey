//
//  SidebarView.swift
//  Slashey
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedService: Service?
    @Binding var selectedScope: CommandScope
    let serviceDetector: ServiceDetector
    let commandStore: CommandStore

    var body: some View {
        List {
            // Scope Toggle
            Section {
                Picker("", selection: $selectedScope) {
                    Label("User", systemImage: "person")
                        .tag(CommandScope.user)
                    Label("Project", systemImage: "folder")
                        .tag(CommandScope.project)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            // All Commands option
            Section {
                SidebarRow(
                    title: "All Services",
                    icon: "square.stack.3d.up",
                    iconColor: .purple,
                    count: commandStore.commands(for: nil, scope: selectedScope).count,
                    isSelected: selectedService == nil,
                    isEnabled: true
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedService = nil
                }
            }

            // Services
            Section("Services") {
                ForEach(Service.allCases) { service in
                    let isInstalled = serviceDetector.isInstalled(service)
                    SidebarRow(
                        title: service.displayName,
                        icon: service.iconName,
                        iconColor: service.color,
                        count: commandStore.commands(for: service, scope: selectedScope).count,
                        isSelected: selectedService == service,
                        isEnabled: isInstalled
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isInstalled {
                            selectedService = service
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Slashey")
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let count: Int
    let isSelected: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? iconColor : .secondary)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(isEnabled ? .primary : .secondary)

            Spacer()

            if isEnabled {
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .opacity(isEnabled ? 1 : 0.5)
    }
}
