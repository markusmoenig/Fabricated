//
//  Patterns.swift
//  Fabricated
//
//  Created by Markus Moenig on 26/5/21.
//

import Foundation
import simd

class PatternTileNode : TileNode {
    
    var isMissing = false

    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        isMissing = false
        let alpha = render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        
        var color = float4(repeating: 1)

        if var decoNode = tileCtx.tile.getNextInChain(self, .Decorator) {
            color = decoNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: color)
            //color = appyModifier(decoNode, prevColor: color)
            
            while let nextDecoNode = tileCtx.tile.getNextInChain(decoNode, .Decorator) {
                color = nextDecoNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: color)
                decoNode = nextDecoNode
            }
        }
        
        let backgroundColor = tileCtx.tileSet.getPalette().getColorAtIndex(Int(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Background", 0))).value
        
        if isMissing {
            color = float4(repeating: 0)
        } else {
            color = simd_mix(backgroundColor, color, float4(repeating: alpha))
        }
        
        return color
    }
}

final class DecoratorTilesAndBricks : PatternTileNode {
    
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
            TileNodeOption(self, "Background", .Color, defaultFloat: 0),
            TileNodeOption(self, "Size", .Int, range: float2(1, 40), defaultFloat: 20),
            TileNodeOption(self, "Ratio", .Int, range: float2(1, 20), defaultFloat: 3),
            TileNodeOption(self, "Bevel", .Float, range: float2(0, 1), defaultFloat: 0.2),
            TileNodeOption(self, "Gap", .Float, range: float2(0, 1), defaultFloat: 0.1),
            TileNodeOption(self, "Round", .Float, range: float2(0, 1), defaultFloat: 0.1),
            TileNodeOption(self, "Missing", .Float, range: float2(0, 1), defaultFloat: 0.0),
            TileNodeOption(self, "Brick", .Switch, defaultFloat: 1)
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
        func missingHash(_ p: float2) -> Float { simd_fract(sin(simd_dot(p, float2(27.619, 57.583))) * 43758.5453) }

        func hash21(_ p: float2) -> Float {
            var p3  = fract(float3(p.x, p.y, p.x) * 0.1031)
            p3 += simd_dot(p3, float3(p3.y, p3.z, p3.x) + 33.33)
            return simd_fract((p3.x + p3.y) * p3.z)
        }
        
        var uv = pixelCtx.uv + tileCtx.tileId
        
        var wobble = float2(0,0)
        if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
            let backup = pixelCtx.uv
            wobble.x = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
            pixelCtx.uv += 7.23
            wobble.y = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
            pixelCtx.uv = backup
            
            uv += wobble * 0.08
        }

        let CELL : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Size"))
        let RATIO : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Ratio"))
        let BRICK : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Brick"))

        var U = uv

        let BEVEL_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Bevel")
        let BEVEL = float2(BEVEL_X, BEVEL_X)
        let GAP_X = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Gap")
        let GAP = float2(GAP_X, GAP_X)
        let ROUND = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Round")
        let MISSING = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Missing")

        let W = float2(RATIO,1)
        U *= CELL / W

        if BRICK == 1.0 {
            U.x += 0.5 * fmod(floor(U.y), 2.0)
        }
        
        hash = hash21(floor(U))

        let S = W * (fract(U) - 1.0 / 2.0)
    
        let A = W / 2.0 - GAP - abs(S)
        let B = A * 2.0 / BEVEL
        var m = min(B.x,B.y)
        if A.x < ROUND && A.y < ROUND {
            m = (ROUND - length(ROUND - A)) * 2.0 / dot(BEVEL,normalize(ROUND-A))
        }
        
        if MISSING > missingHash(floor(U)) {
            isMissing = true
        }
    
        return simd_clamp( m, 0.0, 1.0)
    }
}
