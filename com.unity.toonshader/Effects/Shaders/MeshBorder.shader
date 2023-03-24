Shader "Custom/MeshBorderEffect"
{
    Properties
    {
        _DissolveColor ("DissolveColor", Color) = (1,1,1,1)
        _Emissive ("Emissive", Float) = 1
        _Offset ("Offset", Float) = 0.01
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
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _DissolveColor;
            float _Emissive;
            float _Offset;

            struct Attributes
            {
                float4 positionOS : POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS    : SV_POSITION;
                float3 positionWS    : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                return output;
            }

            half4 Frag(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // float3 ndcPos = input.positionCS.xyz / input.positionCS.w;
                float4 ndcHPos = TransformWorldToHClip(input.positionWS);
                float3 ndcPos = ndcHPos.xyz / ndcHPos.w;
                float2 ssUV = ndcPos.xy * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
                ssUV.y = 1.0 - ssUV.y;
#endif
                float depth = SampleSceneDepth(ssUV);
                // depth = 2.0 * depth - 1.0;
                float dist = abs(ndcPos.z - depth);

                half4 finalColor = 0;
                if (dist < _Offset)
                {
                    float diff = -rcp(_Offset) * dist + 1.0; // (_Offset - dist) * (1 / _Offset)
                    finalColor = half4(_DissolveColor.rgb * _Emissive, diff); 
                }

                return finalColor;
            }

            ENDHLSL
        }
    }
}