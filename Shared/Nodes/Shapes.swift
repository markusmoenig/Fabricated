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
        writeFloat("Radius", value: 0.5)
    }
    
    override func setup()
    {
        type = "ShapeDisk"
        options.append(TileNodeOption(self, "Radius", .Float))
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
        var d = length(tileCtx.getPixelUV(pixelCtx.uv)) - readFloat("Radius")
        d = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: d)
        var rc = float4(0,0,0,0)
        let color = float4(1,1,1,1)

        let step = simd_smoothstep(0, -0.02, d)
        rc = simd_mix(prevColor, color, float4(step, step, step, step))

        return rc
    }
}

class ShapeBox : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "Box")
        writeFloat("Round Top Left", value: 0.0)
        writeFloat("Round Top Right", value: 0.0)
        writeFloat("Round Bottom Left", value: 0.0)
        writeFloat("Round Bottom Right", value: 0.0)
    }
    
    override func setup()
    {
        type = "ShapeBox"
        options.append(TileNodeOption(self, "Round Top Left", .Switch))
        options.append(TileNodeOption(self, "Round Top Right", .Switch))
        options.append(TileNodeOption(self, "Round Bottom Left", .Switch))
        options.append(TileNodeOption(self, "Round Bottom Right", .Switch))
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
    
    func sdBox(_ p: float2,_ size: float2) -> Float
    {
        let d = abs(p) - size
        return length(max(d,0.0)) + min(max(d.x,d.y),0.0)
    }
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let upperLeftRounding : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Round Top Left") == 0 ? 0.0 : 0.5
        let upperRightRounding : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Round Top Right") == 0 ? 0.0 : 0.5
        let bottomLeftRounding : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Round Bottom Left") == 0 ? 0.0 : 0.5
        let bottomRightRounding : Float = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Round Bottom Right") == 0 ? 0.0 : 0.5

        let uv = tileCtx.getPixelUV(pixelCtx.uv)
        let d = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: sdRoundedBox(uv, float2(0.5, 0.5), float4(bottomRightRounding,upperRightRounding,bottomLeftRounding,upperLeftRounding)))

        var rc = float4(0,0,0,0)
        let color = float4(1,1,1,1)
        
        let step = simd_smoothstep(0, -0.02, d)
        rc = simd_mix(prevColor, color, float4(step, step, step, step))

        return rc
    }
}

class ShapeHalf : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "Half")
    }
    
    override func setup()
    {
        type = "ShapeHalf"
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
        pixelCtx.localDist = modifyDistance(pixelCtx: pixelCtx, tileCtx: tileCtx, distance: sdHalf(pixelCtx.pUV))        
        return renderDecorators(pixelCtx: pixelCtx, tileCtx: tileCtx, prevColor: prevColor)
    }
}
