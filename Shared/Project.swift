//
//  Project.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import Foundation

class Project           : MMValues, Codable
{
    var screens         : [Screen] = []
    var tileSets        : [TileSet] = []

    var currentLayer    : Layer? = nil
    var currentTileSet  : TileSet? = nil
    
    var projectSettings : Bool = false

    var selectedRect    : SIMD4<Int>? = nil

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
    
    var layers      : [Layer] = []
    var id          = UUID()
    var name        = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
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
        layers = try container.decode([Layer].self, forKey: .layers)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
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
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tileInstances
        case values
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
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tileInstances, forKey: .tileInstances)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:Layer, rhs:Layer) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
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

class Tile         : Codable, Equatable
{
    enum TileRole {
        case Fill
    }
    
    var nodes      : [TileNode] = []

    var id          = UUID()
    var name        = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nodes
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([TileNode].self, ofFamily: NodeFamily.self, forKey: .nodes)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nodes, forKey: .nodes)
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
        return nil
    }
    
    /// Returns the next node of the given role in the chain
    func getNextInChain(_ node: TileNode,_ role: TileNode.TileNodeRole) -> TileNode?
    {
        if let id = node.getChainedNodeIdForRole(role) {
            return getNodeById(id)
        }
        
        return nil
    }
}

class TileInstance : MMValues, Codable, Equatable
{
    var id          = UUID()

    var tileSetId   : UUID
    var tileId      : UUID

    private enum CodingKeys: String, CodingKey {
        case id
        case tileSetId
        case tileId
        case values
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
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tileSetId, forKey: .tileSetId)
        try container.encode(tileId, forKey: .tileId)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:TileInstance, rhs:TileInstance) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
