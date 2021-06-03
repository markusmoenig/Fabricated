//
//  Views.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import SwiftUI
import MarkdownUI

/// ProjectView on the left
struct ProjectView: View {
    @State      var document                    : FabricatedDocument
    @Binding    var updateView                  : Bool
    
    @State      var currentLayer                : Layer? = nil
    @State      var currentTileSet              : TileSet? = nil
    
    @State      var debugText1                  : String = "2.12"
    @State      var debugText2                  : String = "3.71"

    @State var tileImage                        : CGImage? = nil

    @State private var showRenameLayerPopover   : Bool = false
    @State private var layerName                : String = ""
    @State private var contextLayer             : Layer? = nil

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
                                if document.core.renderer.renderMode == .Layer {
                                    document.core.renderer.render()
                                }
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
                                                        document.core.project.currentLayer = layer
                                                        document.core.layerChanged.send(layer)
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
                                                        document.core.project.currentLayer = layer
                                                        document.core.layerChanged.send(layer)
                                                    }
                                                }
                                            }
                                        })
                                    }
                                    
                                    
                                    Divider()

                                    Button("Rename ...", action: {
                                        layerName = layer.name
                                        contextLayer = layer
                                        showRenameLayerPopover = true
                                    })
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
                
                HStack {
                    Menu {
                        Button("Default", action: {

                        })
                    }
                    
                    label: {
                        Text("Default")
                    }
                }
            
                
                PaletteView(core: document.core, updateView: $updateView)
            }
            
            .popover(isPresented: $showRenameLayerPopover,
                     arrowEdge: .top
            ) {
                VStack(alignment: .leading) {
                    Text("Layer Name:")
                    TextField("Name", text: $layerName, onEditingChanged: { (changed) in
                        if let currentLayer = contextLayer {
                            currentLayer.name = layerName
                            updateView.toggle()
                        }
                    })
                    .frame(minWidth: 200)
                }.padding()
            }

            /*
            TextField("Debug1", text: $debugText1, onEditingChanged: { (changed) in
                document.core.project.debug1 = Float(debugText1)!
                document.core.renderer.render()
            })
            
            TextField("Debug2", text: $debugText2, onEditingChanged: { (changed) in
                document.core.project.debug2 = Float(debugText2)!
                document.core.renderer.render()
            })*/
            
            //.listStyle(InsetGroupedListStyle()) // ENABLE_IOS
            
            .onAppear(perform: {
                currentLayer = document.core.project.currentLayer
                currentTileSet = document.core.project.currentTileSet
            })
            
            .onReceive(document.core.tileSetChanged) { tileNode in
                tileImage = nil
                if let tile = document.core.project.currentTileSet?.openTile {
                    tileImage = getTileImage(tile)
                }
            }
            
            Spacer()
            
            if let image = tileImage {
                #if os(macOS)
                Divider()
                #endif
                Image(image, scale: 1.0, label: Text(""))
                    .padding(.bottom, 10)
            }
        }
    }
    
    func getTileImage(_ tile: Tile) -> CGImage? {
        let gridType = document.core.project.getCurrentScreen()?.gridType

        if gridType == .rectFront {
            if let tiled = tile.nodes[0] as? TiledNode {
                return tiled.cgiImage
            }
        } else
        if gridType == .rectIso {
            if let tiled = tile.isoNodes[0] as? IsoTiledNode {
                return tiled.cgiImage
            }
        }
        
        return nil
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
                document.core.screenView.update()
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
                document.core.currentTool = .Move
                document.core.screenView.update()
                updateView.toggle()
            })
            {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(document.core.currentTool == .Move ? Color.primary : Color.secondary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: 22, maxWidth: 22, minHeight: 22, maxHeight: 22)
                        .foregroundColor(document.core.currentTool == .Move ? Color.primary : Color.secondary)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 0)
            
            Button(action: {
                document.core.currentTool = .Resize
                document.core.screenView.update()
                updateView.toggle()
            })
            {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(document.core.currentTool == .Resize ? Color.primary : Color.secondary, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "selection.pin.in.out")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(minWidth: 22, maxWidth: 22, minHeight: 22, maxHeight: 22)
                        .foregroundColor(document.core.currentTool == .Resize ? Color.primary : Color.secondary)
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

/// ToolsView3
struct ToolsView3: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    @State var scaleValue                   : Double = 1.0
    @State var scaleText                    : String = "1.00"

    var body: some View {
        HStack {
            Slider(value: Binding<Double>(get: {scaleValue}, set: { v in
                scaleText = String(format: "%.02f", v)
                scaleValue = v
                document.core.screenView.graphZoom = Float(scaleValue)
                document.core.screenView.update()
            }), in: 0.20...2.0)
            Button(scaleText, action: {
                scaleValue = 1.0
                scaleText = String(format: "%.02f", scaleValue)
                document.core.screenView.graphZoom = Float(scaleValue)
                document.core.screenView.update()
            })
            .frame(maxWidth: 30)
            .buttonStyle(BorderlessButtonStyle())
        }
        .frame(minHeight: 30)
        .frame(maxWidth: 120)
        
        .onReceive(self.document.core.updateTools) { _ in
            scaleValue = Double(document.core.screenView.graphZoom)
            scaleText = String(format: "%.02f", scaleValue)
        }
    }
}

