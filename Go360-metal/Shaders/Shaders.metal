//
//  Shaders.metal
//  Go-Metal
//
//  Created by Mark Lim Pak Mun on 11/10/2020.
//  Copyright © 2020 Mark Lim Pak Mun. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// The model has all 3 vertex attributes viz. position, normal & texture coordinates.
struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];  // unused
};

struct VertexOut {
    float4 position [[position]];   // clip space
    float4 colorFromPosition;
    float2 texCoords;               // float4 instead of float3
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

#define SRGB_ALPHA 0.055

float linear_from_srgb(float x)
{
    if (x <= 0.04045)
        return x / 12.92;
    else
        return powr((x + SRGB_ALPHA) / (1.0 + SRGB_ALPHA), 2.4);
}

float3 linear_from_srgb(float3 rgb)
{
    return float3(linear_from_srgb(rgb.r),
                  linear_from_srgb(rgb.g),
                  linear_from_srgb(rgb.b));
}

float srgb_from_linear(float c) {
    if (isnan(c))
        c = 0.0;
    if (c > 1.0)
        c = 1.0;
    else if (c < 0.0)
        c = 0.0;
    else if (c < 0.0031308)
        c = 12.92 * c;
    else
        //c = 1.055 * powr(c, 1.0/2.4) - 0.055;
        c = (1.0 + SRGB_ALPHA) * powr(c, 1.0/2.4) - SRGB_ALPHA;
    
    return c;
}

float3 srgb_from_linear(float3 rgb) {
    return float3(srgb_from_linear(rgb.r),
                  srgb_from_linear(rgb.g),
                  srgb_from_linear(rgb.b));
}
vertex VertexOut
SphereVertexShader(VertexIn vertexIn            [[stage_in]],
                   constant Uniforms &uniforms  [[buffer(1)]]) {

    // The position and normal of the incoming vertex are in Object/Model Space.
    // The w-component of position vectors should be set to 1.0
    float4 positionMC = float4(vertexIn.position, 1.0);

    // Normal is a vector; its w-component should be set 0.0
    float4 normalMC = float4(vertexIn.normal, 0.0);

    VertexOut vertexOut;
    vertexOut.colorFromPosition = positionMC;
    // Each movie frame is an equirectangular projection map.
    vertexOut.texCoords = vertexIn.texCoords;

    // Transform incoming vertex's position from model space into clip space
    vertexOut.position = uniforms.modelViewProjectionMatrix * positionMC;

    return vertexOut;
}


// The Uniforms are not used but to be declared.
fragment float4
SphereFragmentShader(VertexOut                        fragmentIn  [[stage_in]],
                     texture2d<float, access::sample> inTexture   [[texture(0)]],
                     constant       Uniforms          &uniforms   [[buffer(1)]])
{
    constexpr sampler qsampler;
    float2 uv = fragmentIn.texCoords;
    uv.x = 1.0 - uv.x;
    float4 color = inTexture.sample(qsampler, uv);
    //float gamma = 2.2;
    //color.rgb = pow(color.rgb, float3(1.0/gamma));
    //color.rgb = srgb_from_linear(color.rgb);
    return color;
}


// Based on code from http://mczonk.de/video-texture-streaming-with-metal/
kernel void
YCbCrColorConversion(texture2d<float, access::read>   yTexture  [[texture(0)]],
                     texture2d<float, access::read> cbcrTexture [[texture(1)]],
                     texture2d<float, access::write> outTexture [[texture(2)]],
                     uint2                              gid     [[thread_position_in_grid]])
{
    float3 colorOffset = float3(-(16.0/255.0), -0.5, -0.5);

    float3x3 colorMatrix = float3x3(
        float3(1.164,  1.164, 1.164),
        float3(0.000, -0.392, 2.017),
        float3(1.596, -0.813, 0.000)
    );

    uint2 cbcrCoordinates = uint2(gid.x / 2, gid.y / 2); // half the size because we are using a 4:2:0 chroma subsampling

    float y = yTexture.read(gid).r;
    float2 cbcr = cbcrTexture.read(cbcrCoordinates).rg;

    float3 ycbcr = float3(y, cbcr);

    float3 rgb = colorMatrix * (ycbcr + colorOffset);

    outTexture.write(float4(float3(rgb), 1.0), gid);
}

