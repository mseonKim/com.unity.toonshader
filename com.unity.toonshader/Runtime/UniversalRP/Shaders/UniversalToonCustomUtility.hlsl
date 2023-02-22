#ifndef UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED
#define UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

#define MAX_RAY_STEPS 64

// Required Uniforms:
// 1. _SDF_Tex
// 2. _SDF_Offset
// 3. _FaceForward
// 4. _SDF_BlurIntensity
// 5. _SDF_ShadowMask_Tex
// 6. _StepShadowRayLength
// 7. _MaxShadowRayLength
// 8. _Hair_Highlight_Tex
// 9. _HeadWorldPos
// 10. _HeadUpWorldDir
// 11. _HairHiUVOffset

half GetFaceSDFAtten(float3 lightDir, float3 normal, float2 uv)
{
    half2 l = normalize(lightDir.xz);
    half2 n = normalize(normal.xz);
    half NoL = dot(l, n);

    // Find flip x
    half2 right = (-l.y, l.x);    // rotate 90 degree
    half flip_x = ceil(dot(right, n));
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
    
    // 1-x
    _SDF_var = 1.0 - _SDF_var;
    
    return (0.0, 1.0, _SDF_var + _SDF_Offset <= NoL);
}


half GetFakeScreenSpaceMainShadow(float3 worldPos, float3 lightDirection, float2 uv)
{
    float depth;
    // float occlusion = 0.0;
    float delta;
    float3 ndcRayPos;

#if _USE_SDF
    half _SDF_ShadowMask_var = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv, _SDF_Tex)).a;
    if (_SDF_ShadowMask_var > 0.01)
    {
        return 0.0;
    }
#endif

    // UNITY_UNROLL
    [loop] for (uint idx = 0; idx < MAX_RAY_STEPS; idx++)
    {
        float len = max(0.00001, min(_StepShadowRayLength * (idx + 1), _MaxShadowRayLength));
        float3 rayStep = lightDirection * len.xxx;
        float3 rayViewPos = TransformWorldToView(worldPos + rayStep);
        float4 clipRayPos = TransformWViewToHClip(rayViewPos);
        ndcRayPos = clipRayPos.xyz / clipRayPos.w;
        float2 ssUV = ndcRayPos.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
        ssUV.y = 1.0 - ssUV.y;
#endif
        depth = SampleSceneDepth(ssUV);
        // float z_ndc = depth * 2.0 - 1.0;
        // float4 viewPosH = mul(unity_MatrixInvP, float4(ndcRayPos.xy, z_ndc, 1.0));
        // float delta = viewPosH.z / viewPosH.w - rayViewPos.z;
        delta = depth - ndcRayPos.z;
#if UNITY_REVERSED_Z
        if (depth > ndcRayPos.z && abs(delta) < 0.025)
#else
        if (depth < ndcRayPos.z && abs(delta) < 0.025)
#endif
        {
            return 1.0;
        }
    }
    return 0.0;
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