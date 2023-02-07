#ifndef UNIVERSAL_TOON_FACE_SDF_INCLUDED
#define UNIVERSAL_TOON_FACE_SDF_INCLUDED

// Required Uniforms:
// 1. _SDF_Tex
// 2. _FaceForward

half GetFaceSDFAtten(float3 lightDir, float3 normal, float2 uv)
{
    half NoL = dot(lightDir.xz, normal.xz);

    // Find flip x
    half2 right = (-lightDir.z, lightDir.x);    // rotate 90 degree
    half flip_x = ceil(dot(right, normal.xz));
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
    
    return (0.0, 1.0, _SDF_var <= NoL);
}



#endif // UNIVERSAL_TOON_FACE_SDF_INCLUDED