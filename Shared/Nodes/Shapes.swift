//
//  Shapes.swift
//  Fabricated
//
//  Created by Markus Moenig on 10/4/21.
//

import Foundation
import simd

class ShapeDisk : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "Disk")
    }
    
    override func setup()
    {
        type = "ShapeDisk"
        optionGroups.append(TileNodeOptionsGroup("Disk Shape Options", [
            TileNodeOption(self, "Radius", .Float, defaultFloat: 1)
        ]))
        optionGroups.append(createShapeTransformGroup())
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
        let uv = transformUV(pixelCtx: pixelCtx, tileCtx: tileCtx)
        
        pixelCtx.localDist = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: length(uv) - readFloat("Radius") / 2.0)
        return renderDecorators(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: prevColor)
    }
}

class ShapeBox : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "Box")
    }
    
    override func setup()
    {
        type = "ShapeBox"
        optionGroups.append(TileNodeOptionsGroup("Box Shape Options", [
            TileNodeOption(self, "Width", .Float, defaultFloat: 1),
            TileNodeOption(self, "Height", .Float, defaultFloat: 1),
            TileNodeOption(self, "Rounding", .Float, defaultFloat: 0),
        ]))
        optionGroups.append(createShapeTransformGroup())
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
    
    // https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
    func sdRoundedBox(_ p: float2,_ size: float2,_ radius: float4 ) -> Float
    {
        var r = radius
        //r.xy = (p.x > 0.0) ? r.xy : r.zw
        r.x = (p.x > 0.0) ? r.x : r.z
        r.y = (p.x > 0.0) ? r.y : r.w
        r.x  = (p.y > 0.0) ? r.x  : r.y
        let q : float2 = abs(p) - size + r.x
        return min(max(q.x,q.y),0.0) + length(max(q, 0.0)) - r.x
    }
    
    func sdBox(_ p: float2,_ size: float2,_ rounding: Float) -> Float
    {
        let d = abs(p) - size + rounding
        return length(max(d,0.0)) + min(max(d.x,d.y),0.0) - rounding
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let width : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Width") / 2
        let height : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Height") / 2
        let rounding : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Rounding") / 2.0
        
        let uv = transformUV(pixelCtx: pixelCtx, tileCtx: tileCtx)
        pixelCtx.localDist = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: sdBox(uv, float2(width, height), rounding))
        return renderDecorators(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: prevColor)
    }
}

class ShapeGround : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "Ground")
    }
    
    override func setup()
    {
        type = "ShapeGround"
        optionGroups.append(createShapeTransformGroup())
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
    
    func sdHalf(_ p: float2) -> Float
    {
        return 0.5 - p.y - 0.5
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let uv = transformUV(pixelCtx: pixelCtx, tileCtx: tileCtx)
        pixelCtx.localDist = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: sdHalf(uv))
        return renderDecorators(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: prevColor)
    }
}
