/// The one edit gdswift makes to a user-owned `project.godot`: adding an
/// `[autoload]` entry for a script the user marked. Every other byte of
/// the file is preserved — the editor owns the file, gdswift only
/// appends, and it never reorders or removes an entry.
extension ProjectFile {

    /// The file's text with `name="*<path>"` added at the end of the
    /// `[autoload]` section. The section is created after `[application]`
    /// when the file has none, and at the end of the file when it has
    /// neither.
    public static func appendingAutoload(name: String, path: String, to source: String) -> String {
        var lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let carriageReturn = lines.contains { $0.hasSuffix("\r") }
        func line(_ text: String) -> String { carriageReturn ? text + "\r" : text }
        let entry = line("\(name)=\"*\(path)\"")

        if let header = headerIndex(of: "autoload", in: lines) {
            let index = insertionIndex(after: header, in: lines)
            let opensTheSection = index == header + 1
            lines.insert(contentsOf: opensTheSection ? [line(""), entry] : [entry], at: index)
            return lines.joined(separator: "\n")
        }

        let section = [line(""), line("[autoload]"), line(""), entry]
        if let application = headerIndex(of: "application", in: lines) {
            lines.insert(contentsOf: section, at: insertionIndex(after: application, in: lines))
            return lines.joined(separator: "\n")
        }
        lines.insert(contentsOf: section, at: endOfDocument(in: lines))
        return lines.joined(separator: "\n")
    }

    /// The line declaring `[<kind>]`, ignoring the platform variants
    /// (`[input.macos]`), which carry their own overrides.
    private static func headerIndex(of kind: String, in lines: [String]) -> Int? {
        lines.firstIndex { $0.trimmedLine == "[\(kind)]" }
    }

    private static func isHeader(_ text: String) -> Bool {
        let trimmed = text.trimmedLine
        return trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
    }

    /// One past the section's last property line: the blank lines before
    /// the next header, and the file's trailing newline, stay where they
    /// are.
    private static func insertionIndex(after header: Int, in lines: [String]) -> Int {
        var end = header + 1
        while end < lines.count, !isHeader(lines[end]) { end += 1 }
        var index = end
        while index > header + 1, lines[index - 1].trimmedLine.isEmpty { index -= 1 }
        return index
    }

    private static func endOfDocument(in lines: [String]) -> Int {
        var index = lines.count
        while index > 0, lines[index - 1].trimmedLine.isEmpty { index -= 1 }
        return index
    }
}

private extension String {
    /// The line without the whitespace Godot's own writer never emits.
    var trimmedLine: String {
        var view = Substring(self)
        while let first = view.first, first == " " || first == "\t" { view = view.dropFirst() }
        while let last = view.last, last == " " || last == "\t" || last == "\r" { view = view.dropLast() }
        return String(view)
    }
}
