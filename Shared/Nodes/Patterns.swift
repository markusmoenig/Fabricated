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

final class PatternVoronoi : PatternTileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Pattern, "Voronoi")
    }
    
    override func setup()
    {
        type = "PatternVoronoi"
        
        optionGroups.append(TileNodeOptionsGroup("Voronoi Options", [
            TileNodeOption(self, "Background", .Color, defaultFloat: 0),
            TileNodeOption(self, "Domain Scale", .Float, range: float2(0.001, 20), defaultFloat: 1),
            TileNodeOption(self, "Rounded", .Switch, defaultFloat: 1),
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
                
        func hash22(_ p: float2) -> float2 {

            let n = sin(dot(p, float2(27, 57)))
            return fract(float2(262144, 32768) * n) * 0.7
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
        
        let domainScale : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Domain Scale", 1)
        let rounded = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Rounded")

        /*

        func H(_ n: float2) -> float2 {
            var p = n.x + n.y / 0.7 + float2(1.0, 12.34)
            p.x = sin(p.x)
            p.y = sin(p.y)
            return fract( 1e4 * p)
        }

        var O = float4(repeating: 1)
        
        let U = 5.0 * uv * domainScale// (uv + uv - float2(pixelCtx.width, pixelCtx.height) * domainScale
        var c = float2(0, 0)
        //var l = Float(0)
        //var p = float2(0,0)
        
        O += 1e9 - O  // --- Worley noise: return O.xyz = sorted distance to first 3 nodes
        
        for k1 in 0..<9 {//for (int k=0; k<9; k++) // replace loops i,j: -1..1

            let k = Float(k1)
            let p = ceil(U) + float2(k - k / 3.0 * 3.0, k / 3.0) - 2.0
            
            let c1 = H(p) + p - U
            let l = dot(c1, c)
            c = c1
            
            if l < O.x {
                O.y = O.x
                O.z = O.y
                O.x = l
            } else {
                if l < O.y {
                    O.z = O.y
                    O.y = l
                } else {
                    if l < O.z {
                        O.z = l
                    } else {
                        //O = float4(repeating: l)
                    }
                }
            }
            
            /*
            l < O.x  ? O.yz = O.xy, O.x=l       // ordered 3 min distances
          : l < O.y  ? O.z =O.y , O.y=l
          : l < O.z  ?            O.z=l : l;
            
            //p = ceil(U) + vec2(k-k/3*3,k/3)-2., // cell id = floor(U)+vec2(i,j)
            //l = dot(c = H(p) + p-U , c);        // distance^2 to its node
              l < O.x  ? O.yz=O.xy, O.x=l       // ordered 3 min distances
            : l < O.y  ? O.z =O.y , O.y=l
            : l < O.z  ?            O.z=l : l;
            */
        }
        
        
        O.x = 5.0 * sqrt(O.x)
        O.y = 5.0 * sqrt(O.y)
        O.z = 5.0 * sqrt(O.z)
        O.w = 5.0 * sqrt(O.w)
        
        let l = 1.0 / (1.0 / (O.y - O.x) + 1.0 / ( O.z - O.x ) ) // Formula (c) Fabrice NEYRET - BSD3:mention author.
        O += simd_smoothstep(0.0, 0.3, l - 0.5) - O
        
        //O -= O.x
        //O += 4.0 * (O.y / (O.y / O.z + 1.0) - 0.5 ) - O

        */
        
        // Based on https://www.shadertoy.com/view/lsSfz1, thanks Shane
        
        var cellId = float2(0,0)
        
        // IQ's polynomial-based smooth minimum function.
        func smin(_ a: Float,_ b: Float,_ k: Float) -> Float {
            let h = simd_clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
            return simd_mix(b, a, h) - k*h*(1.0 - h)
        }

        func Voronoi(_ p1: float2) -> float2 {
            
            var p = p1
            
            var n = floor(p)
            p -= n
            let h = simd_step(float2(0.5, 0.5), p) - 1.5
            n += h; p -= h

            var mo = float2(0,0)
            var o = float2(0,0)
            
            var md : Float = 8.0
            var lMd : Float = 8.0
            var lMd2 : Float = 8.0
            
            var lnDist : Float = 0
            var d : Float = 0;
            
            for j in 0..<3 {
                for i in 0..<3 {
            
                    o = float2(Float(i), Float(j))
                    o += hash22(n + o) - p

                    d = dot(o, o);

                    if( d < md ){
                        
                        md = d;
                        mo = o;
                        cellId = float2(Float(i), Float(j)) + n
                    }
                }
            }

            for j in 0..<3 {
                for i in 0..<3 {
                
                    o = float2(Float(i), Float(j))
                    o += hash22(n + o) - p

                    if( dot(o-mo, o-mo) > 0.00001) {
                        lnDist = dot( 0.5 * (o+mo), normalize(o-mo))
                        lMd = smin(lMd, lnDist, 0.15)
                        lMd2 = min(lMd2, lnDist)
                    }
                }
            }

            return max(float2(lMd, lMd2), 0.0)
        }
        
        let v = Voronoi( uv * domainScale)
        
        var m : Float = (rounded == 1 ? v.x : v.y) * 2.0
        
        if v.x < 0.1 {
            m = 0.1 - m
        }
        
        hash = hash21(cellId)
                
        //if MISSING > missingHash(floor(U)) {
        //    isMissing = true
        //}
    
        return simd_clamp( m, 0.0, 1.0)
    }
}


final class PatternTilesAndBricks : PatternTileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Pattern, "Tiles & Bricks")
    }
    
    override func setup()
    {
        type = "PatternTilesAndBricks"
        
        optionGroups.append(TileNodeOptionsGroup("Tiles & Bricks Options", [
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