/// NodeToolbar
struct NodeToolbar: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool
    
    @State var contextMenuText              : String = "Context: Tile"

    var body: some View {
        HStack {
            Button(action: {
                if let tileSet = document.core.project.currentTileSet {
                    tileSet.openTile = nil
                    document.core.tileSetChanged.send(tileSet)
                }
            })
            {
                //Label("Tile Set", systemImage: "arrowshape.turn.up.backward")
                Image(systemName: "arrowshape.turn.up.backward")
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 10)
            
            Menu {
                Menu {
                    Button("Box", action: {
                        addNodeToTile(ShapeBox())
                    })
                    Button("Disk", action: {
                        addNodeToTile(ShapeDisk())
                    })
                    Button("Ground", action: {
                        addNodeToTile(ShapeGround())
                    })
                }
                label: {
                    Text("Shapes")
                        .foregroundColor(Color(.sRGB, red: 0.325, green: 0.576, blue: 0.761, opacity: 1))
                }
                Menu {
                    Button("Noise", action: {
                        addNodeToTile(ModifierNoise())
                    })
                    Button("Tiled Noise", action: {
                        addNodeToTile(ModifierTiledNoise())
                    })
                }
                label: {
                    Text("Modifiers")
                        .foregroundColor(Color(.sRGB, red: 0.631, green: 0.278, blue: 0.506, opacity: 1))
                }
                Menu {
                    Button("Color", action: {
                        addNodeToTile(DecoratorColor())
                    })
                    Button("Gradient", action: {
                        addNodeToTile(DecoratorGradient())
                    })
                }
                label: {
                    Text("Decorators")
                        .foregroundColor(Color(.sRGB, red: 0.765, green: 0.600, blue: 0.365, opacity: 1))
                }
                Menu {
                    Button("Tiles & Bricks", action: {
                        addNodeToTile(DecoratorTilesAndBricks())
                    })
                }
                label: {
                    Text("Patterns")
                        .foregroundColor(Color(.sRGB, red: 0.275, green: 0.439, blue: 0.353, opacity: 1))
                }
            }
            label: {
                Text("Add Node")
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
                        var nodes = document.core.nodeView.getNodes(tile)
                        if let index = nodes.firstIndex(of: node) {
                            nodes.remove(at: index)
                            document.core.nodeView.setNodes(tile, nodes)
                            tile.setHasChanged(true)
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
            
            Menu {
                Button("Context: Tile", action: {
                    contextMenuText = "Context: Tile"
                    document.core.currentContext = .Tile
                    document.core.screenView.update()
                })
                Button("Context: Area", action: {
                    contextMenuText = "Context: Area"
                    document.core.currentContext = .Area
                    document.core.screenView.update()
                })
            }
            label: {
                Text(contextMenuText)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: 100)
            
            Spacer()
        }
        .padding(4)
        .frame(minHeight: 30)
    }
    
    func addNodeToTile(_ node: TileNode) {
        if let tile = document.core.project.currentTileSet?.openTile {
            var nodes = document.core.nodeView.getNodes(tile)
            nodes.append(node)
            document.core.nodeView.setNodes(tile, nodes)
            document.core.nodeView.setCurrentNode(nodes.last!)
            document.core.nodeView.update()
        }
    }
}

/// NodeSettingsView on the bottom right
struct NodeSettingsView: View {
    @State var document                     : FabricatedDocument
    @Binding var updateView                 : Bool

    @State var currentNode                  : TileNode? = nil
    
    /*
    @State var helpText                     : Document = Document(    #"""
        This is a local image:

        ![Dog](ref.jpeg)
        """#)*/
    
    var body: some View {
        VStack {
            if let currentNode = currentNode {
                
                //Markdown(helpText)
                //.markdownBaseURL(Bundle.main.resourceURL)
                
                List() {
                    ForEach(currentNode.optionGroups, id: \.id) { group in
                        Section(header:
                                    HStack {
                                        //Image("viewfinder")
                                        Text(group.name)
                                    } ) {
                            ForEach(group.options, id: \.id) { option in
                                //if self.testExclusion(currentNode, option) == false {
                                    if option.type == .Int {
                                        ParamIntView(document.core, option)
                                            .disabled(self.testExclusion(currentNode, option))
                                    } else
                                    if option.type == .Float {
                                        ParamFloatView(document.core, option)
                                            .disabled(self.testExclusion(currentNode, option))
                                    } else
                                    if option.type == .Switch {
                                        ParamSwitchView(document.core, option)
                                            .disabled(self.testExclusion(currentNode, option))
                                    } else
                                    if option.type == .Color {
                                        ParamColorView(document.core, option)
                                            .disabled(self.testExclusion(currentNode, option))
                                    } else
                                    if option.type == .Menu {
                                        ParamMenuView(document.core, option)
                                            .disabled(self.testExclusion(currentNode, option))
                                    }
                                }
                            //}
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
    
    func testExclusion(_ node: TileNode,_ option: TileNodeOption) -> Bool
    {
        if let exclusion = option.exclusion {
            let value = node.readOptionalFloatInstanceArea(document.core, node, exclusion.name)
            if value == exclusion.value {
                return true
            }
        }
        
        return false
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
        
        _value = State(initialValue: Double(option.node.readOptionalFloatInstanceArea(core, option.node, option.name)))
        _valueText = State(initialValue: String(format: "%.02f", option.node.readOptionalFloatInstanceArea(core, option.node, option.name)))
        
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
                    updateValue(v)
                }), in: rangeX...rangeY)//, step: Double(parameter.step))
                Button(valueText, action: {
                    updateValue(Double(option.defaultFloat))
                })
                .frame(maxWidth: 50)
                .buttonStyle(BorderlessButtonStyle())
                /*
                Text(valueText)
                    .frame(maxWidth: 30)
                */
            }
        }
    }
    
    func updateValue(_ v: Double) {
        if let tile = core.project.currentTileSet?.openTile {
            core.startTileUndo(tile, "Node Option Changed")
        }
        
        value = v
        valueText = String(format: "%.02f", v)

        option.node.writeOptionalFloatInstanceArea(core, option.node, option.name, value: Float(v))
        core.renderer.render()
        if let tile = core.project.currentTileSet?.openTile {
            core.updateTilePreviews(tile)
        }
        
        core.currentTileUndo?.end()
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
        
        _value = State(initialValue: Double(option.node.readOptionalFloatInstanceArea(core, option.node, option.name)))
        _valueText = State(initialValue: String(Int(option.node.readOptionalFloatInstanceArea(core, option.node, option.name))))
        
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

                    option.node.writeOptionalFloatInstanceArea(core, option.node, option.name, value: Float(v))
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
        
        let value = option.node.readOptionalFloatInstanceArea(core, option.node, option.name)
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
            
            option.node.writeOptionalFloatInstanceArea(core, option.node, option.name, value: value == false ? 0 : 1)
            core.renderer.render()
            if let tile = core.project.currentTileSet?.openTile {
                core.updateTilePreviews(tile)
            }
            core.currentTileUndo?.end()
            
            if option.exclusionTrigger == true {
                core.tileNodeChanged.send(option.node)
            }
        }
    }
}

struct ParamColorView: View {
    
    let core                                : Core
    let option                              : TileNodeOption
    
    @State var updateView                   : Bool = false
    
    @State var colorValue                   : Color
    @State var showPopover                  : Bool = false

    init(_ core: Core, _ option: TileNodeOption)
    {
        self.core = core
        self.option = option
        
        if let tileSet = core.project.currentTileSet {
            let palette = tileSet.getPalette()
            let index = Int(option.node.readOptionalFloatInstanceArea(core, option.node, option.name, 0))
                    
            _colorValue = State(initialValue: palette.getColorAtIndex(index).toColor())
        } else {
            _colorValue = State(initialValue: Color.gray)
        }
    }
    
    var body: some View {
        
        HStack(alignment: .center) {
            Text(option.name)
            Spacer()
            Button(action: {
                showPopover = true
            })
            {
                Rectangle()
                    .fill(colorValue)
                    .frame(width: 25, height: 15)
                    .onTapGesture(perform: {
                        
                    })
            }
            // Edit Node name
            .popover(isPresented: $showPopover,
                     arrowEdge: .top
            ) {
                VStack {
                    PaletteView(core: core, updateView: $updateView, option: option)
                        .padding()
                } .frame(width: 220, height: 150)

            }.padding()
            
            .onReceive(core.colorChanged) { _ in
                colorValue = getColor()
            }
        }
    }
    
    /// Gets the current color for the option
    func getColor() -> Color {
        if let tileSet = core.project.currentTileSet {
            let palette = tileSet.getPalette()
            let index = Int(option.node.readOptionalFloatInstanceArea(core, option.node, option.name, 0))
                    
            return palette.getColorAtIndex(index).toColor()
        } else {
            return Color.gray
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
        
        _menuIndex = State(initialValue: Int(option.node.readOptionalFloatInstanceArea(core, option.node, option.name)))
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
                        option.node.writeOptionalFloatInstanceArea(core, option.node, option.name, value: Float(index))
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

