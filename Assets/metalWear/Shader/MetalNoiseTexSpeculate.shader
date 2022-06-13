Shader "Unlit/MetalNoiseTexSpecilar"
{
    Properties
    {
        _BasicColor("Basic Color", Color) = (1, 1, 1, 1)

        _WearColor("Wear Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _WearLimit("Wear Limit", Range(0, 1.0)) = 0.2323
        _WearTex("Wear Texture", 2D) = "white"{}
        _WearTexBrightness("Wear Texture Brightness", Range(0, 1)) = 0

        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        _ShadowLimit1("Shadow Limit 1", Range(0, 1)) = 0.301
        _ShadowLimit2("Shadow Limit 2", Range(0, 1)) = 0.043
        _MidShadowValue("Middle Shadow Value", Range(0, 1)) = 0.5

        _SpecularColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularLimit("Specular Limit", Range(0, 1.0)) = 0.723
        _Smooth("Smooth", Range(1, 128)) = 64

        _NoiseTex("Noise Texture", 2D) = "white"{}
        _NoiseLimit("Noise Limit", Range(0, 1)) = 0.4104
        _BumpScale("Bump Scale", float) = 1
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
                float3 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 tangent_world : TEXCOORD2;
                float3 binormal_world : TEXCOORD3;
                float3 normal_world : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            float4 _BasicColor;

            float4 _WearColor;
            float _WearLimit;
            sampler2D _WearTex;
            float _WearTexBrightness;

            float4 _ShadowColor;
            float _ShadowLimit1;
            float _ShadowLimit2;
            float _MidShadowValue;

            float4 _SpecularColor;
            float _SpecularLimit;
            float _Smooth;

            sampler2D _NoiseTex;
            float2 _NoiseTex_TexelSize;
            float _NoiseLimit;
            float _BumpScale;

            float3 filter(float3 color1, float3 color2)
            {
                float r = 1 - (1 - color1.r) * (1 - color2.r);
                float g = 1 - (1 - color1.g) * (1 - color2.g);
                float b = 1 - (1 - color1.b) * (1 - color2.b);
                return float3(r, g, b);
            }
            float4 darken(float4 colora, float4 colorb)
            {
                float r = min(colora.r, colorb.r);
                float g = min(colora.g, colorb.g);
                float b = min(colora.b, colorb.b);
                return float4(r, g, b, 1.0);
            }
            float3 CalculateNormal(float2 uv)
			{
				float2 du = float2(_NoiseTex_TexelSize.x, 0);
				float2 dv = float2(0, _NoiseTex_TexelSize.y);
                float NoiseHr = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv + du).g, 2.2)), 1.0 / 2.2);
				float NoiseHa = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv + dv).g, 2.2)), 1.0 / 2.2);
				float NoiseHg = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv).g, 2.2)), 1.0 / 2.2);
                float WearHr = smoothstep(_WearLimit, 1.0, lerp(tex2D(_WearTex, uv + du).g, 1.0, _WearTexBrightness));
				float WearHa = smoothstep(_WearLimit, 1.0, lerp(tex2D(_WearTex, uv + dv).g, 1.0, _WearTexBrightness));
				float WearHg = smoothstep(_WearLimit, 1.0, lerp(tex2D(_WearTex, uv).g, 1.0, _WearTexBrightness));
                float Hr = min(NoiseHr, WearHr);
                float Ha = min(NoiseHa, WearHa);
                float Hg = min(NoiseHg, WearHg);
                //float Hr = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv + du).g, 2.2)), 1.0 / 2.2);
                //float Ha = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv + dv).g, 2.2)), 1.0 / 2.2);
                //float Hg = pow(smoothstep(_NoiseLimit, 1.0, pow(tex2D(_NoiseTex, uv).g, 2.2)), 1.0 / 2.2);
                float x = (Hg - Hr) * _BumpScale;
                float y = (Hg - Ha) * _BumpScale; 
                float z = 1.0 - saturate(x * x + y * y);

				return normalize(float3(x, y, z)); //这里加不加负号可以放到高度图的a通道来决定
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.tangent_world = normalize(UnityObjectToWorldDir(v.tangent));
                o.normal_world = normalize(UnityObjectToWorldNormal(v.normal));
                o.binormal_world = normalize(cross(o.normal_world, o.tangent_world));
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float3 tangent_dir = normalize(i.tangent_world);
                float3 binormal_dir = normalize(i.binormal_world);
                float3 normal_dir = normalize(i.normal_world);
                float3 bump = CalculateNormal(i.uv);
                float3 normal_world = normalize(
                    bump.x * tangent_dir + 
                    bump.y * binormal_dir + 
                    bump.z * normal_dir
                );
                //return fixed4(normal_world, 1.0);
                float3 light_dir = normalize( _WorldSpaceLightPos0);
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float shadow = SHADOW_ATTENUATION(i);
                float4 wearValue = smoothstep(float4(float3(1.0, 1.0, 1.0) * _WearLimit, 1.0), float4(1.0, 1.0, 1.0, 1.0), lerp(tex2D(_WearTex, i.uv), float4(1.0, 1.0, 1.0, 1.0), _WearTexBrightness));
                float4 noiseValue = pow(smoothstep(float4(float3(1.0, 1.0, 1.0) * _NoiseLimit, 1.0), float4(1.0, 1.0, 1.0, 1.0), pow(tex2D(_NoiseTex, i.uv), 2.2)), 1.0 / 2.2);
                float wearCol = darken(noiseValue, wearValue).r;
                
                float lambert = saturate(dot(normal_world, light_dir)) * shadow;
                fixed4 basicColor = lerp(_BasicColor, _WearColor, wearCol);

                //return basicColor;

                float3 half_dir = normalize(light_dir + view_dir);

                float shadowStep1 = step(_ShadowLimit1, lambert);
                float shadowStep2 = step(_ShadowLimit2, lambert);
                float lerpValue = (1.0 - shadowStep1) * shadowStep2 * _MidShadowValue + shadowStep1; 
                fixed4 shadowColor = basicColor * _ShadowColor ;

                float SpecularStep = step(_SpecularLimit, pow(saturate(dot(half_dir, normal_world)), _Smooth));

                fixed4 col = lerp(shadowColor, basicColor, lerpValue);
                //fixed4 col = fixed4(fixed3(1, 1, 1) * SpecularStep, 1.0);
                fixed4 colWithSpec = fixed4(filter(col.rgb, _SpecularColor.rgb), 1.0);

                fixed4 finalColor = lerp(col, colWithSpec, SpecularStep );

                return finalColor;
            }
            ENDCG
        }
    }
    FallBack"Diffuse"
}