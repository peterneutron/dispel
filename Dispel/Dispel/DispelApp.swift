//
//  DispelApp.swift
//  Dispel
//

import SwiftUI

@main
struct DispelApp: App {
    // Bridge into our AppKit menubar implementation
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window; keep a minimal Settings scene to satisfy lifecycle
        Settings { EmptyView() }
    }
}
