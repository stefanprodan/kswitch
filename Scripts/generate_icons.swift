#!/usr/bin/swift

import AppKit
import CoreGraphics

// MARK: - Configuration

let kubernetesBlue = NSColor(red: 0x32/255.0, green: 0x6C/255.0, blue: 0xE5/255.0, alpha: 1.0)
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let rootDir = scriptDir.deletingLastPathComponent()

// MARK: - App Icon Generation

func generateAppIcon(size: Int, scale: Int = 1) -> NSImage {
    let actualSize = size * scale
    let image = NSImage(size: NSSize(width: actualSize, height: actualSize))

    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: actualSize, height: actualSize)

    // Draw rounded rectangle background
    let cornerRadius = CGFloat(actualSize) * 0.2
    let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: cornerRadius, yRadius: cornerRadius)
    kubernetesBlue.setFill()
    path.fill()

    // Draw "KS" text
    let fontSize = CGFloat(actualSize) * 0.45
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

    let text = "KS"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]

    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: (CGFloat(actualSize) - textSize.width) / 2,
        y: (CGFloat(actualSize) - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
    )

    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()

    return image
}

func saveIcon(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for \(path)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// MARK: - Menu Bar Icon (Kubernetes Wheel)

func generateMenuBarIcon(size: Int, scale: Int = 1) -> NSImage {
    let actualSize = size * scale
    let image = NSImage(size: NSSize(width: actualSize, height: actualSize))

    image.lockFocus()

    let center = CGFloat(actualSize) / 2
    let outerRadius = CGFloat(actualSize) * 0.45
    let innerRadius = CGFloat(actualSize) * 0.2
    let spokeWidth = CGFloat(actualSize) * 0.08

    // Template image - draw in black, system will handle tinting
    NSColor.black.setFill()
    NSColor.black.setStroke()

    // Draw outer ring
    let outerPath = NSBezierPath()
    outerPath.appendArc(withCenter: NSPoint(x: center, y: center),
                        radius: outerRadius,
                        startAngle: 0,
                        endAngle: 360)
    outerPath.lineWidth = spokeWidth
    outerPath.stroke()

    // Draw inner hub
    let hubPath = NSBezierPath(ovalIn: NSRect(
        x: center - innerRadius,
        y: center - innerRadius,
        width: innerRadius * 2,
        height: innerRadius * 2
    ))
    hubPath.fill()

    // Draw 7 spokes (Kubernetes wheel has 7 spokes)
    let spokeCount = 7
    for i in 0..<spokeCount {
        let angle = (CGFloat(i) / CGFloat(spokeCount)) * 2 * .pi - .pi / 2
        let spokePath = NSBezierPath()

        let innerX = center + cos(angle) * innerRadius
        let innerY = center + sin(angle) * innerRadius
        let outerX = center + cos(angle) * outerRadius
        let outerY = center + sin(angle) * outerRadius

        spokePath.move(to: NSPoint(x: innerX, y: innerY))
        spokePath.line(to: NSPoint(x: outerX, y: outerY))
        spokePath.lineWidth = spokeWidth
        spokePath.lineCapStyle = .round
        spokePath.stroke()
    }

    image.unlockFocus()

    // Mark as template image
    image.isTemplate = true

    return image
}

// MARK: - Main

print("Generating KSwitch icons...")

// Create Icon.iconset directory
let iconsetPath = rootDir.appendingPathComponent("Icon.iconset").path
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes for app icon
let iconSizes: [(size: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for (size, scale, filename) in iconSizes {
    let icon = generateAppIcon(size: size, scale: scale)
    let path = "\(iconsetPath)/\(filename)"
    saveIcon(icon, to: path)
}

// Convert to .icns
let icnsPath = rootDir.appendingPathComponent("Icon.icns").path
let iconutilResult = Process()
iconutilResult.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutilResult.arguments = ["--convert", "icns", "--output", icnsPath, iconsetPath]
try? iconutilResult.run()
iconutilResult.waitUntilExit()

if iconutilResult.terminationStatus == 0 {
    print("Created: \(icnsPath)")
} else {
    print("Warning: iconutil failed to create .icns")
}

// Create menu bar icon imageset directory
let menuBarIconsetPath = rootDir.appendingPathComponent("Sources/kswitch/Resources/Assets.xcassets/MenuBarIcon.imageset").path
try? FileManager.default.createDirectory(atPath: menuBarIconsetPath, withIntermediateDirectories: true)

// Generate menu bar icons
let menuBarIcon1x = generateMenuBarIcon(size: 18, scale: 1)
let menuBarIcon2x = generateMenuBarIcon(size: 18, scale: 2)

saveIcon(menuBarIcon1x, to: "\(menuBarIconsetPath)/MenuBarIcon.png")
saveIcon(menuBarIcon2x, to: "\(menuBarIconsetPath)/MenuBarIcon@2x.png")

// Create Contents.json for the imageset
let contentsJson = """
{
  "images" : [
    {
      "filename" : "MenuBarIcon.png",
      "idiom" : "mac",
      "scale" : "1x"
    },
    {
      "filename" : "MenuBarIcon@2x.png",
      "idiom" : "mac",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
"""

try? contentsJson.write(toFile: "\(menuBarIconsetPath)/Contents.json", atomically: true, encoding: .utf8)
print("Created: \(menuBarIconsetPath)/Contents.json")

print("Done!")
