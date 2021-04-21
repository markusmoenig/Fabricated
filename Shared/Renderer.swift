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
    let texOffset   : float2    // The offset into the texture
    let texUV       : float2    // The global texture UV
    
    let texWidth    : Float     // Texture width
    let texHeight   : Float     // Texture height

    let offset      : float2    // The local tile offset
    let uv          : float2    // The local tile UV
    var pUV         : float2    // The local pixelized tile UV

    let width       : Float     // Tile Width
    let height      : Float     // Tile Height
    
    var localDist   : Float
    var totalDist   : Float
    
    init(texOffset: float2, texWidth: Float, texHeight: Float, tileRect: TileRect)
    {
        self.texOffset = texOffset
        self.texWidth = texWidth
        self.texHeight = texHeight
        
        texUV = texOffset / float2(texWidth, texHeight) - float2(0.5, 0.5)
        
        offset = float2(texOffset.x - Float(tileRect.x), texOffset.y - Float(tileRect.y))
        
        width = Float(tileRect.width)
        height = Float(tileRect.height)
        
        uv = offset / float2(width, height)// - float2(0.5, 0.5)
        pUV = float2(0,0)
        localDist = 0
        totalDist = 0
    }
}

class TileContext
{
    var tile            : Tile!         // The current tile
    var tileInstance    : TileInstance! // The instance of the tile
    var layer           : Layer!        // The current layer

    var pixelSize       : Float!
    
    /// Pixelizes the UV coordinate based on the pixelSize
    func getPixelUV(_ uv: float2) -> float2
    {
        var rc = floor(uv * pixelSize) / pixelSize
        rc += 1.0 / (pixelSize * 2.0)
        return rc
    }    
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
    enum RenderDimensions {
        case All, Visible
    }
    
    let core            : Core
    
    var texture         : MTLTexture? = nil
    
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
        
