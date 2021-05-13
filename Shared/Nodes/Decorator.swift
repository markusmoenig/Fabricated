//
//  Decorator.swift
//  Fabricated
//
//  Created by Markus Moenig on 19/4/21.
//

import Foundation

class DecoratorTileNode : TileNode {

    func renderDecorator(pixelCtx: TilePixelContext, tileCtx: TileContext) -> float4
    {
        return float4(0,0,0,0)
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let shapeMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Shape")
        let modifierMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Modifier")
        let sign : Float = shapeMode == 0 ? -1 : 1
        
        var modifierValue : Float = 0
        if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
            modifierValue = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        }
        
        var step = simd_smoothstep(-sign * 2.0 * tileCtx.antiAliasing / pixelCtx.width, sign * tileCtx.antiAliasing / pixelCtx.width, pixelCtx.distance) * computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        var patternColor = simd_mix(prevColor, renderDecorator(pixelCtx: pixelCtx, tileCtx: tileCtx), float4(step, step, step, step))
        
        if modifierMode == 0 {
            patternColor.x += modifierValue
            patternColor.y += modifierValue
            patternColor.z += modifierValue
        } else {
            let v = (modifierValue + 1.0) / 2.0
            patternColor.x *= v
            patternColor.y *= v
            patternColor.z *= v
            step = v
        }
        
        patternColor = simd_mix(prevColor, patternColor, float4(step, step, step, step))

        return patternColor
    }
}

class DecoratorTilesAndBricks : DecoratorTileNode {
    
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
    
    override func renderDecorator(pixelCtx: TilePixelContext, tileCtx: TileContext) -> float4
    {
        let color = readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, self, "Color")
        let uv = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "UV")

        let CELL : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Size"))
        let RATIO : Float = round(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Ratio"))
    
        var U = uv == 0 ? pixelCtx.uv : pixelCtx.areaUV

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

class DecoratorGradient : DecoratorTileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Decorator, "Gradient")
    }
    
    override func setup()
    {
        type = "DecoratorGradient"
        tool = .Range
        optionGroups.append(TileNodeOptionsGroup("Gradient Decorator Options", [
            TileNodeOption(self, "Gradient", .Menu, menuEntries: ["Linear", "Radial", "Angle"], defaultFloat: 0),

            TileNodeOption(self, "Color1", .Color, defaultFloat4: float4(0.0, 0.0, 0.0, 1)),
            TileNodeOption(self, "Color2", .Color, defaultFloat4: float4(1.0, 1.0, 1.0, 1))
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
        func gradient_linear(uv: float2, p1: float2, p2: float2) -> Float {
            return simd_clamp(dot(uv-p1,p2-p1)/simd_dot(p2-p1,p2-p1),0.0,1.0)
        }
        
        func gradient_radial(uv: float2, p1: float2, p2: float2) -> Float {
            return length(uv-p1)/(length(p1-p2));
        }
        
        func linearstep(_ a: Float,_ b: Float,_ x: Float) -> Float {
            return simd_clamp((x-a)/(b-a),0.0,1.0)
        }
        
        func gradient_angle(uv: float2, p1: float2, p2: float2) -> Float {
            let PI = Float.pi
            let a : Float = (atan2(p1.x - p2.x, p1.y - p2.y) + PI) / (PI * 2.0)
            let a2 = simd_fract((atan2(p1.x-uv.x,p1.y-uv.y)+PI)/(PI*2.0)-a)
                                   
            return a2 + linearstep(0.0005 / length(uv-p1), 0.0, a2)
        }
        
        let gradientMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Gradient")

        let uvMode = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "UV")
        let uv = uvMode == 0 ? pixelCtx.uv : pixelCtx.areaUV

        let p1 = readFloat2FromInstanceAreaIfExists(tileCtx.tileArea, self, "_range1", float2(0.5, 0.3))
        let p2 = readFloat2FromInstanceAreaIfExists(tileCtx.tileArea, self, "_range2", float2(0.5, 0.7))
        
        let s : Float
            
        if gradientMode == 1 {
            s = gradient_radial(uv: uv, p1: p1, p2: p2)
        } else
        if gradientMode == 2 {
            s = gradient_angle(uv: uv, p1: p1, p2: p2)
        } else {
            s = gradient_linear(uv: uv, p1: p1, p2: p2)
        }
        
        let color1 = readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, self, "Color1")
        let color2 = readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, self, "Color2")
        
        return simd_mix(color1, color2, float4(repeating: s))
    }
}

class DecoratorColor : DecoratorTileNode {
    
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
    
    override func renderDecorator(pixelCtx: TilePixelContext, tileCtx: TileContext) -> float4
    {
        return readFloat4FromInstanceAreaIfExists(tileCtx.tileArea, self, "Color")
    }
}

