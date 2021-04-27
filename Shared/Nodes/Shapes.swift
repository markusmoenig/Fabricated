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
    
    // sdBezier
    
    func dot2(_ v: float2 ) -> Float { return simd_dot(v,v) }
    func cross2(_ a: float2,_ b: float2 ) -> Float { return a.x*b.y - a.y*b.x }
    
    // signed distance to a quadratic bezier
    func sdBezier(_ pos: float2,_ A: float2,_ B: float2,_ C: float2 ) -> Float
    {
        let a = B - A
        let b = A - 2.0*B + C
        let c = a * 2.0
        let d = A - pos

        let kk = 1.0/dot(b,b)
        let kx = kk * dot(a,b)
        let ky = kk * (2.0*dot(a,a)+dot(d,b))/3.0
        let kz = kk * dot(d,a)

        var res : Float = 0.0
        var sgn : Float = 0.0

        let p = ky - kx*kx
        let p3 = p*p*p
        let q = kx*(2.0*kx*kx - 3.0*ky) + kz
        var h = q*q + 4.0*p3

        if( h>=0.0 )
        {   // 1 root
            h = sqrt(h)
            let x : float2 = (float2(h,-h)-q)/2.0
            let uv : float2 = float2(sign(x.x) * pow(abs(x.x), 1.0/3.0),
                                     sign(x.y) * pow(abs(x.y), 1.0/3.0))
            let t = simd_clamp(uv.x+uv.y-kx, 0.0, 1.0)
            let  q = d+(c+b*t)*t
            res = dot2(q)
            sgn = cross2(c+2.0*b*t,q)
        }
        else
        {   // 3 roots
            let z = sqrt(-p)
            let v = acos(q/(p*z*2.0))/3.0
            let m = cos(v)
            let n = sin(v)*1.732050808
            let t = simd_clamp( float3(m + m,-n - m,n - m) * z - float3(kx, kx, kx), float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0))
            let  qx = d+(c+b*t.x)*t.x; let dx = dot2(qx), sx = cross2(c+2.0*b*t.x,qx)
            let  qy = d+(c+b*t.y)*t.y; let dy = dot2(qy), sy = cross2(c+2.0*b*t.y,qy)
            if( dx < dy ) { res = dx; sgn = sx } else { res=dy; sgn=sy; }
        }
        
        return sqrt( res )*sign(sgn);
    }
    
    //
    func sdSpline(_ p: float2) -> Float
    {
        return sdBezier(p, float2(-0.5, -0.0), float2(0.3,-0.2), float2(0.2,0.5))
    }
    
    //
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
