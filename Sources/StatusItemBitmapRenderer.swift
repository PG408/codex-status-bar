import AppKit

struct StatusItemBitmapContent {
    let size: NSSize
    let icon: NSImage
    let iconRect: NSRect
    let label: String
    let labelRect: NSRect
    let timer: String
    let timerRect: NSRect
    let font: NSFont
    let textColor: NSColor
}

final class StatusItemBitmapRenderer {
    private var cachedKey: String?
    private var cachedImage: NSImage?

    func image(cacheKey: String, content: StatusItemBitmapContent) -> NSImage {
        if cacheKey == cachedKey, let cachedImage {
            return cachedImage
        }

        let image = rasterizedImage(content: content)
        cachedKey = cacheKey
        cachedImage = image
        return image
    }

    private func rasterizedImage(content: StatusItemBitmapContent) -> NSImage {
        let image = NSImage(size: content.size)
        for scale in [CGFloat(1), CGFloat(2)] {
            if let representation = bitmapRepresentation(content: content, scale: scale) {
                image.addRepresentation(representation)
            }
        }
        image.isTemplate = false
        return image
    }

    private func bitmapRepresentation(content: StatusItemBitmapContent,
                                      scale: CGFloat) -> NSBitmapImageRep? {
        let pixelWidth = Int(ceil(content.size.width * scale))
        let pixelHeight = Int(ceil(content.size.height * scale))
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.scaleBy(x: scale, y: scale)
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        content.icon.draw(in: content.iconRect,
                          from: .zero,
                          operation: .sourceOver,
                          fraction: 1)
        draw(content.label,
             in: content.labelRect,
             alignment: .left,
             font: content.font,
             color: content.textColor)
        draw(content.timer,
             in: content.timerRect,
             alignment: .right,
             font: content.font,
             color: content.textColor)

        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { return nil }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        representation.size = content.size
        return representation
    }

    private func draw(_ text: String,
                      in rect: NSRect,
                      alignment: NSTextAlignment,
                      font: NSFont,
                      color: NSColor) {
        guard !text.isEmpty, rect.width > 0, rect.height > 0 else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let textHeight = ceil(font.ascender - font.descender + font.leading)
        let drawingRect = NSRect(x: rect.minX,
                                 y: rect.midY - textHeight / 2,
                                 width: rect.width,
                                 height: textHeight)
        (text as NSString).draw(in: drawingRect, withAttributes: attributes)
    }
}
