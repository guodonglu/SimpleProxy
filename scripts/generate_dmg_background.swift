import Cocoa

let width: CGFloat = 640
let height: CGFloat = 420
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. Draw elegant background gradient (Liquid Glass aesthetic)
let bgRect = CGRect(x: 0, y: 0, width: width, height: height)
let colors = [
    NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.96, alpha: 1.0).cgColor
] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
}

// 2. Header text
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.55, alpha: 1.0)
]

let titleStr = "SimpleProxy" as NSString
let subtitleStr = "拖拽 SimpleProxy 到 Applications 完成安装" as NSString

let titleSize = titleStr.size(withAttributes: titleAttrs)
let subtitleSize = subtitleStr.size(withAttributes: subtitleAttrs)

titleStr.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: height - 60), withAttributes: titleAttrs)
subtitleStr.draw(at: NSPoint(x: (width - subtitleSize.width) / 2, y: height - 88), withAttributes: subtitleAttrs)

// 3. Center Direction Indicator (Liquid glass pill with subtle border and arrow)
let pillWidth: CGFloat = 84
let pillHeight: CGFloat = 38
let pillX = (width - pillWidth) / 2
let pillY: CGFloat = 185 // Center vertically with App icons

let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 19, cornerHeight: 19, transform: nil)

// Fill
ctx.addPath(pillPath)
ctx.setFillColor(NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.12).cgColor)
ctx.fillPath()

// Border
ctx.addPath(pillPath)
ctx.setStrokeColor(NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.25).cgColor)
ctx.setLineWidth(1.0)
ctx.strokePath()

// Arrow
let arrowAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.9)
]
let arrowStr = "➜" as NSString
let arrowSize = arrowStr.size(withAttributes: arrowAttrs)
arrowStr.draw(at: NSPoint(x: (width - arrowSize.width) / 2, y: pillY + (pillHeight - arrowSize.height) / 2), withAttributes: arrowAttrs)

// 4. Footer info (placed safely above bottom margin)
let footerAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.50, green: 0.55, blue: 0.65, alpha: 1.0)
]
let footerStr = "Swift 6.3 原生 · 极简轻量 · 独立隔离 · 兼容 Whistle 语法" as NSString
let footerSize = footerStr.size(withAttributes: footerAttrs)
footerStr.draw(at: NSPoint(x: (width - footerSize.width) / 2, y: 38), withAttributes: footerAttrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

let targetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg_background.png"
try? png.write(to: URL(fileURLWithPath: targetPath))
print("Background generated at: \(targetPath)")
