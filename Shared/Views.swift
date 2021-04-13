//
//  Views.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import SwiftUI

/// ProjectView on the left
struct ProjectView: View {
    @State      var document                    : FabricatedDocument
    @Binding    var updateView                  : Bool
    
    @State     var currentLayer                 : Screen? = nil

    var body: some View {
        VStack {
            List() {
                
                ForEach(document.core.project.screens, id: \.id) { screen in
                    Section(header:
                                HStack {
                                    //Image("viewfinder")
                                    Text(screen.name)
                                } ) {
                        ForEach(screen.layers, id: \.id) { layer in
                            Button(action: {
                            })
                            {
                                Label(layer.name, systemImage: "camera")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                //if selection == cameraNode.id {
                //                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                //                    } else { Color.clear }
                                
                                Color.clear
                            })
                                .contextMenu {
                                    Text("Layer")
                                }
                        }
                    }
                }
                
                Section(header: Text("Tile Sets")) {
                    ForEach(document.core.project.tileSets, id: \.id) { tileSet in
                        Button(action: {
                            document.core.project.currentTileSet = tileSet
                            tileSet.currentTile = nil
                            document.core.tileSetChanged.send(tileSet)
                        })
                        {
                            Label(tileSet.name, systemImage: "camera")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Group {
                            //if selection == cameraNode.id {
            //                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
            //                    } else { Color.clear }
                            
                            Color.clear
                        })
                            .contextMenu {
                                Text("tileSet")
                            }
                    }
                }
                
                #if os(macOS)
                Divider()
                #endif
                
                Button(action: {
                })
                {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Group {
                    //if selection == cameraNode.id {
    //                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
    //                    } else { Color.clear }
                    
                    Color.clear
                })
            }
            
            //.listStyle(InsetGroupedListStyle()) // ENABLE_IOS
        }
    }
}

/// ProjectSettingsView
struct ProjectSettingsView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        VStack {
            List() {

            }
        }
        .frame(maxWidth: 200)
    }
}

/// ScreenLayerSettingsView on the top right
struct ScreenLayerSettingsView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        VStack {
            if let currentLayer = document.core.project.currentLayer {
                
            } else {
                ProjectSettingsView(document: document, updateView: $updateView)
            }
        }
        .frame(maxWidth: 200)
    }
}

/// NodeToolbar
struct NodeToolbar: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        HStack {
            Menu {
                Menu("Shapes") {
                    Button("Disk", action: {
                        if let tile = document.core.nodeView.currentTile {
                            tile.nodes.append(ShapeDisk())
                            document.core.nodeView.update()
                        }
                    })
                }
            }
            label: {
                Label("Add Node", systemImage: "plus")
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: 120)
                        
            Button(action: {
            })
            {
                Text("Remove")
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading, 10)
            
            Spacer()
            
            Button(action: {
                if let tileSet = document.core.project.currentTileSet {
                    tileSet.currentTile = nil
                    document.core.tileSetChanged.send(tileSet)
                }
            })
            {
                Text("Tile Set")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(4)
        .frame(minHeight: 30)
    }
}

/// NodeSettingsView on the bottom right
struct NodeSettingsView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    @State var currentNode                  : TileNode? = nil
    
    var body: some View {
        VStack {
            //if let currentTile = document.core.project.currentTileSet?.currentTile {
                
                //Text(currentTile.name)
                //Divider()
                
                if let currentNode = currentNode {
                
                    List() {
                        ForEach(currentNode.options, id: \.id) { option in
                            if option.type == .Float {
                                ParamFloatView(document.core, option)
                            }
                        }
                    }
                }
                
                Spacer()
            //}
        }
        .frame(maxWidth: 200)
        
        .onReceive(self.document.core.tileNodeChanged) { tileNode in
            currentNode = nil
            currentNode = tileNode
        }
    }
}

struct ParamFloatView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var value                        : Double = 0
    @State var valueText                    : String = ""

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        _value = State(initialValue: Double(option.node.readFloat(option.name)))
        _valueText = State(initialValue: String(format: "%.02f", option.node.readFloat(option.name)))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            /*
            TextField(option.name, text: $valueText, onEditingChanged: { (changed) in
                //option.raw = valueText
            },
            onCommit: {
                //core.scriptProcessor.replaceOptionInLine(option, useRaw: true)
                if let floatValue = Float(valueText) {
                    option.node.writeFloat(option.name, value: floatValue)
                    core.renderer.render()
                }
            } )
            */
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    value = v
                    valueText = String(format: "%.02f", v)

                    option.node.writeFloat(option.name, value: Float(v / 2.0))
                    core.renderer.render()
                    
                }), in: 0...1)//, step: Double(parameter.step))
                Text(valueText)
                    .frame(maxWidth: 40)
            }
        }
    }
}
