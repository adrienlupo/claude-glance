#!/usr/bin/env swift

import AppKit

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

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded rectangle clipping
    let cornerRadius = s * 0.22
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()

    // Background gradient (Claude's coral/terracotta tones)
    let gradient = NSGradient(
        starting: NSColor(red: 0.85, green: 0.45, blue: 0.35, alpha: 1.0),
        ending: NSColor(red: 0.78, green: 0.35, blue: 0.28, alpha: 1.0)
    )!
    gradient.draw(in: rect, angle: -45)

    // Draw the Claude sunburst/asterisk symbol
    let center = CGPoint(x: s / 2, y: s / 2)
    let numRays = 8
    let rayLength = s * 0.28
    let rayWidth = s * 0.08
    let dotRadius = s * 0.065

    context.saveGState()
    context.setFillColor(CGColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1.0))

    // Central circle
    let centralRadius = s * 0.09
    context.fillEllipse(in: CGRect(
        x: center.x - centralRadius,
        y: center.y - centralRadius,
        width: centralRadius * 2,
        height: centralRadius * 2
    ))

    // Rays with rounded ends
    for i in 0..<numRays {
        let angle = CGFloat(i) * (.pi * 2.0 / CGFloat(numRays))

        let path = CGMutablePath()
        let halfWidth = rayWidth / 2

        let innerRadius = s * 0.12
        let startX = center.x + cos(angle) * innerRadius
        let startY = center.y + sin(angle) * innerRadius
        let endX = center.x + cos(angle) * (innerRadius + rayLength)
        let endY = center.y + sin(angle) * (innerRadius + rayLength)

        // Perpendicular offset for width
        let perpX = -sin(angle) * halfWidth
        let perpY = cos(angle) * halfWidth

        path.move(to: CGPoint(x: startX + perpX, y: startY + perpY))
        path.addLine(to: CGPoint(x: endX + perpX, y: endY + perpY))
        path.addLine(to: CGPoint(x: endX - perpX, y: endY - perpY))
        path.addLine(to: CGPoint(x: startX - perpX, y: startY - perpY))
        path.closeSubpath()

        context.addPath(path)
        context.fillPath()

        // Dot at end of each ray
        context.fillEllipse(in: CGRect(
            x: endX - dotRadius,
            y: endY - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
    }

    context.restoreGState()
    image.unlockFocus()
    return image
}

for (name, size) in sizes {
    let image = drawIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to generate \(name)\n", stderr)
        exit(1)
    }
    let fileURL = outputDir.appendingPathComponent("\(name).png")
    try pngData.write(to: fileURL)
}

// Convert iconset to icns using iconutil
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
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
