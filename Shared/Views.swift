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
                                document.core.project.currentLayer = layer
                                document.core.layerChanged.send(layer)
                                document.core.renderer.render()
                            })
                            {
                                Label(layer.name, systemImage: "camera")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .foregroundColor(layer === document.core.project.currentLayer ? Color.accentColor : Color.primary)
                            }
                                .buttonStyle(PlainButtonStyle())
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
                            tileSet.openTile = nil
                            document.core.tileSetChanged.send(tileSet)
                        })
                        {
                            Label(tileSet.name, systemImage: "camera")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .foregroundColor(tileSet === document.core.project.currentTileSet ? Color.accentColor : Color.primary)
                        }
                            .buttonStyle(PlainButtonStyle())
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
    
    @State var tileSizeText                 : String = "Tile Size: 64x64"
    
    @State var pixelationValue              : Double = 10
    @State var pixelationText               : String = "10"

    var body: some View {
        VStack(alignment: .leading) {
            if let currentLayer = document.core.project.currentLayer {
                Text("\(currentLayer.name) Settings")
                    .padding(2)
                Divider()
                
                Menu(tileSizeText) {
                    Button("16x16", action: {
                        currentLayer.writeFloat("tileSize", value: 16)
                        tileSizeText = getTileSizeText(currentLayer)
                        document.core.renderer.render()
                    })
                    Button("32x32", action: {
                        currentLayer.writeFloat("tileSize", value: 32)
                        tileSizeText = getTileSizeText(currentLayer)
                        document.core.renderer.render()
                    })
                    Button("64x64", action: {
                        currentLayer.writeFloat("tileSize", value: 64)
                        tileSizeText = getTileSizeText(currentLayer)
                        document.core.renderer.render()
                    })
                    Button("128x128", action: {
                        currentLayer.writeFloat("tileSize", value: 128)
                        tileSizeText = getTileSizeText(currentLayer)
                        document.core.renderer.render()
                    })
                }
                .padding(4)

                Text("Pixel Size")

                HStack {
                    Slider(value: Binding<Double>(get: {pixelationValue}, set: { v in
                        pixelationValue = v
                        pixelationText = String(format: "%.02f", v)

                        currentLayer.writeFloat("pixelSize", value: Float(pixelationValue))
                        document.core.renderer.render()
                    }), in: 1...64)//, step: Double(5))
                    Text(pixelationText)
                        .frame(maxWidth: 40)
                }
                .padding(4)
                
                Spacer()
                Divider()
            } else {
                ProjectSettingsView(document: document, updateView: $updateView)
            }
        }
        .frame(maxWidth: 200)
        
        .onAppear(perform: {
            if let currentLayer = document.core.project.currentLayer {
                tileSizeText = getTileSizeText(currentLayer)
            }
        })
    }
    
    func getTileSizeText(_ layer: Layer) -> String {
        let size = Int(layer.readFloat("tileSize"))
        return "Tile Size: \(size)x\(size)"
    }
}

