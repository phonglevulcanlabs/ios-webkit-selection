//
//  FormattedTextWebView.swift
//  webkit-selection
//
//  Created by Phong Le on 22/5/26.
//

import SwiftUI
import WebKit

struct FormattedTextWebView: UIViewRepresentable {
    let html: String
    var onTextSelected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextSelected: onTextSelected)
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
        function reportSelection() {
            setTimeout(function() {
                var text = window.getSelection().toString().trim();
                if (text.length > 0) {
                    window.webkit.messageHandlers.\(messageHandlerName).postMessage(text);
                }
            }, 0);
        }
        document.addEventListener('mouseup', reportSelection);
        document.addEventListener('touchend', reportSelection);
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let onTextSelected: (String) -> Void
        private var lastReportedSelection = ""

        init(onTextSelected: @escaping (String) -> Void) {
            self.onTextSelected = onTextSelected
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == FormattedTextWebView.messageHandlerName,
                  let text = message.body as? String
            else { return }

            guard text != lastReportedSelection else { return }
            lastReportedSelection = text
            onTextSelected(text)
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
