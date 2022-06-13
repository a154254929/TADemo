Shader "Unlit/Hair"
{
    Properties
    {
        [Toggle] _Show("Show", int) = 1

        _ColorTex ("Color Texture", 2D) = "white" {}
        _AMBTex ("AMB Texture", 2D) = "white" {}
        _NormalTex ("Normal Texture", 2D) = "white" {}
        _CTLTex ("CTL Texture", 2D) = "white" {}
        _HairPTex("HairPColor Texture", 2D) = "white" {}

        //漫反射颜色
        _DiffuseColor ("Diffuse Color", Color) = (0.9, 0.9, 0.9,1.0)
        
        //阴影控制相关
        _ShadowLimit ("Shadow Limit", Range(0, 1.0)) = 0.5
        _ShodowColor ("Shadow Color", Color) = (0.5, 0.5, 0.5,1.0)

        //各项异性高光
        _SpecPow ("Specular Power", range(1, 128)) = 64
        _SpecColor ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)

        //渐变色的颜色控制
        _GradualChangeColor("Gradual Change Color", Color) = (0.5, 0.5, 0.5, 1.0)

        //描边相关
        _OutlineWidth ("Outline Width", Range(0.01, 1)) = 0.24
        _OutlineLimit ("Outline Limit", Range(0.01, 1)) = 0.3
        _OutlineColor ("OutLine Color", Color) = (0.5,0.5,0.5,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma shader_feature _SHOW_ON

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 tangent_dir : TEXCOORD1;
                float3 binormal_dir : TEXCOORD2;
                float3 normal_dir : TEXCOORD3;
                float3 worldPos : TEXCOORD4; 
            };
            bool  _Show;

            sampler2D _ColorTex;
            float4 _ColorTex_ST;
            sampler2D _AMBTex;
            float4 _AMBTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            sampler2D _CTLTex;
            float4 _CTLTex_ST;
            sampler2D _HairPTex;
            float4 _HairPTex_ST;

            fixed4 _DiffuseColor;

            float _ShadowLimit;
            fixed4 _ShadowColor;

            float _SpecPow;
            fixed4 _SpecColor;

            fixed4 _GradualChangeColor;
            
            float4 _LightColor0;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _ColorTex);
                o.normal_dir = normalize(UnityObjectToWorldNormal(v.normal));
                o.tangent_dir = normalize(UnityObjectToWorldDir(v.tangent));
                o.binormal_dir = normalize(cross(o.normal_dir, o.tangent_dir)) * v.tangent.w;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #if !_SHOW_ON
                    clip(-1);
                #endif
                float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                fixed3 CTLMap = tex2D(_CTLTex, i.uv);
                fixed4 baseColor = pow(_DiffuseColor, 2.2);
                fixed4 ambColor = pow(_ShadowColor, 2.2);

                //直接光
                float3 tangent_dir = normalize(i.tangent_dir);
                float3 binormal_dir = normalize(i.binormal_dir);
                float3 normal_dir = normalize(i.normal_dir);
                half3 bump = UnpackNormal(tex2D(_NormalTex, i.uv));
                float3 normal = normalize(tangent_dir * bump.x + binormal_dir * bump.y + normal_dir * bump.z);
                float lambert = dot(normal, light_dir) * 0.5 + 0.5;
                float shadowMap = step(_ShadowLimit, lambert);
                float3 diffuse = (baseColor.rgb * shadowMap + ambColor * (1 - shadowMap)) * _LightColor0;

                //各项异性高光
                float3 halfDir = normalize(light_dir + view_dir);         
                float TdotH = dot(binormal_dir, halfDir);
                float hair_highLight = sqrt(1.0 - TdotH * TdotH);
                fixed3 highLight = CTLMap.r * pow(max(0.0, hair_highLight), _SpecPow) * _SpecColor.rgb;

                //头发的渐变（乱写的）
                float term = dot(view_dir, normal);
                float3 strangeColor = pow(tex2D(_HairPTex, float2(max(0.5 - term, lambert / 2.0), 0.5)), 2.2) * _GradualChangeColor;

                fixed4 col = pow(fixed4(diffuse + highLight + strangeColor , 1.0), 1.0 / 2.2);
                return col;
                //return fixed4(strangeColor, 1.0);
            }
            ENDCG
        }
        //描边Pass块
        Pass
        {
            Cull front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _SHOW_ON

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                fixed3 normal : NORMAL;//在顶点着色中我们需要将顶点外扩，因此需要获取法线信息
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };
            bool  _Show;

            float _OutlineWidth;
            float _OutlineLimit;
            fixed4 _OutlineColor;

            v2f vert (appdata v)
            {
               
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float3 pos = UnityObjectToViewPos(v.vertex);
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal); 
                pos += normal * _OutlineWidth * 0.1 * min(o.vertex.w, _OutlineLimit);
                o.vertex = mul(UNITY_MATRIX_P, fixed4(pos, 1.0));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #if !_SHOW_ON
                    clip(-1);
                #endif
                return _OutlineColor;
            }
            ENDCG
        }
    }
}
