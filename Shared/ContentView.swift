//
//  ContentView.swift
//  Shared
//
//  Created by Markus Moenig on 7/4/21.
//

import SwiftUI

#if os(iOS)
import MobileCoreServices
#endif

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
    @State var areasAreOn                   : Bool = false

    @State var areaMenuText                 : String = "Area: None"

    @State var showAreaExporter             : Bool = false

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
                
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            MetalView(document.core, .Preview)
                            ToolsView(document: document, updateView: $updateView)
                            ToolsView2(document: document, updateView: $updateView)
                                .offset(x: geometry.size.width - 130, y: 0)
                            ToolsView3(document: document, updateView: $updateView)
                                .offset(x: geometry.size.width - 130, y: geometry.size.height - 30)
                        }
                    }
                    ProgressBar(document: document).frame(height: 4)
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
                        if let tileSet = currentTileSet {
                            if tileSet.openTile !== nil {
                                NodeSettingsView(document: document, updateView: $updateView)
                            }
                        }
                    }
                    .animation(.default)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                
                toolGridTypeMenu
                
                Spacer()
                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0)
                
                toolAreaMenu
                
                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0)
                
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
                                document.core.project.setHasChanged(true)
                                document.core.renderer.render()
                            })
                            Button("32x32", action: {
                                document.core.project.writeFloat("tileSize", value: 32)
                                tileSizeText = getTileSizeText()
                                document.core.project.setHasChanged(true)
                                document.core.renderer.render()
                            })
                            Button("64x64", action: {
                                document.core.project.writeFloat("tileSize", value: 64)
                                tileSizeText = getTileSizeText()
                                document.core.project.setHasChanged(true)
                                document.core.renderer.render()
                            })
                            Button("128x128", action: {
                                document.core.project.writeFloat("tileSize", value: 128)
                                tileSizeText = getTileSizeText()
                                document.core.project.setHasChanged(true)
                                document.core.renderer.render()
                            })
                            Button("256x256", action: {
                                document.core.project.writeFloat("tileSize", value: 256)
                                tileSizeText = getTileSizeText()
                                document.core.project.setHasChanged(true)
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
                                document.core.project.setHasChanged(true)
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
                                document.core.project.setHasChanged(true)
                                document.core.renderer.render()
                            }), in: 0...5, step: Double(1))
                            Text(antiAliasingText)
                                .frame(maxWidth: 40)
                        }
                        .padding(4)
                        
                        Toggle(isOn: $areasAreOn) {
                            Text("Show Areas")
                        }
                        
                        Toggle(isOn: $gridIsOn) {
                            Text("Show Grid")
                        }
                        
                        .onChange(of: gridIsOn) { value in
                            document.core.screenView.showGrid = gridIsOn
                            document.core.screenView.update()
                        }
                        
                        .onChange(of: areasAreOn) { value in
                            document.core.screenView.showAreas = areasAreOn
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
        
        .onReceive(self.document.core.areaChanged) { _ in
            areaMenuText = "Area: None"
            if let layer = document.core.project.currentLayer {
                if layer.selectedAreas.isEmpty == false {
                    let area = layer.selectedAreas[0]
                    areaMenuText = "Area: \(area.area.z)x\(area.area.w)"
                }
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
    
    func isAreaDisabled() -> Bool
    {
        return areaMenuText == "Area: None"
    }
    
    // tool bar menus
    
    var toolGridTypeMenu : some View {
        Menu {
            Button(action: {
                
                if let currentScreen = document.core.project.getCurrentScreen() {
                    currentScreen.gridType = .rectFront
                }
                document.core.project.setHasChanged(true)
                document.core.nodeView?.update()
                document.core.renderer.render()
                updateView.toggle()
                
            })
            {
                Image(systemName: "squareshape")
                Text("FRONT")
            }
            Button(action: {
            
                if let currentScreen = document.core.project.getCurrentScreen() {
                    currentScreen.gridType = .rectIso
                }
                document.core.project.setHasChanged(true)
                document.core.nodeView?.update()
                document.core.renderer.render()
                updateView.toggle()
            })
            {
                Image(systemName: "squareshape")
                Text("ISO")
            }
        }
        label: {
            if let currentScreen = document.core.project.getCurrentScreen() {
                if currentScreen.gridType == .rectFront {
                    Image(systemName: "squareshape")
                    Text("FRONT")
                } else {
                    Image(systemName: "squareshape")
                    Text("ISO")
                    //Label("Rect Iso", systemImage: "cube")
                }
            }
        }
    }

    var toolAreaMenu : some View {
        Menu {
            Section(header: Text("Export")) {
                Button("Copy to Clipboard", action: {
                    if let layer = document.core.project.currentLayer {
                        if layer.selectedAreas.isEmpty == false {
                            if let rc = document.core.getAreaData(layer.selectedAreas[0]) {
                                
                                if let image = document.core.createCGIImage(rc.2, SIMD2<Int>(rc.0, rc.1)) {
                                    #if os(macOS)
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.writeObjects([NSImage(cgImage: image, size: .zero)])
                                    #endif
                                }
                            }
                        }
                    }
                })
                Button("Export...", action: {
                    showAreaExporter = true
                })
            }
        }
        label: {
            Text(areaMenuText)
        }
        .disabled(isAreaDisabled())
        // Export Image
        .fileExporter(
            isPresented: $showAreaExporter,
            document: document,
            contentType: .png,
            defaultFilename: "AreaImage"
        ) { result in
            do {
                let url = try result.get()
                
                if let layer = document.core.project.currentLayer {
                    if layer.selectedAreas.isEmpty == false {
                        if let rc = document.core.getAreaData(layer.selectedAreas[0]) {
                            
                            if let image = document.core.createCGIImage(rc.2, SIMD2<Int>(rc.0, rc.1)) {
                                if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                                    CGImageDestinationAddImage(imageDestination, image, nil)
                                    CGImageDestinationFinalize(imageDestination)
                                }
                            }
                        }
                    }
                }
            } catch {
                // Handle failure.
            }
        }
    }
}

/// For displaying render progress
struct ProgressBar: View {
    
    @State var document                    : FabricatedDocument
    @State var value                       : Float = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.accentColor)
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
        
        .onReceive(document.core.renderProgressChanged) { progress in
            value = progress
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(FabricatedDocument()))
    }
}
