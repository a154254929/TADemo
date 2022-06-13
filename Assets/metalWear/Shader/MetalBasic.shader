Shader "Unlit/MetalBasic"
{
    Properties
    {
        _BasicColor("Basic Color", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        _ShadowLimit1("Shadow Limit 1", Range(0, 1)) = 0.301
        _ShadowLimit2("Shadow Limit 2", Range(0, 1)) = 0.043
        _MidShadowValue("Middle Shadow Value", Range(0, 1)) = 0.5

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Cull Off
            Tags{ "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
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
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            float4 _BasicColor;
            float4 _ShadowColor;
            float _ShadowLimit1;
            float _ShadowLimit2;
            float _MidShadowValue;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float3 normal_world = normalize(i.worldNormal);
                float3 light_dir = normalize( _WorldSpaceLightPos0);
                float shadow = SHADOW_ATTENUATION(i);
                
                float lambert = saturate(dot(normal_world, light_dir)) * shadow;

                float shadowStep1 = step(_ShadowLimit1, lambert);
                float shadowStep2 = step(_ShadowLimit2, lambert);
                float lerpValue = (1.0 - shadowStep1) * shadowStep2 * _MidShadowValue + shadowStep1; 
                fixed4 shadowColor = _BasicColor * _ShadowColor ;

                fixed4 col = lerp(shadowColor, _BasicColor, lerpValue);
                //fixed4 col = fixed4(fixed3(1, 1, 1) * shadow, 1.0);

                return col;
            }
            ENDCG
        }
    }
    FallBack"Diffuse"
}
