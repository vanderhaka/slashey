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
        List(selection: $selectedService) {
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
                Label {
                    HStack {
                        Text("All Services")
                        Spacer()
                        Text("\(commandStore.commands(for: nil, scope: selectedScope).count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } icon: {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.purple)
                }
                .tag(nil as Service?)
            }

            // Services
            Section("Services") {
                ForEach(Service.allCases) { service in
                    ServiceRowView(
                        service: service,
                        isInstalled: serviceDetector.isInstalled(service),
                        commandCount: commandStore.commands(for: service, scope: selectedScope).count
                    )
                    .tag(service as Service?)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Slashey")
    }
}

struct ServiceRowView: View {
    let service: Service
    let isInstalled: Bool
    let commandCount: Int

    var body: some View {
        Label {
            HStack {
                Text(service.displayName)

                Spacer()

                if isInstalled {
                    Text("\(commandCount)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        } icon: {
            Image(systemName: service.iconName)
                .foregroundStyle(service.color)
        }
        .opacity(isInstalled ? 1 : 0.5)
    }
}
