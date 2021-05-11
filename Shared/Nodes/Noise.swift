//
//  Noise.swift
//  Fabricated
//
//  Created by Markus Moenig on 17/4/21.
//

import simd
import Surge

func f42a(_ a: [Float] ) -> float4 {
    return float4(a[0], a[1], a[2], a[3])
}

// Tileable noises based on https://github.com/tuxalin/procedural-tileable-shaders

/*
 MIT License

 Copyright (c) 2019 Alin

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

// based on GPU Texture-Free Noise by Brian Sharpe: https://archive.is/Hn54S
func permutePrepareMod289(_ x : float3) -> float3 { return x - floor(x * (1.0 / 289.0)) * 289.0 }
func permutePrepareMod289(_ x : float4) -> float4 { return x - floor(x * (1.0 / 289.0)) * 289.0 }
func permuteResolve(_ x : float4) -> float4 { return fract( x * (7.0 / 288.0 )) }
func permuteHashInternal(_ x : float4) -> float4 { return fract(x * ((34.0 / 289.0) * x + (1.0 / 289.0))) * 289.0 }

// generates a random number for each of the 4 cell corners
func permuteHash2D(_ cellIn: float4) -> float4
{
    let cell = permutePrepareMod289(cellIn * 32.0)
    let c1 = float4(cell.x, cell.z, cell.x, cell.z)//cell.xzxz
    let c2 = float4(cell.y, cell.y, cell.w, cell.w)//cell.yyww
    return permuteResolve(permuteHashInternal(permuteHashInternal(c1) + c2));
}

// generates 2 random numbers for each of the 4 cell corners
func permuteHash2D(_ cellIn: float4,_ hashX: inout float4,_ hashY: inout float4)
{
    let cell = permutePrepareMod289(cellIn)
    let c1 = float4(cell.x, cell.z, cell.x, cell.z)//cell.xzxz
    let c2 = float4(cell.y, cell.y, cell.w, cell.w)//cell.yyww
    hashX = permuteHashInternal(permuteHashInternal(c1) + c2)
    hashY = permuteResolve(permuteHashInternal(hashX))
    hashX = permuteResolve(hashX)
}

// the main noise interpolation function using a hermite polynomial
func noiseInterpolate(_ x: float2) -> float2
{
    let x2 = x * x
    let xx = x2 * x
    let xxx = (x * (x * float2(6.0,6.0) - float2(15.0,15.0)) + float2(10.0, 10.0))
    return xx * xxx
}

// 2D Value noise.
// @param scale Number of tiles, must be an integer for tileable results, range: [2, inf]
// @param seed Seed to randomize result, range: [0, inf]
// @return Value of the noise, range: [-1, 1]
func noise(pos: float2, scale: float2, seed: Float) -> Float
{
    let _pos = [pos.x * scale.x, pos.y * scale.y]
    let _pos_floor = Surge.floor(_pos)
    
    var i = Surge.add([_pos_floor[0], _pos_floor[1], _pos_floor[0], _pos_floor[1]], [0, 0, 1, 1])
    let f = Surge.sub([_pos[0], _pos[1]], [i[0], i[1]])
    
    i = Surge.add(Surge.mod(i, [scale.x, scale.y, scale.x, scale.y]), seed)
    
    let hash = permuteHash2D(float4(i[0], i[1], i[2], i[3]))
    let a = hash.x
    let b = hash.y
    let c = hash.z
    let d = hash.w

    let u = noiseInterpolate([f[0], f[1]])
    let value = simd_mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y
    return value * 2.0 - 1.0
}

// 2D Gradient noise.
// @param scale Number of tiles, must be  integer for tileable results, range: [2, inf]
// @param seed Seed to randomize result, range: [0, inf], default: 0.0
// @return Value of the noise, range: [-1, 1]
func gradientNoise(pos: float2, scale: float2, seed: Float) -> Float
{
    let _pos = [pos.x * scale.x, pos.y * scale.y]

    // based on Modifications to Classic Perlin Noise by Brian Sharpe: https://archive.is/cJtlS
    //vec4 i = floor(pos).xyxy + vec2(0.0, 1.0).xxyy;
    let _pos_floor = Surge.floor(_pos)
    var i = Surge.add([_pos_floor[0], _pos_floor[1], _pos_floor[0], _pos_floor[1]], [0, 0, 1, 1])

    //vec4 f = (pos.xyxy - i.xyxy) - vec2(0.0, 1.0).xxyy;
    let f = Surge.sub(Surge.sub([_pos[0], _pos[1], _pos[0], _pos[1]], [i[0], i[1], i[0], i[1]]), [0,0,1,1])

    //i = mod(i, scale.xyxy) + seed
    i = Surge.add(Surge.mod(i, [scale.x, scale.y, scale.x, scale.y]), seed)
    
    // grid gradients
    var hashX: float4 = float4(0,0,0,0)
    var hashY: float4 = float4(0,0,0,0)
    
    permuteHash2D(float4(i[0], i[1], i[2], i[3]), &hashX, &hashY)
    
    //vec4 gradients = hashX * f.xzxz + hashY * f.yyww;
    var gradients = Surge.elmul([hashX.x, hashX.y, hashX.z, hashX.w], [f[0], f[2], f[0], f[2]])
    gradients = Surge.add(gradients, Surge.elmul([hashY.y, hashY.y, hashY.w, hashY.w], [f[1], f[1], f[3], f[3]]))
    
    let u = noiseInterpolate(float2(f[0], f[1]))
    //vec2 g = mix(gradients.xz, gradients.yw, u.x);
    let g = float2(
        simd_mix(gradients[0], gradients[1], u.x),
        simd_mix(gradients[2], gradients[3], u.x)
    )
    return 1.4142135623730950 * simd_mix(g.x, g.y, u.y);
}

// 2D Perlin noise.
// @param scale Number of tiles, must be  integer for tileable results, range: [2, inf]
// @param seed Seed to randomize result, range: [0, inf], default: 0.0
// @return Value of the noise, range: [-1, 1]
func perlinNoise(pos: float2, scale: float2, seed: Float) -> Float
{
    let _pos = [pos.x * scale.x, pos.y * scale.y]

    // based on Modifications to Classic Perlin Noise by Brian Sharpe: https://archive.is/cJtlS
    //vec4 i = floor(pos).xyxy + vec2(0.0, 1.0).xxyy;
    let _pos_floor = Surge.floor(_pos)
    var i = Surge.add([_pos_floor[0], _pos_floor[1], _pos_floor[0], _pos_floor[1]], [0, 0, 1, 1])

    //vec4 f = (pos.xyxy - i.xyxy) - vec2(0.0, 1.0).xxyy;
    let f = Surge.sub(Surge.sub([_pos[0], _pos[1], _pos[0], _pos[1]], [i[0], i[1], i[0], i[1]]), [0,0,1,1])

    //i = mod(i, scale.xyxy) + seed
    i = Surge.add(Surge.mod(i, [scale.x, scale.y, scale.x, scale.y]), seed)
    
    // grid gradients
    var gradientX: float4 = float4(0,0,0,0)
    var gradientY: float4 = float4(0,0,0,0)
    
    permuteHash2D(float4(i[0], i[1], i[2], i[3]), &gradientX, &gradientY)
    gradientX -= 0.49999
    gradientY -= 0.49999
    
    func invSqrt(_ x: Float) -> Float {
        let halfx = 0.5 * x
        var y = x
        var i : Int32 = 0
        memcpy(&i, &y, 4)
        i = 0x5f3759df - (i >> 1)
        memcpy(&y, &i, 4)
        y = y * (1.5 - (halfx * y * y))
        return y
    }

    // perlin surflet
    //vec4 gradients = inversesqrt(gradientX * gradientX + gradientY * gradientY) * (gradientX * f.xzxz + gradientY * f.yyww);
    var gradients : float4 = float4(
        (invSqrt(gradientX.x * gradientX.x + gradientY.x * gradientY.x)) * (gradientX.x * f[0] + gradientY.x * f[1]),
        (invSqrt(gradientX.y * gradientX.y + gradientY.y * gradientY.y)) * (gradientX.y * f[2] + gradientY.y * f[1]),
        (invSqrt(gradientX.z * gradientX.z + gradientY.z * gradientY.z)) * (gradientX.z * f[0] + gradientY.z * f[3]),
        (invSqrt(gradientX.w * gradientX.w + gradientY.w * gradientY.w)) * (gradientX.w * f[2] + gradientY.w * f[3])
        )
    
    // normalize: 1.0 / 0.75^3
    gradients *= 2.3703703703703703703703703703704
    var lengthSq = Surge.elmul(f, f)
    //lengthSq = lengthSq.xzxz + lengthSq.yyww
    lengthSq = Surge.add([lengthSq[0], lengthSq[2], lengthSq[0], lengthSq[2]], [lengthSq[1], lengthSq[1], lengthSq[3], lengthSq[3]])
    var xSq = 1.0 - min(float4(1.0, 1.0, 1.0, 1.0), f42a(lengthSq))
    xSq = xSq * xSq * xSq
    return dot(xSq, gradients)
}
