//
//  NodeView.swift
//  Fabricated
//
//  Created by Markus Moenig on 10/4/21.
//

import MetalKit
import Combine

class NodeSkin {
    
    //let normalInteriorColor     = SIMD4<Float>(0,0,0,0)
    let normalInteriorColor     = SIMD4<Float>(0.227, 0.231, 0.235, 1.000)
    let normalBorderColor       = SIMD4<Float>(0.5,0.5,0.5,1)
    let normalTextColor         = SIMD4<Float>(0.8,0.8,0.8,1)
    let selectedTextColor       = SIMD4<Float>(0.212,0.173,0.137,1)
    
    let selectedItemColor       = SIMD4<Float>(0.4,0.4,0.4,1)

    let selectedBorderColor     = SIMD4<Float>(0.976, 0.980, 0.984, 1.000)

    let normalTerminalColor     = SIMD4<Float>(0.835, 0.773, 0.525, 1)
    let selectedTerminalColor   = SIMD4<Float>(0.835, 0.773, 0.525, 1.000)
    
    let renderColor             = SIMD4<Float>(0.325, 0.576, 0.761, 1.000)
    let worldColor              = SIMD4<Float>(0.396, 0.749, 0.282, 1.000)
    let groundColor             = SIMD4<Float>(0.631, 0.278, 0.506, 1.000)
    let objectColor             = SIMD4<Float>(0.765, 0.600, 0.365, 1.000)
    let variablesColor          = SIMD4<Float>(0.714, 0.349, 0.271, 1.000)
    let postFXColor             = SIMD4<Float>(0.275, 0.439, 0.353, 1.000)
    let lightColor              = SIMD4<Float>(0.494, 0.455, 0.188, 1.000)

    let tempRect                = MMRect()
    let fontScale               : Float
    let font                    : Font
    let lineHeight              : Float
    let itemHeight              : Float = 30
    let margin                  : Float = 20
    
    let tSize                   : Float = 15
    let tHalfSize               : Float = 15 / 2
    
    let itemListWidth           : Float
        
    init(_ font: Font, fontScale: Float = 0.4, graphZoom: Float) {
        self.font = font
        self.fontScale = fontScale
        self.lineHeight = font.getLineHeight(fontScale)
        
        itemListWidth = 140 * graphZoom
    }
}

class NodeView
{
    enum Action {
        case None, DragNode, Connecting
    }
    
    var action              : Action = .None
    
    var core                : Core
    var view                : DMTKView!
    
    let drawables           : MetalDrawables
    
    var currentTile         : Tile? = nil
    var currentTerminalId   : Int? = nil
    
    // For connecting terminals
    var connectingNode      : TileNode? = nil
    var connectingTerminalId: Int? = nil

    var graphZoom           : Float = 0.63
    var graphOffset         = float2(0, 0)

    var dragStart           = float2(0, 0)
    var mouseMovedPos       : float2? = nil
    
    var firstDraw           = true
    
    init(_ core: Core)
    {
        self.core = core
        view = core.nodesView
        drawables = MetalDrawables(core.nodesView)
    }
    
    func draw()
    {
        guard let tile = currentTile else {
            return
        }
        
        drawables.encodeStart()
        
        drawables.drawBoxPattern(position: float2(0,0), size: drawables.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        let skin = NodeSkin(drawables.font, fontScale: 0.4, graphZoom: graphZoom)

        for node in tile.nodes {
            drawNode(node, true, skin)
        }
        
        drawables.encodeEnd()
    }
    
    func drawNode(_ node: TileNode,_ selected: Bool,_ skin: NodeSkin)
    {
        let rect = MMRect()
                
        var extraSpaceForSlots : Float = 0
        //if let shader = node.shader {
        //    extraSpaceForSlots = 20 * Float(shader.inputs.count)
        //}
        
        let nodePos = node.readFloat2("nodePos")
        
        rect.x = drawables.viewSize.x / 2 + nodePos.x * graphZoom
        rect.y = drawables.viewSize.y / 2 + nodePos.y * graphZoom
        rect.width = 120 * graphZoom
        rect.height = (120 + extraSpaceForSlots) * graphZoom
        
        rect.x -= rect.width / 2
        rect.y -= rect.height / 2

        rect.x += graphOffset.x
        rect.y += graphOffset.y
        
        node.nodeRect.copy(rect)

        //drawables.drawBox.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: item.rect.width, height: item.rect.height, round: 12 * graphZoom, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalInteriorColor)
        drawables.drawBox(position: rect.position(), size: rect.size(), rounding: 8 * graphZoom, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalInteriorColor)
        drawables.drawText(position: rect.position() + float2(9, 5) * graphZoom, text: node.name, size: 15 * graphZoom, color: skin.normalTextColor)
        
        drawables.drawLine(startPos: rect.position() + float2(6,24) * graphZoom, endPos: rect.position() + float2(rect.width - 8 * graphZoom, 24 * graphZoom), radius: 0.6, fillColor: skin.normalBorderColor)
    }
    
    func setCurrentTile(_ tile: Tile) {
        currentTile = tile

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
