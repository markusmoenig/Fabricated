//
//  Node.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import Foundation

class TileNodeOption
{
    enum OptionType {
        case Float
    }
    
    var id                  = UUID()

    var type                : OptionType = .Float
    var name                = ""
    
    let node                : TileNode
    
    init(_ node: TileNode,_ name: String,_ type: OptionType)
    {
        self.node = node
        self.name = name
        self.type = type
    }
}

class TileNode : MMValues, Codable, Equatable, Identifiable {

    enum TileNodeRole : Int, Codable {
        case Tile, Pattern, Shape
    }
    
    var id                  = UUID()
    var name                = "" // User defined
    
    var type                = "" // To identify the node when loading via JSON
    
    var role                : TileNodeRole = .Tile
    
    var nodeRect            = MMRect()
    
    var options             : [TileNodeOption] = []
    
    // --- The terminals, nodes can have multiple outputs but only one input
    var terminalsOut        : [Int: UUID] = [:]
    var terminalIn          : UUID? = nil

    // --- For terminal drawing
    var terminalsOutRect    = [MMRect(), MMRect(),MMRect(),MMRect()]
    var terminalInRect      = MMRect()
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case values
    }
    
    init(_ role: TileNodeRole,_ name: String = "Unnamed")
    {
        self.role = role
        self.name = name
        super.init()
        writeFloat2("nodePos", value: float2(0,0))
        setup()
    }
    
    required init(from decoder: Decoder) throws
    {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        values = try container.decode([String:Float].self, forKey: .values)
        setup()
    }
    
    func setup()
    {
        type = "TileNode"
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(values, forKey: .values)
    }
    
    /// Renders the node
    func render(ctx: TilePixelContext, prevColor: float4) -> float4
    {
        return float4()
    }
    
    /// Gets  the next optional id in the chain
    func getChainedNodeIdForRole(_ connectedRole: TileNodeRole) -> UUID?
    {
        if role == .Tile {
            if connectedRole == .Shape || connectedRole == .Pattern {
                if let id = terminalsOut[0] {
                    return id
                }
            }
        } else
        if role == .Shape {
            if connectedRole == .Shape || connectedRole == .Pattern {
                if let id = terminalsOut[2] {
                    return id
                }
            }
        }
        return nil
    }
        
    static func ==(lhs:TileNode, rhs:TileNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
