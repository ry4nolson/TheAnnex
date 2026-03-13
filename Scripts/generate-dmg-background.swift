#!/usr/bin/env swift
import Cocoa

// DMG background image generator for The Annex
// Produces a 660x400 background with app branding and "drag to install" visual

let width: CGFloat = 660
let height: CGFloat = 400

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext

// Background gradient (dark charcoal to near-black)
let gradientColors = [
    NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor
]
if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0.0, 1.0]) {
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
}

// Subtle top highlight line
context.setStrokeColor(NSColor(white: 1.0, alpha: 0.06).cgColor)
context.setLineWidth(1.0)
context.move(to: CGPoint(x: 0, y: height - 0.5))
context.addLine(to: CGPoint(x: width, y: height - 0.5))
context.strokePath()

// App name "The Annex" centered near the top
let titleFont = NSFont.systemFont(ofSize: 28, weight: .light)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.9)
]
let titleString = "The Annex" as NSString
let titleSize = titleString.size(withAttributes: titleAttrs)
let titleRect = NSRect(
    x: (width - titleSize.width) / 2,
    y: height - 58,
    width: titleSize.width,
    height: titleSize.height
)
titleString.draw(in: titleRect, withAttributes: titleAttrs)

// Instruction text
let instrFont = NSFont.systemFont(ofSize: 13, weight: .regular)
let instrAttrs: [NSAttributedString.Key: Any] = [
    .font: instrFont,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.45)
]
let instrString = "Drag to Applications to install" as NSString
let instrSize = instrString.size(withAttributes: instrAttrs)
let instrRect = NSRect(
    x: (width - instrSize.width) / 2,
    y: 42,
    width: instrSize.width,
    height: instrSize.height
)
instrString.draw(in: instrRect, withAttributes: instrAttrs)

// Draw arrow in the center (between where the two icons will sit)
// Icons are positioned at x=155 and x=395 by the DMG layout
// Arrow sits between them
let arrowY: CGFloat = 190
let arrowLeft: CGFloat = 255
let arrowRight: CGFloat = 395
let arrowMidY: CGFloat = arrowY

context.setStrokeColor(NSColor(white: 1.0, alpha: 0.25).cgColor)
context.setLineWidth(2.5)
context.setLineCap(.round)
context.setLineJoin(.round)

// Arrow shaft
context.move(to: CGPoint(x: arrowLeft, y: arrowMidY))
context.addLine(to: CGPoint(x: arrowRight - 12, y: arrowMidY))
context.strokePath()

// Arrow head
context.move(to: CGPoint(x: arrowRight - 24, y: arrowMidY + 12))
context.addLine(to: CGPoint(x: arrowRight - 12, y: arrowMidY))
context.addLine(to: CGPoint(x: arrowRight - 24, y: arrowMidY - 12))
context.strokePath()

// Generate image
guard let cgImage = context.makeImage() else {
    fputs("Failed to create image\n", stderr)
    exit(1)
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
bitmapRep.size = NSSize(width: width, height: height)

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fputs("Failed to create PNG data\n", stderr)
    exit(1)
}

// Output path
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = scriptDir
}

let outputPath = (outputDir as NSString).appendingPathComponent("dmg-background.png")
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✓ Generated DMG background: \(outputPath)")
} catch {
    fputs("Failed to write image: \(error)\n", stderr)
    exit(1)
}

// Also generate a @2x version for Retina
let retinaWidth: CGFloat = width * 2
let retinaHeight: CGFloat = height * 2

guard let retinaContext = CGContext(
    data: nil,
    width: Int(retinaWidth),
    height: Int(retinaHeight),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create retina context\n", stderr)
    exit(1)
}

retinaContext.scaleBy(x: 2.0, y: 2.0)
let retinaGfx = NSGraphicsContext(cgContext: retinaContext, flipped: false)
NSGraphicsContext.current = retinaGfx

// Repeat drawing at 2x
if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0.0, 1.0]) {
    retinaContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
}
retinaContext.setStrokeColor(NSColor(white: 1.0, alpha: 0.06).cgColor)
retinaContext.setLineWidth(1.0)
retinaContext.move(to: CGPoint(x: 0, y: height - 0.5))
retinaContext.addLine(to: CGPoint(x: width, y: height - 0.5))
retinaContext.strokePath()

titleString.draw(in: titleRect, withAttributes: titleAttrs)
instrString.draw(in: instrRect, withAttributes: instrAttrs)

retinaContext.setStrokeColor(NSColor(white: 1.0, alpha: 0.25).cgColor)
retinaContext.setLineWidth(2.5)
retinaContext.setLineCap(.round)
retinaContext.setLineJoin(.round)
retinaContext.move(to: CGPoint(x: arrowLeft, y: arrowMidY))
retinaContext.addLine(to: CGPoint(x: arrowRight - 12, y: arrowMidY))
retinaContext.strokePath()
retinaContext.move(to: CGPoint(x: arrowRight - 24, y: arrowMidY + 12))
retinaContext.addLine(to: CGPoint(x: arrowRight - 12, y: arrowMidY))
retinaContext.addLine(to: CGPoint(x: arrowRight - 24, y: arrowMidY - 12))
retinaContext.strokePath()

guard let retinaCgImage = retinaContext.makeImage() else {
    fputs("Failed to create retina image\n", stderr)
    exit(1)
}
let retinaBitmapRep = NSBitmapImageRep(cgImage: retinaCgImage)
retinaBitmapRep.size = NSSize(width: width, height: height) // logical size stays 1x

guard let retinaPngData = retinaBitmapRep.representation(using: .png, properties: [:]) else {
    fputs("Failed to create retina PNG data\n", stderr)
    exit(1)
}

let retinaOutputPath = (outputDir as NSString).appendingPathComponent("dmg-background@2x.png")
do {
    try retinaPngData.write(to: URL(fileURLWithPath: retinaOutputPath))
    print("✓ Generated Retina DMG background: \(retinaOutputPath)")
} catch {
    fputs("Failed to write retina image: \(error)\n", stderr)
    exit(1)
}
