//
//  Patterns.swift
//  Fabricated
//
//  Created by Markus Moenig on 26/5/21.
//

import Foundation

class DecoratorTilesAndBricks : DecoratorTileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Pattern, "Tiles & Bricks")
    }
    
    override func setup()
    {
        type = "DecoratorTilesAndBricks"
        
        optionGroups.append(TileNodeOptionsGroup("Tiles & Bricks Decorator Options", [
            TileNodeOption(self, "Color", .Color, defaultFloat4: float4(0.682, 0.408, 0.373, 1.000)),
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
    
    override func renderDecorator(pixelCtx: TilePixelContext, tileCtx: TileContext) -> float4
    {
        let color = readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, self, "Color")
        var uv = pixelCtx.uv//transformUV(pixelCtx: pixelCtx, tileCtx: tileCtx, pixelise: false, centered: false, areaAdjust: false)
        uv += tileCtx.tileId

        let CELL : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Size"))
        let RATIO : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Ratio"))
    
        var U = uv

        let BEVEL_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Bevel")
        let BEVEL = float2(BEVEL_X, BEVEL_X)
        let GAP_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Gap")
        let GAP = float2(GAP_X, GAP_X)
        let ROUND = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Round")

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
}
