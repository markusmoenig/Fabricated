//
//  Modifier.swift
//  Fabricated
//
//  Created by Markus Moenig on 17/4/21.
//

import Foundation

class ModifierNoise : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Modifier, "Noise")
    }
    
    override func setup()
    {
        type = "ModifierNoise"
        optionGroups.append(TileNodeOptionsGroup("Noise Modifier Options", [
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Pixel", "Value"], defaultFloat: 1),
            TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Screen"], defaultFloat: 0),
            TileNodeOption(self, "Seed", .Int, defaultFloat: 1),
            TileNodeOption(self, "Scale", .Float, defaultFloat: 0.5),
            TileNodeOption(self, "Sub Divisions", .Int, defaultFloat: 0)
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
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext) -> Float
    {
        let seed : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Seed")
        let uvType : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "UV")
        let scale : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Scale")
        let subDivisions : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Sub Divisions") + 2

        var uv = uvType == 0 ? getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.uv) : getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.texUV)
        //var uv = uvType == 0 ? pixelCtx.uv : pixelCtx.texUV
        uv += 0.5
        let n = noise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * (scale / 2.0)
        return n
    }
}
