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
        case None, DragTool, DragInsert, DragResize
    }
    
    enum ToolControl {
        case None, BezierControl1, BezierControl2, BezierControl3, OffsetControl, Range1Control, Range2Control, ResizeControl1, ResizeControl2, MoveControl
    }
    
    var showGrid            : Bool = true
    var showAreas           : Bool = false

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
    
    var toolControlArea     : TileInstanceArea? = nil
    
    var resizeToolPos1      = float2(0, 0)
    var resizeToolPos2      = float2(0, 0)

    var firstDraw           = true
        
    static var selectionColor = SIMD4<Float>(0.494, 0.455, 0.188, 1.000)
    
    init(_ core: Core)
    {
        self.core = core
        view = core.view
        drawables = MetalDrawables(core.view)
    }
    
    func draw()
    {
        drawables.encodeStart()
     
        let skin = NodeSkin(drawables.font, fontScale: 0.4, graphZoom: graphZoom)

        //drawables.drawBoxPattern(position: float2(0,0), size: drawables.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        let tileSize = core.project.getTileSize()
        let gridType = core.project.getCurrentScreen()?.gridType
        
        if showGrid == true {
            // Rect Front Grid
            var xOffset    : Float = 0
            var yOffset    : Float = 0
            let radius     : Float = 0.5
            let gridColor  = float4(0.5, 0.5, 0.5, 0.5)

            let center = drawables.viewSize / 2.0 + graphOffset

            if gridType == .rectFront {
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
            } else
            if gridType == .rectIso {
                
                let halfTileSize = tileSize / 2 * graphZoom

                while center.x - xOffset >= 0 || center.x + xOffset <= drawables.viewSize.x * 2 {
                    var r = radius
                    if xOffset == 0 {
                        r *= 1.5
                    }
                    
                    let p1 = float2(center.x + xOffset + halfTileSize, center.y + halfTileSize)
                    let p11 = float2(center.x - xOffset + halfTileSize, center.y + halfTileSize)
                    let p2Norm = simd_normalize(float2(center.x + xOffset, center.y + halfTileSize + halfTileSize / 2) - p1)
                    let p3Norm = simd_normalize(float2(center.x - xOffset, center.y + halfTileSize + halfTileSize / 2) - p11)
                    let p2 = p1 + p2Norm * 100000
                    let p3 = p1 + p2Norm * -100000
                    let p4 = p11 + p3Norm * 100000
                    let p5 = p11 + p3Norm * -100000
                    
                    drawables.drawLine(startPos: p1, endPos: p2, radius: r, fillColor: gridColor)
                    drawables.drawLine(startPos: p1, endPos: p3, radius: r, fillColor: gridColor)
                    
                    drawables.drawLine(startPos: p11, endPos: p4, radius: r, fillColor: gridColor)
                    drawables.drawLine(startPos: p11, endPos: p5, radius: r, fillColor: gridColor)

                    let p6Norm = simd_normalize(float2(center.x + xOffset + halfTileSize * 2, center.y + halfTileSize + halfTileSize / 2) - p1)
                    let p7Norm = simd_normalize(float2(center.x - xOffset + halfTileSize * 2, center.y + halfTileSize + halfTileSize / 2) - p11)
                    
                    let p6 = p1 + p6Norm * 100000
                    let p7 = p1 + p6Norm * -100000
                    let p8 = p11 + p7Norm * 100000
                    let p9 = p11 + p7Norm * -100000
                    
                    drawables.drawLine(startPos: p1, endPos: p6, radius: r, fillColor: gridColor)
                    drawables.drawLine(startPos: p1, endPos: p7, radius: r, fillColor: gridColor)
                    
                    drawables.drawLine(startPos: p11, endPos: p8, radius: r, fillColor: gridColor)
                    drawables.drawLine(startPos: p11, endPos: p9, radius: r, fillColor: gridColor)
                    
                    xOffset += tileSize * graphZoom
                }
            }
        }
        
        // Render Texture
        
        var texMulty = tileSize
        if gridType == .rectIso {
            texMulty = 1
        }
        
        let texX = drawables.viewSize.x / 2 + Float(core.renderer.screenDim.x) * texMulty * graphZoom + graphOffset.x
        let texY = drawables.viewSize.y / 2 + Float(core.renderer.screenDim.y) * texMulty * graphZoom + graphOffset.y
        
        func drawTileOutline(rect: SIMD4<Int>, borderColor: float4 = float4(0,0,0,0))
        {
            let rectBorderSize : Float = 3// * graphZoom
            
            if gridType == .rectFront {
                
                let screen = tileIdToScreen(SIMD2<Int>(rect.x, rect.y))
                let position = float2(screen.x,screen.y) - rectBorderSize / 2
                let size = float2(tileSize * Float(rect.z), tileSize * Float(rect.w)) * graphZoom
                
                drawables.drawBox(position: position, size: size, borderSize: rectBorderSize, fillColor: float4(0,0,0,0), borderColor: borderColor)
            } else
            if gridType == .rectIso {
                let radius = rectBorderSize / 2
                let singleSize = float2(tileSize, tileSize) * graphZoom

                let w2 = singleSize.x / 2.0
                let h2 = singleSize.y / 2.0

                let upperLeft = tileIdToScreen(SIMD2<Int>(rect.x, rect.y)) - radius
                let upperRight = tileIdToScreen(SIMD2<Int>(rect.x + rect.z, rect.y))
                let lowerLeft = tileIdToScreen(SIMD2<Int>(rect.x, rect.y + rect.w)) - radius
                let lowerRight = tileIdToScreen(SIMD2<Int>(rect.x + rect.z, rect.y + rect.w))

                drawables.drawLine(startPos: upperLeft + float2(w2, 0), endPos: lowerLeft + float2(w2, 0), radius: radius, fillColor: borderColor)
                drawables.drawLine(startPos: upperLeft + float2(w2, 0), endPos: upperRight + float2(w2, 0), radius: radius, fillColor: borderColor)
                drawables.drawLine(startPos: lowerLeft + float2(w2, 0), endPos: lowerLeft + float2(w2, h2), radius: radius, fillColor: borderColor)

                drawables.drawLine(startPos: upperRight + float2(w2, 0), endPos: upperRight + float2(w2, h2), radius: radius, fillColor: borderColor)
                drawables.drawLine(startPos: upperRight + float2(w2, h2), endPos: lowerRight + float2(w2, h2), radius: radius, fillColor: borderColor)

                drawables.drawLine(startPos: lowerLeft + float2(w2, h2), endPos: lowerRight + float2(w2, h2), radius: radius, fillColor: borderColor)
            }
        }
        
        if core.renderer.renderMode == .Screen {
            if let currentScreen = core.project.getCurrentScreen() {
                for layer in currentScreen.layers {
                    if let texture = layer.texture {
                        drawables.drawBox(position: float2(texX,texY), size: float2(Float(texture.width), Float(texture.height)) * graphZoom, texture: texture)
                    }
                }
            }
        } else
        if core.renderer.renderMode == .Layer {
            if let layer = core.project.currentLayer {
                if let texture = layer.texture {
                    drawables.drawBox(position: float2(texX,texY), size: float2(Float(texture.width), Float(texture.height)) * graphZoom, texture: texture)
                }
            }
        }
                
        // Hover rectangle
        if let hover = core.project.hoverRect {
            drawTileOutline(rect: hover, borderColor: float4(0.4, 0.4, 0.4, 1))
        }
                
        // Selected areas
        if let currentLayer = core.project.currentLayer {
            
            if showAreas == true {
                for area in currentLayer.tileAreas {
                    
                    if currentLayer.selectedAreas.contains(area) == false {
                        drawTileOutline(rect: area.area, borderColor: float4(1,1,1,0.5))
                    }
                }
            }
            
            // Selected rectangle
            if let selection = core.project.selectedRect {
                drawTileOutline(rect: selection, borderColor: ScreenView.selectionColor)
            }

            for area in currentLayer.selectedAreas {
                drawTileOutline(rect: area.area, borderColor: ScreenView.selectionColor)
            }
        }
        
        // Draw tool controls
        
        toolControlArea = nil
        
        let currentNode = core.nodeView?.currentNode
        if (currentNode != nil && core.project.currentTileSet?.openTile != nil ) || core.currentTool == .Resize {
            
            var area = getCurrentArea()
            
            if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 {
                area = actionArea
            }
            
            if let area = area {
                if currentNode?.tool != .None || core.currentTool == .Resize {
                    drawToolControls(currentNode, area, skin)
                    toolControlArea = area
                }
            }
        }
        drawables.encodeEnd()
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
        
        var p = pos - center
        
        let gridType = core.project.getCurrentScreen()?.gridType
        
        if gridType == .rectFront {
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
        } else
        if gridType == .rectIso {            
            let offset = (pos - graphOffset) / graphZoom - tileSize / 2
            
            let tileAspectX = tileSize / 2
            let tileAspectY = tileSize / 4
            
            let center = size / 2 / graphZoom + tileSize / 2
            let centerX = (center.x / tileAspectX + center.y / tileAspectY) / 2.0
            let centerY = (center.y / tileAspectY - (center.x / tileAspectX)) / 2.0
                                    
            let mapX = (offset.x / tileAspectX + offset.y / tileAspectY) / 2.0
            let mapY = (offset.y / tileAspectY - (offset.x / tileAspectX)) / 2.0
                        
            tileId = SIMD2<Int>(Int(round(mapX - centerX)), Int(round(mapY - centerY)))
            tileId.x += 1
            
            p = tileIdToScreen(tileId)
            
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
        if let currentLayer = core.project.currentLayer {
            return currentLayer.selectedAreas.first
        }
        return nil
    }
    
    func touchDown(_ pos: float2)
    {
        actionArea = nil
        
        if let layer = core.project.currentLayer {

            var tileId : SIMD2<Int> = SIMD2<Int>(0,0)
            var tilePos = SIMD2<Float>(0,0)
            getTileIdPos(pos, tileId: &tileId, tilePos: &tilePos)

            // --- Check for Control Tool
            if let area = toolControlArea {
                let nAreaPos = getNormalizedAreaPos(pos, area)
                
                let control = getToolControl(pos, nAreaPos)
                if control != .None {
                    self.toolControl = control
                    action = .DragTool
                    
                    dragId = tileId
                    dragStart = nAreaPos
                    
                    var undoText = "Area Control Changed"
                    if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 {
                        undoText = "Area Resize"
                    } else
                    if toolControl == .MoveControl {
                        undoText = "Area Move"
                    }
                    
                    core.currentLayerUndo = nil
                    core.currentTileUndo = nil
                                        
                    if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 || toolControl == .MoveControl {
                        
                        core.startLayerUndo(layer, undoText)

                        layer.selectedAreas = []
                        core.project.selectedRect = actionArea?.area

                        if let area = actionArea {
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
                    } else {
                        if core.currentContext == .Area {
                            core.startLayerUndo(layer, undoText)
                        } else
                        if let tile = core.nodeView?.getCurrentTile() {
                            core.startTileUndo(tile, undoText)
                        }
                    }
                }
            }
            
            //print("touch at", tileId.x, tileId.y, "offset", tilePos.x, tilePos.y)

            if core.currentTool == .Apply && core.project.currentTileSet?.currentTile != nil {
                if layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] == nil {
                    
                    dragTileIds = [tileId]
                    action = .DragInsert
                    
                    core.project.selectedRect = SIMD4<Int>(tileId.x, tileId.y, 1, 1)
                    
                    core.startLayerUndo(layer, "Area Creation")
                }
            } else
            if core.currentTool == .Select || (core.currentTool == .Resize && toolControl == .None) || core.currentTool == .Move {
                if let instance = layer.tileInstances[SIMD2<Int>(tileId.x, tileId.y)] {

                    // Assemble all areas in which the tile is included and select them
                    layer.selectedAreas = getAreasOfTileInstance(layer, instance)
                    core.areaChanged.send()

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
                } else {
                    layer.selectedAreas = []
                    core.areaChanged.send()
                    update()
                }
            } else
            if core.currentTool == .Clear {
                
                core.startLayerUndo(layer, "Area Removal")

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
                core.project.setHasChanged(true)
                layer.selectedAreas = []
                core.renderer.render()
                
                core.currentLayerUndo?.end()
                core.currentLayerUndo = nil
            }
        }
        
        update()
    }
    
    func touchDragged(_ pos: float2)
    {
        core.project.hoverRect = nil
        if let _ = core.project.currentLayer {

            var tileId : SIMD2<Int> = SIMD2<Int>(0,0)
            var tilePos = SIMD2<Float>(0,0)
            getTileIdPos(pos, tileId: &tileId, tilePos: &tilePos)

            if action == .DragTool {
                if let area = actionArea {
                    let nAreaPos = getNormalizedAreaPos(pos, area)
                    let diff = nAreaPos - dragStart
                    
                    if let node = core.nodeView?.currentNode {
                        if toolControl == .BezierControl1 {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_control1", float2(0.0, 0.5))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_control1", value: p)
                        } else
                        if toolControl == .BezierControl2 {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_control2", float2(0.5, 0.501))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_control2", value: p)
                        } else
                        if toolControl == .BezierControl3 {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_control3", float2(1.0, 0.5))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_control3", value: p)
                        } else
                        if toolControl == .OffsetControl {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_offset", float2(0.5, 0.5))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_offset", value: p)
                        } else
                        if toolControl == .Range1Control {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_range1", float2(0.5, 0.3))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_range1", value: p)
                        } else
                        if toolControl == .Range2Control {
                            var p = node.readOptionalFloat2InstanceArea(core, node, "_range2", float2(0.5, 0.7))
                            p += diff; p.clamp(lowerBound: float2(0,0), upperBound: float2(1,1))
                            node.writeOptionalFloat2InstanceArea(core, node, "_range2", value: p)
                        }
                    }
                    
                    if toolControl == .MoveControl {
                        if let area = actionArea {
                            let rect = area.area
                            
                            let areaPos = SIMD2<Int>(area.area.x, area.area.y)
                                                        
                            let x = rect.x + tileId.x - areaPos.x
                            let y = rect.y + tileId.y - areaPos.y
                            let width = rect.z
                            let height = rect.w
                            
                            if width > 0 && height > 0 {
                                core.project.selectedRect = SIMD4<Int>(x, y, width, height)
                            }
                        }
                    }
                    
                    if toolControl == .ResizeControl1 {
                        if let area = actionArea {
                            let rect = area.area
                            
                            let areaPos = SIMD2<Int>(area.area.x, area.area.y)
                                                        
                            let x = rect.x + tileId.x - areaPos.x
                            let y = rect.y + tileId.y - areaPos.y
                            var width = rect.z
                            var height = rect.w
                            
                            if tileId.x > areaPos.x {
                                width -= tileId.x - areaPos.x
                            } else {
                                width += areaPos.x - tileId.x
                            }
                            
                            if tileId.y > areaPos.y {
                                height -= tileId.y - areaPos.y
                            } else {
                                height += areaPos.y - tileId.y
                            }
                            
                            if width > 0 && height > 0 {
                                core.project.selectedRect = SIMD4<Int>(x, y, width, height)
                            }
                        }
                    } else
                    if toolControl == .ResizeControl2 {
                        if let area = actionArea {
                            let rect = area.area
                            
                            let areaPos = SIMD2<Int>(area.area.x + area.area.z, area.area.y + area.area.w)
                                                        
                            let x = rect.x
                            let y = rect.y
                            var width = rect.z
                            var height = rect.w
                            
                            if tileId.x > areaPos.x {
                                width += tileId.x - areaPos.x
                            } else {
                                width -= areaPos.x - tileId.x
                            }
                            
                            if tileId.y > areaPos.y {
                                height += tileId.y - areaPos.y
                            } else {
                                height -= areaPos.y - tileId.y
                            }
                            
                            width += 1
                            height += 1
                            
                            if width > 0 && height > 0 {
                                core.project.selectedRect = SIMD4<Int>(x, y, width, height)
                            }
                        }
                    }
                    
                    dragStart = nAreaPos
                }
                //core.renderer.render()
                update()
            } else
            if action == .DragInsert {

                if dragTileIds.contains(tileId) == false {
                    dragTileIds.append(tileId)
                                                
                    let dim = calculateAreaDimensions(dragTileIds)
                    core.project.selectedRect = SIMD4<Int>(dim.1.x, dim.1.y, dim.0.x, dim.0.y)
                }
                update()
            }
        }
    }
    
    func touchHover(_ pos: float2)
    {
        if let _ = core.project.currentLayer, action == .None {
            
            var tileId : SIMD2<Int> = SIMD2<Int>(0,0)
            var tilePos = SIMD2<Float>(0,0)
            getTileIdPos(pos, tileId: &tileId, tilePos: &tilePos)

            core.project.hoverRect = SIMD4<Int>(tileId.x, tileId.y, 1, 1)
            update()
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
                        
                        layer.selectedAreas = [area]
                        layer.tileAreas.append(area)
                        
                        core.currentLayerUndo?.end()
                        core.renderer.render()
                    }
                }
            } else
            if action == .DragTool && (toolControl == .ResizeControl1 || toolControl == .ResizeControl2 || toolControl == .MoveControl) {

                var ids : [SIMD2<Int>] = []
                
                // Collect all tileIds inside the currently selected rect
                let rect = core.project.selectedRect!
                for h in rect.y..<(rect.y + rect.w) {
                    for w in rect.x..<(rect.x + rect.z) {
                        ids.append(SIMD2<Int>(w, h))
                    }
                }
                
                // Iterate the tileIds and assign the area
                let area = actionArea!
                for tileId in ids {
                    if let instance = layer.tileInstances[tileId] {
                        instance.tileAreas.append(area.id)
                    } else {
                        let instance = TileInstance(area.tileSetId, area.tileId)
                        instance.tileAreas.append(area.id)
                        layer.tileInstances[tileId] = instance
                    }
                }
                
                area.area = core.project.selectedRect!
                core.project.selectedRect = nil
                
                layer.selectedAreas = [area]
                
                core.currentLayerUndo?.end()
                core.currentTileUndo?.end()
                
                core.currentLayerUndo = nil
                core.currentTileUndo = nil

                if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 || toolControl == .MoveControl {
                    core.project.setHasChanged(true)
                    core.renderer.render()
                } else {
                    core.renderer.render()
                }
            } else
            if action == .DragTool {
                core.currentLayerUndo?.end()
                core.currentLayerUndo = nil
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
            graphZoom = min(2, graphZoom)
        }
        
        core.updateTools.send()
        update()
    }
    
    var scaleBuffer : Float = 0
    func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            scaleBuffer = graphZoom
        }
        
        graphZoom = max(0.2, scaleBuffer * scale)
        graphZoom = min(2, graphZoom)
        update()
    }
    
    func update() {
        drawables.update()
    }
}

