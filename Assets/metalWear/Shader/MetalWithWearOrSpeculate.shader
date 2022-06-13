Shader "Unlit/MetalWithWearOrSpecilar"
{
    Properties
    {
        _BasicColor("Basic Color", Color) = (1, 1, 1, 1)

        _WearColor("Wear Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _WearLimit("Wear Limit", Range(0, 1.0)) = 0.2323
        _WearPow("Wear Pow", float) = 2.0

        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        _ShadowLimit1("Shadow Limit 1", Range(0, 1)) = 0.301
        _ShadowLimit2("Shadow Limit 2", Range(0, 1)) = 0.043
        _MidShadowValue("Middle Shadow Value", Range(0, 1)) = 0.5

        _SpecularColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularLimit("Specular Limit", Range(0, 1.0)) = 0.723
        _Smooth("Smooth", Range(1, 128)) = 64

        _WearRoughness("Wear Roughness", Range(0, 1)) = 0

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
                float3 col : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                float3 col : COLOR;
                SHADOW_COORDS(3)
            };

            float4 _BasicColor;

            float4 _WearColor;
            float _WearLimit;
            float _WearPow;

            float4 _ShadowColor;
            float _ShadowLimit1;
            float _ShadowLimit2;
            float _MidShadowValue;

            float4 _SpecularColor;
            float _SpecularLimit;
            float _Smooth;

            float _WearRoughness;

            float3 filter(float3 color1, float3 color2)
            {
                float r = 1 - (1 - color1.r) * (1 - color2.r);
                float g = 1 - (1 - color1.g) * (1 - color2.g);
                float b = 1 - (1 - color1.b) * (1 - color2.b);
                return float3(r, g, b);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.col = pow(v.col, _WearPow);
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float3 normal_world = normalize(i.worldNormal);
                float3 light_dir = normalize( _WorldSpaceLightPos0);
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float shadow = SHADOW_ATTENUATION(i);
                float wearValue = smoothstep(0.0, _WearLimit, i.col.r);
                
                float lambert = saturate(dot(normal_world, light_dir)) * shadow;
                fixed4 basicColor = lerp(_BasicColor, _WearColor, wearValue);
                float3 half_dir = normalize(light_dir + view_dir);

                float shadowStep1 = step(_ShadowLimit1, lambert);
                float shadowStep2 = step(_ShadowLimit2, lambert);
                float lerpValue = (1.0 - shadowStep1) * shadowStep2 * _MidShadowValue + shadowStep1; 
                fixed4 shadowColor = basicColor * _ShadowColor ;

                float SpecularStep = lerp(step(_SpecularLimit, pow(saturate(dot(half_dir, normal_world)), _Smooth)), _WearRoughness, wearValue);

                fixed4 col = lerp(shadowColor, basicColor, lerpValue);
                //fixed4 col = fixed4(fixed3(1, 1, 1) * _WearRoughness, 1.0);
                fixed4 colWithSpec = fixed4(filter(col.rgb, _SpecularColor.rgb), 1.0);

                fixed4 finalColor = lerp(col, colWithSpec, SpecularStep );

                return finalColor;
            }
            ENDCG
        }
    }
    FallBack"Diffuse"
}
