//
//  ScreenView.swift
//  Fabricated
//
//  Created by Markus Moenig on 13/4/21.
//

import MetalKit
import Combine

class ScreenView
{
    enum Action {
        case None, DragNode, Connecting
    }
    
    var action              : Action = .None
    
    var core                : Core
    var view                : DMTKView!
    
    let drawables           : MetalDrawables

    var graphZoom           : Float = 1
    var graphOffset         = float2(0, 0)

    var dragStart           = float2(0, 0)
    var mouseMovedPos       : float2? = nil
    
    var firstDraw           = true
        
    init(_ core: Core)
    {
        self.core = core
        view = core.view
        drawables = MetalDrawables(core.view)
    }
    
    func draw()
    {
        drawables.encodeStart()
        
        //drawables.drawBoxPattern(position: float2(0,0), size: drawables.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        if let texture = core.renderer.texture {
            
            let x = drawables.viewSize.x / 2 + Float(core.renderer.screenDim.x) * 64 + graphOffset.x
            let y = drawables.viewSize.y / 2 - Float(core.renderer.screenDim.y) * 64 + graphOffset.y

            drawables.drawBox(position: float2(x,y), size: float2(Float(texture.width), Float(texture.height)) * graphZoom, texture: texture)
        }
        
        let center = drawables.viewSize / 2.0 + graphOffset
        
        // Draw Grid
        var xOffset    : Float = 0
        var yOffset    : Float = 0
        let radius     : Float = 0.5
        let gridColor  = float4(0.5, 0.5, 0.5, 0.5)

        while center.y - yOffset >= 0 || center.y + yOffset <= drawables.viewSize.x {
            var r = radius
            if yOffset == 0 {
                r *= 1.5
            }
            drawables.drawLine(startPos: float2(0, center.y + yOffset), endPos: float2(drawables.viewSize.x, center.y + yOffset), radius: r, fillColor: gridColor)
            drawables.drawLine(startPos: float2(0, center.y - yOffset), endPos: float2(drawables.viewSize.x, center.y - yOffset), radius: r, fillColor: gridColor)
            yOffset += 64 * graphZoom
        }
        
        while center.x - xOffset >= 0 || center.x + xOffset <= drawables.viewSize.x {
            var r = radius
            if xOffset == 0 {
                r *= 1.5
            }
            drawables.drawLine(startPos: float2(center.x + xOffset, 0), endPos: float2(center.x + xOffset, drawables.viewSize.y), radius: r, fillColor: gridColor)
            drawables.drawLine(startPos: float2(center.x - xOffset, 0), endPos: float2(center.x - xOffset, drawables.viewSize.y), radius: r, fillColor: gridColor)
            xOffset += 64 * graphZoom
        }

        drawables.encodeEnd()
    }
    
    func touchDown(_ pos: float2)
    {
        let size = drawables.viewSize
        let center = size / 2 + graphOffset
        
        let p = pos - center
        var tileId : SIMD2<Int> = SIMD2<Int>(Int(floor(p.x / 64.0 / graphZoom)), Int(floor(p.y / 64.0 / graphZoom)))
        tileId.y = -tileId.y
        print("touch at", tileId.x, tileId.y)
        
        if let layer = core.project.currentLayer {
            if let currentTileSet = core.project.currentTileSet {
                if let currentTile = currentTileSet.currentTile {
                    layer.tileInstances[tileId] = TileInstance(currentTileSet.id, currentTile.id)
                    core.renderer.render()
                }
            }
        }
        
        update()
    }
    
    func touchMoved(_ pos: float2)
    {
    }

    func touchUp(_ pos: float2)
    {
    }
    
    func scrollWheel(_ delta: float3)
    {
        if view.commandIsDown == false {
            graphOffset.x += delta.x
            graphOffset.y += delta.y
        } else {
            graphZoom += delta.y * 0.003
            graphZoom = max(0.2, graphZoom)
            graphZoom = min(1, graphZoom)
        }
        
        update()
    }
    
    var scaleBuffer : Float = 0
    func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            scaleBuffer = graphZoom
        }
        
        graphZoom = max(0.2, scaleBuffer * scale)
        graphZoom = min(1, graphZoom)
        update()
    }
    
    func update() {
        drawables.update()
    }
}

