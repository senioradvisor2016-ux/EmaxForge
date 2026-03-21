#!/usr/bin/env swift

import AppKit
import CoreGraphics

// EMAX II-inspired app icon generator
// Creates a vintage sampler aesthetic with waveform + disk motif

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let ctx = NSGraphicsContext.current!.cgContext
    
    // Background gradient (dark vintage sampler blue-grey)
    let colors = [
        NSColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray,
                              locations: [0.0, 1.0])!
    
    ctx.drawLinearGradient(gradient,
                          start: CGPoint(x: 0, y: size),
                          end: CGPoint(x: 0, y: 0),
                          options: [])
    
    // Border (subtle vintage bezel)
    ctx.setStrokeColor(NSColor(white: 0.3, alpha: 0.5).cgColor)
    ctx.setLineWidth(size * 0.015)
    ctx.addRect(CGRect(x: size * 0.05, y: size * 0.05,
                      width: size * 0.9, height: size * 0.9))
    ctx.strokePath()
    
    // Disk icon (SCSI/ZuluSCSI motif)
    let diskSize = size * 0.35
    let diskX = size * 0.15
    let diskY = size * 0.5
    
    // Disk body
    ctx.setFillColor(NSColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1.0).cgColor)
    ctx.fillEllipse(in: CGRect(x: diskX, y: diskY, width: diskSize, height: diskSize))
    
    // Disk center hole
    let holeSize = diskSize * 0.25
    ctx.setFillColor(NSColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0).cgColor)
    ctx.fillEllipse(in: CGRect(x: diskX + diskSize/2 - holeSize/2,
                               y: diskY + diskSize/2 - holeSize/2,
                               width: holeSize, height: holeSize))
    
    // Waveform (iconic EMAX II sample display)
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1.0).cgColor)
    ctx.setLineWidth(size * 0.012)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    
    let waveStart = size * 0.15
    let waveWidth = size * 0.7
    let waveY = size * 0.28
    let waveHeight = size * 0.15
    let segments = 40
    
    ctx.beginPath()
    
    for i in 0...segments {
        let x = waveStart + (CGFloat(i) / CGFloat(segments)) * waveWidth
        // Classic sampler waveform shape
        let phase = (CGFloat(i) / CGFloat(segments)) * .pi * 8
        let amplitude = sin(phase) * (1.0 - CGFloat(i) / CGFloat(segments) * 0.3)
        let y = waveY + waveHeight/2 + amplitude * waveHeight/2 * 0.8
        
        if i == 0 {
            ctx.move(to: CGPoint(x: x, y: y))
        } else {
            ctx.addLine(to: CGPoint(x: x, y: y))
        }
    }
    
    ctx.strokePath()
    
    // "EMAX" text badge (top right corner, subtle)
    let badge = NSAttributedString(
        string: "E-μ",
        attributes: [
            .font: NSFont.systemFont(ofSize: size * 0.14, weight: .bold),
            .foregroundColor: NSColor(red: 0.3, green: 0.9, blue: 0.6, alpha: 0.7)
        ]
    )
    
    let badgePoint = CGPoint(x: size * 0.62, y: size * 0.70)
    badge.draw(at: badgePoint)
    
    // SCSI ID indicator (bottom right, like hardware LED)
    let ledSize = size * 0.06
    let ledX = size * 0.78
    let ledY = size * 0.15
    
    ctx.setFillColor(NSColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.6).cgColor)
    ctx.fillEllipse(in: CGRect(x: ledX, y: ledY, width: ledSize, height: ledSize))
    
    image.unlockFocus()
    
    return image
}

// Generate all required icon sizes for macOS
let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
var representations: [NSBitmapImageRep] = []

for size in sizes {
    let icon = createIcon(size: size)
    
    if let tiffData = icon.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData) {
        representations.append(bitmap)
    }
}

// Create .icns file
let icnsImage = NSImage(size: NSSize(width: 1024, height: 1024))

for rep in representations {
    icnsImage.addRepresentation(rep)
}

// Save to Resources/AppIcon.icns
let resourcesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("EmaxForge/Resources")

try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

if let data = icnsImage.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: data),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    
    // For .icns, we need iconutil or sips - let's create a preview PNG first
    try? pngData.write(to: resourcesDir.appendingPathComponent("AppIcon_1024.png"))
    print("✅ Created preview: \(resourcesDir.path)/AppIcon_1024.png")
    print("Run: sips -s format icns EmaxForge/Resources/AppIcon_1024.png --out EmaxForge/Resources/AppIcon.icns")
}
