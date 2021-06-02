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
    
    /// Computes the decorator mask
    func computeDecoratorMask(pixelCtx: TilePixelContext, tileCtx: TileContext, inside: Bool) -> Float
    {
        /*
        float innerBorderMask(float dist, float width)
        {
            //dist += 1.0;
            return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
        }

        float outerBorderMask(float dist, float width)
        {
            //dist += 1.0;
            return clamp(dist, 0.0, 1.0) - clamp(dist - width, 0.0, 1.0);
        }
         
         float fillMask(float dist)
         {
             return clamp(-dist, 0.0, 1.0);
         }
         
         func innerBorderMask(_ dist: Float,_ width: Float) -> Float
         {
             //dist += 1.0;
             return simd_clamp(dist + width, 0.0, 1.0) - simd_clamp(dist, 0.0, 1.0)
         }
         
         func fillMask(_ dist: Float) -> Float
         {
             return simd_clamp(-dist, 0.0, 1.0)
         }
         
         */
        
        let depthRange = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Depth Range", 0)
        
        if depthRange == 0 {
            return 1
        }

        let maskStart = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Depth Start", 0)
        let maskEnd = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Depth End", 1)
        
        let d = pixelCtx.distance
        
        if inside {
            if d <= -maskStart && d >= -(maskStart + maskEnd) {
                return 1
            } else {
                return 0
            }
        } else {
            if d >= maskStart && d <= (maskStart + maskEnd) {
                return 1
            } else {
                return 0
            }
        }
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        if pixelCtx.preview {
            return renderDecorator(pixelCtx: pixelCtx, tileCtx: tileCtx)
        }
        
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
        patternColor = patternColor.clamped(lowerBound: float4(repeating: 0), upperBound: float4(repeating: 1))
                
        return patternColor
    }
}

final class DecoratorGradient : DecoratorTileNode {
    
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
            TileNodeOption(self, "Pixelise", .Switch, defaultFloat: 1),

            TileNodeOption(self, "Color #1", .Color, defaultFloat: 0),
            TileNodeOption(self, "Color #2", .Color, defaultFloat: 1)
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
        let pixelise : Float = readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Pixelise")

        let uv = transformUV(pixelCtx: pixelCtx, tileCtx: tileCtx, pixelise: pixelise == 1, centered: false, areaAdjust: true)
        
        let p1 = readFloat2FromInstanceAreaIfExists(tileCtx.tileArea, self, "_range1", float2(0.5, 0.3)) * tileCtx.areaSize
        let p2 = readFloat2FromInstanceAreaIfExists(tileCtx.tileArea, self, "_range2", float2(0.5, 0.7)) * tileCtx.areaSize
        
        let s : Float
            
        if gradientMode == 1 {
            s = gradient_radial(uv: uv, p1: p1, p2: p2)
        } else
        if gradientMode == 2 {
            s = gradient_angle(uv: uv, p1: p1, p2: p2)
        } else {
            s = gradient_linear(uv: uv, p1: p1, p2: p2)
        }
        
        let color1 = tileCtx.tileSet.getPalette().getColorAtIndex(Int(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Color #1", 0))).value
        let color2 = tileCtx.tileSet.getPalette().getColorAtIndex(Int(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Color #2", 0))).value

        
        return simd_mix(color1, color2, float4(repeating: s))
    }
}

final class DecoratorColor : DecoratorTileNode {
    
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
            TileNodeOption(self, "Color", .Color, defaultFloat: 0)
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
        return tileCtx.tileSet.getPalette().getColorAtIndex(Int(readFloatFromInstanceAreaIfExists(tileCtx.tileArea, self, "Color", 0))).value
    }
}

