Shader "Unlit/CartoonMetal04"
{
    Properties
    {
       // _MainTex ("Texture", 2D) = "white" {}
        _CubeMap("Cube Map", Cube) = "white" {}

        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Spec Color", Color) = (1, 1, 1, 1)
        _MidSpecularColor("Mid Spec Color", Color) = (1, 1, 1, 1)

        _LightLimit("Light Limit", Range(0, 1.0)) = 0.086
        _DarkLimit("Dark Limit", Range(0, 1.0)) = 0.05
        _Gloss("Gloss", Range(1, 512)) = 128
        _OutSpecularLimit("Out Specular Limit", Range(0, 1.0)) = 0.377
        _MidSpecularLimit("Mid Specular Limit", Range(0, 1.0)) = 0.584
        _InnerSpecularLimit("Inner Specular Limit", Range(0, 1.0)) = 0.677
		_Brightness("Brightness", Float) = 1	//��������
        _Hues("Hues",range(0, 1)) = 0
		_Saturation("Saturation", Float) = 1	//�������Ͷ�
		_Contrast("Contrast", Float) = 1
		_QuenchPower("Quench Power", Range(0, 1)) = 1

        //������
        _OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutlineLimit ("Outline Limit", Range(0.01, 4)) = 0.3
        _OutlineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)

        //
        _UpLimit("Up Limit",float) = 0
        _DownLimit("Down Limit",float) = 0

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
                float3 pos_local : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            //sampler2D _MainTex;
            //float4 _MainTex_ST;
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;

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
            float _QuenchPower;

            float _UpLimit;
            float _DownLimit;
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
                  float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                  float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                  return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
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
                o.pos_local = v.vertex;
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

                //���ȡ����Ͷȡ��Աȶ�
			    //contrast�Աȶȣ����ȼ���Աȶ���͵�ֵ
			    fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
			    //����Contrast�ڶԱȶ���͵�ͼ���ԭͼ֮���ֵ
			    color_cube = fixed4(lerp(avgColor, color_cube.rgb, _Contrast), 1.0);
                float3 hsv = RGB2HSV(color_cube.xyz);
                hsv.x += _Hues;
                color_cube = fixed4(HSV2RGB(hsv), 1.0);

                //���Ͷ�
                fixed grey = max(color_cube.r, max(color_cube.g, color_cube.b));
                color_cube = fixed4(lerp(fixed3(grey, grey, grey), color_cube.rgb, _Saturation), 1.0);
			    //brigtness����ֱ�ӳ���һ��ϵ����Ҳ����RGB�������ţ���������
			    color_cube = color_cube * _Brightness;

                //fixed4 quench_color = fixed4(sin(i.uv.x * acos(-1.0)), sin(i.uv.y * acos(-1.0)), sin(i.uv.x * acos(-1.0) + i.uv.y * acos(-1.0)), 0);
                //i.pos_local = normalize(abs(i.pos_local));
                //fixed4 quench_color = fixed4(sin(i.pos_local * acos(-1.0)), 1.0);
                fixed4 quench_color;
                quench_color.r = smoothstep(_DownLimit, _UpLimit, i.pos_local.x * 100);
                quench_color.g = smoothstep(_DownLimit, _UpLimit, i.pos_local.y * 100);
                quench_color.b = smoothstep(_DownLimit, _UpLimit, i.pos_local.z * 100);
                quench_color.a = 1.0;
                fixed3 quench_hsv = RGB2HSV(quench_color.rgb);
                quench_hsv.x -= 0.14;
                quench_color = fixed4(HSV2RGB(quench_hsv), 1.0);
                fixed quench_grey = max(quench_color.r, max(quench_color.g, quench_color.b));
                quench_color = fixed4(lerp(fixed3(quench_grey, quench_grey, quench_grey), quench_color.rgb, 0.5), 1.0);

                //return quench_color;
                //fixed4 quench_color = fixed4(i.uv, 0, 0);
                grey = max(quench_color.r, max(quench_color.g, quench_color.b));
                quench_color = fixed4(lerp(fixed3(grey, grey, grey), quench_color.rgb, 0.5), 0.5);
                color_cube = color_cube + quench_color * _QuenchPower;

                float shadow = SHADOW_ATTENUATION(i);
                float lambert = saturate(dot(normal_dir, light_dir)) * shadow;
                float shadowMap = smoothstep(_DarkLimit, _LightLimit, lambert);
                fixed4 final_color = color_cube * ((1.0 - shadowMap) * _ShadowColor + shadowMap * fixed4(1, 1, 1, 1));
                final_color = ColorFilter(pow(final_color, 1.0 / 2.2), specColor);


                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                return final_color;
                //return quench_color;
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
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * min(pos.w, _OutlineLimit);//�����߱任��NDC�ռ�
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//�����ü������Ͻ�λ�õĶ���任���۲�ռ�
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//�����Ļ��߱�
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
