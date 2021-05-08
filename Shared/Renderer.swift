//
//  Renderer.swift
//  Fabricated
//
//  Created by Markus Moenig on 10/4/21.
//

import MetalKit
import simd

class TileRect
{
    let x       : Int
    let y       : Int
    var width   : Int
    var height  : Int
    
    var right   : Int
    var bottom  : Int
    
    var size    : Int
    
    init(_ x: Int,_ y: Int,_ width: Int,_ height: Int)
    {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        right = x + width
        bottom = y + height
        size = width * height
    }
}

class TilePixelContext
{
    let areaOffset  : float2    // The offset into the area
    let areaSize    : float2    // Area Size
    var areaUV      : float2    // The global texture UV
    
    let offset      : float2    // The local tile offset
    var uv          : float2    // The local tile UV

    let width       : Float     // Tile Width
    let height      : Float     // Tile Height
    
    var localDist   : Float
        
    init(areaOffset: float2, areaSize: float2, tileRect: TileRect)
    {
        self.areaOffset = areaOffset
        self.areaSize = areaSize
        
        areaUV = areaOffset / areaSize - float2(0.5, 0.5)
        
        offset = float2(areaOffset.x - Float(tileRect.x), areaOffset.y - Float(tileRect.y))
        
        width = Float(tileRect.width)
        height = Float(tileRect.height)
        
        uv = offset / float2(width, height)// - float2(0.5, 0.5)
        localDist = 10000
    }
}

class TileContext
{
    var tile            : Tile!             // The current tile
    var tileInstance    : TileInstance!     // The instance of the tile
    var tileArea        : TileInstanceArea! // The area of the tile
    var layer           : Layer!            // The current layer

    var pixelSize       : Float = 1
    var antiAliasing    : Float = 2
    
    var areaOffset      = float2(0,0)
    var areaSize        = float2(1,1)

    var tileId          = float2(0,0)
}

class TileJob
{
    var tileContext     : TileContext
    var tileRect        : TileRect

    init(_ tileContext: TileContext,_ tileRect: TileRect)
    {
        self.tileContext = tileContext
        self.tileRect = tileRect
    }
}

class Renderer
{
    enum RenderMode {
        case Screen, Layer
    }
    
    let core            : Core
    
    var renderMode      : RenderMode = .Screen
    
    var commandQueue    : MTLCommandQueue? = nil
    var commandBuffer   : MTLCommandBuffer? = nil
    
    var screenDim       = SIMD4<Int>(0,0,0,0)
    
    var semaphore       : DispatchSemaphore!
    var dispatchGroup   : DispatchGroup!
    
    var startTime       : Double = 0
    var totalTime       : Double = 0
    var coresActive     : Int = 0
    
    var isRunning       : Bool = false
    var stopRunning     : Bool = false

    var tileJobs        : [TileJob] = []

    init(_ core: Core)
    {
        self.core = core
                
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
    }
    
