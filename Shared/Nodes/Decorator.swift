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
    
    override func render(pixelCtx: TilePixelContext, tileCtx: TileContext, prevColor: float4) -> float4
    {
        let shapeMode = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Shape")
        let modifierMode = readFloatFromInstanceIfExists(tileCtx.tileInstance, "Modifier")
        let sign : Float = shapeMode == 0 ? -1 : 1
        
        var modifierValue : Float = 0
        if let modifierNode = tileCtx.tile.getNextInChain(self, .Modifier) {
            modifierValue = modifierNode.render(pixelCtx: pixelCtx, tileCtx: tileCtx)
        }
        
        let step = simd_smoothstep(-sign * 2.0 * tileCtx.antiAliasing / pixelCtx.width, sign * tileCtx.antiAliasing / pixelCtx.width, pixelCtx.localDist) * computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        var patternColor = simd_mix(prevColor, readFloat4FromInstanceIfExists(tileCtx.tileInstance, "Color"), float4(step, step, step, step))
        
        if modifierMode == 0 {
            patternColor.x += modifierValue
            patternColor.y += modifierValue
            patternColor.z += modifierValue
        } else {
            let v = (modifierValue + 1.0) / 2.0
            patternColor.w *= v
        }
        
        //patternColor.w *= computeDecoratorMask(pixelCtx: pixelCtx, tileCtx: tileCtx, inside: shapeMode == 0)
        patternColor = simd_mix(prevColor, patternColor, float4(step, step, step, step))

        return patternColor
    }
}

