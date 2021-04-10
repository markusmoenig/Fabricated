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
    var drawablesView   : MetalDrawables!
    var drawablesNodes  : MetalDrawables!

    var scaleFactor     : Float

    var textureLoader   : MTKTextureLoader!

    var project         : Project
    var renderer        : Renderer!
    
    init()
    {
        project = Project()
        
        let tile = Tile("Test")
        let discNode = ShapeDisk()
        
        tile.nodes.append(discNode)
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
        drawablesView = MetalDrawables(view)
        renderer = Renderer(self)
        
        renderer.render()
        
        textureLoader = MTKTextureLoader(device: device)

        view.platformInit()
    }
    
    public func setupNodesView(_ view: DMTKView)
    {
        view.platformInit()

        nodesView = view
        view.core = self
        
        drawablesNodes = MetalDrawables(nodesView)

        //nodesWidget = NodesWidget(self)
    }
    
    // Called when the preview needs to be drawn
    public func drawPreview()
    {
        drawablesView.encodeStart()
        
        drawablesView.drawBoxPattern(position: float2(0,0), size: drawablesView.viewSize, fillColor: float4(0.12, 0.12, 0.12, 1), borderColor: float4(0.14, 0.14, 0.14, 1))
        
        //if renderer.checkIfTextureIsValid(self) == false {
        //            return
        //}
        
        if let texture = renderer.texture {
            drawablesView.drawBox(position: float2(0,0), size: float2(Float(texture.width), Float(texture.height)), texture: texture)
        }

        drawablesView.encodeEnd()
    }
    
    // Called when the nodes have to be drawn
    public func drawNodes()
    {
        
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
