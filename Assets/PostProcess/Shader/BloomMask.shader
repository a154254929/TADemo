Shader "Unlit/BloomMask"
{
    Properties
    {
        _BaseColor("Base Color", color) = (0.5, 0.5, 0.5, 1.0)
        _Alpha("Alpha" , range(0, 1)) = 0
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
            #include "Lighting.cginc"

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

            fixed4 _BaseColor;
            float _Alpha;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float lambert = smoothstep(0.3, 0.9, dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5);
                return fixed4(_BaseColor.rgb * lambert, _Alpha);
            }
            ENDCG
        }
    }
}
