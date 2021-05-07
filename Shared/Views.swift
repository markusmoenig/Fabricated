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
    
    @State      var currentLayer                : Layer? = nil
    @State      var currentTileSet              : TileSet? = nil
    
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
                                currentLayer = layer
                                document.core.project.currentLayer = layer
                                document.core.layerChanged.send(layer)
                                document.core.renderer.render()
                            })
                            {
                                Label(layer.name, systemImage: "rectangle.split.3x3")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .foregroundColor(layer === currentLayer ? Color.accentColor : Color.primary)
                            }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Menu("Add Layer") {
                                        Button("Before", action: {
                                            let layer = Layer("New Layer")
                                            if let currentLayer = currentLayer {
                                                if let screen = document.core.project.getScreenForLayer(currentLayer.id) {
                                                    if let index = screen.layers.firstIndex(of: currentLayer) {
                                                        screen.layers.insert(layer, at: index)
                                                        self.currentLayer = layer
                                                        document.core.layerChanged.send(layer)
                                                        document.core.renderer.render()
                                                    }
                                                }
                                            }
                                        })
                                        Button("After", action: {
                                            let layer = Layer("New Layer")
                                            if let currentLayer = currentLayer {
                                                if let screen = document.core.project.getScreenForLayer(currentLayer.id) {
                                                    if let index = screen.layers.firstIndex(of: currentLayer) {
                                                        screen.layers.insert(layer, at: index+1)
                                                        self.currentLayer = layer
                                                        document.core.layerChanged.send(layer)
                                                        document.core.renderer.render()
                                                    }
                                                }
                                            }
                                        })
                                    }
                                }
                        }
                    }
                }
                
                Section(header: Text("Tile Sets")) {
                    ForEach(document.core.project.tileSets, id: \.id) { tileSet in
                        Button(action: {
                            currentTileSet = tileSet
                            document.core.project.currentTileSet = tileSet
                            tileSet.openTile = nil
                            document.core.tileSetChanged.send(tileSet)
                            document.core.updateTileSetPreviews(tileSet)
                        })
                        {
                            Label(tileSet.name, systemImage: "rectangle.grid.2x2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .foregroundColor(tileSet === currentTileSet ? Color.accentColor : Color.primary)
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
            }
            
            //.listStyle(InsetGroupedListStyle()) // ENABLE_IOS
            
            .onAppear(perform: {
                currentLayer = document.core.project.currentLayer
                currentTileSet = document.core.project.currentTileSet
            })
        }
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

/// ToolsView2
struct ToolsView2: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    @State var text                         : String = "Render: Screen"

    var body: some View {
        HStack {
            Menu {
                Button("Render: Screen", action: {
                    text = "Render: Screen"
                    document.core.renderer.renderMode = .Screen
                    document.core.renderer.render()
                })
                Button("Render: Layer", action: {
                    text = "Render: Layer"
                    document.core.renderer.renderMode = .Layer
                    document.core.renderer.render()
                })
            }
            label: {
                Text(text)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: 120)
                    
        }
        .frame(minHeight: 30)
    }
}

/// NodeToolbar
struct NodeToolbar: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    var body: some View {
        HStack {
            Menu {
                Menu {
                    Button("Box", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeBox())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                    Button("Disk", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeDisk())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                    Button("Ground", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ShapeGround())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                }
                label: {
                    Text("Shapes")
                        .foregroundColor(Color(.sRGB, red: 0.325, green: 0.576, blue: 0.761, opacity: 1))
                }
                Menu {
                    Button("Noise", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(ModifierNoise())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                }
                label: {
                    Text("Modifiers")
                        .foregroundColor(Color(.sRGB, red: 0.631, green: 0.278, blue: 0.506, opacity: 1))
                }
                Menu {
                    Button("Color", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(DecoratorColor())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                    Button("TilesAndBricks", action: {
                        if let tile = document.core.project.currentTileSet?.openTile {
                            tile.nodes.append(DecoratorTilesAndBricks())
                            document.core.nodeView.setCurrentNode(tile.nodes.last!)
                            document.core.nodeView.update()
                        }
                    })
                }
                label: {
                    Text("Decorators")
                        .foregroundColor(Color(.sRGB, red: 0.765, green: 0.600, blue: 0.365, opacity: 1))
                }
            }
            label: {
                Label("Add Node", systemImage: "plus")
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: 120)
                        
            Button(action: {
                if let node = document.core.nodeView.currentNode, node.role != .Tile {
                    
                    if let tile = document.core.project.currentTileSet?.openTile {
                        document.core.startTileUndo(tile, "Node Deleted")
                    }
                    
                    document.core.nodeView.nodeIsAboutToBeDeleted(node)
                    
                    if let tile = document.core.project.currentTileSet?.openTile {
                        if let index = tile.nodes.firstIndex(of: node) {
                            tile.nodes.remove(at: index)
                        }
                    }
                    
                    document.core.nodeView.update()
                    document.core.renderer.render()
                    document.core.updateTilePreviews()
                    
                    document.core.currentTileUndo?.end()
                }
            })
            {
                Text("Remove")
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading, 10)
            //.disabled(document.core.nodeView.currentNode?.role != .Tile)
            
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
            if let currentNode = currentNode {
                List() {
                    ForEach(currentNode.optionGroups, id: \.id) { group in
                        Section(header:
                                    HStack {
                                        //Image("viewfinder")
                                        Text(group.name)
                                    } ) {
                            ForEach(group.options, id: \.id) { option in
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
                }
            }
            
            Spacer()
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
    
    @State var rangeX                       : Double = 0
    @State var rangeY                       : Double = 1

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        _value = State(initialValue: Double(option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name)))
        _valueText = State(initialValue: String(format: "%.02f", option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name)))
        
        _rangeX = State(initialValue: Double(option.range.x))
        _rangeY = State(initialValue: Double(option.range.y))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                Text(option.name)
                /*
                Spacer()
                Button(action: {
                })
                {
                    Image(systemName: "questionmark")
                }
                .buttonStyle(PlainButtonStyle())*/
            }
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    
                    if let tile = core.project.currentTileSet?.openTile {
                        core.startTileUndo(tile, "Node Option Changed")
                    }
                    
                    value = v
                    valueText = String(format: "%.02f", v)

                    option.node.writeOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name, value: Float(v))
                    core.renderer.render()
                    if let tile = core.project.currentTileSet?.openTile {
                        core.updateTilePreviews(tile)
                    }
                    
                    core.currentTileUndo?.end()
                    
                }), in: rangeX...rangeY)//, step: Double(parameter.step))
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
    
    @State var rangeX                       : Double = 0
    @State var rangeY                       : Double = 1

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        _value = State(initialValue: Double(option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name)))
        _valueText = State(initialValue: String(Int(option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name))))
        
        _rangeX = State(initialValue: Double(option.range.x))
        _rangeY = State(initialValue: Double(option.range.y))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    
                    if let tile = core.project.currentTileSet?.openTile {
                        core.startTileUndo(tile, "Node Option Changed")
                    }
                    
                    value = v
                    valueText = String(Int(v))

                    option.node.writeOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name, value: Float(v))
                    core.renderer.render()
                    if let tile = core.project.currentTileSet?.openTile {
                        core.updateTilePreviews(tile)
                    }
                    
                    core.currentTileUndo?.end()
                }), in: rangeX...rangeY, step: 1)
                Text(valueText)
                    .frame(maxWidth: 20)
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
        
        let value = option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name)
        _toggleValue = State(initialValue: Bool(value == 0 ? false : true))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Toggle(isOn: $toggleValue) {
                Text(option.name)
            }
        }
        
        .onChange(of: toggleValue) { value in
            if let tile = core.project.currentTileSet?.openTile {
                core.startTileUndo(tile, "Node Option Changed")
            }
            
            option.node.writeOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name, value: value == false ? 0 : 1)
            core.renderer.render()
            if let tile = core.project.currentTileSet?.openTile {
                core.updateTilePreviews(tile)
            }
            core.currentTileUndo?.end()
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
        
        let value = option.node.readOptionalFloat4InstanceArea(core, core.nodeView.currentNode!, option.name)
        _colorValue = State(initialValue: Color(.sRGB, red: Double(value.x), green: Double(value.y), blue: Double(value.z), opacity: Double(value.w)))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            ColorPicker("", selection: $colorValue, supportsOpacity: true)
                .onChange(of: colorValue) { color in
                    
                    if let tile = core.project.currentTileSet?.openTile {
                        core.startTileUndo(tile, "Node Option Changed")
                    }
                    let newValue = float4(Float(color.cgColor!.components![0]), Float(color.cgColor!.components![1]), Float(color.cgColor!.components![2]), Float(color.cgColor!.components![3]))
                    
                    option.node.writeOptionalFloat4InstanceArea(core, core.nodeView.currentNode!, option.name, value: newValue)
                    core.renderer.render()
                    if let tile = core.project.currentTileSet?.openTile {
                        core.updateTilePreviews(tile)
                    }
                    core.currentTileUndo?.end()
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
        
        _menuIndex = State(initialValue: Int(option.node.readOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name)))
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Menu {
                ForEach(Array(option.menuEntries!.enumerated()), id: \.offset) { index, optionName in
                    Button(optionName, action: {
                        if let tile = core.project.currentTileSet?.openTile {
                            core.startTileUndo(tile, "Node Option Changed")
                        }
                        menuIndex = index
                        option.node.writeOptionalFloatInstanceArea(core, core.nodeView.currentNode!, option.name, value: Float(index))
                        core.renderer.render()
                        if let tile = core.project.currentTileSet?.openTile {
                            core.updateTilePreviews(tile)
                        }
                        core.currentTileUndo?.end()
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

