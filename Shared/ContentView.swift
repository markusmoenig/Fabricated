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
    @State var currentTileSet               : TileSet? = nil
    
    @State private var showSettingsPopover  : Bool = false

    @State var tileSizeText                 : String = "Tile Size: 64x64"
    
    @State var pixelationValue              : Double = 4
    @State var pixelationText               : String = "4"
    
    @State var antiAliasingValue            : Double = 2
    @State var antiAliasingText             : String = "2"
    
    @State var gridIsOn                     : Bool = true


    @Environment(\.colorScheme) var deviceColorScheme: ColorScheme
    @Environment(\.undoManager) var undoManager

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
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            MetalView(document.core, .Preview)
                            ToolsView(document: document, updateView: $updateView)
                            ToolsView2(document: document, updateView: $updateView)
                                .offset(x: geometry.size.width - 130, y: 0)
                        }
                    }
                    HStack {
                        ZStack(alignment: .topLeading) {
                            if let tileSet = currentTileSet {
                                if tileSet.openTile !== nil {
                                    MetalView(document.core, .Nodes)
                                    NodeToolbar(document: document, updateView: $updateView)
                                } else {
                                    TileGridView(document: document, updateView: $updateView)
                                }
                            }
                        }
                        NodeSettingsView(document: document, updateView: $updateView)
                    }
                    .animation(.default)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                
                Button(action: {
                    showSettingsPopover = true
                }) {
                    Label("Settings", systemImage: "gear")
                }
                .popover(isPresented: self.$showSettingsPopover,
                         arrowEdge: .top
                ) {
                    VStack(alignment: .leading) {
                        Menu(tileSizeText) {
                            Button("16x16", action: {
                                document.core.project.writeFloat("tileSize", value: 16)
                                tileSizeText = getTileSizeText()
                                document.core.renderer.render()
                            })
                            Button("32x32", action: {
                                document.core.project.writeFloat("tileSize", value: 32)
                                tileSizeText = getTileSizeText()
                                document.core.renderer.render()
                            })
                            Button("64x64", action: {
                                document.core.project.writeFloat("tileSize", value: 64)
                                tileSizeText = getTileSizeText()
                                document.core.renderer.render()
                            })
                            Button("128x128", action: {
                                document.core.project.writeFloat("tileSize", value: 128)
                                tileSizeText = getTileSizeText()
                                document.core.renderer.render()
                            })
                        }
                        .padding(4)
                        .frame(minWidth: 200)

                        Text("Pixel Size")
                            .padding(.leading, 4)
                            .padding(.top, 4)
                            .padding(.bottom, 0)

                        HStack {
                            Slider(value: Binding<Double>(get: {pixelationValue}, set: { v in
                                pixelationValue = v
                                pixelationText = String(Int(v))//String(format: "%.02f", v)

                                document.core.project.writeFloat("pixelSize", value: Float(pixelationValue))
                                document.core.renderer.render()
                            }), in: 1...12, step: Double(1))
                            Text(pixelationText)
                                .frame(maxWidth: 40)
                        }
                        .padding(4)
                        
                        Text("Anti-Aliasing")
                            .padding(.leading, 4)
                            .padding(.top, 4)
                            .padding(.bottom, 0)
                        
                        HStack {
                            Slider(value: Binding<Double>(get: {antiAliasingValue}, set: { v in
                                antiAliasingValue = v
                                antiAliasingText = String(Int(v))//String(format: "%.02f", v)

                                document.core.project.writeFloat("antiAliasing", value: Float(antiAliasingValue))
                                document.core.renderer.render()
                            }), in: 0...5, step: Double(1))
                            Text(antiAliasingText)
                                .frame(maxWidth: 40)
                        }
                        .padding(4)
                        
                        Toggle(isOn: $gridIsOn) {
                            Text("Show Grid")
                        }
                        
                        .onChange(of: gridIsOn) { value in
                            document.core.screenView.showGrid = gridIsOn
                            document.core.screenView.update()
                        }
                    }
                    .padding()
                }
            }
        }
        
        .onAppear(perform: {
            currentTileSet = document.core.project.currentTileSet
            document.core.tileSetChanged.send(currentTileSet)

            document.core.renderer.render()
        })
        
        .onReceive(self.document.core.tileSetChanged) { tileSet in
            currentTileSet = nil
            currentTileSet = tileSet
            if undoManager != nil && document.core.undoManager == nil {
                document.core.undoManager = undoManager
            }
        }
        
        .onReceive(self.document.core.startupSignal) { _ in
            if undoManager != nil && document.core.undoManager == nil {
                document.core.undoManager = undoManager
            }
        }
    }
    
    func getTileSizeText() -> String {
        let size = Int(document.core.project.readFloat("tileSize"))
        return "Tile Size: \(size)x\(size)"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(FabricatedDocument()))
    }
}