/// ToolsView
struct ToolsView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        VStack(spacing: 2) {
            Button(action: {
                document.core.currentTool = .Select
                updateView.toggle()
            })
            {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(document.core.currentTool == .Select ? Color.primary : Color.secondary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "cursorarrow")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: 22, maxWidth: 22, minHeight: 22, maxHeight: 22)
                        .foregroundColor(document.core.currentTool == .Select ? Color.primary : Color.secondary)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Button(action: {
                document.core.currentTool = .Apply
                updateView.toggle()
            })
            {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(document.core.currentTool == .Apply ? Color.primary : Color.secondary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "cursorarrow.rays")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: 22, maxWidth: 22, minHeight: 22, maxHeight: 22)
                        .foregroundColor(document.core.currentTool == .Apply ? Color.primary : Color.secondary)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 0)

            Button(action: {
                document.core.currentTool = .Clear
                updateView.toggle()
            })
            {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(document.core.currentTool == .Clear ? Color.primary : Color.secondary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "delete.left")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: 22, maxWidth: 22, minHeight: 22, maxHeight: 22)
                        .foregroundColor(document.core.currentTool == .Clear ? Color.primary : Color.secondary)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 0)
        }
        .padding(4)
        
        //.frame(minHeight: 30)
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
                    Button("Half", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeHalf())
                            document.core.nodeView.update()
                        }
                    })
                    Button("Box", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeBox())
                            document.core.nodeView.update()
                        }
                    })
                    Button("Disk", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeDisk())
                            document.core.nodeView.update()
                        }
                    })
                }
                Menu("Modifiers") {
                    Button("Noise", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ModifierNoise())
                            document.core.nodeView.update()
                        }
                    })
                }
                Menu("Decorators") {
                    Button("Color", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(DecoratorColor())
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
                    tileSet.openTile = nil
                    document.core.tileSetChanged.send(tileSet)
                }
            })
            {
                Label("Tile Set", systemImage: "arrowshape.turn.up.backward")
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
                            if option.type == .Int {
                                ParamIntView(document.core, option)
                            } else
                            if option.type == .Float {
                                ParamFloatView(document.core, option)
                            } else
                            if option.type == .Switch {
                                ParamSwitchView(document.core, option)
                            } else
                            if option.type == .Color {
                                ParamColorView(document.core, option)
                            } else
                            if option.type == .Menu {
                                ParamMenuView(document.core, option)
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
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    value = v
                    valueText = String(format: "%.02f", v)

                    option.node.writeFloat(option.name, value: Float(v))
                    core.renderer.render()
                    
                }), in: 0...1)//, step: Double(parameter.step))
                Text(valueText)
                    .frame(maxWidth: 40)
            }
        }
    }
}

struct ParamIntView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var value                        : Double = 0
    @State var valueText                    : String = ""

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        _value = State(initialValue: Double(option.node.readFloat(option.name)))
        _valueText = State(initialValue: String(Int(option.node.readFloat(option.name))))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    value = v
                    valueText = String(Int(v))

                    option.node.writeFloat(option.name, value: Float(v))
                    core.renderer.render()
                }), in: 0...10, step: 1)
                Text(valueText)
                    .frame(maxWidth: 40)
            }
        }
    }
}

struct ParamSwitchView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var toggleValue                  : Bool = false

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        let value = option.node.readOptionalFloatInstance(core, option.name)
        _toggleValue = State(initialValue: Bool(value == 0 ? false : true))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Toggle(isOn: $toggleValue) {
                Text(option.name)
            }
        }
        
        .onChange(of: toggleValue) { value in
            option.node.writeOptionalFloatInstance(core, option.name, value: value == false ? 0 : 1)
            core.renderer.render()
        }
    }
}

struct ParamColorView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var colorValue                   : Color

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        let value = option.node.readOptionalFloat4Instance(core, option.name)
        _colorValue = State(initialValue: Color(.sRGB, red: Double(value.x), green: Double(value.y), blue: Double(value.z), opacity: Double(value.w)))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            ColorPicker("", selection: $colorValue, supportsOpacity: true)
                .onChange(of: colorValue) { color in
                    
                    let newValue = float4(Float(color.cgColor!.components![0]), Float(color.cgColor!.components![1]), Float(color.cgColor!.components![2]), Float(color.cgColor!.components![3]))
                    
                    option.node.writeOptionalFloat4Instance(core, option.name, value: newValue)
                    core.renderer.render()
                }
        }
    }
}

struct ParamMenuView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var menuIndex                    : Int

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        _menuIndex = State(initialValue: Int(option.node.readOptionalFloatInstance(core, option.name)))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Menu {
                ForEach(Array(option.menuEntries!.enumerated()), id: \.offset) { index, optionName in
                    Button(optionName, action: {
                        menuIndex = index
                        option.node.writeOptionalFloatInstance(core, option.name, value: Float(index))
                        core.renderer.render()
                    })
                }
            }
            
            label: {
                Text(createMenuText())
            }
        }
    }
    
    func createMenuText() -> String {
        return "\(option.name) : \(option.menuEntries![menuIndex])"
    }
}