        texture = allocateTexture(core.device, width: 800, height: 600)
        
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
    }
    
    func render()
    {
        stop()
        
        tileJobs = []
        
        if let layer = core.project.currentLayer {
            
            let tileSize = core.project.getTileSize()

            let dims = calculateTextureSizeForScreen()
            let texSize = SIMD2<Int>(dims.0.x * Int(tileSize), dims.0.y * Int(tileSize))
            
            checkIfTextureIsValid(size: texSize)
            
            for (index, instance) in layer.tileInstances {
                                
                if let tile = core.project.getTileOfTileSet(instance.tileSetId, instance.tileId) {
                    
                    let tileContext = TileContext()
                    tileContext.layer = layer
                    tileContext.pixelSize = core.project.getPixelSize()
                    tileContext.tile = copyTile(tile)
                    tileContext.tileInstance = instance

                    let x : Float = Float(abs(dims.1.x - index.x)) * tileSize
                    let y : Float = Float(abs(dims.1.y - index.y)) * tileSize
                    
                    let rect = TileRect(Int(x), Int(y), Int(tileSize), Int(tileSize))
                    //renderTile(tileContext, rect)
                    tileJobs.append(TileJob(tileContext, rect))
                }
            }
            
            screenDim = dims.1
            
            if layer.tileInstances.isEmpty {
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
            
            guard let texture = texture else {
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
                inProgressArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(1, 0, 0, 1), count: tileRect.size)
            }
            
            updateTexture(inProgressArray!)

            let width: Float = Float(texture.width)
            let height: Float = Float(texture.height)
            
            let tile = tileContext.tile!
                            
            for h in tileRect.y..<tileRect.bottom {

                for w in tileRect.x..<tileRect.right {
                    
                    if stopRunning {
                        break
                    }
                    
                    let pixelContext = TilePixelContext(texOffset: float2(Float(w), Float(h)), texWidth: width, texHeight: height, tileRect: tileRect)
                    pixelContext.pUV = tileContext.getPixelUV(pixelContext.uv)
                    
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
    @discardableResult func checkIfTextureIsValid(size: SIMD2<Int>) -> Bool
    {
        if size.x == 0 || size.y == 0 {
            return false
        }
        
        func clear() {
            startDrawing(core.device)
            clearTexture(texture!, float4(0,0,0,0))
            stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
        }
        
        // Make sure texture is of size size
        if texture == nil || texture!.width != size.x || texture!.height != size.y {
            
            stopRunning = true
            
            if texture != nil {
                texture!.setPurgeableState(.empty)
                texture = nil
            }
            
            texture = allocateTexture(core.device, width: size.x, height: size.y)
            
            clear()
            return true
        }
        
        clear()
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

/*
 
 //
 //  Renderer.swift
 //  Signed
 //
 //  Created by Markus Moenig on 19/11/20.
 //

 import Foundation

 import MetalKit
 import simd

 class Tile
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

 class Renderer
 {
     enum RenderMode {
         case Normal, Preview
     }
     
     var renderMode      : RenderMode = .Normal
     
     var texture         : MTLTexture? = nil
     var temp            : MTLTexture? = nil

     var commandQueue    : MTLCommandQueue? = nil
     var commandBuffer   : MTLCommandBuffer? = nil
     
     var size            = SIMD2<Int>(0,0)
     var time            = Float(0)
     var frame           = UInt32(0)

     var assetFolder     : AssetFolder? = nil
     
     var textureCache    : [UUID:MTLTexture] = [:]
     var textureLoader   : MTKTextureLoader? = nil
     
     var resChanged      : Bool = false
     
     var startTime       : Double = 0
     var totalTime       : Double = 0
     var coresActive     : Int = 0
     
     var semaphore       : DispatchSemaphore!
     var dispatchGroup   : DispatchGroup!
     
     var isRunning       : Bool = false
     var stopRunning     : Bool = false
     
     let core            : Core
             
     var tiles           : [Tile] = []

     init(_ core: Core)
     {
         self.core = core
         semaphore = DispatchSemaphore(value: 1)
         dispatchGroup = DispatchGroup()
     }
     
     deinit
     {
         clear()
     }
     
     func clear() {
         if texture != nil { texture!.setPurgeableState(.empty); texture = nil }
         if temp != nil { temp!.setPurgeableState(.empty); temp = nil }

         for (id, _) in textureCache {
             if textureCache[id] != nil {
                 textureCache[id]!.setPurgeableState(.empty)
             }
         }
         textureCache = [:]
     }
     
     func start()
     {
         guard let main = core.assetFolder.getAsset("main", .Source) else {
             return
         }
         
         guard let context = main.graph else {
             return
         }

         if checkIfTextureIsValid(core, forceClear: true) == false {
             return
         }

         let cores = ProcessInfo().activeProcessorCount// + 1
         
         let width: Int = texture!.width
         let height: Int = texture!.height
         
         let tileSize: Int = 8
         let columns = height / tileSize + 1
         let rows = width / tileSize + 1
         tiles = []
         for h in 0..<columns {
             for w in 0..<rows {
                 let tile = Tile(w * tileSize, h * tileSize, tileSize, tileSize)
                 if tile.y >= height { break }
                 if tile.x >= width { break }
                 if tile.right >= width {
                     tile.width -= tile.right - width + 1
                     tile.right = tile.x + tile.width
                     tile.size = tile.width * tile.height
                 }
                 if tile.bottom >=  height {
                     tile.height -= tile.bottom - height + 1
                     tile.bottom = tile.y + tile.height
                     tile.size = tile.width * tile.height
                 }
                 if tile.width == 0 || tile.height == 0 { break }
                 tiles.append(tile)
             }
         }
         
         var lineCount : Int = 0
         let chunkHeight : Int = height / cores + cores
         
         //print("Cores", cores, chunkHeight)

         startTime = Double(Date().timeIntervalSince1970)
         totalTime = 0
         coresActive = 0
                 
         isRunning = true
         stopRunning = false

         func startThread(_ chunk: SIMD4<Int>) {
             //print("Chunk start", chunk.y, chunk.w)

             coresActive += 1
             dispatchGroup.enter()
             DispatchQueue.global(qos: core.renderQuality == .Normal ? .background : .userInitiated).async {
                 self.renderChunk(context1: context, chunk: chunk)
             }
         }

         for _ in 0..<cores {
             if lineCount < height {
                 startThread(SIMD4<Int>(0, lineCount, 0, min(lineCount + chunkHeight, height)))
                 lineCount += chunkHeight
             }
         }
     }
     
     func getNextTile() -> Tile?
     {
         semaphore.wait()
         var tile : Tile? = nil
         if tiles.isEmpty == false {
             tile = tiles.removeFirst()
         }
         semaphore.signal()
         return tile
     }
     
     func renderChunk(context1: GraphContext, chunk: SIMD4<Int>)
     {
         guard let texture = texture else {
             return
         }
         
         let width: Float = Float(texture.width)
         let height: Float = Float(texture.height)
         
         //let widthInt : Int = texture.width
         //let heightInt : Int = texture!.height

         //var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt)
         
         guard let main = core.assetFolder.getAsset("main", .Source) else {
             return
         }
         
         let asset = Asset(type: .Source, name: "", value: main.value, data: main.data)
         core.graphBuilder.compile(asset, silent: true)
         
         let context = asset.graph!
         
         context.setupBeforeStart()
         context.renderQuality = core.renderQuality
         context.viewSize = float2(width, height)
         
         // Extract Render Options
         var AA : Int = context.renderQuality == .Fast ? 2 : 1
         var iterations : Int = 10
         
         var renderType : GraphNode.NodeRenderType = .Normal
         if let renderNode = context.renderNode {
             renderType = renderNode.renderType
             
             if renderType == .Normal {
                 if let line = core.scriptProcessor.getLine(renderNode.lineNr) {
                     let options = core.scriptProcessor.extractOptionsFromLine(renderNode, line)
                     for o in options {
                         if o.name.lowercased().contains("aliasing") {
                             if let i1 = o.variable as? Int1 {
                                 AA = i1.x
                             }
                         }
                     }
                 }
             } else {
                 if let line = core.scriptProcessor.getLine(renderNode.lineNr) {
                     let options = core.scriptProcessor.extractOptionsFromLine(renderNode, line)
                     for o in options {
                         if o.name.lowercased().contains("iterations") {
                             if let i1 = o.variable as? Int1 {
                                 iterations = i1.x
                             }
                         }
                     }
                 }
             }
         }
             
         while let tile = getNextTile() {
             
             var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: tile.size)

             for h in tile.y..<tile.bottom {

                 let fh : Float = Float(h) / height
                 for w in tile.x..<tile.right {
                     
                     if stopRunning {
                         break
                     }
                     
                     context.reflectionDepth = 0
                     context.hasHitSomething = false
                     
                     context.normal.fromSIMD(float3(0.0, 0.0, 0.0))
                     context.rayPosition.fromSIMD(float3(0.0, 0.0, 0.0))
                     context.outColor.fromSIMD(float4(0.0, 0.0, 0.0, 0.0))

                     if context.renderQuality != .Normal {
                         var tot = float4(0,0,0,0)
                         
                         for m in 0..<AA {
                             for n in 0..<AA {

                                 if stopRunning {
                                     break
                                 }

                                 context.uv = float2(Float(w) / width, fh)
                                 context.camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5

                                 if let cameraNode = context.cameraNode {
                                     cameraNode.execute(context: context)
                                 }
                                 
                                 context.executeRender()
                                 
                                 let result = context.outColor!.toSIMD().clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                                 tot += result
                             }
                         }
                         texArray[(h - tile.y) * tile.width + w - tile.x] = tot / Float(AA*AA)
                     } else {
                         
                         var tot = float4(0,0,0,0)

                         for i in 0..<iterations {
                             
                             context.uv = float2(Float(w) / width, fh)
                             //context.camOffset = float2(Float.random(in: 0...1), Float.random(in: 0...1))
                             if let cameraNode = context.cameraNode {
                                 cameraNode.execute(context: context)
                             }
                             
                             context.executeRender()
                             
                             let result = context.outColor!.toSIMD()//.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                             
                             let k : Float = Float(i+1)
                             tot = tot * (1.0 - 1.0/k) + result * (1.0/k)
                         }
                         //texArray[w] = tot.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                         texArray[(h - tile.y) * tile.width + w - tile.x] = tot.clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                     }
                 }
             }
             
             if stopRunning {
                 break
             }
             
             semaphore.wait()
             let region = MTLRegionMake2D(tile.x, tile.y, tile.width, tile.height)
             
             texArray.withUnsafeMutableBytes { texArrayPtr in
                 texture.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * tile.width))
             }
             
             DispatchQueue.main.async {
                 self.core.updateOnce()
             }

             semaphore.signal()
         }
         
         coresActive -= 1
         if coresActive == 0 && stopRunning == false {
             
             let chunkTime = Double(Date().timeIntervalSince1970) - startTime
             totalTime += chunkTime
             
             if renderMode == .Normal {
                 DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) {
                     self.core.updateOnce()
                 }
             } else {
                 DispatchQueue.main.async {
                     self.core.updateOnce()
                 }
             }
             
             isRunning = false
             print(totalTime)
         }
         
         dispatchGroup.leave()
     }
     
     func restart(_ renderMode : RenderMode = .Normal)
     {
         stop()
             
         self.renderMode = renderMode
         self.start()
     }
     
     func stop()
     {
         stopRunning = true
         dispatchGroup.wait()
     }
     
     /// Render a preview during camera actions
     func previewRender()
     {
     }
     
     func startDrawing(_ device: MTLDevice)
     {
         if commandQueue == nil {
             commandQueue = device.makeCommandQueue()
         }
         commandBuffer = commandQueue!.makeCommandBuffer()
         resChanged = false
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
     
     /// Creates vertex data for the given rectangle
     func createVertexData(texture: MTLTexture, rect: MMRect) -> [Float]
     {
         let left: Float  = -Float(texture.width) / 2.0 + rect.x
         let right: Float = left + rect.width//self.width / 2 - x
         
         let top: Float = Float(texture.height) / 2.0 - rect.y
         let bottom: Float = top - rect.height

         let quadVertices: [Float] = [
             right, bottom, 1.0, 0.0,
             left, bottom, 0.0, 0.0,
             left, top, 0.0, 1.0,
             
             right, bottom, 1.0, 0.0,
             left, top, 0.0, 1.0,
             right, top, 1.0, 1.0,
         ]
         
         return quadVertices
     }
     
     /// Checks if the texture size is valid and if not stop rendering and resize and clear the texture
     func checkIfTextureIsValid(_ core: Core, forceClear: Bool = false) -> Bool
     {
         let size = SIMD2<Int>(Int(core.view.frame.width), Int(core.view.frame.height))
         
         if size.x == 0 || size.y == 0 {
             return false
         }
         
         // Make sure texture is of size size
         if texture == nil || texture!.width != size.x || texture!.height != size.y {
             
             stopRunning = true
             
             if texture != nil {
                 texture!.setPurgeableState(.empty)
                 texture = nil
             }
             texture = allocateTexture(core.device, width: size.x, height: size.y)
             resChanged = true
             
             startDrawing(core.device)
             clearTexture(texture!)
             stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
         } else {
             if forceClear {
                 startDrawing(core.device)
                 clearTexture(texture!)
                 stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
             }
         }
         return true
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
     
     func makeCGIImage(_ device: MTLDevice,_ state: MTLComputePipelineState,_ texture: MTLTexture) -> MTLTexture?
     {
         if temp != nil { temp!.setPurgeableState(.empty); temp = nil }

         temp = allocateTexture(device, width: texture.width, height: texture.height)
         runComputeState(device, state, outTexture: temp!, inTexture: texture, syncronize: true)
         return temp
     }
     
     /// Run the given state
     func runComputeState(_ device: MTLDevice,_ state: MTLComputePipelineState?, outTexture: MTLTexture, inBuffer: MTLBuffer? = nil, inTexture: MTLTexture? = nil, inTextures: [MTLTexture] = [], outTextures: [MTLTexture] = [], inBuffers: [MTLBuffer] = [], syncronize: Bool = false, finishedCB: ((Double)->())? = nil )
     {
         // Compute the threads and thread groups for the given state and texture
         func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ width: Int,_ height: Int, limitThreads: Bool = false)
         {
             let w = limitThreads ? 1 : state.threadExecutionWidth
             let h = limitThreads ? 1 : state.maxTotalThreadsPerThreadgroup / w
             let threadsPerThreadgroup = MTLSizeMake(w, h, 1)

             let threadgroupsPerGrid = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
             encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
         }
         
         startDrawing(device)
         
         let computeEncoder = commandBuffer?.makeComputeCommandEncoder()!
         
         computeEncoder?.setComputePipelineState( state! )
         
         computeEncoder?.setTexture( outTexture, index: 0 )
         
         if let buffer = inBuffer {
             computeEncoder?.setBuffer(buffer, offset: 0, index: 1)
         }
         
         var texStartIndex : Int = 2
         
         if let texture = inTexture {
             computeEncoder?.setTexture(texture, index: 2)
             texStartIndex = 3
         }
         
         for (index,texture) in inTextures.enumerated() {
             computeEncoder?.setTexture(texture, index: texStartIndex + index)
         }
         
         texStartIndex += inTextures.count

         for (index,texture) in outTextures.enumerated() {
             computeEncoder?.setTexture(texture, index: texStartIndex + index)
         }
         
         texStartIndex += outTextures.count

         for (index,buffer) in inBuffers.enumerated() {
             computeEncoder?.setBuffer(buffer, offset: 0, index: texStartIndex + index)
         }
         
         calculateThreadGroups(state!, computeEncoder!, outTexture.width, outTexture.height)
         computeEncoder?.endEncoding()

         stopDrawing(syncTexture: outTexture, waitUntilCompleted: true)
         
         /*
         if let finished = finishedCB {
             commandBuffer?.addCompletedHandler { cb in
                 let executionDuration = cb.gpuEndTime - cb.gpuStartTime
                 //print(executionDuration)
                 finished(executionDuration)
             }
         } */
     }
 }

 */
