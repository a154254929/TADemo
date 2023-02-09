Shader "Unlit/Tree"
{
    Properties
    {
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
        _MainTex ("Texture", 2D) = "white" {}
		_Ramp ("Toon Ramp (RGB)", 2D) = "gray" {} 
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };

            float4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Ramp;
            float4 _Ramp_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 lighrDir = normalize(_WorldSpaceLightPos0);
                float3 noraml = normalize(i.normal);
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float halfLambert = dot(lighrDir, noraml) * 0.5 + 0.5;
                fixed4 result = fixed4(_Color.rgb *  tex2D(_Ramp, float2(halfLambert, halfLambert)).rgb * col.rgb, _Color.a) * 2;
                return result;
            }
            ENDCG
        }
    }
}
