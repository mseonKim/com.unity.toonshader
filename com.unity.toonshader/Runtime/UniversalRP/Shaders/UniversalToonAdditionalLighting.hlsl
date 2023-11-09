float3 AdditionalLighting(UtsLight additionalLight, float4 _MainTex_var, float2 Set_UV0, float3 normalDir, float3 normalDirection, float3 viewDirection, float3 worldPos, float opacity, uint lightIndex = 0)
{
    float notDirectional = 1.0f; //_WorldSpaceLightPos0.w of the legacy code.
    half3 additionalLightColor = GetLightColor(additionalLight);
    float3 lightDirection = additionalLight.direction;
    //v.2.0.5: 
    half3 addPassLightColor = additionalLightColor;
    // float3 addPassLightColor = (0.5*dot(lerp(normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5) * additionalLightColor.rgb;
    float  pureIntencity = max(0.001, (0.299*additionalLightColor.r + 0.587*additionalLightColor.g + 0.114*additionalLightColor.b));
    float3 lightColor = max(float3(0.0,0.0,0.0), lerp(addPassLightColor, lerp(float3(0.0,0.0,0.0), min(addPassLightColor, addPassLightColor / pureIntencity), notDirectional), _Is_Filter_LightColor));
    float3 halfDirection = normalize(viewDirection + lightDirection); // has to be recalced here.

    //v.2.0.5:
    float baseColorStep = saturate(_BaseColor_Step + _StepOffset);
    float shadeColorStep = saturate(_ShadeColor_Step + _StepOffset);
    //
    //v.2.0.5: If Added lights is directional, set 0 as _LightIntensity
    float _LightIntensity = lerp(0, (0.299*additionalLightColor.r + 0.587*additionalLightColor.g + 0.114*additionalLightColor.b), notDirectional);
    //v.2.0.5: Filtering the high intensity zone of PointLights
    float3 Set_LightColor = addPassLightColor;  // = lightColor
    //
    float3 Set_BaseColor = lerp((_BaseColor.rgb*_MainTex_var.rgb*_LightIntensity), ((_BaseColor.rgb*_MainTex_var.rgb)*Set_LightColor), _Is_LightColor_Base);
    //v.2.0.5
    float4 _1st_ShadeMap_var = lerp(SAMPLE_TEXTURE2D(_1st_ShadeMap, sampler_MainTex, TRANSFORM_TEX(Set_UV0, _1st_ShadeMap)), _MainTex_var, _Use_BaseAs1st);
    float3 Set_1st_ShadeColor = lerp((_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb*_LightIntensity), ((_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_1st_Shade);
    //v.2.0.5
    float4 _2nd_ShadeMap_var = lerp(SAMPLE_TEXTURE2D(_2nd_ShadeMap, sampler_MainTex, TRANSFORM_TEX(Set_UV0, _2nd_ShadeMap)), _1st_ShadeMap_var, _Use_1stAs2nd);
    float3 Set_2nd_ShadeColor = lerp((_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb*_LightIntensity), ((_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_2nd_Shade);
    float _HalfLambert_var = 0.5*dot(lerp(normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5;

    float4 _Set_2nd_ShadePosition_var = tex2D(_Set_2nd_ShadePosition, TRANSFORM_TEX(Set_UV0, _Set_2nd_ShadePosition));
    float4 _Set_1st_ShadePosition_var = tex2D(_Set_1st_ShadePosition, TRANSFORM_TEX(Set_UV0, _Set_1st_ShadePosition));

    //v.2.0.5:
    float Set_FinalShadowMask = saturate((1.0 + ((lerp(_HalfLambert_var, (_HalfLambert_var*saturate(1.0 + _Tweak_SystemShadowsLevel)), _Set_SystemShadowsToBase) - (baseColorStep - _BaseShade_Feather)) * ((1.0 - _Set_1st_ShadePosition_var.rgb).r - 1.0)) / (baseColorStep - (baseColorStep - _BaseShade_Feather))));
    //Composition: 3 Basic Colors as finalColor
    float3 finalShadeColor = lerp(Set_1st_ShadeColor, Set_2nd_ShadeColor, saturate((1.0 + ((_HalfLambert_var - (shadeColorStep - _1st2nd_Shades_Feather)) * ((1.0 - _Set_2nd_ShadePosition_var.rgb).r - 1.0)) / (shadeColorStep - (shadeColorStep - _1st2nd_Shades_Feather)))));
    finalShadeColor = _MainLightColor.r + _MainLightColor.g + _MainLightColor.b > 0 ? finalShadeColor * _AdditionalShadowDimmer : 0;
    float3 finalColor = lerp(Set_BaseColor, finalShadeColor, Set_FinalShadowMask); // Final Color

#if _IS_CLIPPING_TRANSMODE && _USE_OIT && _USE_CHAR_SHADOW  // CUSTOM (OIT Transmittance)
    finalColor += AdditionalOITTransmittance(lightDirection, viewDirection, lerp(normalDir, normalDirection, _Is_NormalMapToBase), Set_BaseColor, Set_LightColor, worldPos, opacity, lightIndex);
#endif

    //v.2.0.6: Add HighColor if _Is_Filter_HiCutPointLightColor is False
    float4 _Set_HighColorMask_var = tex2D(_Set_HighColorMask, TRANSFORM_TEX(Set_UV0, _Set_HighColorMask));

    float _Specular_var = 0.5*dot(halfDirection, lerp(normalDir, normalDirection, _Is_NormalMapToHighColor)) + 0.5; //  Specular  
    float hardSpecularVal = 1.0 - pow(abs(_HighColor_Power), 5);
    float hardSpecularLinearStep = saturate((hardSpecularVal - (_Specular_var - _HighColor_Feather)) / (2 * _HighColor_Feather)); 
    float _TweakHighColorMask_var = saturate(_Set_HighColorMask_var.g + _Tweak_HighColorMaskLevel) * lerp(1.0 - hardSpecularLinearStep, pow(_Specular_var, exp2(lerp(11, 1, _HighColor_Power))), _Is_SpecularToHighColor) * _LightIntensity;

    float4 _HighColor_Tex_var = tex2D(_HighColor_Tex, TRANSFORM_TEX(Set_UV0, _HighColor_Tex));

    float3 _HighColor_var = (lerp((_HighColor_Tex_var.rgb*_HighColor.rgb), ((_HighColor_Tex_var.rgb*_HighColor.rgb)*Set_LightColor), _Is_LightColor_HighColor)*_TweakHighColorMask_var);

    finalColor = finalColor + lerp(lerp(_HighColor_var, (_HighColor_var*((1.0 - Set_FinalShadowMask) + (Set_FinalShadowMask*_TweakHighColorOnShadow))), _Is_UseTweakHighColorOnShadow), float3(0, 0, 0), _Is_Filter_HiCutPointLightColor);

    finalColor = SATURATE_IF_SDR(finalColor);
    // finalColor = lerp(finalColor, 0, Set_FinalShadowMask);

#if _USE_CHAR_SHADOW    // CUSTOM (Character Shadow)
    half ssShadowAtten = GetCharAdditionalShadow(worldPos, opacity, lightIndex);
    // finalColor = lerp(finalColor, 0, ssShadowAtten);
    finalColor = lerp(finalColor, finalShadeColor, ssShadowAtten);
    // finalColor = lerp(finalColor, dotNL > 0 ? finalShadeColor * 0.1 : 0, ssShadowAtten);
    // finalColor = lerp(finalColor, lerp(finalShadeColor, 0, Set_FinalShadowMask), ssShadowAtten);
#endif

#if _USE_SSS    // CUSTOM (SSS)
    finalColor += SubsurfaceScattering(lightDirection, viewDirection, lerp(normalDir, normalDirection, _Is_NormalMapToBase), Set_BaseColor, Set_LightColor);
#endif
    return finalColor;
}

float3 AdditionalLightingShadingGradeMap(UtsLight additionalLight, float4 _MainTex_var, float2 Set_UV0, float3 normalDir, float3 normalDirection, float3 viewDirection, float3 worldPos, float opacity, uint lightIndex = 0)
{
    float notDirectional = 1.0f; //_WorldSpaceLightPos0.w of the legacy code.
    half3 additionalLightColor = GetLightColor(additionalLight);
    float3 lightDirection = additionalLight.direction;
    //v.2.0.5: 
    half3 addPassLightColor = additionalLightColor;
    // float3 addPassLightColor = (0.5*dot(lerp(normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5) * additionalLightColor.rgb;
    float  pureIntencity = max(0.001, (0.299*additionalLightColor.r + 0.587*additionalLightColor.g + 0.114*additionalLightColor.b));
    float3 lightColor = max(float3(0.0,0.0,0.0), lerp(addPassLightColor, lerp(float3(0.0,0.0,0.0), min(addPassLightColor, addPassLightColor / pureIntencity), notDirectional), _Is_Filter_LightColor));
    float3 halfDirection = normalize(viewDirection + lightDirection); // has to be recalced here.

    //v.2.0.5:
    float firstShadeColorStep = saturate(_1st_ShadeColor_Step + _StepOffset);
    float secondShadeColorStep = saturate(_2nd_ShadeColor_Step + _StepOffset);
    //
    //v.2.0.5: If Added lights is directional, set 0 as _LightIntensity
    float _LightIntensity = lerp(0, (0.299*additionalLightColor.r + 0.587*additionalLightColor.g + 0.114*additionalLightColor.b), notDirectional);
    //v.2.0.5: Filtering the high intensity zone of PointLights
    float3 Set_LightColor = addPassLightColor; // = lightColor
    //
    float3 Set_BaseColor = lerp((_BaseColor.rgb*_MainTex_var.rgb*_LightIntensity), ((_BaseColor.rgb*_MainTex_var.rgb)*Set_LightColor), _Is_LightColor_Base);
    //v.2.0.5
    float4 _1st_ShadeMap_var = lerp(SAMPLE_TEXTURE2D(_1st_ShadeMap, sampler_MainTex,TRANSFORM_TEX(Set_UV0, _1st_ShadeMap)), _MainTex_var, _Use_BaseAs1st);
    float3 Set_1st_ShadeColor = lerp((_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb*_LightIntensity), ((_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_1st_Shade);
    //v.2.0.5
    float4 _2nd_ShadeMap_var = lerp(SAMPLE_TEXTURE2D(_2nd_ShadeMap, sampler_MainTex,TRANSFORM_TEX(Set_UV0, _2nd_ShadeMap)), _1st_ShadeMap_var, _Use_1stAs2nd);
    float3 Set_2nd_ShadeColor = lerp((_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb*_LightIntensity), ((_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_2nd_Shade);
    float _HalfLambert_var = 0.5*dot(lerp(normalDir, normalDirection, _Is_NormalMapToBase), lightDirection) + 0.5;


//v.2.0.6
    float4 _ShadingGradeMap_var = tex2Dlod(_ShadingGradeMap, float4(TRANSFORM_TEX(Set_UV0, _ShadingGradeMap), 0.0, _BlurLevelSGM));
    //v.2.0.6
    //Minmimum value is same as the Minimum Feather's value with the Minimum Step's value as threshold.
    //float _SystemShadowsLevel_var = (attenuation*0.5)+0.5+_Tweak_SystemShadowsLevel > 0.001 ? (attenuation*0.5)+0.5+_Tweak_SystemShadowsLevel : 0.0001;
    float _ShadingGradeMapLevel_var = _ShadingGradeMap_var.r < 0.95 ? _ShadingGradeMap_var.r + _Tweak_ShadingGradeMapLevel : 1;

    //float Set_ShadingGrade = saturate(_ShadingGradeMapLevel_var)*lerp( _HalfLambert_var, (_HalfLambert_var*saturate(_SystemShadowsLevel_var)), _Set_SystemShadowsToBase );

    float Set_ShadingGrade = saturate(_ShadingGradeMapLevel_var)*lerp(_HalfLambert_var, (_HalfLambert_var*saturate(1.0 + _Tweak_SystemShadowsLevel)), _Set_SystemShadowsToBase);

    float Set_FinalShadowMask = saturate((1.0 + ((Set_ShadingGrade - (firstShadeColorStep - _1st_ShadeColor_Feather)) * (0.0 - 1.0)) / (firstShadeColorStep - (firstShadeColorStep - _1st_ShadeColor_Feather))));
    float Set_ShadeShadowMask = saturate((1.0 + ((Set_ShadingGrade - (secondShadeColorStep - _2nd_ShadeColor_Feather)) * (0.0 - 1.0)) / (secondShadeColorStep - (secondShadeColorStep - _2nd_ShadeColor_Feather)))); // 1st and 2nd Shades Mask

    //Composition: 3 Basic Colors as finalColor
    float3 finalShadeColor = lerp(Set_1st_ShadeColor, Set_2nd_ShadeColor, Set_ShadeShadowMask);
    finalShadeColor = _MainLightColor.r + _MainLightColor.g + _MainLightColor.b > 0 ? finalShadeColor * _AdditionalShadowDimmer : 0;
    float3 finalColor = lerp(Set_BaseColor, finalShadeColor, Set_FinalShadowMask);
    //v.2.0.6: Add HighColor if _Is_Filter_HiCutPointLightColor is False

#if _IS_CLIPPING_TRANSMODE && _USE_OIT && _USE_CHAR_SHADOW  // CUSTOM (OIT Transmittance)
    finalColor += AdditionalOITTransmittance(lightDirection, viewDirection, lerp(normalDir, normalDirection, _Is_NormalMapToBase), Set_BaseColor, Set_LightColor, worldPos, opacity, lightIndex);
#endif

    float4 _Set_HighColorMask_var = tex2D(_Set_HighColorMask, TRANSFORM_TEX(Set_UV0, _Set_HighColorMask));
    float _Specular_var = 0.5*dot(halfDirection, lerp(normalDir, normalDirection, _Is_NormalMapToHighColor)) + 0.5; //  Specular                
    float hardSpecularVal = 1.0 - pow(abs(_HighColor_Power), 5);
    float hardSpecularLinearStep = saturate((hardSpecularVal - (_Specular_var - _HighColor_Feather)) / (2 * _HighColor_Feather)); 
    float _TweakHighColorMask_var = saturate(_Set_HighColorMask_var.g + _Tweak_HighColorMaskLevel) * lerp(1.0 - hardSpecularLinearStep, pow(_Specular_var, exp2(lerp(11, 1, _HighColor_Power))), _Is_SpecularToHighColor) * _LightIntensity;

    float4 _HighColor_Tex_var = tex2D(_HighColor_Tex, TRANSFORM_TEX(Set_UV0, _HighColor_Tex));

    float3 _HighColor_var = (lerp((_HighColor_Tex_var.rgb*_HighColor.rgb), ((_HighColor_Tex_var.rgb*_HighColor.rgb)*Set_LightColor), _Is_LightColor_HighColor)*_TweakHighColorMask_var);

    finalColor = finalColor + lerp(lerp(_HighColor_var, (_HighColor_var*((1.0 - Set_FinalShadowMask) + (Set_FinalShadowMask*_TweakHighColorOnShadow))), _Is_UseTweakHighColorOnShadow), float3(0, 0, 0), _Is_Filter_HiCutPointLightColor);

    finalColor = SATURATE_IF_SDR(finalColor);
    // finalColor = lerp(finalColor, 0, Set_FinalShadowMask);

#if _USE_CHAR_SHADOW    // CUSTOM (Character Shadow)
    half ssShadowAtten = GetCharAdditionalShadow(worldPos, opacity, lightIndex);
    finalColor = lerp(finalColor, finalShadeColor, ssShadowAtten);
#endif

#if _USE_SSS    // CUSTOM (SSS)
    finalColor += SubsurfaceScattering(lightDirection, viewDirection, lerp(normalDir, normalDirection, _Is_NormalMapToBase), Set_BaseColor, Set_LightColor);
#endif
    return finalColor;
}