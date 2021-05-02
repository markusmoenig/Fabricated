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
        case None, DragTool, DragInsert
    }
    
    enum ToolControl {
        case None, BezierControl1, BezierControl2, BezierControl3
    }
    
    var action              : Action = .None
    var toolControl         : ToolControl = .None
    var actionArea          : TileInstanceArea? = nil
    
    var dragTileIds         : [SIMD2<Int>] = []

    var core                : Core
    var view                : DMTKView!
    
    let drawables           : MetalDrawables

    var graphZoom           : Float = 1
    var graphOffset         = float2(0, 0)

    var dragStart           = float2(0, 0)
    var dragId              = SIMD2<Int>(0, 0)
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
                
        // Selected rectangle
        if let selection = core.project.selectedRect {//, core.currentTool == .Select || action == .DragInsert {
            let x = drawables.viewSize.x / 2 + Float(selection.x) * tileSize * graphZoom + graphOffset.x
            let y = drawables.viewSize.y / 2 + Float(selection.y) * tileSize * graphZoom + graphOffset.y
            
            drawables.drawBox(position: float2(x,y), size: float2(tileSize * Float(selection.z), tileSize * Float(selection.w)) * graphZoom, borderSize: 2 * graphZoom, fillColor: float4(0,0,0,0), borderColor: float4(1,1,1,1))
        }
        
        // Selected areas
        for area in core.project.selectedAreas {
            let selection = area.area
            let x = drawables.viewSize.x / 2 + Float(selection.x) * tileSize * graphZoom + graphOffset.x
            let y = drawables.viewSize.y / 2 + Float(selection.y) * tileSize * graphZoom + graphOffset.y
            
            drawables.drawBox(position: float2(x,y), size: float2(tileSize * Float(selection.z), tileSize * Float(selection.w)) * graphZoom, borderSize: 2 * graphZoom, fillColor: float4(0,0,0,0), borderColor: float4(1,1,1,1))
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
        if let currentNode = core.nodeView?.currentNode, core.project.currentTileSet?.openTile != nil {
            if currentNode.role == .Shape {
                if let area = getCurrentArea() {
                    
                    let x = drawables.viewSize.x / 2 + Float(area.area.x) * tileSize * graphZoom + graphOffset.x
                    let y = drawables.viewSize.y / 2 + Float(area.area.y) * tileSize * graphZoom + graphOffset.y
                    
                    drawToolShapes(true, currentNode, area, float2(x, y))
                }
            }
        }
        
        drawables.encodeEnd()
    }
    
    /// Draw the current tool shape of the currently selected shape node
    func drawToolShapes(_ editable: Bool,_ node: TileNode,_ area: TileInstanceArea,_ pos: float2)
    {
        let tileSize = core.project.getTileSize()

        func convertPos(_ p: float2) -> float2 {
            return pos + p * tileSize * float2(Float(area.area.z), Float(area.area.w)) * graphZoom
        }
        
        func convertFloat(_ v: Float) -> Float {
            return v * tileSize * Float(area.area.w) * graphZoom
        }
        
        if node.toolShape == .QuadraticSpline {
            
            let p1 = convertPos(area.readFloat2("_control1", float2(0.0, 0.5)))
            let p2 = convertPos(area.readFloat2("_control2", float2(0.5, 0.501)))
            let p3 = convertPos(area.readFloat2("_control3", float2(1.0, 0.5)))
            
            if editable {
                let r = convertFloat(0.08)
                let off = r / 2 + r / 3
                
                if toolControl == .BezierControl1 {
                    drawables.drawDisk(position: p1 - off, radius: r, borderSize: 2 * graphZoom, borderColor: float4(0,0,0,1))
                } else {
                    drawables.drawDisk(position: p1 - off, radius: r)
                }
                if toolControl == .BezierControl2 {
                    drawables.drawDisk(position: p2 - off, radius: r, borderSize: 2 * graphZoom, borderColor: float4(0,0,0,1))
                } else {
                    drawables.drawDisk(position: p2 - off, radius: r)
                }
                if toolControl == .BezierControl3 {
                    drawables.drawDisk(position: p3 - off, radius: r, borderSize: 2 * graphZoom, borderColor: float4(0,0,0,1))
                } else {
                    drawables.drawDisk(position: p3 - off, radius: r)
                }
            }
            
            //drawables.drawBezier(p1: p1, p2: p2, p3: p3, borderSize: 2 * graphZoom)
        }
    }
    
    /// Returns the tool control for the current normalized touch offset
    func getToolControl(_ pos: float2,_ nPos: float2) -> ToolControl
    {
        var control : ToolControl = .None
        
        func checkForDisc(_ pos: float2,_ discPos: float2,_ radius: Float) -> Bool {
            let rect = MMRect(discPos.x - radius, discPos.y - radius, radius * 2, radius * 2)
            if rect.contains(pos.x, pos.y) {
                return true
            }
            return false
        }
        
        if let currentNode = core.nodeView?.currentNode, core.project.currentTileSet?.openTile != nil {
            if let area = getCurrentArea() {
                if currentNode.role == .Shape {
                    if currentNode.toolShape == .QuadraticSpline {
                        if checkForDisc(nPos, area.readFloat2("_control1", float2(0.0, 0.5)), 0.08) {
                            control = .BezierControl1
                        } else
                        if checkForDisc(nPos, area.readFloat2("_control2", float2(0.5, 0.501)), 0.08) {
                            control = .BezierControl2
                        } else
                        if checkForDisc(nPos, area.readFloat2("_control3", float2(1.0, 0.5)), 0.08) {
                            control = .BezierControl3
                        }
                    }
                }
                
                if control != .None {
                    actionArea = area
                }
            }
        }
        
        return control
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
    
    /// Computes the tileId and the normalized position inside the tile from a given position
    func getTileIdPos(_ pos: float2, tileId: inout SIMD2<Int>, tilePos: inout float2)
    {
        let tileSize = core.project.getTileSize()

        let size = drawables.viewSize
        let center = size / 2 + graphOffset
        
        let p = pos - center
        tileId = SIMD2<Int>(Int(floor(p.x / tileSize / graphZoom)), Int(floor(p.y / tileSize / graphZoom)))
        
        // Calculate the tilePos, the normalized offset from the upper left tile corner
        tilePos = SIMD2<Float>(fmod(p.x / graphZoom, tileSize), fmod(p.y / graphZoom, tileSize))
        if tilePos.x < 0 {
            tilePos.x = tileSize + tilePos.x
        }
        if tilePos.y < 0 {
            tilePos.y = tileSize + tilePos.y
        }
        tilePos /= tileSize
    }
    
    /// Returns the normalized position inside an area
    func getNormalizedAreaPos(_ pos: float2,_ area: TileInstanceArea) -> float2
    {
        let tileSize = core.project.getTileSize()

        let size = drawables.viewSize
        let center = size / 2 + graphOffset
        
        let areaSize = float2(tileSize * Float(area.area.z), tileSize * Float(area.area.w))
                
        var p = pos - center
        p /= graphZoom
            
        let areaPos = p - float2(Float(area.area.x) * tileSize, Float(area.area.y) * tileSize)
        return areaPos / areaSize
    }
    
    /// Calculates the dimensions of the tile area
    func calculateAreaDimensions(_ tileIds: [SIMD2<Int>]) -> (SIMD2<Int>, SIMD4<Int>) {
        var width   : Int = 0
        var height  : Int = 0
        
        var minX    : Int = 10000
        var maxX    : Int = -10000
        var minY    : Int = 10000
        var maxY    : Int = -10000
        
        var tilesInArea : Int = 0

        for index in tileIds {
            
            let x = index.x
            let y = index.y
            
            if x < minX {
                minX = x
            }
            if x > maxX {
                maxX = x
            }
            if y < minY {
                minY = y
            }
            if y > maxY {
                maxY = y
            }
            
            tilesInArea += 1
        }
                
        if tilesInArea > 0 {
            width = (abs(maxX - minX) + 1)
            height = (abs(maxY - minY) + 1)
        }
        
        return (SIMD2<Int>(width, height), SIMD4<Int>(minX, minY, maxX, maxY))
    }
    
    /// Returns the TileInstanceAreas of the given TileInstance
    func getAreasOfTileInstance(_ layer: Layer,_ instance: TileInstance) -> [TileInstanceArea]
    {
        var areas : [TileInstanceArea] = []
        for id in instance.tileAreas {
            if let a = layer.getTileArea(id) {
                areas.append(a)
            }
        }
        return areas
    }
    
    /// Returns the current area we process the tools for
    func getCurrentArea() -> TileInstanceArea? {
        return core.project.selectedAreas.first
    }
    
    func touchDown(_ pos: float2)
    {
        actionArea = nil
        
        if let layer = core.project.currentLayer {

            var tileId : SIMD2<Int> = SIMD2<Int>(0,0)
            var tilePos = SIMD2<Float>(0,0)
            getTileIdPos(pos, tileId: &tileId, tilePos: &tilePos)

            // --- Check for Control Tool
            if let area = getCurrentArea() {
                let nAreaPos = getNormalizedAreaPos(pos, area)
                
                let control = getToolControl(pos, nAreaPos)
                if control != .None {
                    self.toolControl = control
                    action = .DragTool
                    
                    dragId = tileId
                    dragStart = nAreaPos
                }
            }
            
            print("touch at", tileId.x, tileId.y, "offset", tilePos.x, tilePos.y)

            if core.currentTool == .Apply && core.project.currentTileSet?.currentTile != nil {
                if layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] == nil {
                    
                    dragTileIds = [tileId]
                    action = .DragInsert
                    
                    core.project.selectedRect = SIMD4<Int>(tileId.x, tileId.y, 1, 1)
                }
            } else
            if core.currentTool == .Select {
                if let instance = layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] {

                    // Assemble all areas in which the tile is included and select them
                    core.project.selectedAreas = getAreasOfTileInstance(layer, instance)
                    
                    //
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
                if let instance = layer.tileInstances[tileId] {
                    let areas = getAreasOfTileInstance(layer, instance)
                    for area in areas {
                        if let index = layer.tileAreas.firstIndex(of: area) {
                            layer.tileAreas.remove(at: index)

                            for (pos, inst) in layer.tileInstances {
                                if inst.tileAreas.contains(area.id) {
                                    if let index = inst.tileAreas.firstIndex(of: area.id) {
                                        inst.tileAreas.remove(at: index)

                                        if inst.tileAreas.isEmpty {
                                            layer.tileInstances[pos] = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                core.project.selectedRect = nil
                core.project.selectedAreas = []
                core.renderer.render()
            }
        }
        
        update()
    }
    
    func touchMoved(_ pos: float2)
    {
        if let _ = core.project.currentLayer {

            var tileId : SIMD2<Int> = SIMD2<Int>(0,0)
            var tilePos = SIMD2<Float>(0,0)
            getTileIdPos(pos, tileId: &tileId, tilePos: &tilePos)

            if action == .DragTool {
                if let area = actionArea {
                    let nAreaPos = getNormalizedAreaPos(pos, area)
                    let diff = nAreaPos - dragStart

                    if toolControl == .BezierControl1 {
                        var p = area.readFloat2("_control1", float2(0.0, 0.5))
                        p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                        area.writeFloat2("_control1", value: p)
                    } else
                    if toolControl == .BezierControl2 {
                        var p = area.readFloat2("_control2", float2(0.5, 0.501))
                        p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                        area.writeFloat2("_control2", value: p)
                    } else
                    if toolControl == .BezierControl3 {
                        var p = area.readFloat2("_control3", float2(1.0, 0.5))
                        p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                        area.writeFloat2("_control3", value: p)
                    }
                    
                    dragStart = nAreaPos
                }
                //core.renderer.render()
                update()
            } else
            if action == .DragInsert {
                //if let currentTileSet = core.project.currentTileSet {
                    //if let currentTile = currentTileSet.currentTile {
                        
                        if dragTileIds.contains(tileId) == false {
                            dragTileIds.append(tileId)
                            
                            let dim = calculateAreaDimensions(dragTileIds)
                            core.project.selectedRect = SIMD4<Int>(dim.1.x, dim.1.y, dim.0.x, dim.0.y)
                        }
                                                
                        //layer.tileInstances[tileId] = TileInstance(currentTileSet.id, currentTile.id)
                        //core.renderer.render()
                    //}
                //}
                update()
            }
        }
    }

    func touchUp(_ pos: float2)
    {
        if let layer = core.project.currentLayer {
            if action == .DragInsert {
                if let currentTileSet = core.project.currentTileSet {
                    if let currentTile = currentTileSet.currentTile, core.project.selectedRect != nil {
                        
                        var ids : [SIMD2<Int>] = []
                        
                        // Collect all tileIds inside the currently selected rect
                        let rect = core.project.selectedRect!
                        for h in rect.y..<(rect.y + rect.w) {
                            for w in rect.x..<(rect.x + rect.z) {
                                ids.append(SIMD2<Int>(w, h))
                            }
                        }
                        
                        // Iterate the tileIds and assign the area
                        let area = TileInstanceArea(currentTileSet.id, currentTile.id)
                        for tileId in ids {
                            if let instance = layer.tileInstances[tileId] {
                                instance.tileAreas.append(area.id)
                            } else {
                                let instance = TileInstance(currentTileSet.id, currentTile.id)
                                instance.tileAreas.append(area.id)
                                layer.tileInstances[tileId] = instance
                            }
                        }
                        
                        area.area = core.project.selectedRect!
                        core.project.selectedRect = nil
                        core.project.selectedAreas = [area]
                        
                        layer.tileAreas.append(area)
                        core.renderer.render()
                    }
                }
            }
        }
        
        if action != .None {
            core.renderer.render()
        }
        
        action = .None
        toolControl = .None
        actionArea = nil
        update()
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

