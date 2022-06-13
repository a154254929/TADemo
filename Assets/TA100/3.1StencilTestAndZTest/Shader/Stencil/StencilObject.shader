Shader "Toon/Lit StencilMask" 
{
	Properties 
	{
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Ramp ("Toon Ramp (RGB)", 2D) = "gray" {} 
		_ID("Mask ID", Int) = 1

	}

	SubShader {
        //‘⁄’⁄’÷∫Û‰÷»æ
		Tags { "RenderType"="Opaque" "Queue" = "Geometry+2"}
		LOD 200
		
		Stencil {
			Ref [_ID]
			Comp equal
		}
		pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : NORMAL;
                float4 screenPosition : TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = normalize(mul((float3x3)UNITY_MATRIX_M, v.normal));
				o.screenPosition = ComputeScreenPos(o.vertex);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
                float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
                float existingDepthLinear = LinearEyeDepth(existingDepth01);
                float depthDifference = existingDepthLinear - i.screenPosition.w;
				float NdotL = dot(i.worldNormal, _WorldSpaceLightPos0);
				float light = saturate(floor(NdotL * 3) / (2 - 0.5)) * _LightColor0;

				float4 col = tex2D(_MainTex, i.uv);
				return (col * _Color) * (light + unity_AmbientSky);
			}
			ENDCG
		}
	} 
	//Fallback "Diffuse"
}