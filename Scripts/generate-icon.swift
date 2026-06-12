#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let buildURL = rootURL.appendingPathComponent(".build", isDirectory: true)
let iconsetURL = buildURL.appendingPathComponent("FlowBarIcon.iconset", isDirectory: true)
let outputURL = rootURL.appendingPathComponent("Resources/FlowBarIcon.icns")

try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    let image = NSImage(size: NSSize(width: iconFile.pixels, height: iconFile.pixels))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to create graphics context")
    }

    context.interpolationQuality = .high
    context.translateBy(x: 0, y: iconFile.pixels)
    context.scaleBy(x: iconFile.pixels / 1024, y: -iconFile.pixels / 1024)
    drawIcon(in: context)

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Unable to encode \(iconFile.name)")
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(iconFile.name))
}

try? FileManager.default.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", outputURL.path, iconsetURL.path]
process.standardOutput = Pipe()
process.standardError = Pipe()
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    try writeICNS(from: iconsetURL, to: outputURL)
}

func drawIcon(in context: CGContext) {
    let bgPath = CGPath(
        roundedRect: CGRect(x: 152, y: 128, width: 720, height: 720),
        cornerWidth: 168,
        cornerHeight: 168,
        transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 34),
        blur: 34,
        color: CGColor(red: 0.03, green: 0.18, blue: 0.47, alpha: 0.32)
    )
    context.addPath(bgPath)
    context.setFillColor(CGColor(red: 0.10, green: 0.47, blue: 0.95, alpha: 1.0))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    drawGradient(
        in: context,
        colors: [
            CGColor(red: 0.35, green: 0.72, blue: 1.00, alpha: 1.0),
            CGColor(red: 0.10, green: 0.47, blue: 0.95, alpha: 1.0),
            CGColor(red: 0.05, green: 0.25, blue: 0.73, alpha: 1.0)
        ],
        locations: [0.0, 0.52, 1.0],
        start: CGPoint(x: 180, y: 92),
        end: CGPoint(x: 844, y: 932)
    )

    let shinePath = CGPath(
        roundedRect: CGRect(x: 176, y: 152, width: 672, height: 672),
        cornerWidth: 148,
        cornerHeight: 148,
        transform: nil
    )
    context.addPath(shinePath)
    context.clip()
    drawGradient(
        in: context,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.46),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ],
        locations: [0.0, 1.0],
        start: CGPoint(x: 238, y: 144),
        end: CGPoint(x: 786, y: 820)
    )
    context.restoreGState()

    strokePath(in: context, points: [CGPoint(x: 512, y: 258), CGPoint(x: 512, y: 608)], color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), width: 86)
    strokePath(in: context, points: [CGPoint(x: 354, y: 500), CGPoint(x: 512, y: 658), CGPoint(x: 670, y: 500)], color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), width: 86)

    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: 609, y: 716))
    bolt.addLine(to: CGPoint(x: 701, y: 542))
    bolt.addLine(to: CGPoint(x: 625, y: 542))
    bolt.addLine(to: CGPoint(x: 668, y: 414))
    bolt.addLine(to: CGPoint(x: 516, y: 604))
    bolt.addLine(to: CGPoint(x: 602, y: 604))
    bolt.addLine(to: CGPoint(x: 557, y: 736))
    bolt.addCurve(to: CGPoint(x: 609, y: 716), control1: CGPoint(x: 550, y: 757), control2: CGPoint(x: 598, y: 736))
    bolt.closeSubpath()

    context.addPath(bolt)
    context.setFillColor(CGColor(red: 0.87, green: 0.96, blue: 0.36, alpha: 1.0))
    context.fillPath()
}

func drawGradient(in context: CGContext, colors: [CGColor], locations: [CGFloat], start: CGPoint, end: CGPoint) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
        return
    }
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func strokePath(in context: CGContext, points: [CGPoint], color: CGColor, width: CGFloat) {
    guard let first = points.first else {
        return
    }

    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
    context.restoreGState()
}

func writeICNS(from iconsetURL: URL, to outputURL: URL) throws {
    let chunks: [(type: String, fileName: String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png")
    ]

    var body = Data()
    for chunk in chunks {
        let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(chunk.fileName))
        body.append(Data(chunk.type.utf8))
        body.appendBigEndianUInt32(UInt32(pngData.count + 8))
        body.append(pngData)
    }

    var iconData = Data("icns".utf8)
    iconData.appendBigEndianUInt32(UInt32(body.count + 8))
    iconData.append(body)
    try iconData.write(to: outputURL)
}

extension Data {
    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
