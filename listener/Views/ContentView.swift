//
//  ContentView.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ListenerView()
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
}

#Preview {
    ContentView()
}
