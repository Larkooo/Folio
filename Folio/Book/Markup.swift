import Foundation

/// A small DOM built with XMLParser. Element and attribute names are lowercased, and element names drop
/// their namespace prefix (`dc:title` becomes `title`). Attribute names keep it (`epub:type`).
final class MarkupNode: @unchecked Sendable {
    enum Child {
        case element(MarkupNode)
        case text(String)
    }

    let name: String
    let attributes: [String: String]
    fileprivate(set) var children: [Child] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func attribute(_ key: String) -> String? {
        attributes[key]
    }

    var elements: [MarkupNode] {
        children.compactMap { child in
            if case .element(let node) = child { return node }
            return nil
        }
    }

    func child(named name: String) -> MarkupNode? {
        elements.first { $0.name == name }
    }

    func firstDescendant(named name: String) -> MarkupNode? {
        for node in elements {
            if node.name == name { return node }
            if let match = node.firstDescendant(named: name) { return match }
        }
        return nil
    }

    func descendants(named name: String) -> [MarkupNode] {
        var result: [MarkupNode] = []
        collect(named: name, into: &result)
        return result
    }

    private func collect(named name: String, into result: inout [MarkupNode]) {
        for node in elements {
            if node.name == name { result.append(node) }
            node.collect(named: name, into: &result)
        }
    }

    var text: String {
        var result = ""
        appendText(into: &result)
        return result
    }

    private func appendText(into result: inout String) {
        for child in children {
            switch child {
            case .text(let string): result += string
            case .element(let node): node.appendText(into: &result)
            }
        }
    }
}

enum Markup {
    struct Result {
        let root: MarkupNode?
        let isComplete: Bool
    }

    static func parse(_ data: Data) -> Result {
        let builder = Builder()
        let parser = XMLParser(data: sanitize(data))
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        let ok = parser.parse()
        return Result(root: builder.root, isComplete: ok)
    }

    /// Makes typical EPUB XHTML palatable to XMLParser: drops the XML declaration and DOCTYPE,
    /// rewrites HTML named entities as numeric references, and escapes stray ampersands.
    static func sanitize(_ data: Data) -> Data {
        guard var text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
        else { return data }

        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: #"<\?xml[^>]*\?>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"<!DOCTYPE[^>\[]*(\[[^\]]*\])?\s*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(of: #"&(?!#?[A-Za-z0-9]+;)"#, with: "&amp;", options: .regularExpression)
        text = replaceNamedEntities(in: text)
        return Data(text.utf8)
    }

    private static let entityPattern = try! NSRegularExpression(pattern: "&([A-Za-z][A-Za-z0-9]{1,31});")
    private static let xmlEntities: Set<String> = ["amp", "lt", "gt", "quot", "apos"]

    private static func replaceNamedEntities(in text: String) -> String {
        let source = text as NSString
        let matches = entityPattern.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        let result = NSMutableString(string: text)
        for match in matches.reversed() {
            let name = source.substring(with: match.range(at: 1))
            if xmlEntities.contains(name) { continue }
            let replacement = htmlEntities[name].map { "&#\($0);" } ?? ""
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }

    private static let htmlEntities: [String: Int] = [
        "nbsp": 160, "iexcl": 161, "cent": 162, "pound": 163, "yen": 165, "sect": 167, "copy": 169,
        "laquo": 171, "shy": 173, "reg": 174, "deg": 176, "plusmn": 177, "para": 182, "middot": 183,
        "raquo": 187, "frac14": 188, "frac12": 189, "frac34": 190, "iquest": 191,
        "Agrave": 192, "Aacute": 193, "Acirc": 194, "Atilde": 195, "Auml": 196, "Aring": 197, "AElig": 198,
        "Ccedil": 199, "Egrave": 200, "Eacute": 201, "Ecirc": 202, "Euml": 203, "Igrave": 204, "Iacute": 205,
        "Icirc": 206, "Iuml": 207, "Ntilde": 209, "Ograve": 210, "Oacute": 211, "Ocirc": 212, "Otilde": 213,
        "Ouml": 214, "times": 215, "Oslash": 216, "Ugrave": 217, "Uacute": 218, "Ucirc": 219, "Uuml": 220,
        "szlig": 223, "agrave": 224, "aacute": 225, "acirc": 226, "atilde": 227, "auml": 228, "aring": 229,
        "aelig": 230, "ccedil": 231, "egrave": 232, "eacute": 233, "ecirc": 234, "euml": 235, "igrave": 236,
        "iacute": 237, "icirc": 238, "iuml": 239, "ntilde": 241, "ograve": 242, "oacute": 243, "ocirc": 244,
        "otilde": 245, "ouml": 246, "divide": 247, "oslash": 248, "ugrave": 249, "uacute": 250, "ucirc": 251,
        "uuml": 252, "yuml": 255, "OElig": 338, "oelig": 339, "ensp": 8194, "emsp": 8195, "thinsp": 8201,
        "zwnj": 8204, "zwj": 8205, "ndash": 8211, "mdash": 8212, "lsquo": 8216, "rsquo": 8217, "sbquo": 8218,
        "ldquo": 8220, "rdquo": 8221, "bdquo": 8222, "dagger": 8224, "Dagger": 8225, "bull": 8226,
        "hellip": 8230, "prime": 8242, "Prime": 8243, "lsaquo": 8249, "rsaquo": 8250, "euro": 8364,
        "trade": 8482, "larr": 8592, "rarr": 8594,
    ]

    private final class Builder: NSObject, XMLParserDelegate {
        var root: MarkupNode?
        private var stack: [MarkupNode] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
            let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
            var lowered: [String: String] = [:]
            for (key, value) in attributes { lowered[key.lowercased()] = value }
            let node = MarkupNode(name: local.lowercased(), attributes: lowered)
            if let parent = stack.last {
                parent.children.append(.element(node))
            } else if root == nil {
                root = node
            }
            stack.append(node)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            _ = stack.popLast()
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            appendText(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            appendText(String(decoding: CDATABlock, as: UTF8.self))
        }

        private func appendText(_ string: String) {
            guard let parent = stack.last else { return }
            if case .text(let previous)? = parent.children.last {
                parent.children[parent.children.count - 1] = .text(previous + string)
            } else {
                parent.children.append(.text(string))
            }
        }
    }
}
