import AppKit

let inputPath = "/Users/weexnes/Downloads/clyo.png"
let fileManager = FileManager.default

guard let inputImage = NSImage(contentsOfFile: inputPath) else {
    print("Error: Could not load \(inputPath)")
    exit(1)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let masterRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
guard let ctx = NSGraphicsContext(bitmapImageRep: masterRep) else {
    print("Error: Failed to create graphics context")
    exit(1)
}
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high

// Standard macOS HIG squircle: 824x824 centered in 1024 canvas with 185px corner radius
let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0

// Draw shadow under squircle
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0.0, alpha: 0.28)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24.0
shadow.set()

let path = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
NSColor.black.setFill()
path.fill()

// Reset shadow and clip image to rounded squircle
let noShadow = NSShadow()
noShadow.set()

let clipPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
clipPath.addClip()
inputImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

// Target iconset directory
let iconsetDir = URL(fileURLWithPath: "build/AppIcon.iconset")
try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
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

let masterImage = NSImage(size: canvasSize)
masterImage.addRepresentation(masterRep)

for (filename, px) in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    NSGraphicsContext.saveGraphicsState()
    let sCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = sCtx
    sCtx.imageInterpolation = .high
    
    masterImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    
    if let pngData = rep.representation(using: .png, properties: [:]) {
        let fileURL = iconsetDir.appendingPathComponent(filename)
        try pngData.write(to: fileURL)
    }
}

print("Iconset generated successfully at \(iconsetDir.path)")
