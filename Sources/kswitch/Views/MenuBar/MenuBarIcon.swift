import SwiftUI

struct MenuBarIcon: View {
    var body: some View {
        Image(nsImage: menuBarImage)
    }

    private var menuBarImage: NSImage {
        let resourceBundle = Bundle.main.resourceURL!
            .appendingPathComponent("kswitch_kswitch.bundle")
        let bundle = Bundle(url: resourceBundle)!
        let imagePath = bundle.path(forResource: "MenuBarIcon@2x", ofType: "png",
                                    inDirectory: "Assets.xcassets/MenuBarIcon.imageset")!
        let image = NSImage(contentsOfFile: imagePath)!
        image.isTemplate = true
        return image
    }
}
