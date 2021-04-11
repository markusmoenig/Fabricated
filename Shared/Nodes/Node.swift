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
        case Invalid, Pattern, Shape
    }
    
    var id                  = UUID()
    var name                = "" // User defined
    
    var type                = "" // To identify the node when loading via JSON
    
    var role                : TileNodeRole = .Invalid
    
    var nodeRect            = MMRect()
    
    var options             : [TileNodeOption] = []

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
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(values, forKey: .values)
    }
    
    func render(ctx: TilePixelContext, prevColor: float4) -> float4
    {
        return float4()
    }
        
    static func ==(lhs:TileNode, rhs:TileNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
