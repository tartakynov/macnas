#!/usr/bin/env swift
// Generates MacNAS app icon as .icns
// A stylized hard drive / NAS icon with a network indicator

import Cocoa

func createIcon(size: Int, scale: Int) -> NSImage {
    let pixelSize = size * scale
    let img = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    img.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(pixelSize)

    // Background: rounded rect with gradient
    let bgRect = CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.84, height: s * 0.84)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.19, cornerHeight: s * 0.19, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Gradient: dark blue to slightly lighter blue
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 1.0),
        CGColor(red: 0.16, green: 0.22, blue: 0.35, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: s * 0.08), end: CGPoint(x: s/2, y: s * 0.92), options: [])
    ctx.restoreGState()

    // Draw two stacked drive bays
    func drawDriveBay(rect: CGRect, highlight: Bool) {
        let bayPath = CGPath(roundedRect: rect, cornerWidth: s * 0.03, cornerHeight: s * 0.03, transform: nil)

        // Bay background
        ctx.saveGState()
        ctx.addPath(bayPath)
        ctx.clip()
        let bayColors = [
            CGColor(red: 0.22, green: 0.28, blue: 0.42, alpha: 1.0),
            CGColor(red: 0.18, green: 0.23, blue: 0.36, alpha: 1.0),
        ] as CFArray
        let bayGrad = CGGradient(colorsSpace: colorSpace, colors: bayColors, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(bayGrad, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
        ctx.restoreGState()

        // Bay border
        ctx.setStrokeColor(CGColor(red: 0.35, green: 0.42, blue: 0.58, alpha: 0.8))
        ctx.setLineWidth(s * 0.008)
        ctx.addPath(bayPath)
        ctx.strokePath()

        // Drive slot lines (horizontal lines inside bay)
        let lineY1 = rect.midY
        ctx.setStrokeColor(CGColor(red: 0.30, green: 0.36, blue: 0.50, alpha: 0.5))
        ctx.setLineWidth(s * 0.004)
        ctx.move(to: CGPoint(x: rect.minX + s * 0.03, y: lineY1))
        ctx.addLine(to: CGPoint(x: rect.maxX - s * 0.12, y: lineY1))
        ctx.strokePath()

        // LED indicator dot
        let ledRadius = s * 0.018
        let ledCenter = CGPoint(x: rect.maxX - s * 0.06, y: rect.midY)
        let ledRect = CGRect(x: ledCenter.x - ledRadius, y: ledCenter.y - ledRadius, width: ledRadius * 2, height: ledRadius * 2)
        if highlight {
            // Green LED
            ctx.setFillColor(CGColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0))
            ctx.fillEllipse(in: ledRect)
            // LED glow
            ctx.saveGState()
            ctx.setFillColor(CGColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.3))
            let glowRect = ledRect.insetBy(dx: -ledRadius * 0.8, dy: -ledRadius * 0.8)
            ctx.fillEllipse(in: glowRect)
            ctx.restoreGState()
        } else {
            // Dim blue LED
            ctx.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.6))
            ctx.fillEllipse(in: ledRect)
        }
    }

    let bayWidth = s * 0.62
    let bayHeight = s * 0.15
    let bayX = s * 0.19
    let gap = s * 0.04

    let totalHeight = bayHeight * 3 + gap * 2
    let startY = (s - totalHeight) / 2

    // Three drive bays
    drawDriveBay(rect: CGRect(x: bayX, y: startY, width: bayWidth, height: bayHeight), highlight: true)
    drawDriveBay(rect: CGRect(x: bayX, y: startY + bayHeight + gap, width: bayWidth, height: bayHeight), highlight: true)
    drawDriveBay(rect: CGRect(x: bayX, y: startY + (bayHeight + gap) * 2, width: bayWidth, height: bayHeight), highlight: false)

    // Network/connection symbol: small wifi-like arcs in top-right area
    let arcCenter = CGPoint(x: s * 0.78, y: s * 0.78)
    ctx.setStrokeColor(CGColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.9))
    ctx.setLineWidth(s * 0.012)
    ctx.setLineCap(.round)

    for i in 0..<3 {
        let radius = s * (0.04 + CGFloat(i) * 0.035)
        let startAngle = CGFloat.pi * 0.25
        let endAngle = CGFloat.pi * 0.75
        ctx.addArc(center: arcCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        ctx.strokePath()
    }

    // Small dot at arc center
    let dotR = s * 0.012
    ctx.setFillColor(CGColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: arcCenter.x - dotR, y: arcCenter.y - dotR, width: dotR * 2, height: dotR * 2))

    img.unlockFocus()
    return img
}

// Generate iconset
let iconsetPath = "/Users/artem/src/macnas/.build/MacNAS.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] {
        let icon = createIcon(size: size, scale: scale)
        let pixelSize = size * scale
        let tiffData = icon.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiffData)!
        let pngData = bitmap.representation(using: .png, properties: [:])!

        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(size)x\(size)\(suffix).png"
        let filePath = (iconsetPath as NSString).appendingPathComponent(filename)
        try! pngData.write(to: URL(fileURLWithPath: filePath))
        print("Generated \(filename) (\(pixelSize)x\(pixelSize)px)")
    }
}

print("Iconset created at \(iconsetPath)")
print("Run: iconutil -c icns \(iconsetPath) -o MacNAS/Resources/AppIcon.icns")
