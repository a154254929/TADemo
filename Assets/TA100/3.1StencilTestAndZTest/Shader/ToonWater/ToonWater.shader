Shader "Roystan/Toon/Water"
{
    Properties
    {
        //湖的浅部颜色、深部颜色以及视觉最大深度
        _DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725)
        _DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749)
        _DepthMaxDistance("Depth Maximum Distance", Float) = 1

        //边缘泡沫
        _FoamMaxDistance("Foam Maximum Distance", Float) = 0.4
        _FoamMinDistance("Foam Minimum Distance", Float) = 0.04


        //湖面泡沫
        _FoamColor("Foam Color", Color) = (1,1,1,1)
        _SurfaceNoise("Surface Noise", 2D) = "white" {}
        _SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.777
        _SurfaceNoiseTimeScroll("Surface Noise Time Scroll Amount", Vector) = (0.03, 0.03, 0, 0)
        
        //湖面泡沫扰动
        _SurfaceDistortion("Surface Distortion", 2D) = "white" {}	
        _SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27
    }
    SubShader
    {
        Tags{"Queue" = "Transparent"}
        Pass
        { 
            Tags{ "LightMode"="ForwardBase" }
            //Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
			CGPROGRAM
            #define SMOOTHSTEP_AA 0.01
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            //#include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewNormal : NORMAL;
                float4 screenPosition : TEXCOORD1;
                float2 distortUV : TEXCOORD2;
            };

            half4 _DepthGradientShallow;
            half4 _DepthGradientDeep;
            float _DepthMaxDistance;

            half4 _FoamColor;
            float _FoamMaxDistance;
            float _FoamMinDistance;

            sampler2D _CameraDepthTexture;
            sampler2D _CameraNormalsTexture;

            sampler2D _SurfaceNoise;
            float4 _SurfaceNoise_ST;
            float _SurfaceNoiseCutoff;
            float4 _SurfaceNoiseTimeScroll;

            sampler2D _SurfaceDistortion;
            float4 _SurfaceDistortion_ST;
            float _SurfaceDistortionAmount;

            float4 alphaBlend(float4 top, float4 bottom)
            {
	            float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
	            float alpha = top.a + bottom.a * (1 - top.a);

	            return float4(color, alpha);
            }
            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv * _SurfaceNoise_ST.xy + _SurfaceNoise_ST.zw;
                o.viewNormal = COMPUTE_VIEW_NORMAL;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPosition = ComputeScreenPos(o.vertex);
                o.distortUV = v.uv * _SurfaceDistortion_ST.xy + _SurfaceDistortion_ST.zw;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //计算摄像机视角下湖面深度
                float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
                float existingDepthLinear = LinearEyeDepth(existingDepth01);
                float depthDifference = existingDepthLinear - i.screenPosition.w;
                float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);
                half4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);
                //return waterColor;

                //摄像机视角下的法线计算，用于计算其他物体与湖面的泡沫
                float3 existingNormal = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(i.screenPosition));
                float3 normalDot = saturate(dot(existingNormal, i.viewNormal));
                
                float2 distortSample = (tex2D(_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;
                float2 noiseUV = float2(i.uv.x + frac(_Time.y * _SurfaceNoiseTimeScroll.x) + distortSample.x, i.uv.y + frac(_Time.y * _SurfaceNoiseTimeScroll.y) + distortSample.y);
                float surfaceNoiseSample = tex2D(_SurfaceNoise, noiseUV).r;
                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
                float foamDepthDifference01 = saturate(depthDifference / foamDistance);
                float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;

                //float surfaceNoise = step(surfaceNoiseCutoff, surfaceNoiseSample);
                float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);;
                half4 foamColor = half4(_FoamColor.rgb, surfaceNoise);
				//return float4(surfaceNoiseSample, surfaceNoiseSample, surfaceNoiseSample, 0.5);
				//return half4(existingNormal, 1.0);
				return alphaBlend(foamColor, waterColor);
            }
            ENDCG
        }
    }
}