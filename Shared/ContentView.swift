//
//  ContentView.swift
//  Shared
//
//  Created by Markus Moenig on 7/4/21.
//

import SwiftUI

struct ContentView: View {
    
    @Binding var document                   : FabricatedDocument

    @State private var updateView           : Bool = false

    @Environment(\.colorScheme) var deviceColorScheme: ColorScheme

    #if os(macOS)
    let leftPanelWidth                      : CGFloat = 200
    #else
    let leftPanelWidth                      : CGFloat = 250
    #endif
    
    var body: some View {
        HStack() {
            NavigationView() {
                
                ProjectView(document: document, updateView: $updateView)
                    .frame(minWidth: leftPanelWidth, idealWidth: leftPanelWidth, maxWidth: leftPanelWidth)
                
                VStack(spacing: 2) {
                    HStack {
                        MetalView(document.core, .Preview)
                        ScreenLayerSettingsView(document: document, updateView: $updateView)
                    }
                    HStack {
                        ZStack(alignment: .topLeading) {
                            MetalView(document.core, .Nodes)
                            NodeToolbar(document: document, updateView: $updateView)
                        }
                        NodeSettingsView(document: document, updateView: $updateView)
                    }
                }
            }
        }
        .onAppear(perform: {
            document.core.renderer.render()
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(FabricatedDocument()))
    }
}
