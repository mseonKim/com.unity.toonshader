//Unity Toon Shader/Universal
//nobuyuki@unity3d.com
//toshiyuki@unity3d.com (Universal RP/HDRP) 

// CUSTOM
// Abstraction over Light shading data.
            struct UtsLight
            {
                float3   direction;
                float3   color;
                float    distanceAttenuation;
                float    shadowAttenuation;
                int      type;
            };

            ///////////////////////////////////////////////////////////////////////////////
            //                      Light Abstraction                                    //
            /////////////////////////////////////////////////////////////////////////////
            half MainLightRealtimeShadowUTS(float4 shadowCoord, float4 positionCS)
            {
#if !defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                return 1.0;
#endif
                ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                half4 shadowParams = GetMainLightShadowParams();
#if defined(UTS_USE_RAYTRACING_SHADOW)
                float w = (positionCS.w == 0) ? 0.00001 : positionCS.w;
                float4 screenPos = ComputeScreenPos(positionCS / w);
                return SAMPLE_TEXTURE2D(_RaytracedHardShadow, sampler_RaytracedHardShadow, screenPos);
#elif defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                return SampleScreenSpaceShadowmap(shadowCoord);
#endif
                return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, false);
            }

            half AdditionalLightRealtimeShadowUTS(int lightIndex, float3 positionWS, float4 positionCS)
            {
#if  defined(UTS_USE_RAYTRACING_SHADOW)
                float w = (positionCS.w == 0) ? 0.00001 : positionCS.w;
                float4 screenPos = ComputeScreenPos(positionCS / w);
                return SAMPLE_TEXTURE2D(_RaytracedHardShadow, sampler_RaytracedHardShadow, screenPos);
#endif // UTS_USE_RAYTRACING_SHADOW

#if defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)


# if (SHADER_LIBRARY_VERSION_MAJOR >= 13 && UNITY_VERSION >= 202220 )
                ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData(lightIndex);
# else
                ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData();
# endif

#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
                lightIndex = _AdditionalShadowsIndices[lightIndex];

                // We have to branch here as otherwise we would sample buffer with lightIndex == -1.
                // However this should be ok for platforms that store light in SSBO.
                UNITY_BRANCH
                    if (lightIndex < 0)
                        return 1.0;

                float4 shadowCoord = mul(_AdditionalShadowsBuffer[lightIndex].worldToShadowMatrix, float4(positionWS, 1.0));
#else
                float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[lightIndex], float4(positionWS, 1.0));
#endif

                half4 shadowParams = GetAdditionalLightShadowParams(lightIndex);
                return SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_LinearClampCompare), shadowCoord, shadowSamplingData, shadowParams, true);
#else
                return 1.0h;
