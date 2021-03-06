//
//  MetalDrawables.swift
//  Fabricated
//
//  Created by Markus Moenig on 8/4/21.
//

import MetalKit

class MetalDrawables
{
    let metalView       : DMTKView
    
    let device          : MTLDevice
    let commandQueue    : MTLCommandQueue!
    
    var pipelineState   : MTLRenderPipelineState! = nil
    var pipelineStateDesc : MTLRenderPipelineDescriptor! = nil

    var renderEncoder   : MTLRenderCommandEncoder! = nil

    var vertexBuffer    : MTLBuffer? = nil
    var viewportSize    : vector_uint2
    
    var commandBuffer   : MTLCommandBuffer! = nil
    
    var discState       : MTLRenderPipelineState? = nil
    var boxState        : MTLRenderPipelineState? = nil

    var scaleFactor     : Float
    var viewSize        = float2(0,0)
    
    var font            : Font! = nil

    init(_ metalView: DMTKView)
    {
        self.metalView = metalView
        #if os(iOS)
        metalView.layer.isOpaque = false
        #else
        metalView.layer?.isOpaque = false
        #endif

        device = metalView.device!
        viewportSize = vector_uint2( UInt32(metalView.bounds.width), UInt32(metalView.bounds.height) )
        commandQueue = device.makeCommandQueue()
        
        scaleFactor = metalView.core.scaleFactor
                
        if let defaultLibrary = device.makeDefaultLibrary() {

            pipelineStateDesc = MTLRenderPipelineDescriptor()
            let vertexFunction = defaultLibrary.makeFunction( name: "m4mQuadVertexShader" )
            pipelineStateDesc.vertexFunction = vertexFunction
            pipelineStateDesc.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
            
            pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
            pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
            pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
            pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                        
            func createNewPipelineState(_ fragmentFunction: MTLFunction?) -> MTLRenderPipelineState?
            {
                if let function = fragmentFunction {
                    pipelineStateDesc.fragmentFunction = function
                    do {
                        let renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDesc)
                        return renderPipelineState
                    } catch {
                        print( "createNewPipelineState failed" )
                        return nil
                    }
                }
                return nil
            }
            
            var function = defaultLibrary.makeFunction( name: "m4mDiscDrawable" )
            discState = createNewPipelineState(function)
            function = defaultLibrary.makeFunction( name: "m4mBoxDrawable" )
            boxState = createNewPipelineState(function)
        }
    }
    
    @discardableResult func encodeStart(_ clearColor: float4 = float4(0.125, 0.129, 0.137, 1)) -> MTLRenderCommandEncoder?
    {
        if font == nil { font = Font(name: "OpenSans", core: metalView.core) }
        
        viewportSize = vector_uint2( UInt32(metalView.bounds.width), UInt32(metalView.bounds.height) )
        viewSize = float2(Float(metalView.bounds.width), Float(metalView.bounds.height))

        commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = metalView.currentRenderPassDescriptor
        
        renderPassDescriptor!.colorAttachments[0].loadAction = .clear
        renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColor( red: Double(clearColor.x), green: Double(clearColor.y), blue: Double(clearColor.z), alpha: Double(clearColor.w))
        
        if renderPassDescriptor != nil {
            renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor! )
            return renderEncoder
        }
        
        return nil
    }
    
    func encodeRun( _ renderEncoder: MTLRenderCommandEncoder, pipelineState: MTLRenderPipelineState? )
    {
        renderEncoder.setRenderPipelineState( pipelineState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    func encodeEnd()
    {
        renderEncoder?.endEncoding()
        
        guard let drawable = metalView.currentDrawable else {
            return
        }
        
        if let commandBuffer = commandBuffer {
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    /// Draws a disk
    func drawDisk(position: float2, radius: Float, borderSize: Float = 0, onion: Float = 0, rotation: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0))
    {
        var data = DiscUniform()
        data.borderSize = borderSize
        data.radius = radius
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.onion = onion
        data.rotation = rotation.degreesToRadians
        data.hasTexture = 0

        let rect = MMRect(position.x - data.borderSize / 2, position.y - data.borderSize / 2, data.radius * 2 + data.borderSize * 2, data.radius * 2 + data.borderSize * 2)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<DiscUniform>.stride, index: 0)
        renderEncoder.setRenderPipelineState(discState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws a box
    func drawBox(position: float2, size: float2, rounding: Float = 0, borderSize: Float = 0, onion: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0), texture: MTLTexture? = nil)
    {
        var data = BoxUniform()
        data.borderSize = borderSize
        data.size = size
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.onion = onion
        //data.rotation = rotation.degreesToRadians
        data.hasTexture = texture != nil ? 1 : 0
        data.round = rounding

        let rect = MMRect(position.x - data.borderSize / 2, position.y - data.borderSize / 2, size.x + data.borderSize * 2, size.y + data.borderSize * 2, scale: 1)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<BoxUniform>.stride, index: 0)
        if let texture = texture {
            renderEncoder.setFragmentTexture(texture, index: 1)
        }
        renderEncoder.setRenderPipelineState(boxState!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws a box pattern
    func drawBoxPattern(position: float2, size: float2, rounding: Float = 0, borderSize: Float = 0, onion: Float = 0, rotation: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0), texture: MTLTexture? = nil)
    {
        var data = BoxUniform()
        data.screenSize = viewSize
        data.borderSize = borderSize
        data.size = size
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.onion = onion
        data.rotation = rotation.degreesToRadians
        data.hasTexture = texture != nil ? 1 : 0
        data.round = rounding

        let rect = MMRect(position.x - data.borderSize / 2, position.y - data.borderSize / 2, size.x + data.borderSize * 2, size.y + data.borderSize * 2, scale: 1)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<BoxUniform>.stride, index: 0)
        if let texture = texture {
            renderEncoder.setFragmentTexture(texture, index: 1)
        }
        renderEncoder.setRenderPipelineState(metalView.core.metalStates.getState(state: .DrawBackPattern))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws a line
    func drawLine(startPos: float2, endPos: float2, radius: Float, borderSize: Float = 0, fillColor: float4 = float4(1,1,1,1), borderColor: float4 = float4(0,0,0,0))
    {
        let sx = startPos.x
        let sy = startPos.y
        let ex = endPos.x
        let ey = endPos.y
        
        let minX = min(sx, ex)
        let maxX = max(sx, ex)
        let minY = min(sy, ey)
        let maxY = max(sy, ey)
        
        let areaWidth : Float = maxX - minX + borderSize + radius * 2
        let areaHeight : Float = maxY - minY + borderSize + radius * 2
                
        let middleX : Float = (sx + ex) / 2
        let middleY : Float = (sy + ey) / 2
        
        var data = LineUniform()
        data.size = float2(areaWidth, areaHeight)
        data.width = radius
        data.borderSize = borderSize
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.sp = float2(sx - middleX, middleY - sy)
        data.ep = float2(ex - middleX, middleY - ey)

        let rect = MMRect( minX - borderSize / 2, minY - borderSize / 2, areaWidth, areaHeight, scale: 1)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<LineUniform>.stride, index: 0)
        renderEncoder.setRenderPipelineState(metalView.core.metalStates.getState(state: .DrawLine))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws a bezier
    func drawBezier(p1: float2, p2: float2, p3: float2, width: Float = 2, borderSize: Float = 0, fillColor: float4 = float4(1,1,1,0), borderColor: float4 = float4(1,1,1,1))
    {
        let sx = p1.x
        let sy = p1.y
        let mx = p2.x
        let my = p2.y
        let ex = p3.x
        let ey = p3.y
        
        let minX = min(sx, ex)
        let maxX = max(sx, ex)
        let minY = min(sy, ey)
        let maxY = max(sy, ey)
        
        let areaWidth : Float = maxX - minX + borderSize + width * 2 + 200
        let areaHeight : Float = maxY - minY + borderSize + width * 2 + 200
                
        let middleX : Float = (sx + ex) / 2 + 100
        let middleY : Float = (sy + ey) / 2 + 100
        
        var data = BezierUniform()
        data.size = float2(areaWidth, areaHeight)
        data.width = width
        data.borderSize = borderSize
        data.fillColor = fillColor
        data.borderColor = borderColor
        data.p1 = float2(sx - middleX, middleY - sy)
        data.p2 = float2(mx - middleX, middleY - my)
        data.p3 = float2(ex - middleX, middleY - ey)

        let rect = MMRect( minX - borderSize / 2, minY - borderSize / 2, areaWidth, areaHeight, scale: 1)
        let vertexData = createVertexData(rect)
        
        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&data, length: MemoryLayout<BezierUniform>.stride, index: 0)
        renderEncoder.setRenderPipelineState(metalView.core.metalStates.getState(state: .DrawBezier))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Draws the given text
    func drawText(position: float2, text: String, size: Float, color: float4 = float4(1,1,1,1))
    {
        func drawChar(char: BMChar, x: Float, y: Float, adjScale: Float)
        {
            var data = TextUniform()
            
            data.atlasSize.x = Float(font!.atlas!.width)
            data.atlasSize.y = Float(font!.atlas!.height)
            data.fontPos.x = char.x
            data.fontPos.y = char.y
            data.fontSize.x = char.width
            data.fontSize.y = char.height
            data.color = color

            let rect = MMRect(x, y, char.width * adjScale, char.height * adjScale, scale: 1)
            let vertexData = createVertexData(rect)

            renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)

            renderEncoder.setFragmentBytes(&data, length: MemoryLayout<TextUniform>.stride, index: 0)
            renderEncoder.setFragmentTexture(font!.atlas, index: 1)

            renderEncoder.setRenderPipelineState(metalView.core.metalStates.getState(state: .DrawTextChar))
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        if let font = font {
         
            let scale : Float = (1.0 / font.bmFont!.common.lineHeight) * size
            let adjScale : Float = scale// / 2
            
            var posX = position.x// / game.scaleFactor
            let posY = position.y// / game.scaleFactor

            for c in text {
                let bmChar = font.getItemForChar( c )
                if bmChar != nil {
                    drawChar(char: bmChar!, x: posX + bmChar!.xoffset * adjScale, y: posY + bmChar!.yoffset * adjScale, adjScale: adjScale)
                    posX += bmChar!.xadvance * adjScale;
                }
            }
        }
    }
    
    /// Gets the width of the given text
    func getTextWidth(text: String, size: Float) -> Float
    {
        if let font = font {
         
            let scale : Float = (1.0 / font.bmFont!.common.lineHeight) * size
            let adjScale : Float = scale// / 2
            
            var posX : Float = 0

            for c in text {
                let bmChar = font.getItemForChar( c )
                if bmChar != nil {
                    posX += bmChar!.xadvance * adjScale
                }
            }
            
            return posX
        }
        return 0
    }
    
    /// Creates vertex data for the given rectangle
    func createVertexData(_ rect: MMRect) -> [Float]
    {
        let left: Float  = -viewSize.x / 2.0 + rect.x
        let right: Float = left + rect.width
        
        let top: Float = viewSize.y / 2.0 - rect.y
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
    
    /// Updates the view
    func update() {
        metalView.enableSetNeedsDisplay = true
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: metalView.frame.width, height: metalView.frame.height)
        metalView.setNeedsDisplay(nsrect)
        #else
        metalView.setNeedsDisplay()
        #endif
    }
}
