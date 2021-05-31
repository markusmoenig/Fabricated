//
//  ScreenViewTools.swift
//  Fabricated
//
//  Created by Markus Moenig on 31/5/21.
//

import Foundation

extension ScreenView {
        
    /// Draws the current tool controls of the currently selected node for the given area
    func drawToolControls(_ node: TileNode?,_ area: TileInstanceArea,_ skin: NodeSkin)
    {
        let tileSize = core.project.getTileSize()
        let gridType = core.project.getCurrentScreen()?.gridType
                
        let areaRect = getAreaScreenRect(area)

        if gridType == .rectIso {
            // Draw a box around the area to show valid range
            drawables.drawBox(position: areaRect.position(), size: areaRect.size(), borderSize: 2, fillColor: float4(repeating: 0), borderColor: float4(1, 1, 1, 1))
        }
        
        // Converts the normalized position (relative to the area rect) p to the screen position
        func convertPos(_ p: float2) -> float2 {
            return areaRect.position() + p * areaRect.size()
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

            var p1 : float2 = convertPos(float2(0.0, 0.0))
            var p2 : float2 = convertPos(float2(1.0, 1.0))
            
            if gridType == .rectFront {
                p1 = convertPos(float2(0.0, 0.0))
                p2 = convertPos(float2(1.0, 1.0))
            } else {
            //if gridType == .rectIso {
                
                let upperLeft = tileIdToScreen(SIMD2<Int>(area.area.x, area.area.y))
                let lowerRight = tileIdToScreen(SIMD2<Int>(area.area.x + area.area.z, area.area.y + area.area.w))
                p1 = upperLeft + float2(tileSize / 2.0, 0) * graphZoom
                p2 = lowerRight + (float2(tileSize, tileSize) / 2.0) * graphZoom
            }
            
            p1 -= float2(rectBorderSize, 30 * graphZoom)

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
    
    /// Convert a tileId to the screen position
    func tileIdToScreen(_ tileId: SIMD2<Int>) -> float2
    {
        let x : Float
        let y : Float

        let tileSize = core.project.getTileSize()
        let gridType = core.project.getCurrentScreen()?.gridType
        
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
    
    /// Returns the screen rect of an area
    func getAreaScreenRect(_ area: TileInstanceArea) -> MMRect
    {
        let upperLeft = tileIdToScreen(SIMD2<Int>(area.area.x, area.area.y))
            
        let tileSize = core.project.getTileSize()
        let gridType = core.project.getCurrentScreen()?.gridType

        let rect = MMRect()
        
        rect.x = upperLeft.x
        rect.y = upperLeft.y

        if gridType == .rectFront {
            let size = tileSize * float2(Float(area.area.z), Float(area.area.w)) * graphZoom
            rect.width = size.x
            rect.height = size.y
        } else {
            let lowerRight = tileIdToScreen(SIMD2<Int>(area.area.x + area.area.z, area.area.y + area.area.w))

            rect.width = lowerRight.x - upperLeft.x + tileSize * graphZoom
            rect.height = lowerRight.y - upperLeft.y + (tileSize / 2.0) * graphZoom
        }
        
        return rect
    }
    
    /// Returns the normalized position inside an area
    func getNormalizedAreaPos(_ pos: float2,_ area: TileInstanceArea) -> float2
    {
        let areaRect = getAreaScreenRect(area)
        
        var norm = float2()
        
        norm.x = pos.x - areaRect.x
        norm.y = pos.y - areaRect.y
        norm.x /= areaRect.width
        norm.y /= areaRect.height

        return norm
    }
}