#endif
            }

            UtsLight GetUrpMainUtsLight()
            {
                UtsLight light;
                light.direction = _MainLightPosition.xyz;
#if USE_FORWARD_PLUS
                #if defined(LIGHTMAP_ON)
                    light.distanceAttenuation = _MainLightColor.a;
                #else
                    light.distanceAttenuation = 1.0;
                #endif
#else
                // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
                light.distanceAttenuation = unity_LightData.z;
#endif
#if defined(LIGHTMAP_ON) || defined(_MIXED_LIGHTING_SUBTRACTIVE)
                // unity_ProbesOcclusion.x is the mixed light probe occlusion data
                light.distanceAttenuation *= unity_ProbesOcclusion.x;
#endif
                light.shadowAttenuation = 1.0;
                light.color = lerp(_MainLightColor.rgb, max(_MainLightColor.rgb, _MinLightIntensity.rrr), _MainLightColor.rgb > 0);
                light.type = _MainLightPosition.w;
                return light;
            }

            UtsLight GetUrpMainUtsLight(float4 shadowCoord, float4 positionCS)
            {
                UtsLight light = GetUrpMainUtsLight();
                light.shadowAttenuation = MainLightRealtimeShadowUTS(shadowCoord, positionCS);
                return light;
            }

            // Fills a light struct given a perObjectLightIndex
            UtsLight GetAdditionalPerObjectUtsLight(int perObjectLightIndex, float3 positionWS,float4 positionCS)
            {
                // Abstraction over Light input constants
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
                float4 lightPositionWS = _AdditionalLightsBuffer[perObjectLightIndex].position;
                half3 color = _AdditionalLightsBuffer[perObjectLightIndex].color.rgb;
                half4 distanceAndSpotAttenuation = _AdditionalLightsBuffer[perObjectLightIndex].attenuation;
                half4 spotDirection = _AdditionalLightsBuffer[perObjectLightIndex].spotDirection;
                half4 lightOcclusionProbeInfo = _AdditionalLightsBuffer[perObjectLightIndex].occlusionProbeChannels;
#else
                float4 lightPositionWS = _AdditionalLightsPosition[perObjectLightIndex];
                half3 color = _AdditionalLightsColor[perObjectLightIndex].rgb;
                half4 distanceAndSpotAttenuation = _AdditionalLightsAttenuation[perObjectLightIndex];
                half4 spotDirection = _AdditionalLightsSpotDir[perObjectLightIndex];
                half4 lightOcclusionProbeInfo = _AdditionalLightsOcclusionProbes[perObjectLightIndex];
#endif

                // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
                // This way the following code will work for both directional and punctual lights.
                float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
                float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);

                half3 lightDirection = half3(lightVector * rsqrt(distanceSqr));
                half attenuation = DistanceAttenuation(distanceSqr, distanceAndSpotAttenuation.xy) * AngleAttenuation(spotDirection.xyz, lightDirection, distanceAndSpotAttenuation.zw);

                UtsLight light;
                light.direction = lightDirection;
                light.distanceAttenuation = attenuation;
                light.shadowAttenuation = AdditionalLightRealtimeShadowUTS(perObjectLightIndex, positionWS, positionCS);
                light.color = color;
                light.type = lightPositionWS.w;

                // In case we're using light probes, we can sample the attenuation from the `unity_ProbesOcclusion`
#if defined(LIGHTMAP_ON) || defined(_MIXED_LIGHTING_SUBTRACTIVE)
                // First find the probe channel from the light.
                // Then sample `unity_ProbesOcclusion` for the baked occlusion.
                // If the light is not baked, the channel is -1, and we need to apply no occlusion.

                // probeChannel is the index in 'unity_ProbesOcclusion' that holds the proper occlusion value.
                int probeChannel = lightOcclusionProbeInfo.x;

                // lightProbeContribution is set to 0 if we are indeed using a probe, otherwise set to 1.
                half lightProbeContribution = lightOcclusionProbeInfo.y;

                half probeOcclusionValue = unity_ProbesOcclusion[probeChannel];
                light.distanceAttenuation *= max(probeOcclusionValue, lightProbeContribution);
#endif

                return light;
            }

            // Fills a light struct given a loop i index. This will convert the i
// index to a perObjectLightIndex
            UtsLight GetAdditionalUtsLight(uint i, float3 positionWS,float4 positionCS)
            {
#if USE_FORWARD_PLUS
                int lightIndex = i;
#else
                int lightIndex = GetPerObjectLightIndex(i);
#endif
                UtsLight light = GetAdditionalPerObjectUtsLight(lightIndex, positionWS, positionCS);
#if defined(_LIGHT_COOKIES)
                real3 cookieColor = SampleAdditionalLightCookie(lightIndex, positionWS);
                light.color *= cookieColor;
#endif
                return light;
            }

            half3 GetLightColor(UtsLight light)
            {
                return light.color * light.distanceAttenuation;
            }


