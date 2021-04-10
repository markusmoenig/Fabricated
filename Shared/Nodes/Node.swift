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
    var name                = ""
    
    var type                = ""
    
    var role                : TileNodeRole = .Invalid

    private enum CodingKeys: String, CodingKey {
        case id
        case name
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
        setup()
    }
    
    func setup()
    {
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
    }
    
    func render(ctx: TilePixelContext, prevColor: float4) -> float4
    {
        return float4()
    }
    
    static func ==(lhs:TileNode, rhs:TileNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
