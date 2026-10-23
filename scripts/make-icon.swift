// Renders the app icon PNG: a white keyboard glyph on a blue rounded square.
// Usage: swift make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]

let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let inset: CGFloat = 100
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(srgbRed: 0.27, green: 0.55, blue: 1.0, alpha: 1),
               ending: NSColor(srgbRed: 0.12, green: 0.27, blue: 0.80, alpha: 1))!
        .draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    let glyph = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let g = glyph.size
    glyph.draw(in: NSRect(x: (size - g.width) / 2, y: (size - g.height) / 2, width: g.width, height: g.height))
    return true
}

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
