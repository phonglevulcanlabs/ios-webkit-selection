//
//  ContentView.swift
//  webkit-selection
//
//  Created by Phong Le on 22/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        FormattedTextWebView(html: SampleFormattedHTML.content) { selection in
            print("[WebView selection] text: \(selection.plainText)")
            print("[WebView selection] html: \(selection.html)")
            for (index, fragment) in selection.fragments.enumerated() {
                let tags = fragment.tags.isEmpty ? "none" : fragment.tags.joined(separator: " > ")
                print("[WebView selection] fragment \(index): \"\(fragment.text.trimmingCharacters(in: .whitespacesAndNewlines))\" tags=\(tags) styles=\(fragment.styles)")
            }
            if let attributed = selection.attributedString {
                print("[WebView selection] attributed length: \(attributed.length)")
                attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                    let substring = (attributed.string as NSString).substring(with: range)
                    print("[WebView selection] run \"\(substring)\" attributes: \(attrs)")
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
}
