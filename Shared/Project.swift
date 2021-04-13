//
//  Project.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import Foundation

class Project           : Codable
{
    var screens         : [Screen] = []
    var tileSets        : [TileSet] = []

    var currentLayer    : Layer? = nil
    var currentTileSet  : TileSet? = nil
    
    init()
    {
        
    }
    
    private enum CodingKeys: String, CodingKey {
        case screens
        case tileSets
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screens = try container.decode([Screen].self, forKey: .screens)
        tileSets = try container.decode([TileSet].self, forKey: .tileSets)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screens, forKey: .screens)
        try container.encode(tileSets, forKey: .tileSets)
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

class Layer         : Codable, Equatable
{
    var layers      : [Layer] = []
    var id          = UUID()
    var name        = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
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
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
    
    static func ==(lhs:Layer, rhs:Layer) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class TileSet      : Codable, Equatable
{
    var tiles      : [Tile] = []
    
    var currentTile: Tile? = nil

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
