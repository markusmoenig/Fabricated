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
    enum DrawingTool {
        case Select, Apply, Clear
    }
    
    var currentTool     : DrawingTool = .Select
    
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
    
    // Preview Rendering
    var semaphore       : DispatchSemaphore!
    var dispatchGroup   : DispatchGroup!
    
    var isRunning       : Bool = false
    var stopRunning     : Bool = false

    init()
    {
        project = Project()
                
        let screen = Screen("Screen #1")
        let layer = Layer("Main Layer")
        
        screen.layers.append(layer)
        
        let tileSet = TileSet("Tiles #1")
        let tile = Tile("Tile")
        let tiledNode = TiledNode()
        
        tileSet.tiles.append(tile)
        tile.nodes.append(tiledNode)
        
        project.screens.append(screen)
        project.tileSets.append(tileSet)
            
        project.currentLayer = layer
        project.currentTileSet = tileSet
        
        tileSetChanged.send(tileSet)
        
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
        
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
    
    // MARK: Node and Tile preview rendering
    
    /// Updates the node previews for the given tile
    func updateTilePreviews(_ tile: Tile)
    {
        stopUpdateThread()
        
        stopRunning = false
        isRunning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.dispatchGroup.enter()
            self.renderTilePreview(tile)
        }
    }
    
    /// Updates the node previews for the current tile
    func updateTilePreviews()
    {
        guard let tile = project.currentTileSet?.openTile else {
            return
        }
        
        updateTilePreviews(tile)
    }
    
    /// Updates the node previews for the given tileset
    func updateTileSetPreviews(_ tileSet: TileSet)
    {
        stopUpdateThread()
        
        stopRunning = false
        isRunning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.dispatchGroup.enter()
            for tile in tileSet.tiles {
                if self.stopRunning == false {
                    self.renderTilePreview(tile, singleShot: false)
                }
            }
            self.dispatchGroup.leave()
            //DispatchQueue.main.async {
            print("finished")
            DispatchQueue.main.async {
                self.tileSetChanged.send(tileSet)
            }
        }
    }
    
    /// Updates the node previews for the current tileset
    func updateTileSetPreviews()
    {
        guard let tileSet = project.currentTileSet else {
            return
        }
        
        updateTileSetPreviews(tileSet)
    }
    
    /// Renders the tile previews in a separate thread
    func renderTilePreview(_ tile: Tile, singleShot: Bool = true)
    {
        print("render update for tile", tile.name)
        
        let tileSize = 80
        
        func updateTexture(_ texture: MTLTexture,_ a: Array<SIMD4<Float>>)
        {
            var array = a
            
            semaphore.wait()
            let region = MTLRegionMake2D(tileRect.x, tileRect.y, tileRect.width, tileRect.height)
            
            array.withUnsafeMutableBytes { texArrayPtr in
                texture.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * tileRect.width))
            }
            
            if let _ = self.project.currentTileSet?.openTile {
                DispatchQueue.main.async {
                    if let _ = self.project.currentTileSet?.openTile {
                        self.nodeView.update()
                    }
                }
            }
            
            semaphore.signal()
        }
                
        let tileContext = TileContext()
        tileContext.layer = nil
        tileContext.pixelSize = project.getPixelSize()
        tileContext.antiAliasing = project.getAntiAliasing()
        tileContext.tile = renderer.copyTile(tile)
        tileContext.tileInstance = TileInstance(UUID(), UUID())
        
        let tileRect = TileRect(0, 0, tileSize, tileSize)
        
        let width: Float = Float(tileSize)
        let height: Float = Float(tileSize)
                                
        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tileRect.size)
            
        for node in tile.nodes {
            
            // Always render the Tile preview, the other nodes only if the tile is currently shown
            if (node.role != .Tile && project.currentTileSet?.openTile !== tile) || stopRunning {
                break
            }
         
            for h in tileRect.y..<tileRect.bottom {

                if stopRunning {
                    break
                }
                
                for w in tileRect.x..<tileRect.right {
                    
                    if stopRunning {
                        break
                    }
                    
                    let pixelContext = TilePixelContext(texOffset: float2(Float(w), Float(h)), texWidth: width, texHeight: height, tileRect: tileRect)
                    
                    var color = float4(0, 0, 0, 0)
                    
                    let tile = tileContext.tile!
                    
                    if node.role == .Tile {
                        var node = tile.getNextInChain(tile.nodes[0], .Shape)
                        while node !== nil {
                            color = node!.render(pixelCtx: pixelContext, tileCtx: tileContext, prevColor: color)
                            node = tile.getNextInChain(node!, .Shape)
                        }
                    } else {
                        color = node.render(pixelCtx: pixelContext, tileCtx: tileContext, prevColor: color)
                    }

                    texArray[(h - tileRect.y) * tileRect.width + w - tileRect.x] = color.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                }
            }
            
            if stopRunning == false {
                if node.texture == nil {
                    node.texture = renderer.allocateTexture(device, width: tileSize, height: tileSize)
                }
                updateTexture(node.texture!, texArray)
                
                if node.role == .Tile {
                    if let tiled = node as? TiledNode {
                        tiled.cgiImage = createCGIImage(texArray, tileSize)
                    }
                }
            }
        }

        if singleShot {
            dispatchGroup.leave()
        }
    }
    
    /// Stops the preview rendering thread
    func stopUpdateThread()
    {
        stopRunning = true
        dispatchGroup.wait()
    }
    
    /// Creates an CGIImage from an float4 array
    func createCGIImage(_ array: Array<SIMD4<Float>>,_ tileSize: Int) -> CGImage?
    {
        struct PixelData {
            let r: UInt8
            let g: UInt8
            let b: UInt8
            let a: UInt8
        }
        
        let data = array.map { pixel -> PixelData in
            let red = UInt8(pixel.x * 255)
            let green = UInt8(pixel.y * 255)
            let blue = UInt8(pixel.z * 255)
            let alpha = UInt8(pixel.w * 255)
            return PixelData(r: red, g: green, b: blue, a: alpha)
        }.withUnsafeBytes { Data($0) }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bitsPerComponent = 8
        let bitsPerPixel = 32

        guard
            let providerRef = CGDataProvider(data: data as CFData),
            let cgImage = CGImage(width: tileSize,
                                  height: tileSize,
                                  bitsPerComponent: bitsPerComponent,
                                  bitsPerPixel: bitsPerPixel,
                                  bytesPerRow: tileSize * MemoryLayout<PixelData>.stride,
                                  space: rgbColorSpace,
                                  bitmapInfo: bitmapInfo,
                                  provider: providerRef,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: .defaultIntent)
        else {
            return nil
        }
        
        return cgImage
    }
}
