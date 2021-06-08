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
    
    let tileColor               = SIMD4<Float>(0.714, 0.349, 0.271, 1.000)
    let shapeColor              = SIMD4<Float>(0.325, 0.576, 0.761, 1.000)
    let modifierColor           = SIMD4<Float>(0.631, 0.278, 0.506, 1.000)
    let decoratorColor          = SIMD4<Float>(0.765, 0.600, 0.365, 1.000)
    let patternColor            = SIMD4<Float>(0.275, 0.439, 0.353, 1.000)

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
        case None, DragNode, DragConnect
    }
    
    var action              : Action = .None
    
    var core                : Core
    var view                : DMTKView!
    
    let drawables           : MetalDrawables
        
    var currentNode         : TileNode? = nil
    
    var previewTexture      : MTLTexture! = nil
    var isoCubePreviewTop   : MTLTexture! = nil
    var isoCubePreviewLeft  : MTLTexture! = nil
    var isoCubePreviewRight : MTLTexture! = nil

    // For connecting terminals
    var connectingNode      : TileNode? = nil

    var graphZoom           : Float = 0.63
    var graphOffset         = float2(0, 0)

    var dragStart           = float2(0, 0)
    var mouseMovedPos       : float2? = nil
        
    var firstDraw           = true
        
    let isoCubeSize         : Int = 80

    var isoCubeNormalArray  : Array<SIMD4<Float>>
        
    init(_ core: Core)
    {
        self.core = core
        view = core.nodesView
        drawables = MetalDrawables(core.nodesView)
        
        previewTexture = core.renderer.allocateTexture(view.device!, width: isoCubeSize, height: isoCubeSize)
        isoCubePreviewTop = core.renderer.allocateTexture(view.device!, width: isoCubeSize, height: isoCubeSize)
        isoCubePreviewLeft = core.renderer.allocateTexture(view.device!, width: isoCubeSize, height: isoCubeSize)
        isoCubePreviewRight = core.renderer.allocateTexture(view.device!, width: isoCubeSize, height: isoCubeSize)

        isoCubeNormalArray =  Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: isoCubeSize * isoCubeSize)
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.renderIsoCube()
        }        
    }
    
    func getCurrentTile() -> Tile? {
        return core.project.currentTileSet?.openTile
    }
    
    func draw()
    {
        guard let tile = getCurrentTile() else {
            return
        }
        
        drawables.encodeStart()
        
        drawables.drawBoxPattern(position: float2(0,0), size: drawables.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        let skin = NodeSkin(drawables.font, fontScale: 0.4, graphZoom: graphZoom)

        let nodes = getNodes(tile)

        for node in nodes {
            drawNode(node, node === currentNode, skin)
        }
        
        // Draw live connection line
        if action == .DragConnect {
            if let currentNode = currentNode {
                if let mouseMovedPos = mouseMovedPos {
                    let x = currentNode.nodePreviewRect.right()
                    let y = currentNode.nodePreviewRect.middle().y
                    drawables.drawLine(startPos: float2(x,y), endPos: mouseMovedPos, radius: 2 * graphZoom, fillColor: skin.selectedBorderColor)
                }
            }
        }
        
        // Draw Connections
        for node in nodes {
            for (index, nodeUUIDs) in node.terminalsOut {
                for nodeUUID in nodeUUIDs {
                    if let connTo = tile.getNodeById(nodeUUID) {
                        let dRect = getTerminal(connTo, id: -1)
                        let sRect = getTerminal(node, id: index)
                        
                        if sRect.x != 0.0 && sRect.y != 0.0 {
                            let color = terminalOutColor(node, index, skin, false).0
                            //drawables.drawLine(startPos: sRect.middle(), endPos: dRect.middle(), radius: 1, fillColor: color)
                            let p1 = sRect.middle()
                            let p3 = dRect.middle()
                            let p2 = (p1 + p3) / 2.0
                            drawables.drawBezier(p1: p1, p2: p1 + float2(20, 0) * graphZoom, p3: p2, width: 1.5 * graphZoom, fillColor: color)
                            drawables.drawBezier(p1: p2, p2: p3 - float2(20, 0) * graphZoom, p3: p3, width: 1.5 * graphZoom, fillColor: color)
                        }
                    }
                }
            }
        }
        
        drawables.encodeEnd()
    }
    
    // Returns the nodes for the current screen mode
    func getNodes(_ tile: Tile) -> [TileNode]
    {
        if let screen = core.project.getCurrentScreen() {
            if screen.gridType == .rectFront {
                return tile.nodes
            } else
            if screen.gridType == .rectIso {
                return tile.isoNodes
            }
        }
        return []
    }
    
    // Sets the nodes for the current screen mode
    func setNodes(_ tile: Tile,_ nodes: [TileNode])
    {
        if let screen = core.project.getCurrentScreen() {
            if screen.gridType == .rectFront {
                tile.nodes = nodes
            } else
            if screen.gridType == .rectIso {
                tile.isoNodes = nodes
            }
        }
    }
    
    // Gets the terminal rect for the given node and id
    func getTerminal(_ node: TileNode, id: Int) -> MMRect
    {
        if id == -1 {
            return node.terminalInRect
        } else {
            return node.terminalsOutRect[id]
        }
    }
    
    func getNodeColor(_ node: TileNode,_ skin: NodeSkin) -> float4
    {
        var color = skin.normalInteriorColor
        
        if node.role == .Tile {
            color = skin.tileColor
        } else
        if node.role == .Shape {
            color = skin.shapeColor
        } else
        if node.role == .Modifier {
            color = skin.modifierColor
        } else
        if node.role == .Decorator {
            color = skin.decoratorColor
        } else
        if node.role == .Pattern {
            color = skin.patternColor
        }
        return color
    }
    
    /// Get the colors for an out terminal
    func terminalOutColor(_ node: TileNode,_ terminalId: Int, _ skin: NodeSkin,_ selected: Bool) -> (float4, float4)
    {
        var fillColor = skin.normalInteriorColor
        var borderColor = skin.normalBorderColor
        
        if node.role == .Tile {
            if terminalId == 0 {
                fillColor = skin.shapeColor
            }
        } else
        if node.role == .IsoTile {
            fillColor = skin.shapeColor
            if let isoNode = node as? IsoTiledNode {
                if terminalId == isoNode.isoFace.rawValue {
                    borderColor = skin.selectedBorderColor
                }
            }
        } else
        if node.role == .Shape {
            if terminalId == 0 {
                fillColor = skin.modifierColor
            } else
            if terminalId == 1 {
                fillColor = skin.decoratorColor
            } else
            if terminalId == 2 {
                fillColor = skin.shapeColor
            }
        } else
        if node.role == .Decorator {
            if terminalId == 0 {
                fillColor = skin.modifierColor
            } else
            if terminalId == 1 {
                fillColor = skin.decoratorColor
            }
        } else
        if node.role == .Pattern {
            if terminalId == 0 {
                fillColor = skin.modifierColor
            } else
            if terminalId == 1 {
                fillColor = skin.decoratorColor
            }
        }
        
        //if selected {
            //borderColor = skin.selectedBorderColor
        //}
        
        return (fillColor, borderColor)
    }
    
    func drawNode(_ node: TileNode,_ selected: Bool,_ skin: NodeSkin)
    {
        let rect = MMRect()
                
        let nodePos = node.readFloat2("nodePos")
        
        rect.x = drawables.viewSize.x / 2 + nodePos.x * graphZoom
        rect.y = drawables.viewSize.y / 2 + nodePos.y * graphZoom
        rect.width = 120 * graphZoom
        
        let nodeHeight : Float = 120
        rect.height = nodeHeight * graphZoom
        
        rect.x -= rect.width / 2
        rect.y -= rect.height / 2

        rect.x += graphOffset.x
        rect.y += graphOffset.y
        
        node.nodeRect.copy(rect)
        
        let nodeColor = getNodeColor(node, skin)

        //drawables.drawBox.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: item.rect.width, height: item.rect.height, round: 12 * graphZoom, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalInteriorColor)
        drawables.drawBox(position: rect.position(), size: rect.size(), rounding: 8 * graphZoom, borderSize: 1, fillColor: nodeColor, borderColor: selected ? skin.selectedBorderColor : skin.normalInteriorColor)
        drawables.drawText(position: rect.position() + float2(9, 5) * graphZoom, text: node.name, size: 15 * graphZoom, color: skin.normalTextColor)
        
        drawables.drawLine(startPos: rect.position() + float2(6,24) * graphZoom, endPos: rect.position() + float2(rect.width - 8 * graphZoom, 24 * graphZoom), radius: 0.6, fillColor: skin.normalTextColor)
        
        let previewPos = rect.position() + float2(20,34) * graphZoom
        let previewSize = float2(80,80) * graphZoom
        var borderColor = float4(0,0,0,0)
        let borderSize : Float = 2 * graphZoom
        if action == .DragConnect && (node === currentNode || node === connectingNode) {
            borderColor = skin.selectedBorderColor
        }
        
        node.nodePreviewRect = MMRect(previewPos.x, previewPos.y, previewSize.x, previewSize.y)
        if node.role != .IsoTile {
            if node.texture != nil {
                drawables.drawBox(position: previewPos, size: previewSize, rounding: 8 * graphZoom, borderSize: borderSize, fillColor: skin.normalInteriorColor, borderColor: borderColor, texture: node.texture)
            }
        } else
        if let isoNode = node as? IsoTiledNode {
            /// Iso Cube
            var texture : MTLTexture? = nil
            if isoNode.isoFace == .Top {
                texture = isoCubePreviewTop
            } else
            if isoNode.isoFace == .Left {
                texture = isoCubePreviewLeft
            }
            if isoNode.isoFace == .Right {
                texture = isoCubePreviewRight
            }
            
            if let texture = texture {
                drawables.drawBox(position: previewPos, size: previewSize, rounding: 8 * graphZoom, borderSize: borderSize, fillColor: skin.normalInteriorColor, borderColor: borderColor, texture: texture)
            }
        }
        
        /// Get the colors for a terminal
        func terminalInColor() -> (float4, float4)
        {
            let fillColor = node.role != .Pattern ? getNodeColor(node, skin) : skin.shapeColor
            var borderColor = skin.normalBorderColor
            
            if selected {
                borderColor = skin.selectedBorderColor
            }
            
            return (fillColor, borderColor)
        }
        
        func drawInTerminal()
        {
            let tColors = terminalInColor()
            let x = rect.x - 7 * graphZoom
            drawables.drawDisk(position: float2(x, y), radius: 7 * graphZoom, borderSize: 1, fillColor: tColors.0, borderColor: tColors.1)
            node.terminalInRect.set(x, y, 14 * graphZoom, 14 * graphZoom)
            //let textWidth = drawables.getTextWidth(text: name, size: 15 * graphZoom)
            //drawables.drawText(position: float2(x, y) - float2(5, 0) * graphZoom - float2(textWidth, 0), text: name, size: 15 * graphZoom, color: skin.normalTextColor)
        }
        
        func drawOutTerminal(_ index: Int,_ y: Float)
        {
            let tColors = terminalOutColor(node, index, skin, selected )
            let x = rect.x + rect.width - 7 * graphZoom
            drawables.drawDisk(position: float2(x, y), radius: 7 * graphZoom, borderSize: 1, fillColor: tColors.0, borderColor: tColors.1)
            node.terminalsOutRect[index].set(x, y, 14 * graphZoom, 14 * graphZoom)
        }
        
        var y = rect.y + 32 * graphZoom
        
        if node.role == .Tile {
            drawOutTerminal(0, y)
        } else
        if node.role == .Shape {
            drawInTerminal()
            drawOutTerminal(0, y)
            y += 24 * graphZoom
            drawOutTerminal(1, y)
            y += 36 * graphZoom
            drawOutTerminal(2, y)
        } else
        if node.role == .Modifier {
            drawInTerminal()
        } else
        if node.role == .Decorator {
            drawInTerminal()
            drawOutTerminal(0, y)
            y += 24 * graphZoom
            drawOutTerminal(1, y)
        } else
        if node.role == .Pattern {
            drawInTerminal()
            drawOutTerminal(0, y)
            y += 24 * graphZoom
            drawOutTerminal(1, y)
        } else
        if node.role == .IsoTile {
            drawOutTerminal(0, y)
            y += 24 * graphZoom
            drawOutTerminal(1, y)
            y += 24 * graphZoom
            drawOutTerminal(2, y)
        }
    }
    
    func setCurrentNode(_ node: TileNode?) {
        if node !== currentNode {
            currentNode = node
            core.tileNodeChanged.send(node)
            core.screenView.update()
        }
    }
    
    /// Check if there is a terminal at the given position
    func checkForNodeTerminal(_ node: TileNode, at: float2) -> Int?
    {
        for (index, slot) in node.terminalsOutRect.enumerated() {
            if slot.contains(at.x, at.y) {
                return index
            }
        }
        
        if node.terminalInRect.contains(at.x, at.y) {
            return -1
        }
        
        return nil
    }
    
    /// Called before nodes get deleted, make sure to break its connections
    @discardableResult func nodeIsAboutToBeDeleted(_ node: TileNode) -> Bool
    {
        guard let tile = getCurrentTile() else {
            return false
        }
        
        let nodes = getNodes(tile)
        for n in nodes {
            if n !== node {
                for (index, nodeUUIDs) in n.terminalsOut {
                    // TODO
                    for nodeUUID in nodeUUIDs {
                        if nodeUUID == node.id {
                            var t = n.terminalsOut[index]!
                            if t.count == 1 {
                                n.terminalsOut[index] = []
                            } else {
                                if let i = t.firstIndex(of: node.id) {
                                    t.remove(at: i)
                                    n.terminalsOut[index] = t
                                }
                            }
                            return true
                        }
                    }
                }
            }
        }
        setNodes(tile, nodes)
        return false
    }
    
    func touchDown(_ pos: float2)
    {
        if view.hasDoubleTap == true {
            if let tile = getCurrentTile() {
                let nodes = getNodes(tile)
                for node in nodes {
                    if node.nodePreviewRect.contains(pos.x, pos.y) {
                        core.startTileUndo(tile, "Node Disconnected")
                        if nodeIsAboutToBeDeleted(node) {
                            core.updateTileAndNodesPreviews()
                            tile.setHasChanged(true)
                            core.renderer.render()
                            update()
                            core.currentTileUndo?.end()
                        } else {
                            core.currentTileUndo = nil
                        }
                    }
                }
            }
            return
        }
        
        connectingNode = nil
        if let tile = getCurrentTile() {
            let nodes = getNodes(tile)
            for node in nodes {
                var freshlySelectedNode : TileNode? = nil
                if node.nodeRect.contains(pos.x, pos.y) {
                    
                    if let isoNode = node as? IsoTiledNode {
                        // Click on Iso Cube
                        
                        let x = ((pos.x - node.nodeRect.x) / node.nodeRect.width) * Float(isoCubeSize)
                        let y = ((pos.y - node.nodeRect.y) / node.nodeRect.height) * Float(isoCubeSize)
                        
                        let xInt : Int = Int(x)
                        let yInt : Int = Int(y)
                                                
                        let n = isoCubeNormalArray[yInt * isoCubeSize + xInt]
                        
                        if (n.z > 0.5) {
                            isoNode.isoFace = .Left
                        } else
                        if (n.y > 0.5) {
                            isoNode.isoFace = .Top
                        } else
                        if (n.x > 0.5) {
                            isoNode.isoFace = .Right
                        }
                    }
                    
                    action = .DragNode
                    dragStart = pos
                    
                    freshlySelectedNode = node
                    
                    if freshlySelectedNode!.nodePreviewRect.contains(pos.x, pos.y) {
                        action = .DragConnect
                    }
                }
                
                if freshlySelectedNode != nil && currentNode !== freshlySelectedNode {
                    setCurrentNode(freshlySelectedNode!)
                }
            }
        }
        
        drawables.update()
    }
    
    func touchDragged(_ pos: float2)
    {
        mouseMovedPos = pos
        connectingNode = nil

        if action == .DragNode {
            if let node = currentNode {
                node.values["nodePos_x"]! += (pos.x - dragStart.x) / graphZoom
                node.values["nodePos_y"]! += (pos.y - dragStart.y) / graphZoom
                dragStart = pos
                update()
            }
        } else
        if action == .DragConnect {
            
            func canConnect(_ from: TileNode,_ to: TileNode) -> Bool
            {
                if from.role == .Tile {
                    if to.role == .Shape {
                        return true
                    } else
                    if to.role == .Pattern {
                        return true
                    }
                } else
                if from.role == .IsoTile {
                    if to.role == .Shape {
                        return true
                    }
                } else
                if from.role == .Shape {
                    if to.role == .Modifier {
                        return true
                    } else
                    if to.role == .Decorator {
                        return true
                    } else
                    if to.role == .Shape || to.role == .Pattern {
                        return true
                    }
                } else
                if from.role == .Decorator {
                    if to.role == .Modifier {
                        return true
                    } else
                    if to.role == .Decorator {
                        return true
                    }
                } else
                if from.role == .Pattern {
                    if to.role == .Modifier {
                        return true
                    } else
                    if to.role == .Decorator {
                        return true
                    }
                }
                return false
            }
            
            if let tile = getCurrentTile() {
                let nodes = getNodes(tile)
                for node in nodes {
                    if node !== currentNode && node.nodePreviewRect.contains(pos.x, pos.y) && canConnect(currentNode!, node) {
                        connectingNode = node
                        
                        mouseMovedPos!.x = node.nodePreviewRect.x
                        mouseMovedPos!.y = node.nodePreviewRect.middle().y
                    }
                }
            }
            update()
        }
    }

    func touchUp(_ pos: float2)
    {
        if action == .DragConnect && connectingNode != nil {
            let from = currentNode!
            let to = connectingNode!
            
            core.startTileUndo(getCurrentTile()!, "Node Connect")
            
            /// Adds the given id to the given terminalsOut index
            func addIdToTerminalIndex(_ index: Int,_ id: UUID)
            {
                if var t = from.terminalsOut[index] {
                    t.append(id)
                    from.terminalsOut[index] = t
                } else {
                    from.terminalsOut[index] = [id]
                }
            }
            
            if from.role == .Tile {
                if to.role == .Shape {
                    addIdToTerminalIndex(0, to.id)
                } else
                if to.role == .Pattern {
                    addIdToTerminalIndex(0, to.id)
                }
            } else
            if from.role == .IsoTile {
                if to.role == .Shape {
                    if let isoNode = from as? IsoTiledNode {
                        addIdToTerminalIndex(isoNode.isoFace.rawValue, to.id)
                    }
                }
            }
            if from.role == .Shape {
                if to.role == .Modifier {
                    addIdToTerminalIndex(0, to.id)
                } else
                if to.role == .Decorator {
                    addIdToTerminalIndex(1, to.id)
                } else
                if to.role == .Shape || to.role == .Pattern {
                    addIdToTerminalIndex(2, to.id)
                }
            } else
            if from.role == .Decorator {
                if to.role == .Modifier {
                    addIdToTerminalIndex(0, to.id)
                } else
                if to.role == .Decorator {
                    addIdToTerminalIndex(1, to.id)
                }
            } else
            if from.role == .Pattern {
                if to.role == .Modifier {
                    addIdToTerminalIndex(0, to.id)
                } else
                if to.role == .Decorator {
                    addIdToTerminalIndex(1, to.id)
                }
            }
            
            core.currentTileUndo?.end()
            
            core.updateTileAndNodesPreviews()
            getCurrentTile()!.setHasChanged(true)
            core.renderer.render()
            update()
        }
        action = .None
        mouseMovedPos = nil
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
    
    /// Returns true if the two terminals can connect
    func canConnect(_ node1: TileNode,_ terminal1: Int,_ node2: TileNode,_ terminal2: Int) -> Bool
    {
        func canTerminalsConnect(_ outNode: TileNode,_ outIndex: Int,_ inNode: TileNode,_ inIndex: Int) -> Bool
        {
            if outNode.role == .Tile {
                if inNode.role == .Shape {
                    if outIndex == 0 {
                        return true
                    }
                }
            } else
            if outNode.role == .Shape {
                if inNode.role == .Modifier {
                    if outIndex == 0 {
                        return true
                    }
                } else
                if inNode.role == .Decorator {
                    if outIndex == 1 {
                        return true
                    }
                } else
                if inNode.role == .Shape {
                    if outIndex == 2 {
                        return true
                    }
                }
            } else
            if outNode.role == .Decorator {
                if inNode.role == .Modifier {
                    if outIndex == 0 {
                        return true
                    }
                }
                if inNode.role == .Decorator {
                    if outIndex == 1 {
                        return true
                    }
                }
            }
            return false
        }
        
        if terminal1 == -1 {
            return canTerminalsConnect(node2, terminal2, node1, terminal1)
        } else {
            return canTerminalsConnect(node1, terminal1, node2, terminal2)
        }
    }
    
    /// Updates the display
    func update() {
        drawables.update()
    }
}
