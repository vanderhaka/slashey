//
//  SettingsView.swift
//  Slashey
//

import SwiftUI

struct SettingsView: View {
    let serviceDetector: ServiceDetector
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ServicesSettingsView(serviceDetector: serviceDetector)
                .tabItem {
                    Label("Services", systemImage: "app.connected.to.app.below.fill")
                }

            SyncSettingsView(syncEngine: syncEngine)
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 480, height: 320)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)

            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Build") {
                    Text("1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ServicesSettingsView: View {
    let serviceDetector: ServiceDetector

    var body: some View {
        Form {
            Section("Detected Services") {
                ForEach(Service.allCases) { service in
                    ServiceStatusRow(
                        service: service,
                        isInstalled: serviceDetector.isInstalled(service)
                    )
                }
            }

            Section {
                Button("Refresh Detection") {
                    serviceDetector.refresh()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ServiceStatusRow: View {
    let service: Service
    let isInstalled: Bool

    var body: some View {
        LabeledContent {
            HStack {
                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installed")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Not Found")
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label(service.displayName, systemImage: service.iconName)
                .foregroundStyle(service.color)
        }
    }
}

struct SyncSettingsView: View {
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        Form {
            Section("Sync Strategy") {
                Picker("When to Sync", selection: $syncEngine.syncStrategy) {
                    Text("Manual Only").tag(SyncStrategy.manual)
                    Text("On File Change").tag(SyncStrategy.onChange)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Conflict Resolution") {
                Picker("When Conflicts Occur", selection: $syncEngine.conflictResolution) {
                    ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Enabled Services") {
                ForEach(Service.allCases) { service in
                    Toggle(service.displayName, isOn: Binding(
                        get: { syncEngine.enabledServices.contains(service) },
                        set: { syncEngine.toggleService(service, enabled: $0) }
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
