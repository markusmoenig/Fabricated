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
        case Select, Apply, Move, Resize, Clear
    }
    
    enum NodeContext {
        case Tile, Area
    }
    
    var currentTool     : DrawingTool = .Select
    var currentContext  : NodeContext = .Tile
    
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
    
    let screenChanged   = PassthroughSubject<Screen?, Never>()
    let layerChanged    = PassthroughSubject<Layer?, Never>()
    let areaChanged     = PassthroughSubject<Void, Never>()

    let tileSetChanged  = PassthroughSubject<TileSet?, Never>()

    let updateTools     = PassthroughSubject<Void, Never>()
    
    let startupSignal   = PassthroughSubject<Void, Never>()

    // Preview Rendering
    var semaphore       : DispatchSemaphore!
    var dispatchGroup   : DispatchGroup!
    
    var isRunning       : Bool = false
    var stopRunning     : Bool = false
    
    var undoManager     : UndoManager? = nil
    
    init()
    {
        project = Project()
                
        let screen = Screen("Screen #1")
        let layer = Layer("Main Layer")
        
        screen.layers.append(layer)
        
        let tileSet = TileSet("Tiles #1")
        let tile = Tile("Tile")
        
        tileSet.tiles.append(tile)
        
        project.screens.append(screen)
        project.tileSets.append(tileSet)
            
        project.currentLayer = layer
        project.currentTileSet = tileSet
        
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
        
        self.tileSetChanged.send(tileSet)

        #if os(OSX)
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
        #else
        scaleFactor = Float(UIScreen.main.scale)
        #endif
        
        // Send the startup signal to capture the undoManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startupSignal.send()
        }
    }
    
    /// Sets a loaded project
    func setProject(project: Project)
    {
        self.project = project
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateTileSetPreviews()
        }
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
        
        DispatchQueue.global(qos: .userInteractive).async {
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
        
        let gridType = project.getCurrentScreen()?.gridType

        DispatchQueue.global(qos: .utility).async {
            self.dispatchGroup.enter()
            for tile in tileSet.tiles {
                if self.stopRunning == false {
                    
                    if gridType == .rectFront {
                        self.renderTilePreview(tile, singleShot: false)
                    } else {
                        self.renderIsoTilePreview(tile, singleShot: false)
                    }
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
        tileContext.tile = copyTile(tile)
        tileContext.tileInstance = TileInstance(UUID(), UUID())
        tileContext.tileArea = TileInstanceArea(UUID(), UUID())
        tileContext.tileArea.area = SIMD4<Int>(0,0,1,1)
        
        tileContext.areaOffset = float2(0,0)
        tileContext.areaSize = float2(1, 1)
        tileContext.tileId = float2(0,0)
        
        let tileRect = TileRect(0, 0, tileSize, tileSize)
        
        let width: Float = Float(tileSize)
        let height: Float = Float(tileSize)
                                
        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tileRect.size)
        
        var nodes = tile.nodes
        
        if let nodeView = nodeView {
            nodes = nodeView.getNodes(tile)
        }
                
        for node in nodes {
            
            // Always render the Tile preview, the other nodes only if the tile is currently shown
            if ((node.role != .Tile || node.role != .IsoTile) && project.currentTileSet?.openTile !== tile) || stopRunning {
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
                    
                    let pixelContext = TilePixelContext(areaOffset: float2(Float(w), Float(h)), areaSize: float2(width, height), tileRect: tileRect)
                    pixelContext.preview = true
                    
                    var color = float4(0, 0, 0, 0)
                    
                    let tile = tileContext.tile!
                                        
                    if node.role == .Tile || node.role == .IsoTile {
                        var node = tile.getNextInChain(nodes[0], .Shape)

                        while node !== nil {
                            
                            color = node!.render(pixelCtx: pixelContext, tileCtx: tileContext, prevColor: color)
                            node = tile.getNextInChain(node!, .Shape)
                            
                            if stopRunning {
                                break
                            }
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
    
    /// Renders the is tile preview
    func renderIsoTilePreview(_ tile: Tile, singleShot: Bool = true)
    {
        print("render update for iso tile", tile.name)
        
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
        tileContext.tile = copyTile(tile)
        tileContext.tileInstance = TileInstance(UUID(), UUID())
        tileContext.tileArea = TileInstanceArea(UUID(), UUID())
        tileContext.tileArea.area = SIMD4<Int>(0,0,1,1)
        
        tileContext.areaOffset = float2(0,0)
        tileContext.areaSize = float2(1, 1)
        tileContext.tileId = float2(0,0)
        
        let tileRect = TileRect(0, 0, tileSize, tileSize)
                                
        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tileRect.size)
 
        let isoCubeRenderer = IsoCubeRenderer()
        
        let node = tile.isoNodes[0]

        let tileJob = TileJob(tileContext, tileRect)
        
        isoCubeRenderer.render(self, tileJob, &texArray)

        if stopRunning == false {
            if node.texture == nil {
                node.texture = renderer.allocateTexture(device, width: tileSize, height: tileSize)
            }
            updateTexture(node.texture!, texArray)
            
            if node.role == .IsoTile {
                if let tiled = node as? IsoTiledNode {
                    tiled.cgiImage = createCGIImage(texArray, tileSize)
                }
            }
        }

        if singleShot {
            dispatchGroup.leave()
        }
    }
    
    /// Copy a tile. Each thread during rendering gets a copy of the original tile to prevent race conditions
    func copyTile(_ tile: Tile) -> Tile {
        if let data = try? JSONEncoder().encode(tile) {
            if let copiedTile = try? JSONDecoder().decode(Tile.self, from: data) {
                return copiedTile
            }
        }
        return tile
    }
    
    func getAreaData(_ area: TileInstanceArea) -> (Int, Int, Array<float4>)?
    {
        let tileSize = Int(project.getTileSize())
        
        if let layer = project.currentLayer {
            let rect = area.area
            
            let width = rect.z * tileSize
            let height = rect.w * tileSize
            var array = Array<float4>(repeating: float4(0, 0, 0, 0), count: width * height)
            
            for y in rect.y..<(rect.y + rect.w) {
                for x in rect.x..<(rect.x + rect.z) {
                    let tileId = SIMD2<Int>(x, y)
                    if let tileInstance = layer.tileInstances[tileId] {
                        if let data = tileInstance.tileData {
                            
                            let offsetX = x - rect.x
                            let offsetY = y - rect.y
                            
                            for ly in 0..<tileSize {
                                for lx in 0..<tileSize {
                                    array[offsetX * tileSize + lx + (offsetY * tileSize * tileSize) + ly * tileSize ] = data[lx + ly * tileSize]//.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                                }
                            }
                        }
                    }
                }
            }
            
            return(width, height, array)
        }

        return nil
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
    
    /// Creates an CGIImage from an float4 array
    func createCGIImage(_ array: Array<SIMD4<Float>>,_ tileSize: SIMD2<Int>) -> CGImage?
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
            let cgImage = CGImage(width: tileSize.x,
                                  height: tileSize.y,
                                  bitsPerComponent: bitsPerComponent,
                                  bitsPerPixel: bitsPerPixel,
                                  bytesPerRow: tileSize.x * MemoryLayout<PixelData>.stride,
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
    
    // MARK: Layer Undo
    
    var currentLayerUndo : LayerUndoComponent? = nil    
    func startLayerUndo(_ layer: Layer,_ name: String) {
        currentLayerUndo = LayerUndoComponent(layer, self, name)
        currentLayerUndo!.start()
    }
    
    // MARK: Tile Undo
    
    var currentTileUndo : TileUndoComponent? = nil
    func startTileUndo(_ tile: Tile,_ name: String) {
        currentTileUndo = TileUndoComponent(tile, self, name)
        currentTileUndo!.start()
    }
}
