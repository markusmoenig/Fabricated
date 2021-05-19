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
    
    enum IsoFace {
        case Top, Left, Right
    }
    
    var action              : Action = .None
    var isoFace             : IsoFace = .Left
    
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
        
        DispatchQueue.global(qos: .userInitiated).async {
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
            for (index, nodeUUID) in node.terminalsOut {
                if let connTo = tile.getNodeById(nodeUUID) {
                    let dRect = getTerminal(connTo, id: -1)
                    let sRect = getTerminal(node, id: index)
                    
                    if sRect.x != 0.0 && sRect.y != 0.0 {
                        let color = terminalOutColor(node, index, skin, false).0
                        drawables.drawLine(startPos: sRect.middle(), endPos: dRect.middle(), radius: 1, fillColor: color)
                    }
                }
            }
        }
        
        if core.project.getCurrentScreen()?.gridType == .rectIso {
            var texture : MTLTexture? = nil
            if isoFace == .Top {
                texture = isoCubePreviewTop
            } else
            if isoFace == .Left {
                texture = isoCubePreviewLeft
            }
            if isoFace == .Right {
                texture = isoCubePreviewRight
            }
            
            if let texture = texture {
                drawables.drawBox(position: drawables.viewSize - float2(Float(texture.width), Float(texture.height)), size: float2(Float(texture.width), Float(texture.height)), rounding: 0, borderSize: 0, fillColor: float4(1,1,1,1), texture: texture)
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
                if isoFace == .Top {
                    tile.isoNodesTop[0].name = "Iso Top"
                    return tile.isoNodesTop
                } else
                if isoFace == .Left {
                    tile.isoNodesLeft[0].name = "Iso Left"
                    return tile.isoNodesLeft
                } else
                if isoFace == .Right {
                    tile.isoNodesRight[0].name = "Iso Right"
                    return tile.isoNodesRight
                }
            }
        }
        return []
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
        }
        
        if selected {
            borderColor = skin.selectedBorderColor
        }
        
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
        if node.texture != nil {
            drawables.drawBox(position: previewPos, size: previewSize, rounding: 8 * graphZoom, borderSize: borderSize, fillColor: skin.normalInteriorColor, borderColor: borderColor, texture: node.texture)
        }
        
        /// Get the colors for a terminal
        func terminalInColor() -> (float4, float4)
        {
            let fillColor = getNodeColor(node, skin)
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
                for (index, nodeUUID) in n.terminalsOut {
                    if nodeUUID == node.id {
                        n.terminalsOut[index] = nil
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func touchDown(_ pos: float2)
    {
        // Click on Iso Cube ?
        if let screen = core.project.getCurrentScreen() {
            if screen.gridType == .rectIso {
                let corner = drawables.viewSize - Float(isoCubeSize)
                if pos.x > corner.x && pos.y > corner.y {

                    let x : Int = Int(pos.x - corner.x)
                    let y : Int = Int(pos.y - corner.y)
                    
                    let n = isoCubeNormalArray[y * isoCubeSize + x]
                    
                    if (n.z > 0.5) {
                        isoFace = .Left
                        update()
                    } else
                    if (n.y > 0.5) {
                        isoFace = .Top
                        update()
                    } else
                    if (n.x > 0.5) {
                        isoFace = .Right
                        update()
                    }
                    
                    return
                }
            }
        }
        
        if view.hasDoubleTap == true {
            if let tile = getCurrentTile() {
                let nodes = getNodes(tile)
                for node in nodes {
                    if node.nodePreviewRect.contains(pos.x, pos.y) {
                        core.startTileUndo(tile, "Node Disconnected")
                        if nodeIsAboutToBeDeleted(node) {
                            core.updateTilePreviews()
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
    
    func touchMoved(_ pos: float2)
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
                    }
                } else
                if from.role == .Shape {
                    if to.role == .Modifier {
                        return true
                    } else
                    if to.role == .Decorator {
                        return true
                    } else
                    if to.role == .Shape {
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
            
            if from.role == .Tile {
                if to.role == .Shape {
                    from.terminalsOut[0] = to.id
                }
            } else
            if from.role == .Shape {
                if to.role == .Modifier {
                    from.terminalsOut[0] = to.id
                } else
                if to.role == .Decorator {
                    from.terminalsOut[1] = to.id
                } else
                if to.role == .Shape {
                    from.terminalsOut[2] = to.id
                }
            } else
            if from.role == .Decorator {
                if to.role == .Modifier {
                    from.terminalsOut[0] = to.id
                } else
                if to.role == .Decorator {
                    from.terminalsOut[1] = to.id
                }
            }
            
            core.currentTileUndo?.end()
            
            core.updateTilePreviews()
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
    
    func renderIsoCube()
    {
        let width  : Float = Float(previewTexture.width)
        let height : Float = Float(previewTexture.height)
        
        let widthInt  = previewTexture.width
        let heightInt = previewTexture.height
        
        let AA = 2
        
        func sdBox(_ p: float3) -> Float
        {
            let size = float3(1,1,1)
            let q : float3 = abs(p - float3(0,0,0)) - size
            return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0)
        }
        
        func calcNormal(position: float3) -> float3
        {
            /*
            vec3 epsilon = vec3(0.001, 0., 0.);
            
            vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                          map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                          map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
            
            return normalize(n);*/

            let e = float3(0.001, 0.0, 0.0)

            var eOff : float3 = position + float3(e.x, e.y, e.y)
            var n1 = sdBox(eOff)
            
            eOff = position - float3(e.x, e.y, e.y)
            n1 = n1 - sdBox(eOff)
            
            eOff = position + float3(e.y, e.x, e.y)
            var n2 = sdBox(eOff)
            
            eOff = position - float3(e.y, e.x, e.y)
            n2 = n2 - sdBox(eOff)
            
            eOff = position + float3(e.y, e.y, e.x)
            var n3 = sdBox(eOff)
            
            eOff = position - float3(e.y, e.y, e.x)
            n3 = n3 - sdBox(eOff)
            
            return simd_normalize(float3(n1, n2, n3))
        }
        
        var isoTopArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
        var isoLeftArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
        var isoRightArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
                
        for h in 0..<heightInt {

            let fh : Float = Float(h) / height
            for w in 0..<widthInt {
                
                let uv = float2(Float(w) / width, fh)

                var total = float4(0,0,0,0)
                var totalIsoTop = float4(0,0,0,0)
                var totalIsoLeft = float4(0,0,0,0)
                var totalIsoRight = float4(0,0,0,0)
                var totalIsoNormal = float4(0,0,0,0)

                for m in 0..<AA {
                    for n in 0..<AA {

                        let camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5

                        //func isoCamera(uv: float2, tileSize: float2, origin: float3, lookAt: float3, fov: Float, offset: float2) -> (float3, float3)

                        let camera = core.renderer.isoCamera(uv: uv, tileSize: float2(width, height), origin: float3(8,8,8), lookAt: float3(0,0,0), fov: 15.2, offset: camOffset)
                        
                        // Raymarch
                        var hit = false
                        var t : Float = 0.001;

                        for _ in 0..<70
                        {
                            let pos = camera.0 + t * camera.1
                            //executeSDF(camOrigin + t * camDir)

                            let d = sdBox(pos)
                            
                            if abs(d) < (0.0001*t) {
                                hit = true
                                break
                            } /*else
                            if t > maxDist {
                                break
                            }*/
                            
                            t += d
                        }
                        
                        if hit == true {
                            
                            let selectedColor : Float = 0.8
                            let normalColor : Float = 0.3

                            let normal = calcNormal(position: camera.0 + t * camera.1)
                            total.x += normal.x
                            total.y += normal.y
                            total.z += normal.z
                            total.w += 1
                            
                            totalIsoNormal.x += normal.x
                            totalIsoNormal.y += normal.y
                            totalIsoNormal.z += normal.z

                            totalIsoTop.w += 1
                            totalIsoLeft.w += 1
                            totalIsoRight.w += 1

                            if normal.y > 0.5 {
                                totalIsoTop.x += selectedColor
                                totalIsoTop.y += selectedColor
                                totalIsoTop.z += selectedColor
                            } else {
                                totalIsoTop.x += normalColor
                                totalIsoTop.y += normalColor
                                totalIsoTop.z += normalColor
                            }
                            
                            if normal.z > 0.5 {
                                totalIsoLeft.x += selectedColor
                                totalIsoLeft.y += selectedColor
                                totalIsoLeft.z += selectedColor
                            } else {
                                totalIsoLeft.x += normalColor
                                totalIsoLeft.y += normalColor
                                totalIsoLeft.z += normalColor
                            }
                            
                            if normal.x > 0.5 {
                                totalIsoRight.x += selectedColor
                                totalIsoRight.y += selectedColor
                                totalIsoRight.z += selectedColor
                            } else {
                                totalIsoRight.x += normalColor
                                totalIsoRight.y += normalColor
                                totalIsoRight.z += normalColor
                            }
                        }
                    }
                }
                
                isoTopArray[h * widthInt + w] = totalIsoTop / Float(AA*AA)
                isoLeftArray[h * widthInt + w] = totalIsoLeft / Float(AA*AA)
                isoRightArray[h * widthInt + w] = totalIsoRight / Float(AA*AA)
                
                isoCubeNormalArray[h * widthInt + w] = totalIsoNormal / Float(AA*AA)
            }
        }
        
        DispatchQueue.main.sync {
            let region = MTLRegionMake2D(0, 0, widthInt, heightInt)
            
            // Iso Top
            isoTopArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewTop.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            // Iso Left
            isoLeftArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewLeft.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            // Iso Right
            isoRightArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewRight.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            drawables.update()
        }
    }
}
