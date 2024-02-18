#ifndef UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED
#define UNIVERSAL_TOON_CUSTOM_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.toongraphics/CharacterShadowMap/Shaders/CharacterShadowInput.hlsl"
#include "Packages/com.unity.toongraphics/CharacterShadowMap/Shaders/CharacterShadowTransforms.hlsl"
#include "Packages/com.unity.toongraphics/CharacterShadowMap/Shaders/DeclareCharacterShadowTexture.hlsl"

// Required Uniforms:
// 1. _SDF_Tex
// 2. _SDF_Offset
// 3. _FaceForward
// 4. _FaceUp
// 5. _RcpSDFSize
// 6. _SDF_Feather
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

// Reference: UE5 SpiralBlur-Texture
half SpiralBlur(TEXTURE2D_PARAM(tex, samplerTex), float2 UV, float Distance, float DistanceSteps, float RadialSteps, float RadialOffset, float KernelPower)
{
    half CurColor = 0;
    float2 NewUV = UV;
    int i = 0;
    float StepSize = Distance / (int)DistanceSteps;
    float CurDistance = 0;
    float2 CurOffset = 0;
    float SubOffset = 0;
    // float TwoPi = 6.283185;
    float accumdist = 0;

    if (DistanceSteps < 1)
    {
        return SAMPLE_TEXTURE2D(tex, samplerTex, UV).r;		
    }

    while (i < (int)DistanceSteps)
    {
        CurDistance += StepSize;
        for (int j = 0; j < (int)RadialSteps; j++)
        {
            SubOffset +=1;
            CurOffset.x = cos(TWO_PI * (SubOffset / RadialSteps));
            CurOffset.y = sin(TWO_PI * (SubOffset / RadialSteps));
            NewUV.x = UV.x + CurOffset.x * CurDistance;
            NewUV.y = UV.y + CurOffset.y * CurDistance;
            float distpow = pow(CurDistance, KernelPower);
            CurColor += SAMPLE_TEXTURE2D(tex, samplerTex, NewUV).r * distpow;		
            accumdist += distpow;
        }
        SubOffset += RadialOffset;
        i++;
    }
    CurColor = CurColor;
    CurColor /= accumdist;
    return CurColor;
}


#define COS_54 0.587
#define COS_66 0.406
#define COS_50 0.64278
#define COS_70 0.34202
half GetFaceSDFAtten(half3 lightDir, float2 uv)
{
#if _USE_CHAR_SHADOW
    lightDir = _BrightestLightDirection.xyz;
#endif
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

    if (NoL < 0)
    {
        return 0;
    }

    // To skip ugly facemask shadow
    if (NoL > COS_70 && NoL < COS_50)
    {
        NoL = 0.5;
        if (NoL > COS_54)
        {
            NoL = smoothstep(0.5, COS_50, NoL);
        }
        else if (NoL < COS_66)
        {
            NoL = smoothstep(COS_70, 0.5, NoL);
        }
    }

    bool flipped = saturate(sign(lightT.y));

    // Sample
    half faceSdfAtten = SpiralBlur(TEXTURE2D_ARGS(_SDF_Tex, sampler_SDF_Tex), uv, _RcpSDFSize, 16, 8, 0.62, 1) + _SDF_Offset;

    // Apply Flip
    faceSdfAtten = lerp(1.0 - faceSdfAtten, faceSdfAtten, flipped);
    
    // Reverse if need
    faceSdfAtten = lerp(faceSdfAtten, 1.0 - faceSdfAtten, _SDF_Reverse);

    faceSdfAtten = LinearStep(-_SDF_Feather, _SDF_Feather, NoL - faceSdfAtten);
    return faceSdfAtten;
}


half GetCharMainShadow(float3 worldPos, float2 uv, float opacity, half sdfAtten = 1, half sdfMask = 0)
{
#if _USE_SDF
    if (sdfMask > 0.01) // Ignore if masked
    {
        return 1.0 - sdfAtten;
    }
    return max(1.0 - sdfAtten, SampleCharacterAndTransparentShadow(worldPos, opacity));
#else
    // Max(Shadowmap, TransparentShadowmap)
    return SampleCharacterAndTransparentShadow(worldPos, opacity);
#endif
}

half GetCharAdditionalShadow(float3 worldPos, float opacity, uint lightIndex, half sdfAtten = 1, half sdfMask = 0)
{
#if _USE_SDF
    uint i;
    ADDITIONAL_CHARSHADOW_CHECK(i, lightIndex);
    if (sdfMask > 0.01) // Ignore if masked
    {
        return 1.0 - sdfAtten;
    }
    return max(1.0 - sdfAtten, SampleAdditionalCharacterAndTransparentShadow(worldPos, opacity, lightIndex));
#else
    return SampleAdditionalCharacterAndTransparentShadow(worldPos, opacity, lightIndex);
#endif
}


half3 AnisotropicHairHighlight(float3 viewDirection, float2 uv, float3 worldPos)
{
    float dotViewUp = saturate(dot(viewDirection, _HeadUpWorldDir.xyz));
    float sinVU = sqrt(1 - dotViewUp * dotViewUp);
    float2 hairUV = float2(uv.x, uv.y + sinVU * _HairHiUVOffset);
    float hairHiTexVar = SAMPLE_TEXTURE2D(_Hair_Highlight_Tex, sampler_Hair_Highlight_Tex, TRANSFORM_TEX(hairUV, _Hair_Highlight_Tex)).a;
    float3 hairDir = normalize(worldPos - _HeadWorldPos.xyz);
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
    float2 ssUV = TransformWorldToCharShadowCoord(worldPos).xy;

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
    uint i;
    ADDITIONAL_CHARSHADOW_CHECK(i, lightIndex)

    float2 ssUV = TransformWorldToCharShadowCoord(worldPos).xy;

    float NoL = saturate(dot(-lightDir, normal));
    NoL = LinearStep(0.49, 0.51, NoL);
    float o = 1.0 / 2048.0;   // Should be matched with atlas size
    float tr = 1 - TransparentAttenuation(ssUV, opacity);
    float scale = 0.66;

    // lightColor : actual light color * attenuation
    half3 col = diffuse * lightColor * tr * NoL * scale;
    return col;
}

half3 SubsurfaceScattering(float3 lightDir, float3 viewDir, float3 normal, half3 diffuse, half3 lightColor)
{
    const float3 tr = float3(0.4, 0.25, 0.2);
    const float3 H = normalize(lightDir + normal * _SSS_Normal_Distortion);
    float fLTDot = pow(saturate(dot(viewDir, -H)), _SSS_Power) * _SSS_Scale;
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