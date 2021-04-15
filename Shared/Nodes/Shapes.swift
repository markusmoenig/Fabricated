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
        var rc = float4(0,0,0,0)
        let color = float4(1,1,1,1)

        if d <= 0.0 {//&& d >= -1.0 / tileCtx.pixelSize {
            d = 1.0
        } else {
            d = 0.0
        }

        rc = simd_mix(prevColor, color, float4(d,d,d,d))

        return rc
    }
}

