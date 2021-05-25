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
        
        /// Convert a tileId to the screen position
        func tileIdToScreen(_ tileId: SIMD2<Int>) -> float2
        {
            let x : Float
            let y : Float

            if gridType == .rectFront {
                x = drawables.viewSize.x / 2 + Float(tileId.x) * tileSize * graphZoom + graphOffset.x
                y = drawables.viewSize.y / 2 + Float(tileId.y) * tileSize * graphZoom + graphOffset.y
            } else {
                let iso = core.renderer.toIso(float2(Float(tileId.x), Float(tileId.y)))
                x = drawables.viewSize.x / 2 + iso.x * graphZoom + graphOffset.x
                y = drawables.viewSize.y / 2 + iso.y * graphZoom + graphOffset.y
            }
            
            return float2(x,y)
        }
        
        
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
        
        let rectBorderSize : Float = 3// * graphZoom
        
        // Selected rectangle
        if let selection = core.project.selectedRect {//, core.currentTool == .Select || action == .DragInsert {
            
            let screen = tileIdToScreen(SIMD2<Int>(selection.x, selection.y))
            
            drawables.drawBox(position: float2(screen.x,screen.y) - rectBorderSize / 2, size: float2(tileSize * Float(selection.z), tileSize * Float(selection.w)) * graphZoom, borderSize: rectBorderSize, fillColor: float4(0,0,0,0), borderColor: ScreenView.selectionColor)
        }
                
        // Selected areas
        if let currentLayer = core.project.currentLayer {
            
            if showAreas == true {
                for area in currentLayer.tileAreas {
                    
                    if currentLayer.selectedAreas.contains(area) == false {
                        let selection = area.area
                        
                        let screen = tileIdToScreen(SIMD2<Int>(selection.x, selection.y))
                        
                        drawables.drawBox(position: float2(screen.x,screen.y) - rectBorderSize / 2, size: float2(tileSize * Float(selection.z), tileSize * Float(selection.w)) * graphZoom, borderSize: rectBorderSize, fillColor: float4(0,0,0,0), borderColor: float4(1,1,1,0.5))
                    }
                }
            }

            for area in currentLayer.selectedAreas {
                let selection = area.area
                
                let screen = tileIdToScreen(SIMD2<Int>(selection.x, selection.y))
                
                drawables.drawBox(position: float2(screen.x,screen.y) - rectBorderSize / 2, size: float2(tileSize * Float(selection.z), tileSize * Float(selection.w)) * graphZoom, borderSize: rectBorderSize, fillColor: float4(0,0,0,0), borderColor: ScreenView.selectionColor)
            }
        }
        


        // Draw tool shape(s)
        
        let currentNode = core.nodeView?.currentNode
        if (currentNode != nil && core.project.currentTileSet?.openTile != nil ) || core.currentTool == .Resize {
            
            var area = getCurrentArea()
            
            if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 {
                area = actionArea
            }
            
            if let area = area {
                if currentNode?.tool != .None || core.currentTool == .Resize {
                    
                    let x = drawables.viewSize.x / 2 + Float(area.area.x) * tileSize * graphZoom + graphOffset.x
                    let y = drawables.viewSize.y / 2 + Float(area.area.y) * tileSize * graphZoom + graphOffset.y
                    
                    drawToolShapes(currentNode, area, float2(x, y), skin)
                }
            }
        }
        drawables.encodeEnd()
    }
    
    /// Draw the current tool shape of the currently selected shape node
    func drawToolShapes(_ node: TileNode?,_ area: TileInstanceArea,_ pos: float2,_ skin: NodeSkin)
    {
        let tileSize = core.project.getTileSize()
        
        func convertPos(_ p: float2) -> float2 {
            return pos + p * tileSize * float2(Float(area.area.z), Float(area.area.w)) * graphZoom
        }
        
        func convertFloat(_ v: Float) -> Float {
            return v * tileSize * Float(area.area.w) * graphZoom
        }
        
        var borderColor = float4(0,0,0,1)
        var fillColor = skin.selectedBorderColor

        if node === core.nodeView?.currentNode {
            if core.currentContext == .Tile {
                borderColor = skin.variablesColor
            } else {
                borderColor = skin.worldColor
            }
        }
        
        func swapColor() {
            let t = borderColor
            borderColor = fillColor
            fillColor = t
        }
        
        let borderSize = 2 * graphZoom
        
        let r = convertFloat(0.08)
        let off = r / 2 + r / 3
        
        if let node = node, core.currentTool == .Select {
            if node.tool == .QuadraticSpline {
                
                let p1 = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_control1", float2(0.0, 0.5)))
                let p2 = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_control2", float2(0.5, 0.501)))
                let p3 = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_control3", float2(1.0, 0.5)))
                                
                if toolControl == .BezierControl1 {
                    swapColor()
                    drawables.drawDisk(position: p1 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                    swapColor()
                } else {
                    drawables.drawDisk(position: p1 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                }
                if toolControl == .BezierControl2 {
                    swapColor()
                    drawables.drawDisk(position: p2 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                    swapColor()
                } else {
                    drawables.drawDisk(position: p2 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                }
                if toolControl == .BezierControl3 {
                    swapColor()
                    drawables.drawDisk(position: p3 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                    swapColor()
                } else {
                   drawables.drawDisk(position: p3 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
               }
                
                //drawables.drawBezier(p1: p1, p2: p2, p3: p3, borderSize: 2 * graphZoom)
            } else
            if node.tool == .Offset {
                
                if toolControl != .None {
                    swapColor()
                }
                
                let p = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_offset", float2(0.5, 0.5)))
                drawables.drawDisk(position: p - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
            } else
            if node.tool == .Range {
                
                let bColor = borderColor

                fillColor = node.readFloat4FromInstanceAreaIfExists(area, node, "Color1", float4(0,0,0,1))
                
                if toolControl != .None {
                    swapColor()
                }
                
                let p1 = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_range1", float2(0.5, 0.3)))
                let p2 = convertPos(node.readOptionalFloat2InstanceArea(core, node, "_range2", float2(0.5, 0.7)))
                
                drawables.drawDisk(position: p1 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
                
                borderColor = bColor
                fillColor = node.readFloat4FromInstanceAreaIfExists(area, node, "Color2", float4(1,1,1,1))
                
                if toolControl != .None {
                    swapColor()
                }
                
                drawables.drawDisk(position: p2 - off, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
            }
        } else
        if core.currentTool == .Resize {
            
            let rectBorderSize : Float = 3 * graphZoom

            let p1 = convertPos(float2(0.0, 0.0)) - float2(rectBorderSize, 30 * graphZoom)
            var p2 = convertPos(float2(1.0, 1.0))

            drawables.drawBox(position: p1, size: float2(rectBorderSize, 30 * graphZoom), fillColor: ScreenView.selectionColor)
            drawables.drawBox(position: p2, size: float2(rectBorderSize, 30 * graphZoom), fillColor: ScreenView.selectionColor)
            
            p2.y += 30 * graphZoom
            
            fillColor = ScreenView.selectionColor
            borderColor = skin.selectedBorderColor
            
            if toolControl == .ResizeControl1 {
                swapColor()
            }
            
            resizeToolPos1 = p1
            drawables.drawDisk(position: p1 - r, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
            
            fillColor = ScreenView.selectionColor
            borderColor = skin.selectedBorderColor
            
            if toolControl == .ResizeControl2 {
                swapColor()
            }
            
            resizeToolPos2 = p2
            drawables.drawDisk(position: p2 - r, radius: r, borderSize: borderSize, fillColor: fillColor, borderColor: borderColor)
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
                
                if core.currentTool == .Select {
                    
                    // Tool controls available in .Select Mode
                    if currentNode.tool == .QuadraticSpline {
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_control1", float2(0.0, 0.5)), 0.08) {
                            control = .BezierControl1
                        } else
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_control2", float2(0.5, 0.501)), 0.08) {
                            control = .BezierControl2
                        } else
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_control3", float2(1.0, 0.5)), 0.08) {
                            control = .BezierControl3
                        }
                    } else
                    if currentNode.tool == .Offset {
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_offset", float2(0.5, 0.5)), 0.08) {
                            control = .OffsetControl
                        }
                    } else
                    if currentNode.tool == .Range {
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_range1", float2(0.5, 0.3)), 0.08) {
                            control = .Range1Control
                        }
                        if checkForDisc(nPos, currentNode.readOptionalFloat2InstanceArea(core, currentNode, "_range2", float2(0.5, 0.7)), 0.08) {
                            control = .Range2Control
                        }
                    }
                }
                
                if control != .None {
                    actionArea = area
                }
            }
        }
        
        if control == .None && core.currentTool == .Resize {
            
            if let area = getCurrentArea() {

                let tileSize = core.project.getTileSize()

                func convertFloat(_ v: Float) -> Float {
                    return v * tileSize * Float(area.area.w) * graphZoom
                }
                
                let r = convertFloat(0.08)
                
                if checkForDisc(pos, resizeToolPos1, r) {
                    control = .ResizeControl1
                } else
                if checkForDisc(pos, resizeToolPos2, r) {
                    control = .ResizeControl2
                }
                
                if control != .None {
                    actionArea = area
                }
            }
        }
        
        if control == .None && core.currentTool == .Move {
            if let area = getCurrentArea() {

                control = .MoveControl
                
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
        }
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
            if let area = getCurrentArea() {
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
                    
                    core.startLayerUndo(layer, undoText)
                    
                    if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 || toolControl == .MoveControl {
                        
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
                    }
                }
            }
            
            print("touch at", tileId.x, tileId.y, "offset", tilePos.x, tilePos.y)

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
                
                if toolControl == .ResizeControl1 || toolControl == .ResizeControl2 || toolControl == .MoveControl {
                    core.project.setHasChanged(true)
                    core.renderer.render()
                } else {
                    core.renderer.render()
                }
            } else
            if action == .DragTool {
                core.currentLayerUndo?.end()
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

