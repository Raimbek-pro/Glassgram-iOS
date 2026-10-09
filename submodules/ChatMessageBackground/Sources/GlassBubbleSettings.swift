import Foundation
import UIKit

/// Glassgram: user-adjustable look of the Liquid Glass message bubbles.
/// Values are stored in UserDefaults; every change posts `didChange`
/// so visible bubbles update immediately.
public struct GlassBubbleSettings: Equatable {
    /// 0 = colorless glass, 1 = solid theme color
    public var tintAlpha: CGFloat
    /// Rim brightness at the top edge
    public var rimTopAlpha: CGFloat
    /// Rim brightness on the sides
    public var rimMiddleAlpha: CGFloat
    /// Rim brightness at the bottom edge
    public var rimBottomAlpha: CGFloat

    public init(tintAlpha: CGFloat, rimTopAlpha: CGFloat, rimMiddleAlpha: CGFloat, rimBottomAlpha: CGFloat) {
        self.tintAlpha = tintAlpha
        self.rimTopAlpha = rimTopAlpha
        self.rimMiddleAlpha = rimMiddleAlpha
        self.rimBottomAlpha = rimBottomAlpha
    }

    public static let defaults = GlassBubbleSettings(tintAlpha: 0.25, rimTopAlpha: 0.95, rimMiddleAlpha: 0.2, rimBottomAlpha: 0.55)

    public static let didChange = Notification.Name("GlassgramGlassBubbleSettingsDidChange")

    /// Liquid Glass renders short views as frosted "control" glass. Glass views are kept
    /// at least this tall (centered, clipped by the bubble shape) so short messages stay clear.
    public static let minGlassHeight: CGFloat = 100.0

    /// Glass bubbles need the iOS 26 Liquid Glass API.
    public static var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    private static let storageKey = "glassgram.glassBubbleSettings"
    private static let lock = NSLock()
    private static var cached: GlassBubbleSettings?

    /// Current settings. Safe to read from any thread; write on the main thread.
    public static var current: GlassBubbleSettings {
        get {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cached {
                return cached
            }
            let loaded = load()
            cached = loaded
            return loaded
        }
        set {
            lock.lock()
            let changed = newValue != cached
            if changed {
                cached = newValue
            }
            lock.unlock()
            guard changed else {
                return
            }
            save(newValue)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    private static func load() -> GlassBubbleSettings {
        guard let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] else {
            return defaults
        }
        func value(_ key: String, _ fallback: CGFloat) -> CGFloat {
            return dict[key].map { CGFloat($0) } ?? fallback
        }
        return GlassBubbleSettings(tintAlpha: value("tint", defaults.tintAlpha),
                                   rimTopAlpha: value("rimTop", defaults.rimTopAlpha),
                                   rimMiddleAlpha: value("rimMiddle", defaults.rimMiddleAlpha),
                                   rimBottomAlpha: value("rimBottom", defaults.rimBottomAlpha))
    }

    private static func save(_ settings: GlassBubbleSettings) {
        let dict: [String: Double] = [
            "tint": Double(settings.tintAlpha),
            "rimTop": Double(settings.rimTopAlpha),
            "rimMiddle": Double(settings.rimMiddleAlpha),
            "rimBottom": Double(settings.rimBottomAlpha)
        ]
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}

/// A thin ring along the edge of a bubble shape image (tail included), used as the rim mask.
/// Telegram's own outline images are drawn in the theme's stroke color, which is fully
/// transparent in many dark themes, so the ring is derived from the shape's alpha instead:
/// shape minus the shape eroded by ~1pt. Results are cached per shape image (main thread).
private var glassRimImageCache: [ObjectIdentifier: UIImage] = [:]

func makeGlassRimImage(fromShape shape: UIImage) -> UIImage? {
    let key = ObjectIdentifier(shape)
    if let cached = glassRimImageCache[key] {
        return cached
    }
    guard let cgImage = shape.cgImage else {
        return nil
    }
    let width = cgImage.width
    let height = cgImage.height
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return nil
    }
    let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height))
    let radius = max(1, Int((shape.scale * 1.0).rounded()))

    // Erode: keep only pixels that are inside the shape in every direction within `radius`.
    context.draw(cgImage, in: rect)
    context.setBlendMode(.destinationIn)
    for dx in -radius ... radius {
        for dy in -radius ... radius where (dx != 0 || dy != 0) && dx * dx + dy * dy <= radius * radius {
            context.draw(cgImage, in: rect.offsetBy(dx: CGFloat(dx), dy: CGFloat(dy)))
        }
    }
    guard let eroded = context.makeImage() else {
        return nil
    }

    // Ring = shape − eroded shape.
    context.setBlendMode(.copy)
    context.clear(rect)
    context.draw(cgImage, in: rect)
    context.setBlendMode(.destinationOut)
    context.draw(eroded, in: rect)
    guard let ring = context.makeImage() else {
        return nil
    }

    let result = UIImage(cgImage: ring, scale: shape.scale, orientation: .up).resizableImage(withCapInsets: shape.capInsets, resizingMode: shape.resizingMode)
    glassRimImageCache[key] = result
    return result
}

/// Bright edge of the glass: a white gradient visible only through the bubble outline.
final class GlassRimView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    let outlineView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        if let gradient = self.layer as? CAGradientLayer {
            gradient.locations = [0.0, 0.5, 1.0]
            gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        }
        self.mask = self.outlineView
        self.apply(GlassBubbleSettings.current)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ settings: GlassBubbleSettings) {
        guard let gradient = self.layer as? CAGradientLayer else {
            return
        }
        gradient.colors = [
            UIColor(white: 1.0, alpha: settings.rimTopAlpha).cgColor,
            UIColor(white: 1.0, alpha: settings.rimMiddleAlpha).cgColor,
            UIColor(white: 1.0, alpha: settings.rimBottomAlpha).cgColor
        ]
    }
}
