//
//  ContentView.swift
//  Shared
//
//  Created by Markus Moenig on 7/4/21.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: FabricatedDocument

    @Environment(\.colorScheme) var deviceColorScheme: ColorScheme

    var body: some View {
        HStack() {
            NavigationView() {
                VStack(spacing: 2) {
                    MetalView(document.core, .Preview)
                    MetalView(document.core, .Nodes)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(FabricatedDocument()))
    }
}
