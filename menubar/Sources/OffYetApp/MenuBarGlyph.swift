import AppKit
import SwiftUI

// macOS 26 的状态项快照只渲染 Text/Image 原语，任意 Shape/Canvas 绘制都会被静默丢弃
// （离屏 ImageRenderer 却一切正常），故字形先用 CoreGraphics 画进位图，再以模板 NSImage 交给 Image
struct MenuBarGlyph: View {
    var body: some View {
        Image(nsImage: Self.image)
    }

    private static let image: NSImage = renderGlyphImage()

    private static func renderGlyphImage() -> NSImage {
        let g = GlyphGeometry()
        let side = GlyphGeometry.referenceSize
        let scale: CGFloat = 2
        let pixelSide = Int(side * scale)
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = CGContext(
                data: nil,
                width: pixelSide,
                height: pixelSide,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { fatalError("glyph bitmap context unavailable") }

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: side)
        ctx.scaleBy(x: 1, y: -1)

        let box = CGRect(x: 0, y: 0, width: side, height: side)
        let ink = CGColor(gray: 0, alpha: 1)
        ctx.setStrokeColor(ink)
        ctx.setFillColor(ink)

        ctx.setLineWidth(g.ringWidth)
        ctx.addPath(g.ringPath(in: box).cgPath)
        ctx.strokePath()

        ctx.setLineCap(.round)
        ctx.setLineWidth(g.tickWidth)
        for tick in g.tickPaths(in: box) {
            ctx.addPath(tick.cgPath)
        }
        ctx.strokePath()

        ctx.setLineWidth(g.horizonWidth)
        ctx.addPath(g.horizonPath(in: box).cgPath)
        ctx.strokePath()

        ctx.addPath(g.sunDomePath(in: box).cgPath)
        ctx.fillPath()

        guard let cgImage = ctx.makeImage() else { fatalError("glyph image unavailable") }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
        image.isTemplate = true
        return image
    }
}

private struct GlyphGeometry {
    static let referenceSize: CGFloat = 18

    let ringWidth: CGFloat = 1.2
    let tickWidth: CGFloat = 1.15
    let horizonWidth: CGFloat = 1.15

    private let center = CGPoint(x: 9, y: 9)
    private let ringRadius: CGFloat = 6.9
    private let tickOuterR: CGFloat = 5.95
    private let tickInnerR: CGFloat = 4.9
    private let twelveTickInnerR: CGFloat = 5.1
    private let horizonY: CGFloat = 13.1
    private let sunRadius: CGFloat = 4.7

    func ringPath(in rect: CGRect) -> Path {
        let s = scale(in: rect)
        let c = point(center, s: s, in: rect)
        let r = ringRadius * s
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    func tickPaths(in rect: CGRect) -> [Path] {
        let s = scale(in: rect)
        return [
            line(
                from: CGPoint(x: center.x, y: center.y - twelveTickInnerR),
                to: CGPoint(x: center.x, y: center.y - tickOuterR),
                s: s,
                in: rect
            ),
            line(
                from: CGPoint(x: center.x + tickInnerR, y: center.y),
                to: CGPoint(x: center.x + tickOuterR, y: center.y),
                s: s,
                in: rect
            ),
            line(
                from: CGPoint(x: center.x - tickInnerR, y: center.y),
                to: CGPoint(x: center.x - tickOuterR, y: center.y),
                s: s,
                in: rect
            ),
        ]
    }

    func horizonPath(in rect: CGRect) -> Path {
        let s = scale(in: rect)
        let dy = horizonY - center.y
        let half = (ringRadius * ringRadius - dy * dy).squareRoot()
        return line(
            from: CGPoint(x: center.x - half, y: horizonY),
            to: CGPoint(x: center.x + half, y: horizonY),
            s: s,
            in: rect
        )
    }

    func sunDomePath(in rect: CGRect) -> Path {
        let s = scale(in: rect)
        let c = point(CGPoint(x: center.x, y: horizonY), s: s, in: rect)
        let r = sunRadius * s
        var dome = Path()
        dome.move(to: CGPoint(x: c.x - r, y: c.y))
        dome.addArc(
            center: c,
            radius: r,
            startAngle: .radians(.pi),
            endAngle: .radians(0),
            clockwise: false
        )
        dome.closeSubpath()
        return dome
    }

    private func scale(in rect: CGRect) -> CGFloat {
        min(rect.width, rect.height) / Self.referenceSize
    }

    private func point(_ p: CGPoint, s: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * s, y: rect.minY + p.y * s)
    }

    private func line(from a: CGPoint, to b: CGPoint, s: CGFloat, in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(a, s: s, in: rect))
        path.addLine(to: point(b, s: s, in: rect))
        return path
    }
}
