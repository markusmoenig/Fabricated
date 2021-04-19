//
//  Modifier.swift
//  Fabricated
//
//  Created by Markus Moenig on 17/4/21.
//

import Foundation

class ModifierNoise : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Modifier, "Noise")
        writeFloat("Noise", value: 1)
    }
    
    override func setup()
    {
        type = "ModifierNoise"
        options.append(TileNodeOption(self, "Noise", .Menu, menuEntries: ["Pixel", "Value"]))
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
        let uv = tileCtx.getPixelUV((pixelCtx.uv))
        let n = noise(pos: uv, scale: float2(4,4), seed: 1) * 0.1
        //print(n)
        return n
    }
}
