//
//  Decorator.swift
//  Fabricated
//
//  Created by Markus Moenig on 19/4/21.
//

import Foundation

class DecoratorTilesAndBricks : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Decorator, "Tiles & Bricks")
    }
    
    override func setup()
    {
        type = "DecoratorTilesAndBricks"
        
        optionGroups.append(TileNodeOptionsGroup("Tiles & Bricks Decorator Options", [
            TileNodeOption(self, "Color", .Color, defaultFloat4: float4(0.682, 0.408, 0.373, 1.000)),
            TileNodeOption(self, "UV", .Menu, menuEntries: ["Tile", "Area"], defaultFloat: 0),
            TileNodeOption(self, "Size", .Int, range: float2(1, 40), defaultFloat: 20),
            TileNodeOption(self, "Ratio", .Int, range: float2(1, 20), defaultFloat: 3),
            TileNodeOption(self, "Bevel", .Float, range: float2(0, 1), defaultFloat: 0.2),
            TileNodeOption(self, "Gap", .Float, range: float2(0, 1), defaultFloat: 0.1),
            TileNodeOption(self, "Round", .Float, range: float2(0, 1), defaultFloat: 0.1)
        ]))
        optionGroups.append(createDefaultDecoratorOptionsGroup())
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
    
    func generatePattern(pixelCtx: TilePixelContext, tileCtx: TileContext) -> float4
    {
        let color = readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, "Color")
        let uv = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "UV")

        let CELL : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Size"))
        let RATIO : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Ratio"))
    
        var U = uv == 0 ? pixelCtx.uv : pixelCtx.areaUV

        let BEVEL_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Bevel")
        let BEVEL = float2(BEVEL_X, BEVEL_X)
        let GAP_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Gap")
        let GAP = float2(GAP_X, GAP_X)
        let ROUND = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Round")

        let W = float2(RATIO,1)
        U *= CELL / W

        U.x += 0.5 * fmod(floor(U.y), 2.0)

        let S = W * (fract(U) - 1.0 / 2.0)
    
        let A = W / 2.0 - GAP - abs(S)
        let B = A * 2.0 / BEVEL
        var m = min(B.x,B.y)
        if A.x < ROUND && A.y < ROUND {
            m = (ROUND - length(ROUND - A)) * 2.0 / dot(BEVEL,normalize(ROUND-A))
        }
    
        let alpha = simd_clamp( m, 0.0, 1.0)
        return float4(color.x, color.y, color.z, alpha)
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let shapeMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Shape")
        let modifierMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Modifier")
        let sign : Float = shapeMode == 0 ? -1 : 1
        
        var modifierValue : Float = 0
        if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
            modifierValue = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        }
        
        let step = simd_smoothstep(-sign * 2.0 * tileCtx.antiAliasing / pixelCtx.width, sign * tileCtx.antiAliasing / pixelCtx.width, pixelCtx.localDist) * computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        var patternColor = simd_mix(prevColor, generatePattern(pixelCtx: pixelCtx, tileCtx: tileCtx), float4(step, step, step, step))
        
        if modifierMode == 0 {
            patternColor.x += modifierValue
            patternColor.y += modifierValue
            patternColor.z += modifierValue
        } else {
            let v = (modifierValue + 1.0) / 2.0
            patternColor.w *= v
        }
        
        //patternColor.w *= computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        patternColor = simd_mix(prevColor, patternColor, float4(step, step, step, step))

        return patternColor
    }
}

class DecoratorColor : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Decorator, "Color")
    }
    
    override func setup()
    {
        type = "DecoratorColor"
        
        optionGroups.append(TileNodeOptionsGroup("Color Decorator Options", [
            TileNodeOption(self, "Color", .Color, defaultFloat4: float4(0.765, 0.600, 0.365, 1))
        ]))
        optionGroups.append(createDefaultDecoratorOptionsGroup())
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
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let shapeMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Shape")
        let modifierMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, "Modifier")
        let sign : Float = shapeMode == 0 ? -1 : 1
        
        var modifierValue : Float = 0
        if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
            modifierValue = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        }
        
        let step = simd_smoothstep(-sign * 2.0 * tileCtx.antiAliasing / pixelCtx.width, sign * tileCtx.antiAliasing / pixelCtx.width, pixelCtx.localDist) * computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        var patternColor = simd_mix(prevColor, readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, "Color"), float4(step, step, step, step))
        
        if modifierMode == 0 {
            patternColor.x += modifierValue
            patternColor.y += modifierValue
            patternColor.z += modifierValue
        } else {
            let v = (modifierValue + 1.0) / 2.0
            patternColor.w *= v
        }
        
        //patternColor.w *= computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        patternColor = simd_mix(prevColor, patternColor, float4(step, step, step, step))

        return patternColor
    }
}

