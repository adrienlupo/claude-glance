#!/usr/bin/env swift

import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let sourceImage = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("ClaudeGlance")
    .appendingPathComponent("Sources")
    .appendingPathComponent("Resources")
    .appendingPathComponent("logo-grey.png")

guard let image = NSImage(contentsOf: sourceImage) else {
    fputs("Failed to load \(sourceImage.path)\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ClaudeGlanceIcon.iconset")
try? FileManager.default.removeItem(at: outputDir)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, size) in sizes {
    let s = CGFloat(size)
    let resized = NSImage(size: NSSize(width: s, height: s))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: s, height: s),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
    )
    resized.unlockFocus()

    guard let tiffData = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to generate \(name)\n", stderr)
        exit(1)
    }
    let fileURL = outputDir.appendingPathComponent("\(name).png")
    try pngData.write(to: fileURL)
}

let resourcesDir = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("ClaudeGlance")
    .appendingPathComponent("Resources")
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns").path

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", icnsPath, outputDir.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(1)
}

try? FileManager.default.removeItem(at: outputDir)
print("Generated \(icnsPath)")
