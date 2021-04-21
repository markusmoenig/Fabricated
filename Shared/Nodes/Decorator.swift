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
    }
    
    override func setup()
    {
        type = "DecoratorColor"
        
        optionGroups.append(TileNodeOptionsGroup("Color Decorator Options", [
            TileNodeOption(self, "Color", .Color, defaultFloat4: float4(0,0,0,1))
        ]))
        optionGroups.append(createDecoratorMaskGroup())
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
        let step = simd_smoothstep(0, -1.0 / pixelCtx.width, pixelCtx.localDist) * computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx)
        return simd_mix(prevColor, readFloat4FromInstanceIfExists(tileCtx.tileInstance, "Color"), float4(step, step, step, step))
    }
}

