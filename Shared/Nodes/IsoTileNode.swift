//
//  IsoTileNode.swift
//  Fabricated
//
//  Created by Markus Moenig on 28/5/21.
//

import Foundation

final class IsoTiledNode : TileNode {
    
    enum IsoFace : Int {
        case Top, Left, Right
    }

    var isoFace : IsoFace = .Top
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.IsoTile, "Iso Tile")
    }
    
    override func setup()
    {
        type = "IsoTiledNode"
        
        optionGroups.append(TileNodeOptionsGroup("Iso Shape Options", [
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Cube"], defaultFloat: 0),
            TileNodeOption(self, "Orientation", .Menu, menuEntries: ["Normal", "Back"], defaultFloat: 0),
            TileNodeOption(self, "Size", .Float, range: float2(0, 1), defaultFloat: 1),
            TileNodeOption(self, "Height", .Float, range: float2(0, 1), defaultFloat: 1),
            TileNodeOption(self, "Offset", .Float, range: float2(-1, 1), defaultFloat: 0),
        ]))
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
}

