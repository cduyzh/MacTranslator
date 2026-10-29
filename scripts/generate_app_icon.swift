import AppKit

// Draw an opaque, full-bleed master; macOS supplies its own presentation mask.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: swift scripts/generate_app_icon.swift <master.png> <output.iconset>")
}
let masterURL = URL(fileURLWithPath: arguments[1])
let iconsetURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let size = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.setAllowsAntialiasing(true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func gradient(_ colors: [UInt32], from: CGPoint, to: CGPoint) {
    let values = colors.map { color($0).cgColor } as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: values, locations: nil)!
    context.drawLinearGradient(gradient, start: from, end: to,
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

gradient([0x233855, 0x172237, 0x111827],
         from: CGPoint(x: 0, y: 1024), to: CGPoint(x: 1024, y: 0))

func bubble(_ rect: NSRect, tail: [NSPoint], colors: [UInt32]) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 66, yRadius: 66)
    let triangle = NSBezierPath()
    triangle.move(to: tail[0])
    triangle.line(to: tail[1])
    triangle.line(to: tail[2])
    triangle.close()
    path.append(triangle)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    gradient(colors, from: CGPoint(x: rect.minX, y: rect.maxY),
             to: CGPoint(x: rect.maxX, y: rect.minY - 60))
    NSGraphicsContext.restoreGraphicsState()
}

func label(_ text: String, in rect: NSRect, fontSize: CGFloat, foreground: UInt32) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color(foreground)
    ]
    let value = NSAttributedString(string: text, attributes: attributes)
    let bounds = value.size()
    value.draw(at: NSPoint(x: rect.midX - bounds.width / 2,
                          y: rect.midY - bounds.height / 2))
}

let source = NSRect(x: 180, y: 435, width: 390, height: 350)
bubble(source, tail: [
    NSPoint(x: 240, y: 463), NSPoint(x: 236, y: 366), NSPoint(x: 343, y: 463)
], colors: [0xFFFFFF, 0xE4ECF6])
label("A", in: source, fontSize: 260, foreground: 0x20314D)

let destination = NSRect(x: 445, y: 240, width: 390, height: 355)
bubble(destination, tail: [
    NSPoint(x: 672, y: 267), NSPoint(x: 785, y: 171), NSPoint(x: 785, y: 267)
], colors: [0x46E4E5, 0x18AFDD, 0x2878F0])
label("文", in: destination, fontSize: 238, foreground: 0xFFFFFF)

// A four-point intelligence signal accompanies, rather than replaces, translation.
let star = NSBezierPath()
star.move(to: NSPoint(x: 769, y: 857))
star.curve(to: NSPoint(x: 891, y: 738),
           controlPoint1: NSPoint(x: 784, y: 771),
           controlPoint2: NSPoint(x: 806, y: 752))
star.curve(to: NSPoint(x: 769, y: 619),
           controlPoint1: NSPoint(x: 806, y: 724),
           controlPoint2: NSPoint(x: 784, y: 706))
star.curve(to: NSPoint(x: 647, y: 738),
           controlPoint1: NSPoint(x: 754, y: 706),
           controlPoint2: NSPoint(x: 732, y: 724))
star.curve(to: NSPoint(x: 769, y: 857),
           controlPoint1: NSPoint(x: 732, y: 752),
           controlPoint2: NSPoint(x: 754, y: 771))
star.close()
NSGraphicsContext.saveGraphicsState()
star.addClip()
gradient([0x81F3EC, 0x78A9FF, 0xB89CFF],
         from: CGPoint(x: 690, y: 830), to: CGPoint(x: 850, y: 640))
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

try bitmap.representation(using: .png, properties: [:])!.write(to: masterURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, dimension) in variants {
    let output = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: dimension, pixelsHigh: dimension,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let target = NSGraphicsContext(bitmapImageRep: output)!
    NSGraphicsContext.current = target
    target.imageInterpolation = .high
    target.cgContext.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0,
                                                     width: dimension, height: dimension))
    NSGraphicsContext.restoreGraphicsState()
    try output.representation(using: .png, properties: [:])!
        .write(to: iconsetURL.appendingPathComponent("\(name).png"))
}
print("Generated full-bleed translation + AI icon and \(variants.count) iconset sizes.")
