import SwiftUI
import AppKit

public struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var isDarkMode: Bool
    var onTextChange: ((String) -> Void)?

    public init(text: Binding<String>, isDarkMode: Bool, onTextChange: ((String) -> Void)? = nil) {
        self._text = text
        self.isDarkMode = isDarkMode
        self.onTextChange = onTextChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = isDarkMode
            ? NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
            : NSColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 8
        layoutManager.addTextContainer(textContainer)

        let textView = CustomCodeNSTextView(frame: CGRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.delegate = context.coordinator

        textView.string = text
        context.coordinator.currentText = text

        applyThemeAndSyntax(textView: textView, isDarkMode: isDarkMode, coordinator: context.coordinator)

        scrollView.documentView = textView

        // Setup Line Number Ruler View
        let ruler = LineNumberRulerView(textView: textView, isDarkMode: isDarkMode)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomCodeNSTextView else { return }

        // Only update colors/theme when theme changed
        if context.coordinator.lastDarkMode != isDarkMode {
            context.coordinator.lastDarkMode = isDarkMode
            scrollView.backgroundColor = isDarkMode
                ? NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
                : NSColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0)

            applyThemeAndSyntax(textView: textView, isDarkMode: isDarkMode, coordinator: context.coordinator)

            if let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
                ruler.isDarkMode = isDarkMode
                ruler.needsDisplay = true
            }
        }

        // Only update from SwiftUI if text differs externally
        if context.coordinator.currentText != text {
            context.coordinator.currentText = text
            let selectedRange = textView.selectedRange()
            textView.string = text
            applyThemeAndSyntax(textView: textView, isDarkMode: isDarkMode, coordinator: context.coordinator)
            if selectedRange.location + selectedRange.length <= (text as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    private func applyThemeAndSyntax(textView: CustomCodeNSTextView, isDarkMode: Bool, coordinator: Coordinator? = nil) {
        coordinator?.isApplyingSyntax = true
        defer { coordinator?.isApplyingSyntax = false }
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let defaultTextColor = isDarkMode
            ? NSColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
            : NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)

        textView.font = font
        textView.textColor = defaultTextColor
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: defaultTextColor
        ]

        if isDarkMode {
            textView.backgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0)
            textView.insertionPointColor = NSColor(red: 0.28, green: 0.82, blue: 1.0, alpha: 1.0)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.20, green: 0.45, blue: 0.85, alpha: 0.50)
            ]
        } else {
            textView.backgroundColor = NSColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0)
            textView.insertionPointColor = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.20)
            ]
        }

        // Apply Syntax Highlighting to textStorage
        guard let storage = textView.textStorage else { return }
        let fullString = storage.string as NSString
        if fullString.length == 0 { return }

        let commentColor = isDarkMode
            ? NSColor(red: 0.44, green: 0.68, blue: 0.48, alpha: 1.0)
            : NSColor(red: 0.32, green: 0.54, blue: 0.35, alpha: 1.0)

        let keywordColor = isDarkMode
            ? NSColor(red: 0.38, green: 0.82, blue: 1.0, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.45, blue: 0.90, alpha: 1.0)

        let statusColor = isDarkMode
            ? NSColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1.0)
            : NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1.0)

        storage.beginEditing()
        // Reset base font & color
        storage.setAttributes([
            .font: font,
            .foregroundColor: defaultTextColor
        ], range: NSRange(location: 0, length: fullString.length))

        // Scan lines for comments and keywords
        fullString.enumerateSubstrings(in: NSRange(location: 0, length: fullString.length), options: .byLines) { _, subRange, _, _ in
            let line = fullString.substring(with: subRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Full line comment
            if trimmed.hasPrefix("#") {
                storage.addAttribute(.foregroundColor, value: commentColor, range: subRange)
                return
            }

            // Inline comment
            if let hashRange = line.range(of: "#") {
                let nsHashPos = NSRange(hashRange, in: line).location
                let commentRange = NSRange(location: subRange.location + nsHashPos, length: subRange.length - nsHashPos)
                storage.addAttribute(.foregroundColor, value: commentColor, range: commentRange)
            }

            // Keyword highlights
            let keywords = ["resBody://", "reqHeaders://", "resHeaders://", "redirect://", "https://", "http://"]
            for kw in keywords {
                if let r = line.range(of: kw) {
                    let nsRange = NSRange(r, in: line)
                    storage.addAttribute(.foregroundColor, value: keywordColor, range: NSRange(location: subRange.location + nsRange.location, length: nsRange.length))
                }
            }

            if let r = line.range(of: "statusCode://") {
                let nsRange = NSRange(r, in: line)
                storage.addAttribute(.foregroundColor, value: statusColor, range: NSRange(location: subRange.location + nsRange.location, length: nsRange.length))
            }
        }
        storage.endEditing()
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var currentText: String = ""
        var lastDarkMode: Bool? = nil
        var isApplyingSyntax: Bool = false

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard !isApplyingSyntax else { return }
            guard let textView = notification.object as? CustomCodeNSTextView else { return }
            let newText = textView.string
            if currentText != newText {
                currentText = newText
                parent.text = newText
                parent.onTextChange?(newText)
            }
        }
    }
}

