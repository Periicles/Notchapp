import AppKit
import SwiftUI

/// A SwiftUI view rendered offscreen into plain pixels, so end-to-end tests can
/// assert on what would actually be drawn rather than on view internals.
struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

struct RenderedImage {
    let width: Int
    let height: Int
    private let rgba: [UInt8]

    @MainActor
    init?(_ view: some View, size: CGSize) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height, alignment: .top))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }

        let width = image.width
        let height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        self.width = width
        self.height = height
        self.rgba = buffer
    }

    /// Alpha of the pixel at `x`, `y` measured from the top-left corner.
    func alpha(x: Int, y: Int) -> UInt8 {
        rgba[(y * width + x) * 4 + 3]
    }

    func color(x: Int, y: Int) -> Pixel {
        let offset = (y * width + x) * 4
        return Pixel(red: rgba[offset], green: rgba[offset + 1], blue: rgba[offset + 2], alpha: rgba[offset + 3])
    }

    /// Whether anything visible is drawn in the rows `rows` (top = 0).
    func hasInk(inRows rows: Range<Int>, threshold: UInt8 = 8) -> Bool {
        let clamped = rows.clamped(to: 0..<height)
        for y in clamped {
            for x in 0..<width where alpha(x: x, y: y) > threshold {
                return true
            }
        }
        return false
    }

    var isBlank: Bool {
        !hasInk(inRows: 0..<height, threshold: 0)
    }

    /// Index of the last row holding visible pixels, or `nil` when blank.
    var lastInkRow: Int? {
        (0..<height).last { hasInk(inRows: $0..<($0 + 1)) }
    }
}
