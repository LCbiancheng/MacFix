import AppKit

// 生成一个简洁的 macOS 风格应用图标（蓝色渐变圆角背景 + 白色齿轮）
// 用法: swift generate_icon.swift <输出路径.png>

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size = 1024

guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else {
    fatalError("无法创建色彩空间")
}
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("无法创建绘图上下文")
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// 背景渐变
let colors = [
    CGColor(red: 0.36, green: 0.60, blue: 0.95, alpha: 1.0),
    CGColor(red: 0.08, green: 0.36, blue: 0.72, alpha: 1.0)
] as CFArray
let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0])!

// 圆角背景
let cornerRadius: CGFloat = 200
let bgPath = CGPath(roundedRect: rect.insetBy(dx: 30, dy: 30), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
ctx.restoreGState()

// 齿轮
let center = CGPoint(x: 512, y: 512)
let gearRadius: CGFloat = 290
let toothRadius: CGFloat = 90

ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))

// 主体大圆
ctx.fillEllipse(in: CGRect(x: center.x - gearRadius, y: center.y - gearRadius, width: gearRadius * 2, height: gearRadius * 2))

// 齿（12 个）
for i in 0..<12 {
    let angle = CGFloat(i) * (CGFloat.pi * 2 / 12)
    let cx = center.x + cos(angle) * gearRadius
    let cy = center.y + sin(angle) * gearRadius
    ctx.fillEllipse(in: CGRect(x: cx - toothRadius, y: cy - toothRadius, width: toothRadius * 2, height: toothRadius * 2))
}

// 中心孔
ctx.setFillColor(CGColor(red: 0.12, green: 0.42, blue: 0.82, alpha: 1.0))
let holeRadius: CGFloat = 120
ctx.fillEllipse(in: CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))

// 中心孔内再开一个小孔，形成环
ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
let innerHoleRadius: CGFloat = 52
ctx.fillEllipse(in: CGRect(x: center.x - innerHoleRadius, y: center.y - innerHoleRadius, width: innerHoleRadius * 2, height: innerHoleRadius * 2))

guard let image = ctx.makeImage() else {
    fatalError("无法生成图像")
}

let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("无法编码 PNG")
}

do {
    try data.write(to: URL(fileURLWithPath: output))
    print("图标已生成：\(output)")
} catch {
    fatalError("写入失败：\(error)")
}
