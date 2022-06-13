Shader "Unlit/CartoonMetal03"
{
    Properties
    {
       // _MainTex ("Texture", 2D) = "white" {}
        _CubeMap("Cube Map", Cube) = "white" {}

        _ReflectionColor("Reflection Color", Color) = (1, 1, 1, 1)
        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Spec Color", Color) = (1, 1, 1, 1)
        _MidSpecularColor("Mid Spec Color", Color) = (1, 1, 1, 1)

        _LightLimit("Light Limit", Range(0, 1.0)) = 0.086
        _DarkLimit("Dark Limit", Range(0, 1.0)) = 0.05
        _Gloss("Gloss", Range(1, 512)) = 128
        _OutSpecularLimit("Out Specular Limit", Range(0, 1.0)) = 0.377
        _MidSpecularLimit("Mid Specular Limit", Range(0, 1.0)) = 0.584
        _InnerSpecularLimit("Inner Specular Limit", Range(0, 1.0)) = 0.677
		_Brightness("Brightness", Float) = 1	//调整亮度
        _Hues("Hues", Range(0, 1)) = 0.5
		_Saturation("Saturation", Float) = 1	//调整饱和度
		_Contrast("Contrast", Float) = 1

        //描边相关
        _OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutlineLimit ("Outline Limit", Range(0.01, 4)) = 0.3
        _OutlineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)

        
        //_Lum("Lum",Range(0, 1.0)) = 1
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
            fixed4 _SpecularColor;
            fixed4 _MidSpecularColor;

            float _LightLimit;
            float _DarkLimit;
            float _Gloss;
            float _OutSpecularLimit;
            float _MidSpecularLimit;
            float _InnerSpecularLimit;
            float _Brightness;
            float _Hues;
            float _Saturation;
            float _Contrast;

            //float _Lum;

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
            float3 RGB2HSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	            float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
	            float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

	            float d = q.x - min(q.w, q.y);
	            float e = 1.0e-10;
	            return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }
            float3 HSV2RGB(float3 c)
            {
                float3 rgb = clamp( abs(fmod(c.x*6.0+float3(0.0,4.0,2.0),6)-3.0)-1.0, 0, 1);
                rgb = rgb*rgb*(3.0-2.0*rgb);
                return c.z * lerp( float3(1,1,1), rgb, c.y);
            }

            float4 ColorFilter(float4 color1, float4 color2)
            {
                float r = 1.0 - (1.0 - color1.r) * (1.0 - color2.r);
                float g = 1.0 - (1.0 - color1.g) * (1.0 - color2.g);
                float b = 1.0 - (1.0 - color1.b) * (1.0 - color2.b);
                float a = 1.0;
                return float4(r, g, b, a);
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
                float3 half_dir = normalize(light_dir + view_dir);

                float spec = pow(saturate(dot(half_dir, normal_dir)), _Gloss);
                float outSpec = step(min(_OutSpecularLimit, _MidSpecularLimit), spec);
                float innerSpec = step(_MidSpecularLimit, spec);
                fixed4 specColor = outSpec * (1 - innerSpec) * smoothstep(min(_OutSpecularLimit, _MidSpecularLimit), _MidSpecularLimit, spec) * _MidSpecularColor +
                    innerSpec * (smoothstep(min(_MidSpecularLimit, _InnerSpecularLimit), _InnerSpecularLimit, spec) * (_SpecularColor - _MidSpecularColor) + _MidSpecularColor);

                fixed4 color_cube = texCUBE(_CubeMap, reflect_dir);
                color_cube = pow(color_cube, 2.2);
                color_cube = fixed4(DecodeHDR(color_cube, _CubeMap_HDR), 1.0);

                //亮度、饱和度、对比度
			    //contrast对比度：首先计算对比度最低的值
			    fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
			    //根据Contrast在对比度最低的图像和原图之间差值
			    color_cube = fixed4(lerp(avgColor, color_cube.rgb, _Contrast), 1.0);
                //调整色相
                float3 hsv = RGB2HSV(color_cube.rgb);
                hsv.r =  hsv.r + _Hues;
                color_cube = fixed4(HSV2RGB(hsv), 1.0);
                //饱和度
                fixed grey = max(max(color_cube.r, color_cube.g), color_cube.b);
                color_cube = fixed4(lerp(fixed3(grey, grey, grey), color_cube.rgb, _Saturation), 1.0);
			    //brigtness亮度直接乘以一个系数，也就是RGB整体缩放，调整亮度
                color_cube *= _Brightness;
                //return pow(color_cube, 1.0 / 2.2);


                float shadow = SHADOW_ATTENUATION(i);
                float lambert = saturate(dot(normal_dir, light_dir)) * shadow;
                float shadowMap = smoothstep(_DarkLimit, _LightLimit, lambert);
                fixed4 final_color = color_cube * ((1.0 - shadowMap) * _ShadowColor + shadowMap * fixed4(1, 1, 1, 1));
                final_color = ColorFilter(pow(final_color, 1.0 / 2.2), specColor);
                //final_color = final_color + specColor;

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
