//
//  ToolbarComponents.swift
//  Slashey
//

import SwiftUI

struct SyncStatusIndicator: View {
    let syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: 6) {
            if syncEngine.isSyncing {
                ProgressView()
                    .controlSize(.small)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastSync = syncEngine.lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
