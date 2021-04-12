//
//  Core.swift
//  Fabricated
//
//  Created by Markus Moenig on 7/4/21.
//

import MetalKit
import Combine
import AVFoundation

class Core
{
    var view            : DMTKView!
    var device          : MTLDevice!

    var nodesView       : DMTKView!
    
    var metalStates     : MetalStates!
    var drawables       : MetalDrawables!

    var scaleFactor     : Float

    var textureLoader   : MTKTextureLoader!

    var project         : Project
    var renderer        : Renderer!
    var nodeView        : NodeView!
    
    /// Send when the current tile node in the NodeView changed
    let tileNodeChanged = PassthroughSubject<TileNode?, Never>()
    
    let screenChanged = PassthroughSubject<Screen?, Never>()
    let layerChanged = PassthroughSubject<Layer?, Never>()

    init()
    {
        project = Project()
        
        let tile = Tile("Test")
        let tileNode = TileNode(.Tile, "Tile")
        
        let screen = Screen("Screen #1")
        let layer = Layer("Main Layer")
        
        screen.layers.append(layer)

        tile.nodes.append(tileNode)
        
        project.screens.append(screen)
        project.tiles.append(tile)
                
        #if os(OSX)
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
        #else
        scaleFactor = Float(UIScreen.main.scale)
        #endif
    }
    
    /// Sets a loaded project
    func setProject(project: Project)
    {
        self.project = project
    }
    
    /// Setup the preview view
    public func setupView(_ view: DMTKView)
    {
        self.view = view
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            device = metalDevice
        } else {
            print("Cannot initialize Metal!")
        }
        view.core = self
        
        metalStates = MetalStates(self)
        drawables = MetalDrawables(view)
        renderer = Renderer(self)
                
        textureLoader = MTKTextureLoader(device: device)

        view.platformInit()
    }
    
    public func setupNodesView(_ view: DMTKView)
    {
        view.platformInit()

        nodesView = view
        view.core = self
        
        nodeView = NodeView(self)

        //nodesWidget = NodesWidget(self)
    }
    
    // Called when the preview needs to be drawn
    public func drawPreview()
    {
        drawables.encodeStart()
        
        drawables.drawBoxPattern(position: float2(0,0), size: drawables.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        //if renderer.checkIfTextureIsValid(self) == false {
        //            return
        //}
        
        if let texture = renderer.texture {
            drawables.drawBox(position: float2(0,0), size: float2(Float(texture.width), Float(texture.height)), texture: texture)
        }

        drawables.encodeEnd()
    }
    
    // Called when the nodes have to be drawn
    public func drawNodes()
    {
        nodeView.setCurrentTile(project.tiles[0])
        nodeView.draw()
    }
    
    /// Updates the display once
    var isUpdating : Bool = false
    func updatePreviewOnce()
    {
        if isUpdating == false {
            isUpdating = true
            #if os(OSX)
            let nsrect : NSRect = NSRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
            self.view.setNeedsDisplay(nsrect)
            #else
            self.view.setNeedsDisplay()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) {
                self.isUpdating = false
            }
        }
    }
}
