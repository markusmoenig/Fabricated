//
//  NoiseStates.swift
//  Fabricated
//
//  Created by Markus Moenig on 10/5/21.
//

import MetalKit

class NoiseStates {
    
    enum States : Int {
        case Noise2D
    }
    
    var defaultLibrary          : MTLLibrary!

    let pipelineStateDescriptor : MTLRenderPipelineDescriptor
    
    var states                  : [Int:MTLRenderPipelineState] = [:]

    var core                    : Core
    
    init(_ core: Core)
    {
        self.core = core
        
        defaultLibrary = core.device.makeDefaultLibrary()
        
        let vertexFunction = defaultLibrary!.makeFunction( name: "m4mQuadVertexShader" )
        
        pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexFunction
        //        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.r16Float
        
        states[States.Noise2D.rawValue] = createQuadState(name: "noise2D")        
    }
    
    /// Creates a quad state from an optional library and the function name
    func createQuadState( library: MTLLibrary? = nil, name: String ) -> MTLRenderPipelineState?
    {
        let function : MTLFunction?
            
        if library != nil {
            function = library!.makeFunction( name: name )
        } else {
            function = defaultLibrary!.makeFunction( name: name )
        }
                
        var renderPipelineState : MTLRenderPipelineState?
        
        do {
            //renderPipelineState = try device.makeComputePipelineState( function: function! )
            pipelineStateDescriptor.fragmentFunction = function
            renderPipelineState = try core.device.makeRenderPipelineState( descriptor: pipelineStateDescriptor )
        } catch {
            print( "computePipelineState failed" )
            return nil
        }
        
        return renderPipelineState
    }
    
    func getState(state: States) -> MTLRenderPipelineState
    {
        return states[state.rawValue]!
    }
}
