//
//  Project.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import MetalKit

class Project           : MMValues, Codable
{
    var screens         : [Screen] = []
    var tileSets        : [TileSet] = []

    var currentLayer    : Layer? = nil
    var currentTileSet  : TileSet? = nil
    
    var projectSettings : Bool = false

    // For preview of selection in progress
    var selectedRect    : SIMD4<Int>? = nil
    
    var debug1          : Float = 2
    var debug2          : Float = 4

    override init()
    {
        super.init()
        writeFloat("tileSize", value: 64)
        writeFloat("pixelSize", value: 4)
        writeFloat("antiAliasing", value: 2)
    }
    
    private enum CodingKeys: String, CodingKey {
        case screens
        case tileSets
        case values
    }
    
    required init(from decoder: Decoder) throws
    {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screens = try container.decode([Screen].self, forKey: .screens)
        tileSets = try container.decode([TileSet].self, forKey: .tileSets)
        values = try container.decode([String:Float].self, forKey: .values)
        
        currentLayer = screens[0].layers[0]
        currentTileSet = tileSets[0]
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screens, forKey: .screens)
        try container.encode(tileSets, forKey: .tileSets)
        try container.encode(values, forKey: .values)
    }
    
    /// Returns the screen which contains the layer identified by its id
    func getScreenForLayer(_ id: UUID) -> Screen? {
        for screen in screens {
            for layer in screen.layers {
                if layer.id == id {
                    return screen
                }
            }
        }
        return nil
    }
    
    /// Returns the current screen
    func getCurrentScreen() -> Screen? {
        if let currentLayer = currentLayer {
            return getScreenForLayer(currentLayer.id)
        }
        return nil
    }
    
    /// Returns the TileSet identified by its id
    func getTileSet(_ id: UUID) -> TileSet? {
        for tileSet in tileSets {
            if tileSet.id == id {
                return tileSet
            }
        }
        return nil
    }
    
    /// Returns the Tile of a TileSet, both identified by their id
    func getTileOfTileSet(_ tileSetId: UUID, _ tileId: UUID) -> Tile? {
        if let tileSet = getTileSet(tileSetId) {
            for tile in tileSet.tiles {
                if tile.id == tileId {
                    return tile
                }
            }
        }
        return nil
    }
    
    
    /// Returns the tileset which contains the tile identified by its id
    func getTileSetForTile(_ id: UUID) -> TileSet? {
        for tileSet in tileSets {
            for tile in tileSet.tiles {
                if tile.id == id {
                    return tileSet
                }
            }
        }
        return nil
    }
    
    /// Sets the changed state of the current screen and all tilesets
    func setHasChanged(_ changed: Bool) {
        
        if let screen = getCurrentScreen() {
            for layer in screen.layers {
                for area in layer.tileAreas {
                    area.hasChanged = changed
                }
            }
        }
        
        for tileSet in tileSets {
            for tile in tileSet.tiles {
                for node in tile.nodes {
                    node.hasChanged = changed
                }
            }
        }
    }
    
    /// Get the tile size of the project
    func getTileSize() -> Float {
        return readFloat("tileSize", 64)
    }
    
    /// Get the pixel size of the project
    func getPixelSize() -> Float {
        return readFloat("pixelSize", 4)
    }
    
    /// Get the anti-aliasing of the project
    func getAntiAliasing() -> Float {
        return readFloat("antiAliasing", 2)
    }
}

class Screen        : Codable, Equatable
{    
    enum GridType : Int, Codable {
        case rectFront, rectIso
    }
    
    var gridType        : GridType = .rectFront
    
    var layers          : [Layer] = []
    var id              = UUID()
    var name            = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case gridType
        case layers
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gridType = try container.decode(GridType.self, forKey: .gridType)
        layers = try container.decode([Layer].self, forKey: .layers)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(gridType, forKey: .gridType)
        try container.encode(layers, forKey: .layers)
    }
    
    static func ==(lhs:Screen, rhs:Screen) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class Layer             : MMValues, Codable, Equatable
{
    var layers          : [Layer] = []
    var id              = UUID()
    var name            = ""
    
    var tileInstances   : [SIMD2<Int>: TileInstance] = [:]
    var tileAreas       : [TileInstanceArea] = []
    
    // The currently selected areas for this layer
    var selectedAreas   : [TileInstanceArea] = []
    
    // The layer renders into this texture
    var texture         : MTLTexture? = nil
    
    // The draw jobs for this layer during rendering (some gridTypes need sorted rendering)
    var drawJobs        : [DrawJob] = []

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tileInstances
        case values
        case tileAreas
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
        super.init()
    }
    
    required init(from decoder: Decoder) throws
    {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tileInstances = try container.decode([SIMD2<Int>: TileInstance].self, forKey: .tileInstances)
        values = try container.decode([String:Float].self, forKey: .values)
        tileAreas = try container.decode([TileInstanceArea].self, forKey: .tileAreas)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tileInstances, forKey: .tileInstances)
        try container.encode(values, forKey: .values)
        try container.encode(tileAreas, forKey: .tileAreas)
    }
    
    static func ==(lhs:Layer, rhs:Layer) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
    
    /// Returns the TileInstanceArea identified by its id
    func getTileArea(_ id: UUID) -> TileInstanceArea?
    {
        for area in tileAreas {
            if area.id == id {
                return area
            }
        }
        
        return nil
    }
}

class TileSet      : Codable, Equatable
{
    var tiles      : [Tile] = []
    
    var currentTile: Tile? = nil
    var openTile   : Tile? = nil

    var id          = UUID()
    var name        = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tiles
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tiles = try container.decode([Tile].self, forKey: .tiles)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tiles, forKey: .tiles)
    }
    
    static func ==(lhs:TileSet, rhs:TileSet) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class Tile               : Codable, Equatable
{
    enum TileRole {
        case Fill
    }
    
    /// Which iso cube we use in iso grid mode
    enum TileIsoType    : Int, Codable {
        case Cube
    }
    
    var nodes           : [TileNode] = [TiledNode()]

    var isoNodesTop     : [TileNode] = [TiledNode()]
    var isoNodesLeft    : [TileNode] = [TiledNode()]
    var isoNodesRight   : [TileNode] = [TiledNode()]
    
    /// Holds all options for iso rendering modes
    var isoCubeNode     = IsoCubeNode()

    var id              = UUID()
    var name            = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nodes
        case isoNodesTop
        case isoNodesLeft
        case isoNodesRight
        case isoCubeNode
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([TileNode].self, ofFamily: NodeFamily.self, forKey: .nodes)
        isoNodesTop = try container.decode([TileNode].self, ofFamily: NodeFamily.self, forKey: .isoNodesTop)
        isoNodesLeft = try container.decode([TileNode].self, ofFamily: NodeFamily.self, forKey: .isoNodesLeft)
        isoNodesRight = try container.decode([TileNode].self, ofFamily: NodeFamily.self, forKey: .isoNodesRight)
        isoCubeNode = try container.decode(IsoCubeNode.self, forKey: .isoCubeNode)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(isoNodesTop, forKey: .isoNodesTop)
        try container.encode(isoNodesLeft, forKey: .isoNodesLeft)
        try container.encode(isoNodesRight, forKey: .isoNodesRight)
        try container.encode(isoCubeNode, forKey: .isoCubeNode)
    }
    
    static func ==(lhs:Tile, rhs:Tile) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
    
    /// Returns a node by its id
    func getNodeById(_ id: UUID) -> TileNode?
    {
        for node in nodes {
            if node.id == id {
                return node
            }
        }
        for node in isoNodesTop {
            if node.id == id {
                return node
            }
        }
        for node in isoNodesLeft {
            if node.id == id {
                return node
            }
        }
        for node in isoNodesRight {
            if node.id == id {
                return node
            }
        }
        return nil
    }
    
    /// Returns the next nodes of the given role in the chain
    func getNextInChain(_ node: TileNode,_ role: TileNode.TileNodeRole) -> TileNode?
    {
        let ids = node.getChainedNodeIdsForRole(role)
        var rc : [TileNode] = []
        for id in ids {
            if let node = getNodeById(id) {
                rc.append(node)
            }
        }
        if rc.count < 2 {
            return rc.first
        } else {
            // TODO Multiple nodes, use the hash to identify
            
            let offset = node.hash * Float(rc.count)
            
            return rc[Int(offset)]
        }
    }
    
    /// Returns true if one of the nodes in the tile has been changed
    func hasChanged() -> Bool {
        for node in nodes {
            if node.hasChanged {
                return true
            }
        }
        return false
    }
    
    /// Sets the changed state of the current screen and all tilesets
    func setHasChanged(_ changed: Bool = true) {
        for node in nodes {
            node.hasChanged = true
        }
    }
}

class TileInstanceArea : MMValues, Codable, Equatable
{
    var id          = UUID()

    var tileSetId   : UUID
    var tileId      : UUID
    
    var area        : SIMD4<Int>
    
    private enum CodingKeys: String, CodingKey {
        case id
        case tileSetId
        case tileId
        case area
        case values
    }
    
    init(_ tileSetId: UUID,_ tileId: UUID,_ area: SIMD4<Int> = SIMD4<Int>(0,0,0,0))
    {
        self.tileSetId = tileSetId
        self.tileId = tileId
        self.area = area
        super.init()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tileSetId = try container.decode(UUID.self, forKey: .tileSetId)
        tileId = try container.decode(UUID.self, forKey: .tileId)
        area = try container.decode(SIMD4<Int>.self, forKey: .area)
        super.init()
        values = try container.decode([String:Float].self, forKey: .values)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tileSetId, forKey: .tileSetId)
        try container.encode(tileId, forKey: .tileId)
        try container.encode(area, forKey: .area)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:TileInstanceArea, rhs:TileInstanceArea) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class TileInstance : MMValues, Codable, Equatable
{
    var id          = UUID()

    var tileSetId   : UUID
    var tileId      : UUID
    
    var tileAreas   : [UUID] = []
    
    var tileData    : [SIMD4<Float>]? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case tileSetId
        case tileId
        case values
        case tileAreas
    }
    
    init(_ tileSetId: UUID,_ tileId: UUID)
    {
        self.tileSetId = tileSetId
        self.tileId = tileId
        super.init()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tileSetId = try container.decode(UUID.self, forKey: .tileSetId)
        tileId = try container.decode(UUID.self, forKey: .tileId)
        super.init()
        values = try container.decode([String:Float].self, forKey: .values)
        tileAreas = try container.decode([UUID].self, forKey: .tileAreas)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tileSetId, forKey: .tileSetId)
        try container.encode(tileId, forKey: .tileId)
        try container.encode(values, forKey: .values)
        try container.encode(tileAreas, forKey: .tileAreas)
    }
    
    static func ==(lhs:TileInstance, rhs:TileInstance) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
