import AppKit

// Draws the Swatchbook icon: a dark rounded tile with a minimal four-part color swatch.
// Usage: make_icon <output .iconset folder>

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: alpha).cgColor
}

/// Rectangle with an individual radius per corner (y axis points up).
func cornerPath(_ r: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX + bl, y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX - br, y: r.minY))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY),
             tangent2End: CGPoint(x: r.maxX, y: r.minY + br), radius: br)
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - tr))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY),
             tangent2End: CGPoint(x: r.maxX - tr, y: r.maxY), radius: tr)
    p.addLine(to: CGPoint(x: r.minX + tl, y: r.maxY))
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY),
             tangent2End: CGPoint(x: r.minX, y: r.maxY - tl), radius: tl)
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + bl))
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY),
             tangent2End: CGPoint(x: r.minX + bl, y: r.minY), radius: bl)
    p.closeSubpath()
    return p
}

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // 1) Dark rounded tile with a soft vertical gradient
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0x2B2B33), color(0x131316)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])
    ctx.restoreGState()

    ctx.addPath(tilePath)
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(4)
    ctx.strokePath()

    // 2) The swatch: four quadrants meeting in the middle
    let c: CGFloat = 230          // size of one quadrant
    let m: CGFloat = 512          // center of the canvas
    let overlap: CGFloat = 1      // avoids hairline gaps between quadrants

    func fill(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat, _ hex: UInt32) {
        ctx.addPath(cornerPath(rect, tl: tl, tr: tr, br: br, bl: bl))
        ctx.setFillColor(color(hex))
        ctx.fillPath()
    }

    // bottom-right, bottom-left, top-right, top-left
    fill(CGRect(x: m - overlap, y: m - c, width: c + overlap, height: c + overlap),
         tl: 0, tr: 0, br: c, bl: 0, 0x8EC5FF)
    fill(CGRect(x: m - c, y: m - c, width: c + overlap, height: c + overlap),
         tl: 0, tr: 0, br: 0, bl: c, 0x4A90FF)
    fill(CGRect(x: m - overlap, y: m - overlap, width: c + overlap, height: c + overlap),
         tl: 0, tr: c, br: 0, bl: 0, 0x3D5AFE)
    fill(CGRect(x: m - c, y: m - overlap, width: c + overlap, height: c + overlap),
         tl: 54, tr: 0, br: 0, bl: 0, 0x6C2BD9)

    // 3) White dot in the top-left quadrant
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: m - c + 55, y: m + c - 115, width: 60, height: 60))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, px) in entries {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name + ".png")
    try render(px: px).write(to: url)
}
print("Icon written to \(outDir)")
