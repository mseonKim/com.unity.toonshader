Shader "Custom/PP_SceneScanner"
{
    Properties
    {
        _ScanDisColor ("ScanDisColor", Color) = (1,1,1,1)
        _ScanDisOrigin ("ScanDisOrigin", Vector) = (0,0,0,0)
        _ScanDisRange ("ScanDisRange", Range(0, 20)) = 1
        _Power ("Power", Float) = 8
    }
SubShader 
    {
        PackageRequirements
        {
             "com.unity.render-pipelines.universal": "10.5.0"
        }    
        Tags {
            "RenderType"="Transparent"
            "Queue"="Transparent+99"
            "RenderPipeline" = "UniversalPipeline"
        }
        Pass {
            Name "Outline"
            Tags {
                "LightMode" = "SRPDefaultUnlit"
            }
            ZTest Always
            ZWrite OFF
            Cull OFF
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex PPVert
            #pragma fragment PPFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            SAMPLER(sampler_BlitTexture);
            float4 _ScanDisColor;
            float4 _ScanDisOrigin;
            float _ScanDisRange;
            float _Power;


            struct VaryingsCMB
            {
                float4 positionCS    : SV_POSITION;
                float4 texcoord      : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            VaryingsCMB PPVert(Attributes input)
            {
                VaryingsCMB output = (VaryingsCMB)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

#if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
#else
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);
#endif

                output.positionCS = pos;
                output.texcoord.xy = uv;

                float4 projPos = output.positionCS * 0.5;
                projPos.xy = projPos.xy + projPos.w;
                output.texcoord.zw = projPos.xy;

                return output;
            }

            half4 PPFrag(VaryingsCMB input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord.xy);
                float depth = SampleSceneDepth(input.texcoord.xy);
#ifdef UNITY_REVERSED_Z
				depth = (1.0 - depth);
#endif
                depth = 2.0 * depth - 1.0;   // Same behavior on D3D & OpenGL?

                float3 viewPos = ComputeViewSpacePosition(input.texcoord.zw, depth, unity_CameraInvProjection);
                float4 worldPos = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);
                float sdf = distance(worldPos.xyz, _ScanDisOrigin.xyz) / _ScanDisRange;
                clip(1.0 - sdf);

                float offset = pow(sdf, _Power);
                half4 color = _ScanDisColor;
                color.a = lerp(0, 1, offset);

                return color;
            }

            ENDHLSL
        }
    }
}