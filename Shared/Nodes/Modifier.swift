//
//  Modifier.swift
//  Fabricated
//
//  Created by Markus Moenig on 17/4/21.
//

import Foundation
import SwiftNoise

class ModifierNoise : TileNode {
    
    var swiftNoise  : SwiftNoise!
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Modifier, "Noise")
    }
    
    override func setup()
    {
        swiftNoise = SwiftNoise()
        type = "ModifierNoise"
        optionGroups.append(TileNodeOptionsGroup("Noise Modifier Options", [
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Value", "Gradient", "Perlin"], defaultFloat: 0),
            //TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Area"], defaultFloat: 0),
            TileNodeOption(self, "Pixelise", .Switch, defaultFloat: 1),
            TileNodeOption(self, "Domain Scale", .Float, range: float2(0.001, 20), defaultFloat: 1),
            TileNodeOption(self, "Result Scale", .Float, defaultFloat: 0.5),
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
    
    func noise(pos: float2) -> Float
    {
        // https://www.shadertoy.com/view/4dS3Wd
        func hash(_ p: float2) -> Float
        {
            var p3 = simd_fract(float3(p.x, p.y, p.x) * 0.13)
            p3 += simd_dot(p3, float3(p3.y, p3.z, p3.x) + 3.333)
            return simd_fract((p3.x + p3.y) * p3.z)
        }
        
        let i = floor(pos)
        let f = simd_fract(pos)

        let a : Float = hash(i)
        let b : Float = hash(i + float2(1.0, 0.0))
        let c : Float = hash(i + float2(0.0, 1.0))
        let d : Float = hash(i + float2(1.0, 1.0))

        let u : float2 = f * f * (3.0 - 2.0 * f)
        return simd_mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext) -> Float
    {
        //let uvType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "UV")
        let pixelize : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Pixelise")
        let domainScale : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Domain Scale")
        let resultScale : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Result Scale")
        
        var uv : float2
        
        
        if pixelize == 1 {
            uv = getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.originalUV)// + tileCtx.tileId
        } else {
            uv = pixelCtx.originalUV// + tileCtx.tileId
        }
        
        let tileAspectX : Float = 1 / 2
        let tileAspectY : Float = 1 / 4
        
        let center = tileCtx.tileId
        let centerX = (center.x / tileAspectX + center.y / tileAspectY) / 2.0
        let centerY = (center.y / tileAspectY - (center.x / tileAspectX)) / 2.0
                    
        uv += float2(round(centerX), round(centerY))
        
        let noiseType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Noise")

        let n : Float
        n = ((noise(pos: uv * domainScale) * 2) - 1) * resultScale
        /*
        if noiseType == 1 {
            n = swiftNoise.gradientNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
        } else
        if noiseType == 2 {
            n = swiftNoise.perlinNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
        } else {
            n = noise(pos: uv)//swiftNoise.noise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
        }*/
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


class ModifierTiledNoise : TileNode {
    
    var swiftNoise  : SwiftNoise!
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Modifier, "Tiled Noise")
    }
    
    override func setup()
    {
        swiftNoise = SwiftNoise()
        type = "ModifierTiledNoise"
        optionGroups.append(TileNodeOptionsGroup("Noise Modifier Options", [
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Value", "Gradient", "Perlin"], defaultFloat: 0),
            TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Area"], defaultFloat: 0),
            TileNodeOption(self, "Pixelise", .Switch, defaultFloat: 1),
            TileNodeOption(self, "Seed", .Int, range: float2(0, 20), defaultFloat: 1),
            TileNodeOption(self, "Result Scale", .Float, defaultFloat: 0.5),
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
        let seed : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Seed")
        let uvType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "UV")
        let pixelize : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Pixelise")
        let scale : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Result Scale")
        let subDivisions : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Sub Divisions") + 2
        
        let uv : float2
        
        if pixelize == 1 {
            uv = uvType == 0 ? getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.uv) : getPixelUV(pixelCtx: pixelCtx, tileCtx: tileCtx, uv: pixelCtx.areaUV)
        } else {
            uv = uvType == 0 ? pixelCtx.uv : pixelCtx.areaUV
        }
                    
        let noiseType : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Noise")

        let n : Float
        if noiseType == 1 {
            n = swiftNoise.gradientNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
        } else
        if noiseType == 2 {
            n = swiftNoise.perlinNoise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
        } else {
            n = swiftNoise.noise(pos: uv, scale: float2(subDivisions, subDivisions), seed: seed) * scale
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
