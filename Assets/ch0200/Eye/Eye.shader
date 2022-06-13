Shader "Unlit/Eye"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _AMBTex ("AMB Texture", 2D) = "white" {}

        _AMBLimit ("AMB Limit", Range(0,1)) = 0.56
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
                float3 normal : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _AMBTex;
            float4 _AMBTex_ST;

            float _AMBLimit;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 baseColor = pow(tex2D(_MainTex, i.uv), 2.2);
                fixed4 ambColor = pow(tex2D(_AMBTex, i.uv), 2.2);
                float worldNormal = UnityObjectToWorldNormal(normalize(i.normal));
                float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                float lambert = dot(worldNormal, light_dir) * 0.5 + 0.5;
                float term = smoothstep(_AMBLimit, _AMBLimit + 0.05, lambert);
                // sample the texture
                fixed4 col = pow(fixed4(term * baseColor.rgb + (1 - term) * ambColor.rgb, 1.0), 1.0 / 2.2);
                return col;
            }
            ENDCG
        }
    }
}
