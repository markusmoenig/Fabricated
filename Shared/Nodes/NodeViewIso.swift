//
//  NodeViewIso.swift
//  Fabricated
//
//  Created by Markus Moenig on 27/5/21.
//

import MetalKit

extension NodeView {
    
    func handleClickOnIsoCube(_ pos: float2) -> Bool
    {
        if let screen = core.project.getCurrentScreen(), let tile = getCurrentTile() {
            if screen.gridType == .rectIso {
                let corner = drawables.viewSize - Float(isoCubeSize)
                if pos.x > corner.x && pos.y > corner.y {

                    let x : Int = Int(pos.x - corner.x)
                    let y : Int = Int(pos.y - corner.y)
                    
                    let n = isoCubeNormalArray[y * isoCubeSize + x]
                    
                    if (n.z > 0.5) {
                        isoFace = .Left
                        update()
                    } else
                    if (n.y > 0.5) {
                        isoFace = .Top
                        update()
                    } else
                    if (n.x > 0.5) {
                        isoFace = .Right
                        update()
                    }
                    
                    setCurrentNode(tile.isoCubeNode)
                    core.updateTilePreviews(tile)
                    
                    return true
                }
            }
        }
        return false
    }
    
    func renderIsoCube()
    {
        let width  : Float = Float(previewTexture.width)
        let height : Float = Float(previewTexture.height)
        
        let widthInt  = previewTexture.width
        let heightInt = previewTexture.height
        
        let AA = 2
        
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
        
        var isoTopArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
        var isoLeftArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
        var isoRightArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt * heightInt)
        
        let isoCubeRenderer = IsoCubeRenderer()
                
        for h in 0..<heightInt {

            let fh : Float = Float(h) / height
            for w in 0..<widthInt {
                
                let uv = float2(Float(w) / width, fh)

                var total = float4(0,0,0,0)
                var totalIsoTop = float4(0,0,0,0)
                var totalIsoLeft = float4(0,0,0,0)
                var totalIsoRight = float4(0,0,0,0)
                var totalIsoNormal = float4(0,0,0,0)

                for m in 0..<AA {
                    for n in 0..<AA {

                        let camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5

                        //func isoCamera(uv: float2, tileSize: float2, origin: float3, lookAt: float3, fov: Float, offset: float2) -> (float3, float3)

                        let camera = isoCubeRenderer.isoCamera(uv: uv, tileSize: float2(width, height), origin: float3(8,8,8), lookAt: float3(0,0,0), fov: 15.1, offset: camOffset)
                        
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
                            
                            let selectedColor : Float = 0.8
                            let normalColor : Float = 0.3

                            let normal = calcNormal(position: camera.0 + t * camera.1)
                            total.x += normal.x
                            total.y += normal.y
                            total.z += normal.z
                            total.w += 1
                            
                            totalIsoNormal.x += normal.x
                            totalIsoNormal.y += normal.y
                            totalIsoNormal.z += normal.z

                            totalIsoTop.w += 1
                            totalIsoLeft.w += 1
                            totalIsoRight.w += 1

                            if normal.y > 0.5 {
                                totalIsoTop.x += selectedColor
                                totalIsoTop.y += selectedColor
                                totalIsoTop.z += selectedColor
                            } else {
                                totalIsoTop.x += normalColor
                                totalIsoTop.y += normalColor
                                totalIsoTop.z += normalColor
                            }
                            
                            if normal.z > 0.5 {
                                totalIsoLeft.x += selectedColor
                                totalIsoLeft.y += selectedColor
                                totalIsoLeft.z += selectedColor
                            } else {
                                totalIsoLeft.x += normalColor
                                totalIsoLeft.y += normalColor
                                totalIsoLeft.z += normalColor
                            }
                            
                            if normal.x > 0.5 {
                                totalIsoRight.x += selectedColor
                                totalIsoRight.y += selectedColor
                                totalIsoRight.z += selectedColor
                            } else {
                                totalIsoRight.x += normalColor
                                totalIsoRight.y += normalColor
                                totalIsoRight.z += normalColor
                            }
                        }
                    }
                }
                
                isoTopArray[h * widthInt + w] = totalIsoTop / Float(AA*AA)
                isoLeftArray[h * widthInt + w] = totalIsoLeft / Float(AA*AA)
                isoRightArray[h * widthInt + w] = totalIsoRight / Float(AA*AA)
                
                isoCubeNormalArray[h * widthInt + w] = totalIsoNormal / Float(AA*AA)
            }
        }
        
        DispatchQueue.main.sync {
            let region = MTLRegionMake2D(0, 0, widthInt, heightInt)
            
            // Iso Top
            isoTopArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewTop.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            // Iso Left
            isoLeftArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewLeft.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            // Iso Right
            isoRightArray.withUnsafeMutableBytes { texArrayPtr in
                isoCubePreviewRight.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            drawables.update()
        }
    }
    
}

/// MARK: IsoNodes used to show IsoCube options

final class IsoCubeNode : TileNode {
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    required init()
    {
        super.init(.Shape, "IsoCube")
    }
    
    override func setup()
    {
        type = "IsoCube"
        
        optionGroups.append(TileNodeOptionsGroup("Iso Shape Options", [
            TileNodeOption(self, "Noise", .Menu, menuEntries: ["Cube"], defaultFloat: 0),
            TileNodeOption(self, "Orientation", .Menu, menuEntries: ["Normal", "Back"], defaultFloat: 0),
            TileNodeOption(self, "Size", .Float, range: float2(0, 1), defaultFloat: 1),
            TileNodeOption(self, "Height", .Float, range: float2(0, 1), defaultFloat: 1),
            TileNodeOption(self, "Offset", .Float, range: float2(-1, 1), defaultFloat: 0),
        ]))
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
}

