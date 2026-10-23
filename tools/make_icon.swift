// Renders Folio/Assets.xcassets/AppIcon.appiconset/AppIcon.png: an open book on an oxblood ground.
// Run from the repository root:  swift tools/make_icon.swift
import AppKit
import CoreGraphics

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
// Work top-down, like a screen.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linear(_ colors: [CGColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// Ground.
linear([rgb(0x93402F), rgb(0x5C2118)], [0, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 1024))

let spineX: CGFloat = 512
let top: CGFloat = 268
let bottom: CGFloat = 752
let outer: CGFloat = 318   // distance from spine to the outer edge of each page
let lift: CGFloat = 26     // outer corners sit higher than the spine, as an open book does

func page(_ direction: CGFloat, inset: CGFloat = 0, drop: CGFloat = 0) -> CGPath {
    let path = CGMutablePath()
    let edge = spineX + direction * (outer - inset)
    path.move(to: CGPoint(x: spineX, y: top + 18 + drop))
    path.addQuadCurve(to: CGPoint(x: edge, y: top - lift + drop), control: CGPoint(x: spineX + direction * outer * 0.45, y: top - lift * 0.2 + drop))
    path.addLine(to: CGPoint(x: edge, y: bottom - lift + drop))
    path.addQuadCurve(to: CGPoint(x: spineX, y: bottom + 18 + drop), control: CGPoint(x: spineX + direction * outer * 0.45, y: bottom - lift * 0.2 + drop))
    path.closeSubpath()
    return path
}

// Shadow under the book.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 46, color: rgb(0x000000, 0.38))
for direction: CGFloat in [-1, 1] {
    ctx.addPath(page(direction, drop: 14))
    ctx.setFillColor(rgb(0xD9CDB8))
    ctx.fillPath()
}
ctx.restoreGState()

// Page block edges, then the open pages.
for direction: CGFloat in [-1, 1] {
    ctx.addPath(page(direction, drop: 14))
    ctx.setFillColor(rgb(0xD9CDB8))
    ctx.fillPath()
    ctx.addPath(page(direction, drop: 7))
    ctx.setFillColor(rgb(0xE8DECC))
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(page(direction))
    ctx.clip()
    let edge = spineX + direction * outer
    linear(
        [rgb(0xF8F4EB), rgb(0xF3EDE1), rgb(0xD9CFBD)],
        [0, 0.7, 1],
        from: CGPoint(x: edge, y: 0),
        to: CGPoint(x: spineX, y: 0)
    )

    // Lines of type.
    ctx.setFillColor(rgb(0x8C8270, 0.42))
    let lineLeft = direction < 0 ? spineX - outer + 54 : spineX + 46
    let width = outer - 100
    for row in 0..<9 {
        let y = top + 52 + CGFloat(row) * 44
        let length = row == 8 ? width * 0.55 : (row == 3 ? width * 0.8 : width)
        let rect = CGRect(x: lineLeft, y: y, width: length, height: 11)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 5.5, cornerHeight: 5.5, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

// The crease, kept to the pages.
ctx.saveGState()
ctx.addPath(page(-1))
ctx.addPath(page(1))
ctx.clip()
linear(
    [rgb(0x000000, 0), rgb(0x5A3A26, 0.35), rgb(0x000000, 0)],
    [0, 0.5, 1],
    from: CGPoint(x: spineX - 14, y: 0),
    to: CGPoint(x: spineX + 14, y: 0)
)
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let url = URL(fileURLWithPath: "Folio/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: url)
print("wrote \(url.path)")
