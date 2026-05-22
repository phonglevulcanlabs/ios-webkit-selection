//
//  ContentView.swift
//  webkit-selection
//
//  Created by Phong Le on 22/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        FormattedTextWebView(html: SampleFormattedHTML.content) { selectedText in
            print("[WebView selection] \(selectedText)")
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
}
