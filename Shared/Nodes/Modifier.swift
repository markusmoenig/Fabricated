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
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Value", "Gradient", "Perlin"], defaultFloat: 0),
            TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Area"], defaultFloat: 0),
            TileNodeOption(self, "Pixelise", .Switch, defaultFloat: 1),
            TileNodeOption(self, "Seed", .Int, range: float2(0, 20), defaultFloat: 1),
            TileNodeOption(self, "Scale", .Float, defaultFloat: 0.5),
            TileNodeOption(self, "Sub Divisions", .Int, range: float2(0, 12), defaultFloat: 0)
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
        let seed : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Seed")
        let uvType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "UV")
        let pixelize : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Pixelise")
        let scale : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Scale")
        let subDivisions : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Sub Divisions") + 2
        
        let uv : float2
        
        if pixelize == 1 {
            uv = uvType == 0 ? getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.uv) : getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.areaUV)
        } else {
            uv = uvType == 0 ? pixelCtx.uv : pixelCtx.areaUV
        }
            
        let noiseType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Noise")

        let n : Float
        if noiseType == 1 {
            n = gradientNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * (scale / 2.0)
        } else
        if noiseType == 2 {
                n = perlinNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * (scale / 2.0)
        } else {
            n = noise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * (scale / 2.0)
        }
        return n
    }
    
    // Only called for node preview
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        var value : Float = render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        value = (value + 1) / 2
        return float4(value, value, value, 1.0)
    }
}
