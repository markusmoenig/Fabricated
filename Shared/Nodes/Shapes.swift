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
    
    override func render(ctx: TilePixelContext, prevColor: float4) -> float4
    {
        let d = length(ctx.uv) - 0.4
        var rc = float4(0,0,0,0)
        if d <= 0 {
            let d = abs(d)
            rc = float4(d,d,d,1)
        }
        return rc
    }
}

