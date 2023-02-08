#ifndef UNIVERSAL_TOON_FACE_SDF_INCLUDED
#define UNIVERSAL_TOON_FACE_SDF_INCLUDED

// Required Uniforms:
// 1. _SDF_Tex
// 2. _SDF_Offset
// 3. _FaceForward

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
    float offset = 0.005;
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


half SDFMainLightRealtimeShadow(float4 shadowCoord, float4 positionCS)
{
#if !defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    return 1.0;
#endif
    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half4 shadowParams = GetMainLightShadowParams();

    //
    // shadowCoord.z = 500;

#if defined(UTS_USE_RAYTRACING_SHADOW)
    float w = (positionCS.w == 0) ? 0.00001 : positionCS.w;
    float4 screenPos = ComputeScreenPos(positionCS / w);
    return SAMPLE_TEXTURE2D(_RaytracedHardShadow, sampler_RaytracedHardShadow, screenPos);
#elif defined(_MAIN_LIGHT_SHADOWS_SCREEN)
    return SampleScreenSpaceShadowmap(shadowCoord);
#endif
    return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
}



#endif // UNIVERSAL_TOON_FACE_SDF_INCLUDED