#define INIT_UTSLIGHT(utslight) \
            utslight.direction = 0; \
            utslight.color = 0; \
            utslight.distanceAttenuation = 0; \
            utslight.shadowAttenuation = 0; \
            utslight.type = 0


            int DetermineUTS_MainLightIndex(float3 posW, float4 shadowCoord, float4 positionCS)
            {
                UtsLight mainLight;
                INIT_UTSLIGHT(mainLight);

                int mainLightIndex = MAINLIGHT_NOT_FOUND;
                UtsLight nextLight = GetUrpMainUtsLight(shadowCoord, positionCS);
                if (nextLight.distanceAttenuation > mainLight.distanceAttenuation && nextLight.type == 0)
                {
                    mainLight = nextLight;
                    mainLightIndex = MAINLIGHT_IS_MAINLIGHT;
                }
                int lightCount = GetAdditionalLightsCount();
                for (int ii = 0; ii < lightCount; ++ii)
                {
                    nextLight = GetAdditionalUtsLight(ii, posW, positionCS);
                    if (nextLight.distanceAttenuation > mainLight.distanceAttenuation && nextLight.type == 0)
                    {
                        mainLight = nextLight;
                        mainLightIndex = ii;
                    }
                }

                return mainLightIndex;
            }

            UtsLight GetMainUtsLightByID(int index,float3 posW, float4 shadowCoord, float4 positionCS)
            {
                UtsLight mainLight;
                INIT_UTSLIGHT(mainLight);
                if (index == MAINLIGHT_NOT_FOUND)
                {
                    return mainLight;
                }
                if (index == MAINLIGHT_IS_MAINLIGHT)
                {
                    return GetUrpMainUtsLight(shadowCoord, positionCS);
                }
                return GetAdditionalUtsLight(index, posW, positionCS);
            }
            
#if USE_FORWARD_PLUS
    #define UTS_LIGHT_LOOP_BEGIN(lightCount) { \
            uint lightIndex; \
            ClusterIterator _urp_internal_clusterIterator = ClusterInit(GetNormalizedScreenSpaceUV(i.pos), i.worldPos.xyz, 0); \
            [loop] while (ClusterNext(_urp_internal_clusterIterator, lightIndex)) { \
                lightIndex += URP_FP_DIRECTIONAL_LIGHTS_COUNT; \
                FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
    #define UTS_LIGHT_LOOP_END } }
#else
    #define UTS_LIGHT_LOOP_BEGIN(lightCount) \
            for (uint loopCounter = 0u; loopCounter < lightCount; ++loopCounter) {
    #define UTS_LIGHT_LOOP_END }
#endif
//

            uniform float4 _LightColor0; // this is not set in c# code ?

            struct VertexInput {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord0 : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalDir : TEXCOORD1;
                float3 tangentDir : TEXCOORD2;
                float3 bitangentDir : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                float3 objectPos : TEXCOORD5;

                UNITY_VERTEX_OUTPUT_STEREO
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.uv0 = v.texcoord0;
                float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                float2 Set_UV0 = o.uv0;
                float4 _Outline_Sampler_var = tex2Dlod(_Outline_Sampler,float4(TRANSFORM_TEX(Set_UV0, _Outline_Sampler),0.0,0));
                //v.2.0.4.3 baked Normal Texture for Outline
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                float3x3 tangentTransform = float3x3( o.tangentDir, o.bitangentDir, o.normalDir);
                //UnpackNormal() can't be used, and so as follows. Do not specify a bump for the texture to be used.
                float4 _BakedNormal_var = (tex2Dlod(_BakedNormal,float4(TRANSFORM_TEX(Set_UV0, _BakedNormal),0.0,0)) * 2 - 1);
                float3 _BakedNormalDir = normalize(mul(_BakedNormal_var.rgb, tangentTransform));
                //end
                float Set_Outline_Width = (_Outline_Width*0.001*smoothstep( _Farthest_Distance, _Nearest_Distance, distance(objPos.rgb,_WorldSpaceCameraPos) )*_Outline_Sampler_var.rgb).r;
                o.worldPos = TransformObjectToWorld(lerp(float3(v.vertex.xyz + v.normal*Set_Outline_Width), float3(v.vertex.xyz + _BakedNormalDir*Set_Outline_Width),_Is_BakedNormal));
#ifndef _USE_OIT_OUTLINE // CUSTOM - OIT Outline
                Set_Outline_Width *= (1.0f - _ZOverDrawMode);
#endif
                //v.2.0.7.5
                float4 _ClipCameraPos = mul(UNITY_MATRIX_VP, float4(_WorldSpaceCameraPos.xyz, 1));
                //v.2.0.7
                #if defined(UNITY_REVERSED_Z)
                    //v.2.0.4.2 (DX)
                    _Offset_Z = _Offset_Z * -0.01;
                #else
                    //OpenGL
                    _Offset_Z = _Offset_Z * 0.01;
                #endif
//v2.0.4
#ifdef _OUTLINE_NML
                //v.2.0.4.3 baked Normal Texture for Outline
                o.pos = UnityObjectToClipPos(lerp(float4(v.vertex.xyz + v.normal*Set_Outline_Width,1), float4(v.vertex.xyz + _BakedNormalDir*Set_Outline_Width,1),_Is_BakedNormal));
#elif _OUTLINE_POS
                Set_Outline_Width = Set_Outline_Width*2;
                float signVar = dot(normalize(v.vertex.xyz),normalize(v.normal))<0 ? -1 : 1;
                o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + signVar*normalize(v.vertex)*Set_Outline_Width, 1));
#endif
                //v.2.0.7.5
                o.pos.z = o.pos.z + _Offset_Z * _ClipCameraPos.z;

                o.objectPos = v.vertex.xyz;
                return o;
            }

