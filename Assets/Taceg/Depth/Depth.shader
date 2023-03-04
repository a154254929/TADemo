Shader "Unlit/Depth"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            Cull back
            ZWrite On
            HLSLPROGRAM
            #pragma perfer_hlslcc gles
            #pragma vertex vert
            #pragma fragment frag

            //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex); float4 _MainTex_ST;
            CBUFFER_END
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

            Varings vert (Attributes v)
            {
                Varings o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = o.positionCS / max(o.positionCS.w, 0.0005) * 0.5 + 0.5;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {
                // sample the texture
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                //half4 col = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.screenPos.xy);
                return col;
                //return half4(i.positionCS.xy / _ScreenParams.xy, 0, 1);
                //return half4(i.screenPos.xy, 0, 1);
                
            }
            ENDHLSL
        }
    }
}
