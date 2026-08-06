#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = rootURL.appendingPathComponent("Resources/FlowBarIcon.png")
let buildURL = rootURL.appendingPathComponent(".build", isDirectory: true)
let iconsetURL = buildURL.appendingPathComponent("FlowBarIcon.iconset", isDirectory: true)
let outputURL = rootURL.appendingPathComponent("Resources/FlowBarIcon.icns")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Unable to load app icon source at \(sourceURL.path)")
}

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
    let size = NSSize(width: iconFile.pixels, height: iconFile.pixels)
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let bounds = NSRect(origin: .zero, size: size)
    NSGraphicsContext.current?.cgContext.clear(bounds)
    NSBezierPath(
        roundedRect: bounds,
        xRadius: iconFile.pixels * 0.14,
        yRadius: iconFile.pixels * 0.14
    ).addClip()
    sourceImage.draw(in: NSRect(origin: .zero, size: size))
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
