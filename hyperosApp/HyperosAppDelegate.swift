//
//  HyperosAppDelegate.swift
//  hyperosApp
//
//  Created by Alejandro Visiedo on 6/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

class AppDelegate: VMListDelegate {
    actor viewModel: AppViewModel {
        .init()
    }
}

struct HyperosApp: App {
    var listDelegate: VMListDelegate?
    var delegate: AppDelegate?
    var body: some Scene {
        WindowGroup {
            VMList(self.listDelegate)
        }
    }
}

