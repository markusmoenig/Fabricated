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
    
    var distance    : Float     // The current 2D SDF distance as computed by the Shape nodes
    
    var preview      : Bool = false
        
    init(areaOffset: float2, areaSize: float2, tileRect: TileRect)
    {
        self.areaOffset = areaOffset
        self.areaSize = areaSize
        
        areaUV = areaOffset / areaSize
        
        offset = float2(areaOffset.x - Float(tileRect.x), areaOffset.y - Float(tileRect.y))
        
        width = Float(tileRect.width)
        height = Float(tileRect.height)
        
        uv = offset / float2(width, height)
        distance = 10000
    }
}

class TileContext
{
    var tile            : Tile!             // The current tile
    var tileInstance    : TileInstance!     // The instance of the tile
    var tileArea        : TileInstanceArea! // The area of the tile
    var layer           : Layer!            // The current layer
    var tileSet         : TileSet!          // The current tile set

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

struct DrawJob {
    let layer       : Layer
    let tileId      : SIMD2<Int>
    let tileRect    : TileRect
    let data        : [float4]
}

class Renderer
{
    let core            : Core
    
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
    var renderedLayers  : [Layer] = []
    
    var totalJobs       : Int = 0

    init(_ core: Core)
    {
        self.core = core
                
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
    }
    
