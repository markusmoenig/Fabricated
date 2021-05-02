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
            TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Screen"], defaultFloat: 0),
            TileNodeOption(self, "Pixelise", .Switch, defaultFloat: 1),
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
        let pixelize : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Pixelise")
        let scale : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Scale")
        let subDivisions : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Sub Divisions") + 2
        
        let uv : float2
        
        if pixelize == 1 {
            uv = uvType == 0 ? getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.uv) : getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: tileCtx.tileId /* / float2(pixelCtx.texWidth / pixelCtx.width, pixelCtx.texHeight / pixelCtx.height)*/ + pixelCtx.texUV)
        } else {
            uv = uvType == 0 ? pixelCtx.uv : pixelCtx.texUV
        }
            
        let noiseType : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Noise")

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
