//
//  MenuContentView.swift
//  Sysline
//
//  Menu-bar dropdown shell. v1 renders only the Network module.
//  When a 2nd module lands, add a module picker/tabs here.
//

import SwiftUI

struct MenuContentView: View {
    var body: some View {
        // v1 renders only the Network module. Add a module picker here later.
        NetworkView()
    }
}
