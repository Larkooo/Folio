import CoreText
import Observation
import SwiftUI
import UIKit

enum ReaderTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case paper, sepia, stone, night

    var id: Self { self }

    var name: String {
        switch self {
        case .paper: "Paper"
        case .sepia: "Sepia"
        case .stone: "Stone"
        case .night: "Night"
        }
    }

    var uiPaper: UIColor {
        switch self {
        case .paper: UIColor(hex: 0xF7F3EA)
        case .sepia: UIColor(hex: 0xEFE2C8)
        case .stone: UIColor(hex: 0xE4E3DE)
        case .night: UIColor(hex: 0x161513)
        }
    }

    var uiInk: UIColor {
        switch self {
        case .paper: UIColor(hex: 0x2A2620)
        case .sepia: UIColor(hex: 0x3D3022)
        case .stone: UIColor(hex: 0x2B2B29)
        case .night: UIColor(hex: 0xD8D1C4)
        }
    }

    var uiSecondaryInk: UIColor {
        switch self {
        case .paper: UIColor(hex: 0x8D867A)
        case .sepia: UIColor(hex: 0x8F7B61)
        case .stone: UIColor(hex: 0x82817B)
        case .night: UIColor(hex: 0x7C766C)
        }
    }

    var paper: Color { Color(uiPaper) }
    var ink: Color { Color(uiInk) }
    var secondaryInk: Color { Color(uiSecondaryInk) }
    var isDark: Bool { self == .night }
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

enum ReaderFont: String, CaseIterable, Identifiable, Codable, Sendable {
    case newYork, iowan, palatino, georgia, system

    var id: Self { self }

    var name: String {
        switch self {
        case .newYork: "New York"
        case .iowan: "Iowan"
        case .palatino: "Palatino"
        case .georgia: "Georgia"
        case .system: "San Francisco"
        }
    }

    func uiFont(size: CGFloat, bold: Bool = false, italic: Bool = false, smallCaps: Bool = false) -> UIFont {
        let base: UIFont
        switch self {
        case .newYork:
            let system = UIFont.systemFont(ofSize: size)
            base = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? system
        case .iowan:
            base = UIFont(name: "IowanOldStyle-Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case .palatino:
            base = UIFont(name: "Palatino-Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case .georgia:
            base = UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size)
        case .system:
            base = UIFont.systemFont(ofSize: size)
        }

        var descriptor = base.fontDescriptor
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if !traits.isEmpty, let styled = descriptor.withSymbolicTraits(traits) {
            descriptor = styled
        }
        if smallCaps {
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kLowerCaseType,
                    UIFontDescriptor.FeatureKey.selector: kLowerCaseSmallCapsSelector,
                ]],
            ])
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    func font(size: CGFloat) -> Font {
        Font(uiFont(size: size))
    }
}

enum LineSpacing: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact, regular, relaxed

    var id: Self { self }

    var name: String {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        case .relaxed: "Relaxed"
        }
    }

    var multiple: CGFloat {
        switch self {
        case .compact: 1.18
        case .regular: 1.32
        case .relaxed: 1.5
        }
    }
}

/// Everything about the text that affects how it is typeset.
struct TypeStyle: Hashable, Sendable {
    var font: ReaderFont
    var size: CGFloat
    var spacing: LineSpacing
    var justified: Bool
    var theme: ReaderTheme
}

@MainActor
@Observable
final class ReaderSettings {
    static let sizeRange: ClosedRange<CGFloat> = 13...30

    var theme: ReaderTheme { didSet { save() } }
    var font: ReaderFont { didSet { save() } }
    var fontSize: CGFloat { didSet { save() } }
    var spacing: LineSpacing { didSet { save() } }
    var justified: Bool { didSet { save() } }

    private static let defaults = UserDefaults.standard

    init() {
        let defaults = Self.defaults
        var storedTheme = defaults.string(forKey: "reader.theme").flatMap(ReaderTheme.init)
        #if DEBUG
        // Applied before the first assignment so the override is not saved as the reader's choice.
        storedTheme = DebugFlags.theme.flatMap(ReaderTheme.init) ?? storedTheme
        #endif
        theme = storedTheme ?? .paper
        font = defaults.string(forKey: "reader.font").flatMap(ReaderFont.init) ?? .newYork
        let storedSize = defaults.double(forKey: "reader.fontSize")
        fontSize = storedSize > 0 ? storedSize : 18
        spacing = defaults.string(forKey: "reader.spacing").flatMap(LineSpacing.init) ?? .regular
        justified = defaults.object(forKey: "reader.justified") as? Bool ?? true
    }

    var style: TypeStyle {
        TypeStyle(font: font, size: fontSize, spacing: spacing, justified: justified, theme: theme)
    }

    func adjustSize(by step: CGFloat) {
        fontSize = min(max(fontSize + step, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }

    private func save() {
        let defaults = Self.defaults
        defaults.set(theme.rawValue, forKey: "reader.theme")
        defaults.set(font.rawValue, forKey: "reader.font")
        defaults.set(Double(fontSize), forKey: "reader.fontSize")
        defaults.set(spacing.rawValue, forKey: "reader.spacing")
        defaults.set(justified, forKey: "reader.justified")
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
