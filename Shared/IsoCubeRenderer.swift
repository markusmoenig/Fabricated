//
//  IsoCubeRenderer.swift
//  Fabricated
//
//  Created by Markus Moenig on 20/5/21.
//

import Foundation

class IsoCubeRenderer
{
    init() {
    }
    
    func render(_ renderer: Renderer,_ tileJob: TileJob,_ array: inout Array<float4>) {
     
        let tileContext = tileJob.tileContext
        let tileRect = tileJob.tileRect
        //let tile = tileContext.tile!
        
        func sdBox(_ p: float3) -> Float
        {
            let size = float3(1,1,1)
            let q : float3 = abs(p - float3(0,0,0)) - size
            return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0)
        }
        
        func calcNormal(position: float3) -> float3
        {
            /*
            vec3 epsilon = vec3(0.001, 0., 0.);
            
            vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                          map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                          map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
            
            return normalize(n);*/

            let e = float3(0.001, 0.0, 0.0)

            var eOff : float3 = position + float3(e.x, e.y, e.y)
            var n1 = sdBox(eOff)
            
            eOff = position - float3(e.x, e.y, e.y)
            n1 = n1 - sdBox(eOff)
            
            eOff = position + float3(e.y, e.x, e.y)
            var n2 = sdBox(eOff)
            
            eOff = position - float3(e.y, e.x, e.y)
            n2 = n2 - sdBox(eOff)
            
            eOff = position + float3(e.y, e.y, e.x)
            var n3 = sdBox(eOff)
            
            eOff = position - float3(e.y, e.y, e.x)
            n3 = n3 - sdBox(eOff)
            
            return simd_normalize(float3(n1, n2, n3))
        }
        
        let AA = max(Int(renderer.core.project.getAntiAliasing()), 1)
        let tileSize = float2(Float(tileRect.width), Float(tileRect.height))

        for h in tileRect.y..<tileRect.bottom {

            for w in tileRect.x..<tileRect.right {
                
                var total = float4(0,0,0,0)

                let areaOffset = tileContext.areaOffset + float2(Float(w), Float(h))
                let areaSize = tileContext.areaSize * tileSize

                let pixelContext = TilePixelContext(areaOffset: areaOffset, areaSize: areaSize, tileRect: tileRect)
                                
                for m in 0..<AA {
                    for n in 0..<AA {

                        let camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5
                        let camera = isoCamera(uv: pixelContext.uv, tileSize: tileSize, origin: float3(8,8,8), lookAt: float3(0,0,0), fov: 15.5, offset: camOffset)
                        
                        // Raymarch
                        var hit = false
                        var t : Float = 0.001;

                        for _ in 0..<70
                        {
                            let pos = camera.0 + t * camera.1
                            //executeSDF(camOrigin + t * camDir)

                            let d = sdBox(pos)
                            
                            if abs(d) < (0.0001*t) {
                                hit = true
                                break
                            } /*else
                            if t > maxDist {
                                break
                            }*/
                            
                            t += d
                        }
                        
                        if hit == true {
                            let normal = calcNormal(position: camera.0 + t * camera.1)

                            total.x += normal.x
                            total.y += normal.y
                            total.z += normal.z
                            total.w += 1
                        }
                    }
                }
                array[(h - tileRect.y) * tileRect.width + w - tileRect.x] = total / Float(AA*AA)
            }
        }
    }
    
    /// isoCamera
    func isoCamera(uv: float2, tileSize: float2, origin: float3, lookAt: float3, fov: Float, offset: float2) -> (float3, float3)
    {
        let ratio : Float = tileSize.x / tileSize.y
        let pixelSize : float2 = float2(1.0, 1.0) / tileSize

        let camOrigin = origin
        let camLookAt = lookAt

        let halfWidth : Float = tan(fov.degreesToRadians * 0.5) * fov
        let halfHeight : Float = halfWidth / ratio
        
        let upVector = float3(0.0, 1.0, 0.0)

        let w : float3 = simd_normalize(camOrigin - camLookAt)
        let u : float3 = simd_cross(upVector, w)
        let v : float3 = simd_cross(w, u)

        /*
        var lowerLeft : float3 = camOrigin - halfWidth * u
        lowerLeft -= halfHeight * v - w
        
        let horizontal : float3 = u * halfWidth * 2.0
        
        let vertical : float3 = v * halfHeight * 2.0
        var dir : float3 = lowerLeft - camOrigin

        dir += horizontal * (pixelSize.x * offset.x + uv.x)
        dir += vertical * (pixelSize.y * offset.y + uv.y)*/
        
        let horizontal = u * halfWidth * 2.0
        let vertical = v * halfHeight * 2.0
                
        var outOrigin = camOrigin
        outOrigin += horizontal * (pixelSize.x * offset.x + uv.x - 0.5)
        outOrigin += vertical * (pixelSize.y * offset.y + (1.0 - uv.y) - 0.5)
        
        return (outOrigin, simd_normalize(-w))
    }
}