#ifdef _USE_OIT // CUSTOM_OIT
            [earlydepthstencil]
#endif
            float4 frag(VertexOutput i) : SV_Target{
#if _MATERIAL_TRANSFORM
                // Material Transformer
                MaterialTransformerFragDiscard(i.objectPos);
#endif
                //v.2.0.5
#ifndef _USE_OIT_OUTLINE // CUSTOM - OIT Outline
                if (_ZOverDrawMode > 0.99f)
                {
                    return float4(1.0f, 1.0f, 1.0f, 1.0f);  // but nothing should be drawn except Z value as colormask is set to 0
                }
#endif
                _Color = _BaseColor;
                float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                //v.2.0.9
                float3 envLightSource_GradientEquator = unity_AmbientEquator.rgb >0.05 ? unity_AmbientEquator.rgb : half3(0.05,0.05,0.05);
                float3 envLightSource_SkyboxIntensity = max(ShadeSH9(half4(0.0,0.0,0.0,1.0)),ShadeSH9(half4(0.0,-1.0,0.0,1.0))).rgb;
                float3 ambientSkyColor = envLightSource_SkyboxIntensity.rgb>0.0 ? envLightSource_SkyboxIntensity*_Unlit_Intensity : envLightSource_GradientEquator*_Unlit_Intensity;
                //

                /// CUSTOM - These are moved from below [Line Moved] comment location.)
                float2 Set_UV0 = i.uv0;
                float4 _MainTex_var = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, TRANSFORM_TEX(Set_UV0, _MainTex));
                float3 Set_BaseColor = _BaseColor.rgb*_MainTex_var.rgb;

                // CUSTOM (Character Shadowmap)
                half ssShadowAtten = 0;
                float outlineAlpha = 1;
#if _USE_CHAR_SHADOW
                float opacity = _Color.a * _MainTex_var.a;
                ssShadowAtten = GetCharMainShadow(i.worldPos, Set_UV0, opacity);
                _LightColor0.rgb = lerp(_LightColor0.rgb, 0, ssShadowAtten);
#endif

                /// CUSTOM - Outline brightness
