import UIKit

/// Applies a `TypeStyle` to a chapter's semantic text: fonts, paragraph styles and colour, plus a few
/// book conventions (no indent after headings, small caps to open a chapter, a sunk chapter opening).
///
/// Every transformation here adds the same characters whatever the style, so character offsets stay
/// comparable between layouts. Reading positions rely on that.
enum Typesetter {
    static func style(_ source: NSAttributedString, with style: TypeStyle, pageHeight: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let string = source.string as NSString
        let size = style.size
        let ink = style.theme.uiInk
        let secondary = style.theme.uiSecondaryInk

        var previous: BlockKind?
        var index = 0

        string.enumerateSubstrings(
            in: NSRange(location: 0, length: string.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, _, enclosing, _ in
            let raw = source.attribute(.folioBlock, at: enclosing.location, effectiveRange: nil) as? String
            let kind = raw.flatMap(BlockKind.init) ?? .paragraph
            if index == 0, kind.isHeading {
                result.append(sink(height: (pageHeight * 0.13).rounded()))
            }

            let piece = NSMutableAttributedString(attributedString: source.attributedSubstring(from: enclosing))
            if kind == .item {
                piece.insert(NSAttributedString(string: "\u{2022}\u{2002}"), at: 0)
            }
            let full = NSRange(location: 0, length: piece.length)
            let opensSection = previous == nil || previous?.isHeading == true || previous == .rule

            piece.enumerateAttributes(in: full) { attributes, range, _ in
                let italic = (attributes[.folioItalic] as? Bool ?? false) != (kind == .quote || kind == .h3)
                let bold = attributes[.folioBold] as? Bool ?? false || (kind.headingLevel ?? 0) >= 4
                piece.addAttribute(.font, value: font(for: kind, style: style, bold: bold, italic: italic), range: range)
            }

            if kind == .paragraph, opensSection {
                applySmallCaps(to: piece, style: style)
            }

            piece.addAttribute(.foregroundColor, value: kind == .rule ? secondary : ink, range: full)
            piece.addAttribute(.paragraphStyle, value: paragraphStyle(for: kind, previous: previous, size: size, style: style), range: full)
            result.append(piece)

            previous = kind
            index += 1
        }

        while result.length > 0, (result.string as NSString).character(at: result.length - 1) == 10 {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    private static func font(for kind: BlockKind, style: TypeStyle, bold: Bool, italic: Bool) -> UIFont {
        let size = style.size
        switch kind {
        case .h1, .h2:
            return style.font.uiFont(size: (size * 1.45).rounded(), bold: bold, italic: italic)
        case .h3:
            return style.font.uiFont(size: (size * 1.15).rounded(), bold: bold, italic: italic)
        case .quote:
            return style.font.uiFont(size: (size * 0.95).rounded(), bold: bold, italic: italic)
        case .preformatted:
            return UIFont.monospacedSystemFont(ofSize: (size * 0.82).rounded(), weight: bold ? .semibold : .regular)
        case .rule:
            return style.font.uiFont(size: size)
        default:
            return style.font.uiFont(size: size, bold: bold, italic: italic)
        }
    }

    private static func paragraphStyle(for kind: BlockKind, previous: BlockKind?, size: CGFloat, style: TypeStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.spacing.multiple
        paragraph.alignment = style.justified ? .justified : .natural
        // Justified lines stretch their spaces, so hyphenate whenever it helps rather than only on very
        // short lines.
        paragraph.hyphenationFactor = style.justified ? 1.0 : 0.3

        switch kind {
        case .paragraph:
            if previous == .paragraph {
                paragraph.firstLineHeadIndent = (size * 1.4).rounded()
            } else if previous == .quote || previous == .item || previous == .preformatted {
                paragraph.paragraphSpacingBefore = (size * 0.7).rounded()
            }
        case .h1, .h2, .h3:
            paragraph.alignment = .center
            paragraph.hyphenationFactor = 0
            paragraph.lineHeightMultiple = 1.08
            paragraph.paragraphSpacingBefore = previous == nil || previous?.isHeading == true ? 0 : (size * 1.6).rounded()
            paragraph.paragraphSpacing = (size * (kind == .h3 ? 1.0 : 1.7)).rounded()
        case .h4, .h5, .h6:
            paragraph.alignment = .natural
            paragraph.hyphenationFactor = 0
            paragraph.paragraphSpacingBefore = (size * 0.9).rounded()
            paragraph.paragraphSpacing = (size * 0.4).rounded()
        case .quote:
            let inset = (size * 1.5).rounded()
            paragraph.headIndent = inset
            paragraph.firstLineHeadIndent = inset
            paragraph.tailIndent = -inset
            paragraph.paragraphSpacingBefore = previous == .quote ? 0 : (size * 0.6).rounded()
            paragraph.paragraphSpacing = (size * 0.6).rounded()
        case .item:
            paragraph.headIndent = (size * 1.1).rounded()
            paragraph.firstLineHeadIndent = 0
            paragraph.paragraphSpacing = (size * 0.25).rounded()
            paragraph.paragraphSpacingBefore = previous == .item ? 0 : (size * 0.4).rounded()
        case .preformatted:
            paragraph.alignment = .natural
            paragraph.hyphenationFactor = 0
            paragraph.lineHeightMultiple = 1.1
        case .rule:
            paragraph.alignment = .center
            paragraph.paragraphSpacingBefore = (size * 0.8).rounded()
            paragraph.paragraphSpacing = (size * 0.8).rounded()
        }
        return paragraph
    }

    /// Sets the first few words of a section in small caps, as many printed books do.
    private static func applySmallCaps(to piece: NSMutableAttributedString, style: TypeStyle) {
        let text = piece.string as NSString
        var words = 0
        var end = 0
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: .byWords) { _, range, _, stop in
            words += 1
            end = NSMaxRange(range)
            if words == 3 { stop.pointee = true }
        }
        guard end > 0, end < text.length else { return }
        piece.enumerateAttributes(in: NSRange(location: 0, length: end)) { attributes, range, _ in
            let italic = attributes[.folioItalic] as? Bool ?? false
            let bold = attributes[.folioBold] as? Bool ?? false
            piece.addAttribute(.font, value: style.font.uiFont(size: style.size, bold: bold, italic: italic, smallCaps: true), range: range)
        }
    }

    /// An empty paragraph that lowers a chapter title from the top of its page.
    private static func sink(height: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = height
        paragraph.maximumLineHeight = height
        return NSAttributedString(string: "\n", attributes: [
            .paragraphStyle: paragraph,
            .font: UIFont.systemFont(ofSize: 2),
        ])
    }
}
