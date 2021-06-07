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
    
    func render(_ core: Core,_ tileJob: TileJob,_ array: inout Array<float4>) {
     
        let tileContext = tileJob.tileContext
        let tileRect = tileJob.tileRect
        let tile = tileContext.tile!
        
        let isoNode = tile.isoNodes[0]
        
        func sdBox(_ p: float3) -> Float
        {
            let offset : Float = isoNode.readFloatFromInstanceAreaIfExists(tileContext.tileArea, isoNode, "Offset")
            let facing : Float = isoNode.readFloatFromInstanceAreaIfExists(tileContext.tileArea, isoNode, "Facing")
            let shapeHeight : Float = isoNode.readFloatFromInstanceAreaIfExists(tileContext.tileArea, isoNode, "Height")// + 0.02
            let shapeSize : Float = isoNode.readFloatFromInstanceAreaIfExists(tileContext.tileArea, isoNode, "Size")// + 0.02

            var size     : float3
            
            var moveBy   : float3
            var offsetBy : Float
            
            if offset >= 0 {
                offsetBy = min(offset, 1.0 - shapeSize)
            } else {
                offsetBy = max(offset, -(1.0 - shapeSize))
            }

            if facing == 0 {
                // Facing right
                size = float3(shapeSize, shapeHeight, 1)
                moveBy = float3(offsetBy, -(1 - shapeHeight), 0)
            } else {
                // Facing left
                size = float3(1, shapeHeight, shapeSize)
                moveBy = float3(0, -(1 - shapeHeight), offsetBy)
            }
            
            let q : float3 = abs(p - moveBy) - size
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
        
        let AA = max(Int(core.project.getAntiAliasing()), 1)
        let tileSize = float2(Float(tileRect.width), Float(tileRect.height))
        
        for h in tileRect.y..<tileRect.bottom {

            for w in tileRect.x..<tileRect.right {
                
                var total = float4(0,0,0,0)

                let areaOffset = /*tileContext.areaOffset +*/ float2(Float(w), Float(h))
                let areaSize = tileContext.areaSize * tileSize

                let pixelContext = TilePixelContext(areaOffset: areaOffset, areaSize: areaSize, tileRect: tileRect)
                                
                for m in 0..<AA {
                    for n in 0..<AA {

                        let camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5
                        let camera = isoCamera(uv: pixelContext.uv, tileSize: tileSize, origin: float3(1.2,1.2,1.2), lookAt: float3(0,0,0), fov: 15, offset: camOffset)
                        
                        // Raymarch
                        var hit = false
                        var t : Float = 0.001
                        let maxDist : Float = 4

                        for _ in 0..<70
                        {
                            let pos = camera.0 + t * camera.1
                            //executeSDF(camOrigin + t * camDir)

                            let d = sdBox(pos)
                            
                            if abs(d) < (0.0001*t) {
                                hit = true
                                break
                            } else
                            if t > maxDist {
                                break
                            }
                            
                            t += d
                        }
                        
                        if hit == true {
                            let hp = camera.0 + t * camera.1
                            let normal = calcNormal(position: hp)

                            /*
                            total.x += normal.x
                            total.y += normal.y
                            total.z += normal.z
                            total.w += 1
                            */
                            
                            let areaOffset = tileContext.areaOffset + float2(Float(w), Float(h))
                            let areaSize = tileContext.areaSize * float2(Float(tileRect.width), Float(tileRect.height))

                            let pixelContext = TilePixelContext(areaOffset: areaOffset, areaSize: areaSize, tileRect: tileRect)
                            let tile = tileContext.tile!
                            
                            let nodes   = tile.isoNodes
                            let isoNode = tile.isoNodes[0] as! IsoTiledNode
                            let isoFaceBuffer = isoNode.isoFace
                            var uv      = float2(0,0)
                                                        
                            if normal.y > 0.5 {
                                // Top
                                uv = (float2(hp.x, hp.z) * 0.5) + 0.5
                                pixelContext.uv = uv
                                isoNode.isoFace = .Top
                            } else
                            if normal.z > 0.5 {
                                // Left
                                uv = (float2(hp.x, hp.y) * 0.5) + 0.5
                                uv.y = 1.0 - uv.y
                                pixelContext.uv = uv
                                isoNode.isoFace = .Left
                            } else {
                            //if normal.x > 0.5 {
                                // Right
                                uv = (float2(hp.z, hp.y) * 0.5) + 0.5
                                uv.y = 1.0 - uv.y
                                pixelContext.uv = uv
                                isoNode.isoFace = .Right
                            }
                            
                            var color = float4(0, 0, 0, 0)

                            if nodes.count > 0 {
                                
                                let noded = nodes[0]
                                let offset = noded.readFloat2FromInstanceAreaIfExists(tileContext.tileArea, noded, "_offset", float2(0.5, 0.5)) - float2(0.5, 0.5)
                                pixelContext.uv -= offset
                                pixelContext.areaUV -= offset
                                                                                            
                                var node = tile.getNextInChain(nodes[0], .Shape)
                                while node !== nil {
                                    color = node!.render(pixelCtx: pixelContext, tileCtx: tileContext, prevColor: color)
                                    node = tile.getNextInChain(node!, .Shape)
                                }
                                
                                total += color
                            }
                            
                            isoNode.isoFace = isoFaceBuffer
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
        
        let uv1 = uv + float2(pixelSize.x * 0.75, pixelSize.y * 0.10)

        let camOrigin = origin
        let camLookAt = lookAt

        let halfWidth : Float = tan(fov.degreesToRadians * 0.5) * fov
        let halfHeight : Float = halfWidth / ratio
        
        let upVector = float3(0.0, 1.0, 0.0)

        let w : float3 = simd_normalize(camOrigin - camLookAt)
        let u : float3 = simd_cross(upVector, w)
        let v : float3 = simd_cross(w, u)
        
        let horizontal = u * halfWidth * 1.72
        let vertical = v * halfHeight * 2.0
                
        var outOrigin = camOrigin
        outOrigin += horizontal * (pixelSize.x * offset.x + uv1.x - 0.5)
        outOrigin += vertical * (pixelSize.y * offset.y + (1.0 - uv1.y) - 0.5)
        
        return (outOrigin, simd_normalize(-w))
    }
}
