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
    
    var screenView      : ScreenView!
    var nodeView        : NodeView!
    
    /// Send when the current tile node in the NodeView changed
    let tileNodeChanged = PassthroughSubject<TileNode?, Never>()
    
    let screenChanged = PassthroughSubject<Screen?, Never>()
    let layerChanged = PassthroughSubject<Layer?, Never>()

    let tileSetChanged = PassthroughSubject<TileSet?, Never>()

    init()
    {
        project = Project()
                
        let screen = Screen("Screen #1")
        let layer = Layer("Main Layer")
        
        screen.layers.append(layer)
        
        let tileSet = TileSet("Tiles #1")
        let tile = Tile("Test")
        let tiledNode = TiledNode()
        
        tileSet.tiles.append(tile)
        tile.nodes.append(tiledNode)
        
        project.screens.append(screen)
        project.tileSets.append(tileSet)
            
        project.currentLayer = layer
        project.currentTileSet = tileSet
        
        tileSetChanged.send(tileSet)
        
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

        screenView = ScreenView(self)

        view.platformInit()
    }
    
    public func setupNodesView(_ view: DMTKView)
    {
        view.platformInit()

        nodesView = view
        view.core = self
        
        nodeView = NodeView(self)
    }
    
    // Called when the preview needs to be drawn
    public func drawPreview()
    {
        screenView.draw()
    }
    
    // Called when the nodes have to be drawn
    public func drawNodes()
    {
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
