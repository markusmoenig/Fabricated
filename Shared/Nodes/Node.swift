//
//  Node.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import Foundation

class TileNode : Codable, Equatable, Identifiable {

    enum TileNodeRole : Int, Codable {
        case Invalid, Pattern, Shape
    }
    
    var id                  = UUID()
    var name                = "" // User defined
    
    var type                = "" // To identify the node when loading via JSON
    
    var role                : TileNodeRole = .Invalid
    
    var nodeRect            = MMRect()

    var values              : [String:Float] = ["nodePos_x": 0, "nodePos_y": 0]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case values
    }
    
    init(_ role: TileNodeRole,_ name: String = "Unnamed")
    {
        self.role = role
        self.name = name
        setup()
    }
    
    required init(from decoder: Decoder) throws
    {
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
    
    func readFloat(_ name: String) -> Float
    {
        var rc = Float(0)
        if let x = values[name] { rc = x }
        return rc
    }
    
    func writeFloat(_ name: String, value: Float)
    {
        values[name] = value
    }
    
    func readFloat2(_ name: String) -> float2
    {
        var rc = float2(0,0)
        if let x = values[name + "_x"] { rc.x = x }
        if let y = values[name + "_y"] { rc.y = y }
        return rc
    }
    
    func readFloat3(_ name: String) -> float3
    {
        var rc = float3(0,0,0)
        if let x = values[name + "_x"] { rc.x = x }
        if let y = values[name + "_y"] { rc.y = y }
        if let z = values[name + "_z"] { rc.z = z }
        return rc
    }
    
    func writeFloat3(_ name: String, value: float3)
    {
        values[name + "_x"] = value.x
        values[name + "_y"] = value.y
        values[name + "_z"] = value.z
    }
}
