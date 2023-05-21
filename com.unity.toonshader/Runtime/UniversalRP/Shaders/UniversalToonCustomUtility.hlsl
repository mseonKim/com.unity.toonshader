#ifndef UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED
#define UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.toongraphics/CharacterShadowMap/Shaders/DeclareCharacterShadowTexture.hlsl"

// Required Uniforms:
// 1. _SDF_Tex
// 2. _SDF_Offset
// 3. _FaceForward
// 4. _FaceUp
// 5. _SDF_BlurIntensity
// 6. _SDF_ShadowMask_Tex
// 7. _Hair_Highlight_Tex
// 8. _HeadWorldPos
// 9. _HeadUpWorldDir
// 10. _HairHiUVOffset
// 11. _SDF_Reverse
// 12. _SSS_Power
// 13. _SSS_Scale
// 14. _SSS_Normal_Distortion


half LinearStep(float m, float M, float x)
{
    return saturate((x - m) / (M - m));
}

half GetFaceSDFAtten(half3 lightDir, float2 uv)
{
    // Construct TBN based on face forward & up
    // Transform lightDir to TBN space
    half3 N = _FaceUp.xyz;
    half3 T = _FaceForward.xyz;
    half3 B = cross(T, N);
    half3x3 TBN = half3x3(T, B, N);
    half3 lightT = mul(TBN, lightDir);

    half3 forwardT = mul(TBN, _FaceForward.xyz);
    half2 l = normalize(lightT.xy);
    half2 n = normalize(forwardT.xy);
    half NoL = dot(l, n);

    // Find flip x
    uv.x = lerp(-uv.x, uv.x, saturate(sign(lightT.y)));

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
    
    // TODO: Blur Face Texture
    return (0.0, 1.0, _SDF_var + _SDF_Offset <= NoL);
}


half GetCharMainShadow(float3 worldPos, float2 uv, float opacity)
{
#if _USE_SDF
    half _SDF_ShadowMask_var = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, TRANSFORM_TEX(uv, _SDF_Tex)).a;
    if (_SDF_ShadowMask_var > 0.01) // Ignore if masked
    {
        return 0.0;
    }
#endif
    float4 clipPos = CharShadowWorldToHClip(worldPos);
#if UNITY_REVERSED_Z
    clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
#else
    clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
#endif
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 ssUV = ndc.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    ssUV.y = 1.0 - ssUV.y;
#endif

    // Max(Shadowmap, TransparentShadowmap)
    return GetCharacterAndTransparentShadowmap(ssUV, ndc.z, opacity);
}

half GetCharAdditionalShadow(float3 worldPos, float2 uv, float opacity, uint lightIndex = 0)
{
#ifndef USE_FORWARD_PLUS
    return 0;
#endif
    uint i = LocalLightIndexToShadowmapIndex(lightIndex);
    if (i >= MAX_CHAR_SHADOWMAPS)
        return 0;

    float4 clipPos = CharShadowWorldToHClip(worldPos, i);
#if UNITY_REVERSED_Z
    clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
#else
    clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
#endif
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 ssUV = ndc.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    ssUV.y = 1.0 - ssUV.y;
#endif
    return GetCharacterAndTransparentShadowmap(ssUV, ndc.z, opacity, i);
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


half3 OITTransmittance(float3 lightDir, float3 viewDir, float3 normal, half3 diffuse, half3 lightColor, float3 worldPos, float opacity)
{
    float4 clipPos = CharShadowWorldToHClip(worldPos);
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 ssUV = ndc.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    ssUV.y = 1.0 - ssUV.y;
#endif

    float NoL = saturate(dot(-lightDir, normal));
    NoL = LinearStep(0.49, 0.51, NoL);
    float o = 1.0 / 2048.0;   // Should be matched with atlas size
    float tr = 1 - TransparentAttenuation(ssUV, opacity);
    float scale = 0.66;

    // lightColor : actual light color * attenuation
    half3 col = diffuse * lightColor * tr * NoL * scale;
    return col;
}

half3 AdditionalOITTransmittance(float3 lightDir, float3 viewDir, float3 normal, half3 diffuse, half3 lightColor, float3 worldPos, float opacity, uint lightIndex = 0)
{
#ifndef USE_FORWARD_PLUS
    return 0;
#endif
    uint i = LocalLightIndexToShadowmapIndex(lightIndex);
    if (i >= MAX_CHAR_SHADOWMAPS)
        return 0;

    float4 clipPos = CharShadowWorldToHClip(worldPos, i);
    float3 ndc = clipPos.xyz / clipPos.w;
    float2 ssUV = ndc.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    ssUV.y = 1.0 - ssUV.y;
#endif

    float NoL = saturate(dot(-lightDir, normal));
    NoL = LinearStep(0.49, 0.51, NoL);
    float o = 1.0 / 2048.0;   // Should be matched with atlas size
    float tr = 1 - TransparentAttenuation(ssUV, opacity, i);
    float scale = 0.66;

    // lightColor : actual light color * attenuation
    half3 col = diffuse * lightColor * tr * NoL * scale;
    return col;
}

half3 SubsurfaceScattering(float3 lightDir, float3 viewDir, float3 normal, half3 diffuse, half3 lightColor)
{
    const float3 tr = float3(0.4, 0.25, 0.2);
    float fLTDot = pow(saturate(dot(-lightDir + normal * _SSS_Normal_Distortion, viewDir)), _SSS_Power) * _SSS_Scale;
    // float fLTDot = pow(saturate(dot(-lightDir, normal)), power) * scale;
    if (fLTDot < 0)
    {
        return 0;
    }
    fLTDot = LinearStep(0.25, 0.75, fLTDot);

    // lightColor : actual light color * attenuation
    half3 col = diffuse * lightColor * tr * fLTDot;
    return col;
}


#endif // UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED