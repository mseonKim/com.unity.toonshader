#ifndef UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED
#define UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.toongraphics/CharacterShadowMap/DeclareCharacterShadowTexture.hlsl"

// Required Uniforms:
// 1. _SDF_Tex
// 2. _SDF_Offset
// 3. _FaceForward
// 4. _SDF_BlurIntensity
// 5. _SDF_ShadowMask_Tex
// 6. _Hair_Highlight_Tex
// 7. _HeadWorldPos
// 8. _HeadUpWorldDir
// 9. _HairHiUVOffset
// 10. _SDF_Reverse


half LinearStep(float m, float M, float x)
{
    return saturate((x - m) / (M - m));
}

half GetFaceSDFAtten(float3 lightDir, float3 normal, float2 uv)
{
    half2 l = normalize(lightDir.xz);
    half2 n = normalize(normal.xz);
    half NoL = dot(l, n);

    // Find flip x
    half2 right = (-n.y, n.x);    // rotate 90 degree
    half flip_x = 1.0 - step(dot(right, l), 0.001);
    uv.x = lerp(-uv.x, uv.x, flip_x);

    // Blur
    float offset = _SDF_BlurIntensity;
    half _SDF_var = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv, _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(offset, offset), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(0.0, offset), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(-offset, offset), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(offset, 0.0), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(-offset, 0.0), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(-offset, -offset), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(0.0, -offset), _SDF_Tex)).r;
    _SDF_var += SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv + float2(offset, -offset), _SDF_Tex)).r;
    _SDF_var /= 9.0;
    
    // Reverse if need
    _SDF_var = lerp(_SDF_var, 1.0 - _SDF_var, _SDF_Reverse);
    
    return (0.0, 1.0, _SDF_var + _SDF_Offset <= NoL);
}


half GetCharMainShadow(float3 worldPos, float2 uv)
{
// #if _USE_SDF
//     half _SDF_ShadowMask_var = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv, _SDF_Tex)).a;
//     if (_SDF_ShadowMask_var > 0.01) // Ignore if masked
//     {
//         return 0.0;
//     }
// #endif
    float4 clipPos = CharShadowWorldToHClip(worldPos);
    clipPos.z = 1.0;
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 ssUV = ndc.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    ssUV.y = 1.0 - ssUV.y;
#endif
    return SampleCharacterShadowmapFiltered(ssUV, ndc.z);
}


half3 AnisotropicHairHighlight(float3 viewDirection, float2 uv, float3 worldPos)
{
    float dotViewUp = saturate(dot(viewDirection, _HeadUpWorldDir));
    float sinVU = sqrt(1 - dotViewUp * dotViewUp);
    float2 hairUV = float2(uv.x, uv.y + sinVU * _HairHiUVOffset);
    float hairHiTexVar = SAMPLE_TEXTURE2D(_Hair_Highlight_Tex, sampler_Hair_Highlight_Tex, TRANSFORM_TEX(hairUV, _Hair_Highlight_Tex)).a;
    float3 hairDir = normalize(worldPos - _HeadWorldPos);
    float dotVH = dot(viewDirection, hairDir) * 0.5 + 0.5;
    return pow(lerp(0, hairHiTexVar.xxx, dotVH), 4);
}

// float StrandSpecular(float3 tangent, float3 viewDir, float3 lightDir, float exponent = 1.0, float strength = 1.0)
// {
//     float3 halfV = normalize(viewDir + lightDir);
//     float dotTH = dot(tangent, halfV);
//     float sinTH = sqrt(1.0 - dotTH * dotTH);
//     float dirAtten = smoothstep(-1.0, 0.0, dotTH);
//     return dirAtten * pow(sinTH, exponent) * strength;
// }



#endif // UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED