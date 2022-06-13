Shader "Unlit/Line"
{
    Properties
    {
        [Toggle] _Show("Show", int) = 1
        [HDR]_MainColor ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };
            bool  _Show;

            fixed4 _MainColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #if !_SHOW_ON
                    clip(-1);
                #endif
                return _MainColor;
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
