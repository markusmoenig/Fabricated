//
//  Noise.swift
//  Fabricated
//
//  Created by Markus Moenig on 17/4/21.
//

import simd

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

// the main noise interpolation function using a hermite polynomial
/*
vec2 noiseInterpolate(const in vec2 x)
{
    vec2 x2 = x * x;
    return x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
}*/

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
    var _pos = pos
    _pos *= scale
    
    let _pos_floor = floor(_pos)
    
    //vec4 i = floor(pos).xyxy + vec2(0.0, 1.0).xxyy;
    var i : float4 = float4( _pos_floor.x + 0,
                             _pos_floor.y + 0,
                             _pos_floor.x + 1,
                             _pos_floor.y + 1)
    let f : float2 = _pos - float2(i.x, i.y)
    
    //i = mod(i, scale.xyxy) + seed
    i.x = i.x.truncatingRemainder(dividingBy: scale.x) + seed
    i.y = i.y.truncatingRemainder(dividingBy: scale.y) + seed
    i.z = i.z.truncatingRemainder(dividingBy: scale.x) + seed
    i.w = i.w.truncatingRemainder(dividingBy: scale.y) + seed

    let hash = permuteHash2D(i)
    let a = hash.x
    let b = hash.y
    let c = hash.z
    let d = hash.w

    let u = noiseInterpolate(f)
    let value = simd_mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y
    return value * 2.0 - 1.0
}
