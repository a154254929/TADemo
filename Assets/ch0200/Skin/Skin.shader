Shader "Unlit/Skin"
{
    Properties
    {
        [Toggle] _Show("Show", int) = 1
        _MainColor ("Main Color", 2D) = "white" {}
        _AmbTex ("Amb Texture", 2D) = "white" {}
        _NormalTex ("Normal Texture", 2D) = "white"{}
        _CTLTex ("CTL Texture", 2D) = "white"{}
        
        //阴影控制相关
        _ShadowLimit ("Shadow Limit", Range(0, 1.0)) = 0.5
        
        //边缘光相关
        _RimLimit ("Rim Limit", Range(0, 1.0)) = 0.05
        _RimColor ("Rim Color", Color) = (0.8, 0.8, 0.8, 1)

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
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            bool _Show;

            sampler2D _MainColor;
            float4 _MainColor_ST;
            sampler2D _AmbTex;
            float4 _AmbTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            sampler2D _CTLTex;
            float4 _CTLTex_ST;
            
            float _ShadowLimit;

            float _RimLimit;
            fixed4 _RimColor;
            
            float4 _LightColor0;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainColor);
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
                fixed4 baseColor = pow(tex2D(_MainColor, i.uv), 2.2);
                fixed4 ambColor = pow(tex2D(_AmbTex, i.uv), 2.2);
                
                //直接光
                float3 tangent_dir = normalize(i.tangent_dir);
                float3 binormal_dir = normalize(i.binormal_dir);
                float3 normal_dir = normalize(i.normal_dir);
                half3 bump = UnpackNormal(tex2D(_NormalTex, i.uv));
                float3 normal = normalize(tangent_dir * bump.x + binormal_dir * bump.y + normal_dir * bump.z);
                float lambert = dot(normal, light_dir) * 0.5 + 0.5;
                float shadowMap = step(_ShadowLimit, (lambert + CTLMap.b) * 0.5);
                
                //边缘光
                float RimPower = step(saturate(dot(view_dir, normal)), _RimLimit);
                fixed3 Rim = _RimColor.xyz * baseColor.rgb * RimPower * _LightColor0.rgb;

                float3 diffuse = (baseColor.rgb * shadowMap + ambColor * (1 - shadowMap)) * _LightColor0;
                // sample the texture
                fixed4 col = fixed4(pow(diffuse + Rim, 1.0 / 2.2), 1.0);
                return col;
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
