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
        
        let tileSize = core.project.getTileSize()

        // Render Texture
        if let texture = core.renderer.texture {
            let x = drawables.viewSize.x / 2 + Float(core.renderer.screenDim.x) * tileSize * graphZoom + graphOffset.x
            let y = drawables.viewSize.y / 2 + Float(core.renderer.screenDim.y) * tileSize * graphZoom + graphOffset.y

            drawables.drawBox(position: float2(x,y), size: float2(Float(texture.width), Float(texture.height)) * graphZoom, texture: texture)
        }
        
        var selectedTilePos : float2? = nil
        
        // Selection
        if let selection = core.project.selectedRect, core.currentTool == .Select {
            let x = drawables.viewSize.x / 2 + Float(selection.x) * tileSize * graphZoom + graphOffset.x
            let y = drawables.viewSize.y / 2 + Float(selection.y) * tileSize * graphZoom + graphOffset.y
            
            selectedTilePos = float2(x,y)
            drawables.drawBox(position: float2(x,y), size: float2(tileSize, tileSize) * graphZoom, borderSize: 2 * graphZoom, fillColor: float4(0,0,0,0), borderColor: float4(1,1,1,1))
        }
            
        let center = drawables.viewSize / 2.0 + graphOffset
        
        // Grid
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
            yOffset += tileSize * graphZoom
        }
        
        while center.x - xOffset >= 0 || center.x + xOffset <= drawables.viewSize.x {
            var r = radius
            if xOffset == 0 {
                r *= 1.5
            }
            drawables.drawLine(startPos: float2(center.x + xOffset, 0), endPos: float2(center.x + xOffset, drawables.viewSize.y), radius: r, fillColor: gridColor)
            drawables.drawLine(startPos: float2(center.x - xOffset, 0), endPos: float2(center.x - xOffset, drawables.viewSize.y), radius: r, fillColor: gridColor)
            xOffset += tileSize * graphZoom
        }

        // Draw tool shape(s)
        if let currentNode = core.nodeView?.currentNode, core.project.currentTileSet?.openTile != nil, selectedTilePos != nil {
            if currentNode.role == .Shape {

                if let instance = getInstanceAt(selectedTilePos!) {

                    drawToolShapes(true, currentNode, instance, selectedTilePos!)
                }
            }
        }
        
        drawables.encodeEnd()
    }
    
    /// Draw the current tool shape of the currently selected shape node
    func drawToolShapes(_ editable: Bool,_ node: TileNode,_ instance: TileInstance,_ pos: float2)
    {
        let tileSize = core.project.getTileSize()

        func convertPos(_ p: float2) -> float2 {
            return pos + p * tileSize * graphZoom
        }
        
        func convertFloat(_ v: Float) -> Float {
            return v * tileSize * graphZoom
        }
        
        if node.toolShape == .QuadraticSpline {
            
            let p1 = convertPos(instance.readFloat2("_control1", float2(0.0, 0.5)))
            let p2 = convertPos(instance.readFloat2("_control2", float2(0.5, 0.5)))
            let p3 = convertPos(instance.readFloat2("_control3", float2(1.0, 0.5)))
            
            if editable {
                let r = convertFloat(0.08)
                
                let off = r / 2 + r / 3
                drawables.drawDisk(position: p1 - off, radius: r)
                drawables.drawDisk(position: p2 - off, radius: r)
                drawables.drawDisk(position: p3 - off, radius: r)
            }
            
            let r = convertFloat(0.04)
            drawables.drawBezier(p1: p1, p2: p2, p3: p3, radius: r)
        }
    }
    
    /// Returns the tile instance at the given position
    func getInstanceAt(_ pos: float2) -> TileInstance?
    {
        let size = drawables.viewSize
        let center = size / 2 + graphOffset
        let p = pos - center

        let tileSize = core.project.getTileSize()
        let tileId : SIMD2<Int> = SIMD2<Int>(Int(floor(p.x / tileSize / graphZoom)), Int(floor(p.y / tileSize / graphZoom)))
        
        if let layer = core.project.currentLayer {
            if let instance = layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] {
                return instance
            }
        }
        return nil
    }
    
    func touchDown(_ pos: float2)
    {
        if let layer = core.project.currentLayer {

            let tileSize = core.project.getTileSize()

            let size = drawables.viewSize
            let center = size / 2 + graphOffset
            
            let p = pos - center
            let tileId : SIMD2<Int> = SIMD2<Int>(Int(floor(p.x / tileSize / graphZoom)), Int(floor(p.y / tileSize / graphZoom)))
            
            // Calculate the tilePos, the normalized offset from the upper left tile corner
            var tilePos = SIMD2<Float>(fmod(p.x / graphZoom, tileSize), fmod(p.y / graphZoom, tileSize))
            if tilePos.x < 0 {
                tilePos.x = tileSize + tilePos.x
            }
            if tilePos.y < 0 {
                tilePos.y = tileSize + tilePos.y
            }
            tilePos /= tileSize
            // -

            print("touch at", tileId.x, tileId.y, "offset", tilePos.x, tilePos.y)

            if core.currentTool == .Apply {
                if let currentTileSet = core.project.currentTileSet {
                    if let currentTile = currentTileSet.currentTile {
                        layer.tileInstances[tileId] = TileInstance(currentTileSet.id, currentTile.id)
                        core.renderer.render()
                    }
                }
            } else
            if core.currentTool == .Select {
                core.project.selectedRect = SIMD4<Int>(tileId.x, tileId.y, 1, 1)
                if let instance = layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] {
                    if let tileSet = core.project.getTileSet(instance.tileSetId) {
                        if let newTile = core.project.getTileOfTileSet(instance.tileSetId, instance.tileId) {
                            if tileSet.currentTile !== newTile {
                                tileSet.currentTile = newTile
                                if tileSet.openTile != nil {
                                    tileSet.openTile = newTile
                                }
                                core.tileSetChanged.send(tileSet)
                            }
                        }
                        //core.nodeView.setCurrentNode(nil)
                        //core.nodeView.update()
                    }
                }
            } else
            if core.currentTool == .Clear {
                layer.tileInstances[tileId] = nil
                core.renderer.render()
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

