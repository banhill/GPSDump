// Renders the app icon: "GPS" as 5×7 dot-matrix glyphs in green phosphor on black,
// with a soft CRT glow and faint scanlines.
//
// Usage: swift Tools/make_icon.swift GPSDump/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit
import CoreImage

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let glyphs: [[String]] = [
    [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."], // G
    ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."], // P
    [".####", "#....", "#....", ".###.", "....#", "....#", "####."], // S
]

let phosphor = CGColor(red: 0.20, green: 1.0, blue: 0.35, alpha: 1)
let background = CGColor(red: 0.02, green: 0.05, blue: 0.03, alpha: 1)

let cell: CGFloat = 44          // one dot-matrix pixel
let dot: CGFloat = 37           // drawn dot, leaving a gap between dots
let columns = glyphs.count * 5 + (glyphs.count - 1) // 1 empty column between letters
let originX = (CGFloat(size) - CGFloat(columns) * cell) / 2
let originY = (CGFloat(size) - 7 * cell) / 2

func makeContext(opaque: Bool = false) -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
}

// 1. The lit dots on a transparent layer.
let dots = makeContext()
dots.setFillColor(phosphor)
for (g, glyph) in glyphs.enumerated() {
    for (row, line) in glyph.enumerated() {
        for (col, ch) in line.enumerated() where ch == "#" {
            let x = originX + CGFloat(g * 6 + col) * cell + (cell - dot) / 2
            let y = originY + CGFloat(6 - row) * cell + (cell - dot) / 2 // CG origin is bottom-left
            dots.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: dot, height: dot),
                                cornerWidth: 8, cornerHeight: 8, transform: nil))
        }
    }
}
dots.fillPath()
let dotsImage = dots.makeImage()!

// 2. Glow: two blurred copies of the dots.
let ci = CIContext()
func blurred(_ image: CGImage, radius: Double) -> CGImage {
    let input = CIImage(cgImage: image)
    let blur = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
    return ci.createCGImage(blur, from: input.extent)!
}
let wideGlow = blurred(dotsImage, radius: 60)
let tightGlow = blurred(dotsImage, radius: 14)

// 3. Composite: background, glows, dots, scanlines.
let full = CGRect(x: 0, y: 0, width: size, height: size)
let icon = makeContext(opaque: true)
icon.setFillColor(background)
icon.fill(full)
icon.setAlpha(0.55); icon.draw(wideGlow, in: full)
icon.setAlpha(0.9);  icon.draw(tightGlow, in: full)
icon.setAlpha(1);    icon.draw(dotsImage, in: full)

icon.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
for y in stride(from: 0, to: size, by: 6) {
    icon.fill(CGRect(x: 0, y: y, width: size, height: 2))
}

// The icon context is opaque, so the PNG has no alpha channel (required for app icons).
let rep = NSBitmapImageRep(cgImage: icon.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
