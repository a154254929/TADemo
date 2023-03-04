Shader "URP/EnergyShield"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _CallMode("Call Mode",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("DstFactor",int) = 0
        [Enum(Less,0, Greater,1, LEqual,2, GEqual,3, Equal,4, NotEqual,5, Always,6)]  _ZTest("ZTest",int) = 0
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite",int) = 0
        _MainTex("Main Texture", 2D) = "white" {}

        [Header(Fresnel)]
        _FresnelColor("Fresnel Color",Color) = (1,1,1,1)
        [PowerSlider(3)]_FresnelPower("FresnelPower",Range(0,15)) = 5

        [Header(Distort)]
        _DistortSpeed("Distort Speed", Range(0.1, 8)) = 1
        _DistortIntensity("Distort Intensity", Range(0, 1)) = 0
        [IntRange]_Roughness("Roughness",Range(1, 6)) = 1

        [Header(HighLight)]
        _HighLightColor("HighLight Color",Color) = (1,1,1,1)
        _HighLightFade("HighLight Fade",float) = 3
    }
        SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "UniversalMaterialType" = "Unlit"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Pass"

            // Render State
            Cull [_CallMode]
            Blend [_SrcFactor] [_DstFactor]
            ZTest [_ZTest]
            ZWrite [_ZWrite]

            // Debug
            // <None>

            // --------------------------------------------------
            // Pass

            HLSLPROGRAM

            // Pragmas
            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore
            #pragma vertex vert
            #pragma fragment frag

            // Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            // --------------------------------------------------
            // Structs and Packing

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 positionVS : TEXCOORD3;
                float3 normalWS : NORMAL;
                float3 normalVS : TANGENT;
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex); float4 _MainTex_ST;

                half4 _FresnelColor;
                float _FresnelPower;

                float _DistortSpeed;
                float _DistortIntensity;
                int _Roughness;

                half4 _HighLightColor;
                float _HighLightFade;
            CBUFFER_END
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

            Varings vert(Attributes v)
            {
                Varings o;
                o.positionOS = normalize(v.positionOS);
                o.positionWS = TransformObjectToWorld(v.positionOS);
                o.positionVS = TransformWorldToView(o.positionWS);
                o.positionCS = TransformWViewToHClip(o.positionVS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.normalVS = TransformWorldToViewDir(o.normalWS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(Varings i) : SV_Target
            {
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                float fresnelIntensity = abs(dot(viewDir, i.normalWS));
                float2 screenPos = i.positionCS / _ScreenParams.xy;
                float2 distortScreenPos = screenPos + i.normalVS.xy * _DistortIntensity * fresnelIntensity;
                half4 screenColor = lerp(SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortScreenPos, _Roughness), _FresnelColor, pow(1.0 - fresnelIntensity, _FresnelPower));

                float depthColor = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos);
                float depth = LinearEyeDepth(depthColor.r, _ZBufferParams);
                float highLightIntensity = pow(1 - saturate(depth + i.positionVS.z), _HighLightFade);

                double angleA = frac((acos(normalize(i.positionOS.xz).y * normalize(i.positionOS.x))) / PI);
                double3 pointVector = normalize(i.positionOS);
                double angleB = frac(acos(length(pointVector.xz) * normalize(i.positionOS.y)) / PI + _Time.x);
                double2 sampleUV = TRANSFORM_TEX(double2(angleA, angleB), _MainTex);
                screenColor = lerp(screenColor, _FresnelColor, highLightIntensity);
                // sample the texture
                //half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, sampleUV);
                float x = col.x * frac(i.positionOS.y * 2 + _Time.y * _DistortSpeed);
                screenColor = lerp(screenColor, _HighLightColor, highLightIntensity);
                clip(col.x - 0.1);
                return screenColor;
                //return half4(viewDir, 1);
                //return half4(screenColor.rgb, x);
                //return  col;

            }
            ENDHLSL
        }
    }
}