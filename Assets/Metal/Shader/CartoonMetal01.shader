Shader "Unlit/CartoonMetal01"
{
    Properties
    {
       // _MainTex ("Texture", 2D) = "white" {}
        _CubeMap("Cube Map", Cube) = "white" {}

        _ReflectionColor("Reflection Color", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)

        _LightLimit("Light Limit", Range(0, 1.0)) = 0.086
        _DarkLimit("Dark Limit", Range(0, 1.0)) = 0.05

        //描边相关
        _OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutlineLimit ("Outline Limit", Range(0.01, 4)) = 0.3
        _OutlineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)

        
        _Lum("Lum",Range(0, 2.0)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags{"LightMode" = "ForwardBase"}
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
                float3 normal_world : TEXCOORD1;
                float3 pos_world : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            //sampler2D _MainTex;
            //float4 _MainTex_ST;
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;

            fixed4 _ReflectionColor;
            fixed4 _ShadowColor;

            float _LightLimit;
            float _DarkLimit;

            float _Lum;

            float3 Overlay(float3 color1, float3 color2)
            {
                float r = step(0.5, color1.r) * (color1.r * color2.r - (1 - (1 - color1.r) * (1 - color2.r))) + (1 - (1 - color1.r) * (1 - color2.r));
                float g = step(0.5, color1.g) * (color1.g * color2.g - (1 - (1 - color1.g) * (1 - color2.g))) + (1 - (1 - color1.g) * (1 - color2.g));
                float b = step(0.5, color1.b) * (color1.b * color2.b - (1 - (1 - color1.b) * (1 - color2.b))) + (1 - (1 - color1.b) * (1 - color2.b));
                return float3(r, g, b);
            }

            float3 ACESToneMapping(float3 color, float adapted_lum)
            {
                const float A = 2.51f;
                const float B = 0.03f;
                const float C = 2.43f;
                const float D = 0.59f;
                const float E = 0.14f;
                color *= adapted_lum;
                return (color * (A * color + B)) / (color * (C * color + D) + E);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal_world = normalize(UnityObjectToWorldNormal(v.normal));
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal_dir = normalize(i.normal_world);
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
				fixed3 light_dir = normalize(UnityWorldSpaceLightDir(i.pos_world));
                float3 reflect_dir = reflect(-view_dir, normal_dir);
                fixed4 color_cube = texCUBE(_CubeMap, reflect_dir);
                color_cube = fixed4(DecodeHDR(color_cube, _CubeMap_HDR), 1.0);
                color_cube = fixed4(Overlay(_ReflectionColor.rgb, color_cube.rgb), 1.0);

                //return color_cube;

                float shadow = SHADOW_ATTENUATION(i);
                float lambert = saturate(dot(normal_dir, light_dir)) * shadow;
                float shadowMap = smoothstep(_DarkLimit, _LightLimit, lambert);
                fixed4 final_color = color_cube * ((1.0 - shadowMap) * _ShadowColor + shadowMap * fixed4(1, 1, 1, 1));
                //final_color = pow(final_color, 1.0 / 2.2);

                //fixed4 final_color = fixed4(lambert, lambert, lambert, 1.0);


                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                return final_color;
            }
            ENDCG
        }
        Pass
        {
            Cull front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };
            
            float _OutlineWidth;
            float _OutlineLimit;
            fixed4 _OutlineColor;

            v2f vert (appdata v)
            {
                v2f o;
                float4 pos = UnityObjectToClipPos(v.vertex);
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal.xyz);
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * min(pos.w, _OutlineLimit);//将法线变换到NDC空间
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                ndcNormal.x *= aspect;
                pos.xy += 0.1 * _OutlineWidth * ndcNormal.xy;
                o.pos = pos;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }
    }
    FallBack"Diffuse"
}
