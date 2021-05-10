//
//  Noise.metal
//  Fabricated
//
//  Created by Markus Moenig on 10/5/21.
//

#include <metal_stdlib>
using namespace metal;

#import "../Metal.h"

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} NoiseRasterizerData;

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

// Mark: Hashes

uint ihash1D(uint q)
{
    // hash by Hugo Elias, Integer Hash - I, 2017
    q = (q << 13u) ^ q;
    return q * (q * q * 15731u + 789221u) + 1376312589u;
}

uint2 ihash1D(uint2 q)
{
    // hash by Hugo Elias, Integer Hash - I, 2017
    q = (q << 13u) ^ q;
    return q * (q * q * 15731u + 789221u) + 1376312589u;
}

uint4 ihash1D(uint4 q)
{
    // hash by Hugo Elias, Integer Hash - I, 2017
    q = (q << 13u) ^ q;
    return q * (q * q * 15731u + 789221u) + 1376312589u;
}

// @return Value of the noise, range: [0, 1]
float hash1D(float x)
{
    // based on: pcg by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint state = uint(x * 8192.0) * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return float((word >> 22u) ^ word) * (1.0 / float(0xffffffffu));;
}

// @return Value of the noise, range: [0, 1]
float hash1D(float2 x)
{
    // hash by Inigo Quilez, Integer Hash - III, 2017
    uint2 q = uint2(x * 8192.0);
    q = 1103515245u * ((q >> 1u) ^ q.yx);
    uint n = 1103515245u * (q.x ^ (q.y >> 3u));
    return float(n) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float hash1D(float3 x)
{
    // based on: pcg3 by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint3 v = uint3(x * 8192.0) * 1664525u + 1013904223u;
    v += v.yzx * v.zxy;
    v ^= v >> 16u;
    return float(v.x + v.y * v.z) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float2 hash2D(float2 x)
{
    // based on: Inigo Quilez, Integer Hash - III, 2017
    uint4 q = uint2(x * 8192.0).xyyx + uint2(0u, 3115245u).xxyy;
    q = 1103515245u * ((q >> 1u) ^ q.yxwz);
    uint2 n = 1103515245u * (q.xz ^ (q.yw >> 3u));
    return float2(n) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float3 hash3D(float2 x)
{
    // based on: pcg3 by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint3 v = uint3(x.xyx * 8192.0) * 1664525u + 1013904223u;
    v += v.yzx * v.zxy;
    v ^= v >> 16u;

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return float3(v) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float3 hash3D(float3 x)
{
    // based on: pcg3 by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint3 v = uint3(x * 8192.0) * 1664525u + 1013904223u;
    v += v.yzx * v.zxy;
    v ^= v >> 16u;

    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return float3(v) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float4 hash4D(float2 x)
{
    // based on: pcg4 by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint4 v = uint4(x.xyyx * 8192.0) * 1664525u + 1013904223u;

    v += v.yzxy * v.wxyz;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    
    v.x += v.y * v.w;
    v.w += v.y * v.z;
    
    v ^= v >> 16u;

    return float4(v ^ (v >> 16u)) * (1.0 / float(0xffffffffu));
}

// @return Value of the noise, range: [0, 1]
float4 hash4D(float4 x)
{
    // based on: pcg4 by Mark Jarzynski: http://www.jcgt.org/published/0009/03/02/
    uint4 v = uint4(x * 8192.0) * 1664525u + 1013904223u;

    v += v.yzxy * v.wxyz;
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;
    
    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;

    v ^= v >> 16u;

    return float4(v ^ (v >> 16u)) * (1.0 / float(0xffffffffu));
}

// Mark: Multihashes

// based on GPU Texture-Free Noise by Brian Sharpe: https://archive.is/Hn54S
float3 permutePrepareMod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float4 permutePrepareMod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float4 permuteResolve(float4 x) { return fract( x * (7.0 / 288.0 )); }
float4 permuteHashInternal(float4 x) { return fract(x * ((34.0 / 289.0) * x + (1.0 / 289.0))) * 289.0; }

// generates a random number for each of the 4 cell corners
float4 permuteHash2D(float4 cell)
{
    cell = permutePrepareMod289(cell * 32.0);
    return permuteResolve(permuteHashInternal(permuteHashInternal(cell.xzxz) + cell.yyww));
}

// generates 2 random numbers for each of the 4 cell corners
void permuteHash2D(float4 cell, thread float4 &hashX, thread float4 &hashY)
{
    cell = permutePrepareMod289(cell);
    hashX = permuteHashInternal(permuteHashInternal(cell.xzxz) + cell.yyww);
    hashY = permuteResolve(permuteHashInternal(hashX));
    hashX = permuteResolve(hashX);
}

// generates 2 random numbers for the coordinate
float2 betterHash2D(float2 x)
{
    uint2 q = uint2(x);
    uint h0 = ihash1D(ihash1D(q.x) + q.y);
    uint h1 = h0 * 1933247u + ~h0 ^ 230123u;
    return float2(h0, h1)  * (1.0 / float(0xffffffffu));
}

// generates a random number for each of the 4 cell corners
float4 betterHash2D(float4 cell)
{
    uint4 i = uint4(cell) + 101323u;
    uint4 hash = ihash1D(ihash1D(i.xzxz) + i.yyww);
    return float4(hash) * (1.0 / float(0xffffffffu));
}

// generates 2 random numbers for each of the 4 cell corners
void betterHash2D(float4 cell, thread float4 &hashX, thread float4 &hashY)
{
    uint4 i = uint4(cell) + 101323u;
    uint4 hash0 = ihash1D(ihash1D(i.xzxz) + i.yyww);
    uint4 hash1 = ihash1D(hash0 ^ 1933247u);
    hashX = float4(hash0) * (1.0 / float(0xffffffffu));
    hashY = float4(hash1) * (1.0 / float(0xffffffffu));
}

// generates 2 random numbers for each of the four 2D coordinates
void betterHash2D(float4 coords0, float4 coords1, thread float4 &hashX, thread float4 &hashY)
{
    uint4 hash0 = ihash1D(ihash1D(uint4(uint2(coords0.xz), uint2(coords1.xz))) + uint4(uint2(coords0.yw), uint2(coords1.yw)));
    uint4 hash1 = hash0 * 1933247u + ~hash0 ^ 230123u;
    hashX = float4(hash0) * (1.0 / float(0xffffffffu));
    hashY = float4(hash1) * (1.0 / float(0xffffffffu));
}

// 3D

// generates a random number for each of the 8 cell corners
void permuteHash3D(float3 cell, float3 cellPlusOne, thread float4 &lowHash, thread float4 &highHash)
{
    cell = permutePrepareMod289(cell);
    cellPlusOne = step(cell, float3(287.5)) * cellPlusOne;

    highHash = permuteHashInternal(permuteHashInternal(float2(cell.x, cellPlusOne.x).xyxy) + float2(cell.y, cellPlusOne.y).xxyy);
    lowHash = permuteResolve(permuteHashInternal(highHash + cell.zzzz));
    highHash = permuteResolve(permuteHashInternal(highHash + cellPlusOne.zzzz));
}

// generates a random number for each of the 8 cell corners
void fastHash3D(float3 cell, float3 cellPlusOne, thread float4 &lowHash, thread float4 &highHash)
{
    // based on: https://archive.is/wip/7j1wv
    const float2 kOffset = float2(50.0, 161.0);
    const float kDomainScale = 289.0;
    const float kLargeValue = 635.298681;
    const float kk = 48.500388;
    
    //truncate the domain, equivalant to mod(cell, kDomainScale)
    cell -= floor(cell.xyz * (1.0 / kDomainScale)) * kDomainScale;
    cellPlusOne = step(cell, float3(kDomainScale - 1.5)) * cellPlusOne;

    float4 r = float4(cell.xy, cellPlusOne.xy) + kOffset.xyxy;
    r *= r;
    r = r.xzxz * r.yyww;
    highHash.xy = float2(1.0 / (kLargeValue + float2(cell.z, cellPlusOne.z) * kk));
    lowHash = fract(r * highHash.xxxx);
    highHash = fract(r * highHash.yyyy);
}

// generates a random number for each of the 8 cell corners
void betterHash3D(float3 cell, float3 cellPlusOne, thread float4 &lowHash, thread float4 &highHash)
{
    uint4 cells = uint4(uint2(cell.xy), uint2(cellPlusOne.xy));
    uint4 hash = ihash1D(ihash1D(cells.xzxz) + cells.yyww);
    
    lowHash = float4(ihash1D(hash + uint(cell.z))) * (1.0 / float(0xffffffffu));
    highHash = float4(ihash1D(hash + uint(cellPlusOne.z))) * (1.0 / float(0xffffffffu));
}

// @note Can change to (faster to slower order): permuteHash2D, betterHash2D
// Each has a tradeoff between quality and speed, some may also experience artifacts for certain ranges and are not realiable.
#define multiHash2D betterHash2D

// @note Can change to (faster to slower order): fastHash3D, permuteHash3D, betterHash3D
// Each has a tradeoff between quality and speed, some may also experience artifacts for certain ranges and are not realiable.
#define multiHash3D betterHash3D

void smultiHash2D(float4 cell, thread float4 &hashX, thread float4 &hashY)
{
    multiHash2D(cell, hashX, hashY);
    hashX = hashX * 2.0 - 1.0;
    hashY = hashY * 2.0 - 1.0;
}

// Mark: Interpolate

// the main noise interpolation function using a hermite polynomial
float noiseInterpolate(const float x)
{
    float x2 = x * x;
    return x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float2 noiseInterpolate(const float2 x)
{
    float2 x2 = x * x;
    return x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float3 noiseInterpolate(const float3 x)
{
    float3 x2 = x * x;
    return x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float4 noiseInterpolate(const float4 x)
{
    float4 x2 = x * x;
    return x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float4 noiseInterpolateDu(const float2 x)
{
    float2 x2 = x * x;
    float2 u = x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
    float2 du = 30.0 * x2 * (x * (x - 2.0) + 1.0);
    return float4(u, du);
}

void noiseInterpolateDu(const float3 x, thread float3 &u, thread float3 &du)
{
    float3 x2 = x * x;
    u = x2 * x * (x * (x * 6.0 - 15.0) + 10.0);
    du = 30.0 * x2 * (x * (x - 2.0) + 1.0);
}

// Mark: noise

// mod

float mod(float x, float y) {
    return x - y * floor(x / y);
}

float2 mod(float2 x, float2 y) {
    return x - y * floor(x / y);
}

float4 mod(float4 x, float4 y) {
    return x - y * floor(x / y);
}

// 1D Value noise.
// @param scale Number of tiles, must be an integer for tileable results, range: [2, inf]
// @param seed Seed to randomize result, range: [0, inf]
// @return Value of the noise, range: [-1, 1]
float noise(float pos, float scale, float seed)
{
    pos *= scale;
    float2 i = floor(pos) + float2(0.0, 1.0);
    float f = pos - i.x;
    i = mod(i, float2(scale)) + seed;

    float u = noiseInterpolate(f);
    return mix(hash1D(i.x), hash1D(i.y), u) * 2.0 - 1.0;
}

// 2D Value noise.
// @param scale Number of tiles, must be an integer for tileable results, range: [2, inf]
// @param seed Seed to randomize result, range: [0, inf]
// @return Value of the noise, range: [-1, 1]
float noise(float2 pos, float2 scale, float seed)
{
    pos *= scale;
    float4 i = floor(pos).xyxy + float2(0.0, 1.0).xxyy;
    float2 f = pos - i.xy;
    i = mod(i, scale.xyxy) + seed;

    float4 hash = multiHash2D(i);
    float a = hash.x;
    float b = hash.y;
    float c = hash.z;
    float d = hash.w;

    float2 u = noiseInterpolate(f);
    float value = mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    return value * 2.0 - 1.0;
}

// Mark: Entry Points

fragment float noise2D( NoiseRasterizerData in [[stage_in]], constant NoiseData *data [[ buffer(0) ]])
{
    float2 uv = in.textureCoordinate;
    
    return noise(uv, float2(2, 2), 1);
}
