import AppKit
import ImageIO
import UniformTypeIdentifiers

// A typographic mark using Forma's existing serif identity and palette.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.13, green: 0.21, blue: 0.18, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let cream = NSColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1)
let font = NSFont(name: "NewYorkLarge-Medium", size: 840) ?? NSFont(name: "Baskerville", size: 840)!
let letter = NSAttributedString(string: "f", attributes: [.font: font, .foregroundColor: cream])
let bounds = letter.size()
letter.draw(at: NSPoint(x: (1024 - bounds.width) / 2 - 22, y: (1024 - bounds.height) / 2 + 42))
// A small four-point sparkle echoes the collection's hero graphic.
let star = NSBezierPath()
star.move(to: NSPoint(x: 735, y: 405))
star.curve(to: NSPoint(x: 805, y: 335), controlPoint1: NSPoint(x: 745, y: 352), controlPoint2: NSPoint(x: 752, y: 345))
star.curve(to: NSPoint(x: 735, y: 265), controlPoint1: NSPoint(x: 752, y: 325), controlPoint2: NSPoint(x: 745, y: 318))
star.curve(to: NSPoint(x: 665, y: 335), controlPoint1: NSPoint(x: 725, y: 318), controlPoint2: NSPoint(x: 718, y: 325))
star.curve(to: NSPoint(x: 735, y: 405), controlPoint1: NSPoint(x: 718, y: 345), controlPoint2: NSPoint(x: 725, y: 352))
star.close()
cream.setFill()
star.fill()
NSGraphicsContext.restoreGraphicsState()
let opaque = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
opaque.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, opaque.makeImage()!, nil)
assert(CGImageDestinationFinalize(destination))