// MARK: - Custom NSTextView with Shortcuts (Cmd+/, Tab, Shift+Tab, Cmd+D, Undo/Redo)
public class CustomCodeNSTextView: NSTextView {
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd + / for Toggle Comment
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            toggleComment()
            return true
        }

        // Cmd + D for Duplicate Line
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            duplicateCurrentLine()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        // Tab Key (Keycode 48)
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                unindentLines()
            } else {
                indentLinesOrInsertSpaces()
            }
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Comment / Uncomment Toggle (⌘/)
    public func toggleComment() {
        let fullText = self.string as NSString
        let selRange = selectedRange()
        let lineRange = fullText.lineRange(for: selRange)
        let linesBlock = fullText.substring(with: lineRange)
        var lines = linesBlock.components(separatedBy: "\n")

        let hasTrailingNewline = linesBlock.hasSuffix("\n")
        if hasTrailingNewline && lines.last == "" {
            lines.removeLast()
        }

        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allCommented = !nonEmptyLines.isEmpty && nonEmptyLines.allSatisfy { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
        }

        var modifiedLines: [String] = []
        if allCommented {
            // Uncomment
            for line in lines {
                if let range = line.range(of: "# ") {
                    var copy = line
                    copy.replaceSubrange(range, with: "")
                    modifiedLines.append(copy)
                } else if let range = line.range(of: "#") {
                    var copy = line
                    copy.replaceSubrange(range, with: "")
                    modifiedLines.append(copy)
                } else {
                    modifiedLines.append(line)
                }
            }
        } else {
            // Comment out
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    modifiedLines.append(line)
                } else {
                    modifiedLines.append("# " + line)
                }
            }
        }

        var newBlock = modifiedLines.joined(separator: "\n")
        if hasTrailingNewline {
            newBlock += "\n"
        }

        applyTextReplacement(in: lineRange, with: newBlock)
    }

    // MARK: - Indent / Unindent (Tab / Shift+Tab)
    private func indentLinesOrInsertSpaces() {
        let selRange = selectedRange()
        if selRange.length == 0 {
            insertText("  ", replacementRange: selRange)
        } else {
            let fullText = self.string as NSString
            let lineRange = fullText.lineRange(for: selRange)
            let linesBlock = fullText.substring(with: lineRange)
            var lines = linesBlock.components(separatedBy: "\n")
            let hasTrailing = linesBlock.hasSuffix("\n")
            if hasTrailing && lines.last == "" { lines.removeLast() }

            let modified = lines.map { "  " + $0 }
            var newBlock = modified.joined(separator: "\n")
            if hasTrailing { newBlock += "\n" }

            applyTextReplacement(in: lineRange, with: newBlock)
        }
    }

    private func unindentLines() {
        let fullText = self.string as NSString
        let selRange = selectedRange()
        let lineRange = fullText.lineRange(for: selRange)
        let linesBlock = fullText.substring(with: lineRange)
        var lines = linesBlock.components(separatedBy: "\n")
        let hasTrailing = linesBlock.hasSuffix("\n")
        if hasTrailing && lines.last == "" { lines.removeLast() }

        let modified = lines.map { line -> String in
            if line.hasPrefix("  ") {
                return String(line.dropFirst(2))
            } else if line.hasPrefix(" ") {
                return String(line.dropFirst(1))
            } else if line.hasPrefix("\t") {
                return String(line.dropFirst(1))
            }
            return line
        }

        var newBlock = modified.joined(separator: "\n")
        if hasTrailing { newBlock += "\n" }

        applyTextReplacement(in: lineRange, with: newBlock)
    }

    // MARK: - Duplicate Current Line (⌘D)
    private func duplicateCurrentLine() {
        let fullText = self.string as NSString
        let selRange = selectedRange()
        let lineRange = fullText.lineRange(for: selRange)
        let lineBlock = fullText.substring(with: lineRange)

        let insertBlock = lineBlock.hasSuffix("\n") ? lineBlock : (lineBlock + "\n")
        let insertPos = lineRange.location + lineRange.length

        undoManager?.beginUndoGrouping()
        if shouldChangeText(in: NSRange(location: insertPos, length: 0), replacementString: insertBlock) {
            textStorage?.replaceCharacters(in: NSRange(location: insertPos, length: 0), with: insertBlock)
            didChangeText()
            setSelectedRange(NSRange(location: insertPos + selRange.location - lineRange.location, length: selRange.length))
        }
        undoManager?.endUndoGrouping()
    }

    private func applyTextReplacement(in targetRange: NSRange, with newText: String) {
        guard shouldChangeText(in: targetRange, replacementString: newText) else { return }

        undoManager?.beginUndoGrouping()
        textStorage?.replaceCharacters(in: targetRange, with: newText)
        didChangeText()
        let newSelRange = NSRange(location: targetRange.location, length: (newText as NSString).length)
        setSelectedRange(newSelRange)
        undoManager?.endUndoGrouping()
    }
}

