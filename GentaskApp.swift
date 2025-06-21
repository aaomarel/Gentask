//
//  GentaskApp.swift
//  Gentask
//
//  Created by Ahmed Omar on 6/10/25.
//

import SwiftUI

@main
struct GentaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No main window
        }
    }
}