#ifdef _ADDITIONAL_LIGHTS
    #if USE_FORWARD_PLUS
                UTS_LIGHT_LOOP_BEGIN(0)
                    int iLight = lightIndex;
                    {
                        UtsLight additionalLight = GetUrpMainUtsLight(0,0);
                        if (iLight != -1)
                        {
                            additionalLight = GetAdditionalUtsLight(iLight, i.worldPos, i.pos);
                        }
                        half3 additionalLightColor = GetLightColor(additionalLight);
        #if _USE_CHAR_SHADOW  // CUSTOM (Character Shadowmap)
                        ssShadowAtten = GetCharAdditionalShadow(i.worldPos, opacity, lightIndex);
                        additionalLightColor = lerp(additionalLightColor, 0, ssShadowAtten);
        #endif
                        _LightColor0.rgb += additionalLightColor;
                    }
                UTS_LIGHT_LOOP_END
    #endif
#endif
                _LightColor0.rgb = saturate(_LightColor0.rgb);
                ///
                float3 lightColor = _LightColor0.rgb >0.05 ? _LightColor0.rgb : ambientSkyColor.rgb;
                float lightColorIntensity = (0.299*lightColor.r + 0.587*lightColor.g + 0.114*lightColor.b);
                lightColor = lightColorIntensity<1 ? lightColor : lightColor/lightColorIntensity;
                lightColor = lerp(half3(1.0,1.0,1.0), lightColor, _Is_LightColor_Outline);
                /// CUSTOM - [Line Moved]
                float3 _Is_BlendBaseColor_var = lerp( _Outline_Color.rgb*lightColor, (_Outline_Color.rgb*Set_BaseColor*Set_BaseColor*lightColor), _Is_BlendBaseColor );
                //
                float3 _OutlineTex_var = tex2D(_OutlineTex,TRANSFORM_TEX(Set_UV0, _OutlineTex)).rgb;
//v.2.0.7.5
#ifdef _IS_OUTLINE_CLIPPING_NO
                float3 Set_Outline_Color = lerp(_Is_BlendBaseColor_var, _OutlineTex_var.rgb*_Outline_Color.rgb*lightColor, _Is_OutlineTex );
                return float4(Set_Outline_Color, 1.0);
#elif _IS_OUTLINE_CLIPPING_YES
                float4 _ClippingMask_var = SAMPLE_TEXTURE2D(_ClippingMask, sampler_MainTex, TRANSFORM_TEX(Set_UV0, _ClippingMask));
                float Set_MainTexAlpha = _MainTex_var.a;
                float _IsBaseMapAlphaAsClippingMask_var = lerp( _ClippingMask_var.r, Set_MainTexAlpha, _IsBaseMapAlphaAsClippingMask );
                float _Inverse_Clipping_var = lerp( _IsBaseMapAlphaAsClippingMask_var, (1.0 - _IsBaseMapAlphaAsClippingMask_var), _Inverse_Clipping );
                float Set_Clipping = saturate((_Inverse_Clipping_var+_Clipping_Level));
                clip(Set_Clipping - 0.5);
                float4 Set_Outline_Color = lerp( float4(_Is_BlendBaseColor_var,Set_Clipping), float4((_OutlineTex_var.rgb*_Outline_Color.rgb*lightColor),Set_Clipping), _Is_OutlineTex );

    #ifdef _USE_OIT // CUSTOM - OIT Outline
        #ifdef _USE_OIT_OUTLINE
                float4 clipPos = TransformWorldToHClip(i.worldPos.xyz);
                // clipPos.z = 1.0f;
                float3 ndc = clipPos.xyz / clipPos.w;
                float2 ssUV = ndc.xy * 0.5 + 0.5;
            #if UNITY_UV_STARTS_AT_TOP
                ssUV.y = 1.0 - ssUV.y;
            #endif

                if (SampleOITDepth(ssUV, ndc.z, sampler_MainTex))
                {
                    return 0;
                }
        #endif
    #endif
                return Set_Outline_Color;
#endif
            }
// End of File