    func render()
    {
        print("render", "isRunning?", isRunning)
        if stop() {
            return
        }
                
        isRunning = true
        stopRunning = false
        
        let gridType = core.project.getCurrentScreen()?.gridType
        
        let tileSize = core.project.getTileSize()
        
        tileJobs = []
        renderedLayers = []
        
        totalJobs = 0

        let dims = calculateTextureSizeForScreen()
        let texSize : SIMD2<Int>
        
        if gridType == .rectFront {
            texSize = SIMD2<Int>(dims.0.x * Int(tileSize) * 2, dims.0.y * Int(tileSize) * 2)
        } else {
            texSize = SIMD2<Int>(dims.0.x * 2 + Int(tileSize), dims.0.y * 2 + Int(tileSize))
        }
        
        func collectJobsForLayer(_ layer: Layer) {
            checkIfLayerTextureIsValid(layer: layer, size: texSize)
            
            for area in layer.tileAreas {
                if let tile = core.project.getTileOfTileSet(area.tileSetId, area.tileId) {
                    let rect = area.area
                    for h in rect.y..<(rect.y + rect.w) {
                        for w in rect.x..<(rect.x + rect.z) {
                            //ids.append(SIMD2<Int>(w, h))
                            
                            let tileContext = TileContext()
                            tileContext.tileInstance = layer.tileInstances[SIMD2<Int>(w,h)]
                            tileContext.tileId = SIMD2<Float>(Float(w),Float(h))
                            tileContext.tileSet = core.project.currentTileSet

                            // Calculate tileRect
                            let x : Float
                            let y : Float
                            
                            if gridType == .rectFront {
                                x = Float(abs(dims.1.x - w)) * tileSize
                                y = Float(abs(dims.1.y - h)) * tileSize
                            } else {
                                let offX = Float(tileContext.tileId.x)
                                let offY = Float(tileContext.tileId.y)
                                
                                let isoP = toIso(float2(offX, offY))
                                x = abs(Float(dims.1.x) - isoP.x)
                                y = abs(Float(dims.1.y) - isoP.y)
                            }
                            
                            let tileRect = TileRect(Int(x.rounded()), Int(y.rounded()), Int(tileSize), Int(tileSize))
                            
                            if tile.hasChanged() || area.hasChanged || tileContext.tileInstance?.tileData == nil {

                                tileContext.layer = layer
                                tileContext.pixelSize = core.project.getPixelSize()
                                tileContext.antiAliasing = core.project.getAntiAliasing()
                                tileContext.tile = copyTile(tile)
                                tileContext.tileArea = area
                                
                                tileContext.areaOffset = float2(Float(w - rect.x), Float(h - rect.y))
                                tileContext.areaSize = float2(Float(area.area.z), Float(area.area.w))

                                //renderTile(tileContext, rect)
                                tileJobs.append(TileJob(tileContext, tileRect))
                            } else {
                                if let data = tileContext.tileInstance?.tileData {
                                    // TileInstance is rendered, add it to the scheduler
                                    drawJobAddTileInstanceData(layer: layer, tileId: SIMD2<Int>(w,h), tileRect: tileRect, data: data)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if let screen = core.project.getCurrentScreen() {
            for layer in screen.layers {
                if layer.visible == false {
                    clearLayerTexture(layer)
                } else {
                    collectJobsForLayer(layer)
                    renderedLayers.append(layer)
                }
            }
        }
            
        screenDim = dims.1
        
        if tileJobs.isEmpty {
            print("no jobs")
            drawJobPurge()
            core.updatePreviewOnce()
            isRunning = false
        } else {
            let cores = ProcessInfo().activeProcessorCount
            
            startTime = Double(Date().timeIntervalSince1970)
            totalTime = 0
            coresActive = 0
            
            totalJobs = tileJobs.count
            
            func startThread() {
                coresActive += 1
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    if gridType == .rectFront {
                        self.renderTile()
                    } else
                    if gridType == .rectIso {
                        self.renderIsoCube()
                    }
                }
            }

            for i in 0..<cores {
                if i < tileJobs.count {
                    startThread()
                }
            }
            print("Cores", cores, "Jobs", tileJobs.count, "Cores started:", coresActive)
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
    
    /// Sends the signal to stop rendering and returns the rendering state
    func stop() -> Bool {
        semaphore.wait()
        let busy = isRunning
        semaphore.signal()

        if busy {
            stopRunning = true
        }
        
        return busy
    }
    
    /// MARK: Render Rectangular Tile
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
                inProgressArray = Array<SIMD4<Float>>(repeating: ScreenView.selectionColor, count: tileRect.size)
            }
            
            updateTexture(inProgressArray!)
            
            let tile = tileContext.tile!
                            
            for h in tileRect.y..<tileRect.bottom {

                if stopRunning {
                    break
                }
                
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
                    if let node = node, node.role == .Pattern {
                        pixelContext.distance = -1
                    }
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
            tileJob.tileContext.tileInstance?.tileData = texArray
        }
                
        semaphore.wait()
        coresActive -= 1
        semaphore.signal()

        if coresActive == 0  {
                    
            if stopRunning == false {
                
                drawJobPurge()

                let myTime = Double(Date().timeIntervalSince1970) - startTime
                totalTime += myTime
                
                print(totalTime)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) {
                    self.core.updatePreviewOnce()
                }
                
                core.project.setHasChanged(false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.render()
                }
            }
            
            semaphore.wait()
            isRunning = false
            semaphore.signal()
        }
        
        dispatchGroup.leave()
    }
    
    /// MARK: Render IsoCube
    func renderIsoCube()
    {
        //var inProgressArray : Array<SIMD4<Float>>? = nil
        let isoCubeRenderer = IsoCubeRenderer()

        while let tileJob = getNextTile() {
            
            guard let _ = tileJob.tileContext.layer.texture else {
                return
            }
            
            let tileRect = tileJob.tileRect
            
            var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tileRect.size)
                            
            isoCubeRenderer.render(core, tileJob, &texArray)
            
            if stopRunning {
                break
            }
            
            drawJobAddTileInstanceData(layer: tileJob.tileContext.layer, tileId: SIMD2<Int>(tileJob.tileContext.tileId), tileRect: tileJob.tileRect, data: texArray)
            tileJob.tileContext.tileInstance?.tileData = texArray
        }
        
        semaphore.wait()
        coresActive -= 1
        semaphore.signal()

        if coresActive == 0  {
            
            if stopRunning == false {
                
                drawJobPurge()
                
                let myTime = Double(Date().timeIntervalSince1970) - startTime
                totalTime += myTime
                
                print(totalTime)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) {
                    self.core.updatePreviewOnce()
                }
                
                core.project.setHasChanged(false)
            } else {
                DispatchQueue.main.async {
                    self.render()
                }
            }
            
            semaphore.wait()
            isRunning = false
            semaphore.signal()
        }
        
        dispatchGroup.leave()
    }
    
    /// Add a rendered tile instance to the draw scheduler
    func drawJobAddTileInstanceData(layer: Layer, tileId: SIMD2<Int>, tileRect: TileRect, data: [float4])
    {
        let gridType = core.project.getCurrentScreen()?.gridType

        if gridType == .rectFront {
            var d = data
            let region = MTLRegionMake2D(tileRect.x, tileRect.y, tileRect.width, tileRect.height)
                
            d.withUnsafeMutableBytes { texArrayPtr in
                    layer.texture!.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * tileRect.width))
            }
        } else
        if gridType == .rectIso {
            let drawJob = DrawJob(layer: layer, tileId: tileId, tileRect: tileRect, data: data)
            layer.drawJobs.append(drawJob)
        }
        
        DispatchQueue.main.async {
            let progress = Float(self.totalJobs - self.tileJobs.count) / Float(self.totalJobs)
            //self.core.renderProgressChanged.send(1.0 / Float(self.tileJobs.count))
            self.core.renderProgressChanged.send(progress)
        }
    }
    
    /// Everything has been rendered, draw depending on the grid type
    func drawJobPurge()
    {
        let gridType = core.project.getCurrentScreen()?.gridType
        if gridType == .rectIso {
            
            semaphore.wait()

            for layer in renderedLayers {
                
                let sortedJobs = layer.drawJobs.sorted {
                    $0.tileId.y < $1.tileId.y || $0.tileId.x < $1.tileId.x
                }
                                
                for job in sortedJobs {

                    var data = job.data
                    let tileRect = job.tileRect
                    
                    let region = MTLRegionMake2D(tileRect.x, tileRect.y, tileRect.width, tileRect.height)
                                    
                    var texArray = Array<float4>(repeating: float4(0, 0, 0, 0), count: Int(tileRect.width * tileRect.height))

                    texArray.withUnsafeMutableBytes {
                        layer.texture!.getBytes($0.baseAddress!, bytesPerRow: (MemoryLayout<float4>.size * Int(tileRect.width)), from: region, mipmapLevel: 0)
                    }
                    
                    for h in 0..<tileRect.height {
                        for w in 0..<tileRect.width {
                            let existing = texArray[h * tileRect.width + w]
                            let replacing = data[h * tileRect.width + w]
                            
                            if replacing.w < existing.w {
                                data[h * tileRect.width + w] = simd_mix(replacing, existing, float4(repeating: existing.w))
                            } else {
                                data[h * tileRect.width + w] = simd_mix(existing, replacing, float4(repeating: replacing.w))
                            }
                        }
                    }
                    
                    data.withUnsafeMutableBytes { texArrayPtr in
                        layer.texture!.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * tileRect.width))
                    }
                }
                
                layer.drawJobs = []
            }
            
            DispatchQueue.main.async {
                self.core.updatePreviewOnce()
                self.core.renderProgressChanged.send(0)
            }
            
            semaphore.signal()
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
                        
                        var x = index.x
                        var y = index.y
                        
                        if screen.gridType == .rectIso {
                            let iso = toIso(float2(Float(x),Float(y)))
                            x = Int(iso.x)
                            y = Int(iso.y)
                        }
                        
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
    
    // Converts a screen position to an isometric coordinate
    func toIso(_ p: float2) -> float2
    {
        let tileSize = core.project.getTileSize()

        var isoP = float2()
        isoP.x = (p.x - p.y) * tileSize / 2.0
        isoP.y = (p.y + p.x) * tileSize / 4.0
        return isoP
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
    
    /// Clears the texture of the layer
    func clearLayerTexture(_ layer: Layer) {
        startDrawing(core.device)
        clearTexture(layer.texture!, float4(0,0,0,0))
        stopDrawing(syncTexture: layer.texture!, waitUntilCompleted: true)
    }
    
    /// Checks if the texture is of the given size and if not reallocate, returns true if the texture has been reallocated
    @discardableResult func checkIfLayerTextureIsValid(layer: Layer, size: SIMD2<Int>) -> Bool
    {
        if size.x == 0 || size.y == 0 {
            return false
        }
        
        // Make sure texture is of size size
        if layer.texture == nil || layer.texture!.width != size.x || layer.texture!.height != size.y {
            
            stopRunning = true
            
            if layer.texture != nil {
                layer.texture!.setPurgeableState(.empty)
                layer.texture = nil
            }
            
            layer.texture = allocateTexture(core.device, width: size.x, height: size.y)
            
            clearLayerTexture(layer)
            //core.project.setHasChanged(true)
            return true
        }
        
        clearLayerTexture(layer)

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
