// Run with: swift platforms/ios/generate-app-icon.swift
import AppKit

let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let target = folder.appendingPathComponent("NepTypeMobile/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
context.setFillColor(CGColor(gray: 30/255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
let title = NSAttributedString(string: "NT", attributes: [
    .font: NSFont.systemFont(ofSize: 390, weight: .regular),
    .foregroundColor: NSColor(white: 232/255, alpha: 1)
])
let size = title.size()
title.draw(at: NSPoint(x: (1024 - size.width) / 2, y: (1024 - size.height) / 2))
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: target)