    func render(forceTextureClear: Bool = false)
    {
        stop()
                
        let tileSize = core.project.getTileSize()
        tileJobs = []

        let dims = calculateTextureSizeForScreen()
        let texSize = SIMD2<Int>(dims.0.x * Int(tileSize), dims.0.y * Int(tileSize))
        
        func collectJobsForLayer(_ layer: Layer) {
            checkIfLayerTextureIsValid(layer: layer, size: texSize, forceTextureClear: forceTextureClear)
            
            for area in layer.tileAreas {
                if let tile = core.project.getTileOfTileSet(area.tileSetId, area.tileId) {
                    if tile.hasChanged() || area.hasChanged {
                        let rect = area.area
                        for h in rect.y..<(rect.y + rect.w) {
                            for w in rect.x..<(rect.x + rect.z) {
                                //ids.append(SIMD2<Int>(w, h))
                                
                                let tileContext = TileContext()
                                tileContext.layer = layer
                                tileContext.pixelSize = core.project.getPixelSize()
                                tileContext.antiAliasing = core.project.getAntiAliasing()
                                tileContext.tile = copyTile(tile)
                                tileContext.tileInstance = layer.tileInstances[SIMD2<Int>(w,h)]
                                tileContext.tileArea = area
                                
                                tileContext.areaOffset = float2(Float(w - rect.x), Float(h - rect.y))
                                tileContext.areaSize = float2(Float(area.area.z), Float(area.area.w))

                                tileContext.tileId = SIMD2<Float>(Float(w),Float(h))

                                let x : Float = Float(abs(dims.1.x - w)) * tileSize
                                let y : Float = Float(abs(dims.1.y - h)) * tileSize
                                
                                let rect = TileRect(Int(x), Int(y), Int(tileSize), Int(tileSize))
                                //renderTile(tileContext, rect)
                                tileJobs.append(TileJob(tileContext, rect))
                            }
                        }
                    }
                }
            }
        }
        
        if renderMode == .Screen {
            if let screen = core.project.getCurrentScreen() {
                for layer in screen.layers {
                    collectJobsForLayer(layer)
                }
            }
        } else
        if let layer = core.project.currentLayer {
            collectJobsForLayer(layer)
        }        
            
        screenDim = dims.1
        
        if tileJobs.isEmpty {
            core.updatePreviewOnce()
        } else {
            let cores = ProcessInfo().activeProcessorCount// + 1
            
            startTime = Double(Date().timeIntervalSince1970)
            totalTime = 0
            coresActive = 0
                    
            isRunning = true
            stopRunning = false
            
            func startThread() {
                coresActive += 1
                dispatchGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    self.renderTile()
                }
            }

            for i in 0..<cores {
                if i < tileJobs.count {
                    startThread()
                }
            }
            print("Cores", cores, "Jobs", tileJobs.count, "Core started:", coresActive)
        }
    }
    
    /// Returns the next tile to render inside one of the threads
    func getNextTile() -> TileJob?
    {
        semaphore.wait()
        var tileJob : TileJob? = nil
        if tileJobs.isEmpty == false {
            tileJob = tileJobs.removeFirst()
        }
        semaphore.signal()
        return tileJob
    }
    
    func stop()
    {
        stopRunning = true
        dispatchGroup.wait()
    }
    
    func renderTile()
    {
        var inProgressArray : Array<SIMD4<Float>>? = nil

        while let tileJob = getNextTile() {
            
            guard let texture = tileJob.tileContext.layer.texture else {
                return
            }
            
            func updateTexture(_ a: Array<SIMD4<Float>>)
            {
                var array = a
                
                semaphore.wait()
                let region = MTLRegionMake2D(tileRect.x, tileRect.y, tileRect.width, tileRect.height)
                
                array.withUnsafeMutableBytes { texArrayPtr in
                    texture.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * tileRect.width))
                }
                
                DispatchQueue.main.async {
                    self.core.updatePreviewOnce()
                }
                
                semaphore.signal()
            }
            
            let tileContext = tileJob.tileContext
            let tileRect = tileJob.tileRect
            
            var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tileRect.size)
            if inProgressArray == nil {
                inProgressArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0.494, 0.455, 0.188, 1.000), count: tileRect.size)
            }
            
            updateTexture(inProgressArray!)
            
            let tile = tileContext.tile!
                            
            for h in tileRect.y..<tileRect.bottom {

                for w in tileRect.x..<tileRect.right {
                    
                    if stopRunning {
                        break
                    }
                    
                    let areaOffset = tileContext.areaOffset + float2(Float(w), Float(h))
                    let areaSize = tileContext.areaSize * float2(Float(tileRect.width), Float(tileRect.height))

                    let pixelContext = TilePixelContext(areaOffset: areaOffset, areaSize: areaSize, tileRect: tileRect)
                    //pixelContext.pUV = tileContext.getPixelUV(pixelContext.uv)
                    
                    if tile.nodes.count > 0 {
                        let noded = tile.nodes[0]
                        let offset = noded.readFloat2FromInstanceAreaIfExists(tileContext.tileArea, noded, "_offset", float2(0.5, 0.5)) - float2(0.5, 0.5)
                        pixelContext.uv -= offset
                        pixelContext.areaUV -= offset
                    }
                    
                    var color = float4(0, 0, 0, 0)
                    
                    var node = tile.getNextInChain(tile.nodes[0], .Shape)
                    while node !== nil {
                        color = node!.render(pixelCtx: pixelContext, tileCtx: tileContext, prevColor: color)
                        node = tile.getNextInChain(node!, .Shape)
                    }

                    texArray[(h - tileRect.y) * tileRect.width + w - tileRect.x] = color.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                }
            }
            
            if stopRunning {
                break
            }
            
            updateTexture(texArray)
        }
        
        coresActive -= 1
        if coresActive == 0 && stopRunning == false {
            
            let myTime = Double(Date().timeIntervalSince1970) - startTime
            totalTime += myTime
            
            isRunning = false
            print(totalTime)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) {
                self.core.updatePreviewOnce()
            }
            
            core.project.setHasChanged(false)
        }
        
        dispatchGroup.leave()
    }
    
    /// Copiea a tile. Each thread during rendering gets a copy of the original tile to prevent race conditions
    func copyTile(_ tile: Tile) -> Tile {
        if let data = try? JSONEncoder().encode(tile) {
            if let copiedTile = try? JSONDecoder().decode(Tile.self, from: data) {
                return copiedTile
            }
        }
        return tile
    }
    
    /// Calculates the dimensions of the current screen
    func calculateTextureSizeForScreen() -> (SIMD2<Int>, SIMD4<Int>) {
        var width   : Int = 0
        var height  : Int = 0
        
        var minX    : Int = 10000
        var maxX    : Int = -10000
        var minY    : Int = 10000
        var maxY    : Int = -10000
        
        var tilesInScreen : Int = 0

        if let layer = core.project.currentLayer {
            if let screen = core.project.getScreenForLayer(layer.id) {
                
                for layer in screen.layers {
                    for (index, _) in layer.tileInstances {
                        
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
                        
                        tilesInScreen += 1
                    }
                }
            }
        }
                
        if tilesInScreen > 0 {
            width = (abs(maxX - minX) + 1)
            height = (abs(maxY - minY) + 1)
        }
        
        return (SIMD2<Int>(width, height), SIMD4<Int>(minX, minY, maxX, maxY))
    }
        
    func allocateTexture(_ device: MTLDevice, width: Int, height: Int) -> MTLTexture?
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.pixelFormat = MTLPixelFormat.rgba32Float
        textureDescriptor.width = width == 0 ? 1 : width
        textureDescriptor.height = height == 0 ? 1 : height
        
        textureDescriptor.usage = MTLTextureUsage.unknown
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    /// Checks if the texture is of the given size and if not reallocate, returns true if the texture has been reallocated
    @discardableResult func checkIfLayerTextureIsValid(layer: Layer, size: SIMD2<Int>, forceTextureClear: Bool = false) -> Bool
    {
        if size.x == 0 || size.y == 0 {
            return false
        }
        
        func clear() {
            startDrawing(core.device)
            clearTexture(layer.texture!, float4(0,0,0,0))
            stopDrawing(syncTexture: layer.texture!, waitUntilCompleted: true)
        }
        
        // Make sure texture is of size size
        if layer.texture == nil || layer.texture!.width != size.x || layer.texture!.height != size.y {
            
            stopRunning = true
            
            if layer.texture != nil {
                layer.texture!.setPurgeableState(.empty)
                layer.texture = nil
            }
            
            layer.texture = allocateTexture(core.device, width: size.x, height: size.y)
            
            clear()
            return true
        }
        
        if forceTextureClear {
            clear()
        }
        
        return false
    }
    
    func startDrawing(_ device: MTLDevice)
    {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        commandBuffer = commandQueue!.makeCommandBuffer()
    }
    
    /// Clears the textures
    func clearTexture(_ texture: MTLTexture, _ color: float4 = SIMD4<Float>(0,0,0,1))
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(Double(color.x), Double(color.y), Double(color.z), Double(color.w))
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        let renderEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
    }
    
    func stopDrawing(syncTexture: MTLTexture? = nil, waitUntilCompleted: Bool = false)
    {
        #if os(OSX)
        if let texture = syncTexture {
            let blitEncoder = commandBuffer!.makeBlitCommandEncoder()!
            blitEncoder.synchronize(texture: texture, slice: 0, level: 0)
            blitEncoder.endEncoding()
        }
        #endif
        commandBuffer?.commit()
        if waitUntilCompleted {
            commandBuffer?.waitUntilCompleted()
        }
        commandBuffer = nil
    }
}
