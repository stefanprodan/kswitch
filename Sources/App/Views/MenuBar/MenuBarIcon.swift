// Copyright 2026 Stefan Prodan.
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import Domain
import Infrastructure

struct MenuBarIcon: View {
    var body: some View {
        Image(nsImage: menuBarImage)
    }

    private var menuBarImage: NSImage {
        guard let resourceBundleURL = Bundle.main.resourceURL?
                .appendingPathComponent("kswitch_kswitch.bundle"),
              let bundle = Bundle(url: resourceBundleURL),
              let imagePath = bundle.path(forResource: "MenuBarIcon@2x", ofType: "png",
                                          inDirectory: "Assets.xcassets/MenuBarIcon.imageset"),
              let image = NSImage(contentsOfFile: imagePath) else {
            AppLog.warning("MenuBarIcon not found in bundle, using SF Symbol fallback")
            let fallback = NSImage(systemSymbolName: "cube.transparent",
                                   accessibilityDescription: "KSwitch") ?? NSImage()
            fallback.isTemplate = true
            return fallback
        }
        image.isTemplate = true
        return image
    }
}
