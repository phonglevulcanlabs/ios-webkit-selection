//
//  FormattedTextWebView.swift
//  webkit-selection
//
//  Created by Phong Le on 22/5/26.
//

import SwiftUI
import WebKit

struct WebTextSelection: Equatable {
    let plainText: String
    let html: String
    let fragments: [FormattedTextFragment]

    init?(messageBody: Any) {
        guard let dict = messageBody as? [String: Any],
              let plainText = dict["text"] as? String,
              let html = dict["html"] as? String
        else { return nil }

        self.plainText = plainText
        self.html = html

        let rawFragments = dict["fragments"] as? [[String: Any]] ?? []
        self.fragments = rawFragments.compactMap { FormattedTextFragment(dictionary: $0) }
    }

    var attributedString: NSAttributedString? {
        let document = "<!DOCTYPE html><html><body>\(html)</body></html>"
        guard let data = document.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        )
    }
}

struct FormattedTextFragment: Equatable {
    let text: String
    let tags: [String]
    let styles: TextRunStyles

    init?(dictionary: [String: Any]) {
        guard let text = dictionary["text"] as? String else { return nil }
        self.text = text
        self.tags = dictionary["tags"] as? [String] ?? []
        self.styles = TextRunStyles(dictionary: dictionary["styles"] as? [String: String] ?? [:])
    }
}

struct TextRunStyles: Equatable, CustomStringConvertible {
    let fontWeight: String?
    let fontStyle: String?
    let textDecoration: String?
    let color: String?
    let backgroundColor: String?

    init(dictionary: [String: String]) {
        fontWeight = dictionary["fontWeight"]
        fontStyle = dictionary["fontStyle"]
        textDecoration = dictionary["textDecoration"]
        color = dictionary["color"]
        backgroundColor = dictionary["backgroundColor"]
    }

    var description: String {
        [
            fontWeight.map { "weight=\($0)" },
            fontStyle.map { "style=\($0)" },
            textDecoration.map { "decoration=\($0)" },
            color.map { "color=\($0)" },
            backgroundColor.map { "background=\($0)" },
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

struct FormattedTextWebView: UIViewRepresentable {
    let html: String
    var onSelection: (WebTextSelection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = configuration.userContentController

        let selectionScript = WKUserScript(
            source: Self.selectionListenerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(selectionScript)
        controller.add(context.coordinator, name: Self.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static let messageHandlerName = "textSelection"

    static let selectionListenerScript = """
    (function() {
        function ancestorTags(element) {
            var tags = [];
            var node = element;
            while (node && node.nodeType === Node.ELEMENT_NODE && node.tagName !== 'BODY') {
                tags.push(node.tagName.toLowerCase());
                node = node.parentElement;
            }
            return tags;
        }

        function relevantStyles(element) {
            if (!element || !window.getComputedStyle) return {};
            var style = window.getComputedStyle(element);
            return {
                fontWeight: style.fontWeight,
                fontStyle: style.fontStyle,
                textDecoration: style.textDecorationLine,
                color: style.color,
                backgroundColor: style.backgroundColor
            };
        }

        function fragmentsForRange(range) {
            var fragments = [];
            var walker = document.createTreeWalker(
                range.commonAncestorContainer,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode: function(node) {
                        if (!range.intersectsNode(node)) {
                            return NodeFilter.FILTER_REJECT;
                        }
                        if (!node.textContent.trim()) {
                            return NodeFilter.FILTER_REJECT;
                        }
                        return NodeFilter.FILTER_ACCEPT;
                    }
                }
            );

            var textNode = walker.nextNode();
            while (textNode) {
                var parent = textNode.parentElement;
                if (parent) {
                    fragments.push({
                        text: textNode.textContent,
                        tags: ancestorTags(parent),
                        styles: relevantStyles(parent)
                    });
                }
                textNode = walker.nextNode();
            }
            return fragments;
        }

        function selectionPayload() {
            var selection = window.getSelection();
            if (!selection || selection.rangeCount === 0) return null;

            var plainText = selection.toString().trim();
            if (!plainText) return null;

            var range = selection.getRangeAt(0);
            var container = document.createElement('div');
            container.appendChild(range.cloneContents());

            return {
                text: plainText,
                html: container.innerHTML,
                fragments: fragmentsForRange(range)
            };
        }

        function reportSelection() {
            setTimeout(function() {
                var payload = selectionPayload();
                if (payload) {
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage(payload);
                }
            }, 0);
        }

        document.addEventListener('mouseup', reportSelection);
        document.addEventListener('touchend', reportSelection);
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let onSelection: (WebTextSelection) -> Void
        private var lastReportedSelection: WebTextSelection?

        init(onSelection: @escaping (WebTextSelection) -> Void) {
            self.onSelection = onSelection
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == FormattedTextWebView.messageHandlerName,
                  let selection = WebTextSelection(messageBody: message.body)
            else { return }

            guard selection != lastReportedSelection else { return }
            lastReportedSelection = selection
            onSelection(selection)
        }
    }
}

enum SampleFormattedHTML {
    static let content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                font-size: 17px;
                line-height: 1.5;
                color: #1c1c1e;
                margin: 0;
                padding: 20px;
            }
            h1 { font-size: 28px; margin-bottom: 8px; }
            h2 { font-size: 22px; color: #3a3a3c; margin-top: 24px; }
            p { margin: 12px 0; }
            strong { color: #007aff; }
            em { font-style: italic; color: #636366; }
            mark { background: #fff3cd; padding: 0 4px; border-radius: 4px; }
            ul { padding-left: 24px; }
            blockquote {
                border-left: 4px solid #007aff;
                margin: 16px 0;
                padding: 8px 16px;
                background: #f2f2f7;
                border-radius: 0 8px 8px 0;
            }
            code {
                font-family: ui-monospace, Menlo, monospace;
                background: #f2f2f7;
                padding: 2px 6px;
                border-radius: 4px;
            }
        </style>
    </head>
    <body>
        <h1>Formatted Text Demo</h1>
        <p>
            Select any portion of this page. The app will
            <strong>print your selection</strong> to the Xcode console.
        </p>
        <h2>Rich formatting</h2>
        <p>
            This paragraph mixes <em>italic emphasis</em>,
            <strong>bold highlights</strong>, and <mark>highlighted phrases</mark>
            so you can test selections across styles.
        </p>
        <blockquote>
            “Good design is as little design as possible.” — Dieter Rams
        </blockquote>
        <h2>List example</h2>
        <ul>
            <li>Tap and drag to select words</li>
            <li>Extend the handles to cover multiple lines</li>
            <li>Check the debug console for output</li>
        </ul>
        <p>
            Inline code like <code>window.getSelection()</code> can be selected too.
        </p>
    </body>
    </html>
    """
}
