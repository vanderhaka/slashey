//
//  WindowAccessor.swift
//  Slashey
//

import SwiftUI
import AppKit

/// Bridges SwiftUI view tree to the NSWindow so we can request fullscreen on launch.
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Intentionally empty - onResolve is called once in makeNSView.
        // Calling it here on every SwiftUI update causes unnecessary async dispatches
        // and potential race conditions with the didResizeWindow guard.
    }
}
