import Foundation

extension NSAttributedString.Key {
    /// The `BlockKind` raw value of the paragraph a character belongs to.
    static let folioBlock = NSAttributedString.Key("folio.block")
    static let folioItalic = NSAttributedString.Key("folio.italic")
    static let folioBold = NSAttributedString.Key("folio.bold")
}

enum BlockKind: String {
    case paragraph = "p"
    case h1, h2, h3, h4, h5, h6
    case quote
    case item
    case preformatted = "pre"
    case rule

    var isHeading: Bool {
        headingLevel != nil
    }

    var headingLevel: Int? {
        switch self {
        case .h1: 1
        case .h2: 2
        case .h3: 3
        case .h4: 4
        case .h5: 5
        case .h6: 6
        default: nil
        }
    }
}

/// Turns a chapter's XHTML into a semantic attributed string: one paragraph per block, tagged with its
/// `BlockKind`, plus italic and bold flags. Fonts and paragraph styles are applied later by `Typesetter`.
final class ChapterRenderer {
    private let output = NSMutableAttributedString()
    private var current = NSMutableAttributedString()
    private var blockStack: [BlockKind] = []
    private var italicDepth = 0
    private var boldDepth = 0
    private var suppressSpace = true
    private var pendingSpace = false
    private(set) var firstHeading: String?

    private static let blockElements: Set<String> = [
        "p", "div", "section", "article", "header", "footer", "aside", "main", "nav", "address", "center",
        "figure", "figcaption", "blockquote", "ul", "ol", "li", "dl", "dt", "dd",
        "h1", "h2", "h3", "h4", "h5", "h6", "pre", "table", "tr", "td", "th", "caption",
    ]
    private static let skippedElements: Set<String> = [
        "head", "title", "script", "style", "svg", "math", "noscript", "template", "img", "image", "object",
    ]
    private static let italicElements: Set<String> = ["em", "i", "cite", "dfn", "var"]
    private static let boldElements: Set<String> = ["strong", "b"]

    static func render(_ data: Data) -> (text: NSAttributedString, heading: String?) {
        let renderer = ChapterRenderer()
        let parsed = Markup.parse(data)
        if parsed.isComplete, let root = parsed.root {
            renderer.walk(root.firstDescendant(named: "body") ?? root)
            renderer.flush()
        } else {
            renderer.renderPlainText(from: data)
        }
        return (renderer.output, renderer.firstHeading)
    }

    private func walk(_ node: MarkupNode) {
        for child in node.children {
            switch child {
            case .text(let string): appendText(string)
            case .element(let element): visit(element)
            }
        }
    }

    private func visit(_ element: MarkupNode) {
        let name = element.name
        if Self.skippedElements.contains(name) { return }
        if name == "br" {
            current.append(NSAttributedString(string: "\u{2028}", attributes: inlineAttributes))
            suppressSpace = true
            pendingSpace = false
            return
        }
        if name == "hr" {
            flush()
            emitRule()
            return
        }

        let isBlock = Self.blockElements.contains(name)
        let style = element.attribute("style")?.lowercased() ?? ""
        let isItalic = Self.italicElements.contains(name) || style.contains("italic")
        let isBold = Self.boldElements.contains(name) || style.contains("bold")

        if isBlock {
            flush()
            blockStack.append(kind(for: name))
        }
        if isItalic { italicDepth += 1 }
        if isBold { boldDepth += 1 }
        walk(element)
        if isItalic { italicDepth -= 1 }
        if isBold { boldDepth -= 1 }
        if isBlock {
            flush()
            blockStack.removeLast()
        }
    }

    private func kind(for element: String) -> BlockKind {
        switch element {
        case "h1": .h1
        case "h2": .h2
        case "h3": .h3
        case "h4": .h4
        case "h5": .h5
        case "h6": .h6
        case "blockquote": .quote
        case "li", "dd": .item
        case "pre": .preformatted
        default: .paragraph
        }
    }

    /// The innermost meaningful kind wins, with headings taking precedence over containers.
    private var effectiveKind: BlockKind {
        if let heading = blockStack.last(where: \.isHeading) { return heading }
        if blockStack.contains(.preformatted) { return .preformatted }
        if let container = blockStack.last(where: { $0 == .quote || $0 == .item }) { return container }
        return .paragraph
    }

    private var inlineAttributes: [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if italicDepth > 0 { attributes[.folioItalic] = true }
        if boldDepth > 0 { attributes[.folioBold] = true }
        return attributes
    }

    private func appendText(_ string: String) {
        guard !string.isEmpty else { return }
        if effectiveKind == .preformatted {
            current.append(NSAttributedString(string: string, attributes: inlineAttributes))
            return
        }

        var text = String.UnicodeScalarView()
        for scalar in string.unicodeScalars {
            switch scalar {
            case " ", "\n", "\t", "\r":
                pendingSpace = true
            default:
                if pendingSpace && !suppressSpace {
                    text.append(" ")
                }
                pendingSpace = false
                suppressSpace = false
                text.append(scalar)
            }
        }
        guard !text.isEmpty else { return }
        current.append(NSAttributedString(string: String(text), attributes: inlineAttributes))
    }

    private func flush() {
        defer {
            current = NSMutableAttributedString()
            suppressSpace = true
            pendingSpace = false
        }
        while let last = current.string.unicodeScalars.last, last == "\u{2028}" || last == " " {
            current.deleteCharacters(in: NSRange(location: current.length - 1, length: 1))
        }
        guard current.length > 0 else { return }

        let kind = effectiveKind
        if kind.isHeading, firstHeading == nil {
            firstHeading = current.string
                .replacingOccurrences(of: "\u{2028}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        current.append(NSAttributedString(string: "\n"))
        current.addAttribute(.folioBlock, value: kind.rawValue, range: NSRange(location: 0, length: current.length))
        output.append(current)
    }

    private func emitRule() {
        guard output.length > 0 else { return }
        output.append(NSAttributedString(string: "\u{2042}\n", attributes: [.folioBlock: BlockKind.rule.rawValue]))
    }

    /// Fallback for chapters that are not well-formed XML: strip tags and keep paragraph breaks.
    private func renderPlainText(from data: Data) {
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(
            of: #"(?is)<(head|script|style)\b[^>]*>.*?</\1>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"(?i)</(p|div|h[1-6]|li|blockquote)>|<br[^>]*>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (entity, value) in [("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        for line in text.components(separatedBy: "\n") {
            appendText(line)
            flush()
        }
    }
}
