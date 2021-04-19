//
//  Decorator.swift
//  Fabricated
//
//  Created by Markus Moenig on 19/4/21.
//

import Foundation

class DecoratorColor : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Decorator, "Color")
        writeFloat4("Color", value: float4(0, 0, 0, 1))
    }
    
    override func setup()
    {
        type = "DecoratorColor"
        options.append(TileNodeOption(self, "Color", .Color))
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
        let step = simd_smoothstep(0, -0.02, pixelCtx.localDist)
        return simd_mix(prevColor,  readFloat4FromInstanceIfExists(tileCtx.tileInstance, "Color"), float4(step, step, step, step))
    }
}
