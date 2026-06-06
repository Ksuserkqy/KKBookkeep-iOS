import Foundation

final class WebDAVHrefParser: NSObject, XMLParserDelegate {
    private var hrefs: [String] = []
    private var currentElement = ""
    private var currentValue = ""

    static func parse(data: Data) -> [String] {
        let parserDelegate = WebDAVHrefParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        parser.parse()
        return parserDelegate.hrefs
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isHrefElement(currentElement) else { return }
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard isHrefElement(elementName) else { return }

        let href = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !href.isEmpty {
            hrefs.append(href)
        }

        currentValue = ""
    }

    private func isHrefElement(_ elementName: String) -> Bool {
        elementName == "href" || elementName.hasSuffix(":href")
    }
}

struct WebDAVEntry {
    var name: String
    var isDirectory: Bool

    static func name(from href: String?) -> String? {
        guard var href, !href.isEmpty else { return nil }
        while href.hasSuffix("/") {
            href.removeLast()
        }

        guard !href.isEmpty else { return nil }

        if let url = URL(string: href) {
            let name = url.lastPathComponent
            return name.isEmpty ? nil : name
        }

        let name = href.split(separator: "/").last.map(String.init) ?? ""
        return name.isEmpty ? nil : name
    }
}