// MARK: - Vertical Ruler for Line Numbers
public class LineNumberRulerView: NSRulerView {
    var isDarkMode: Bool = true {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView, isDarkMode: Bool) {
        self.isDarkMode = isDarkMode
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 38

        NotificationCenter.default.addObserver(self, selector: #selector(rulerNeedsDisplay), name: NSText.didChangeNotification, object: textView)
        if let clipView = textView.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(rulerNeedsDisplay), name: NSView.boundsDidChangeNotification, object: clipView)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func rulerNeedsDisplay() {
        self.needsDisplay = true
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Background of gutter
        let gutterColor = isDarkMode
            ? NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 0.95)
            : NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 0.95)
        gutterColor.setFill()
        rect.fill()

        // Border line between gutter and editor
        let borderColor = isDarkMode
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(white: 0.0, alpha: 0.08)
        borderColor.setStroke()
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: self.ruleThickness - 0.5, y: rect.minY))
        borderPath.line(to: NSPoint(x: self.ruleThickness - 0.5, y: rect.maxY))
        borderPath.lineWidth = 1.0
        borderPath.stroke()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let string = textView.string as NSString
        var lineNumber = 1

        string.enumerateSubstrings(in: NSRange(location: 0, length: characterRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        let textColor = isDarkMode
            ? NSColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 1.0)
            : NSColor(red: 0.60, green: 0.62, blue: 0.68, alpha: 1.0)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textColor
        ]

        string.enumerateSubstrings(in: characterRange, options: .byLines) { _, subRange, _, _ in
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: subRange.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let y = lineRect.origin.y + textView.textContainerInset.height
            let str = "\(lineNumber)" as NSString
            let strSize = str.size(withAttributes: textAttributes)
            let drawPoint = NSPoint(x: self.ruleThickness - strSize.width - 8, y: y + (lineRect.height - strSize.height)/2)

            str.draw(at: drawPoint, withAttributes: textAttributes)
            lineNumber += 1
        }
    }
}
