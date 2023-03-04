// Upgrade NOTE: replaced 'glstate_matrix_projection' with 'UNITY_MATRIX_P'

Shader "Unlit/Sequence_BuildIn"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("DstFactor",int) = 0
        _Color ("BaseColor", color) = (1, 1, 1, 1)
        [NoScaleOffset]_MainTex ("Texture", 2D) = "white" {}
        _Param ("Column(X) Row(Y) FPS(Z)", vector) = (4, 3, 30, 0)
    }
    SubShader
    {
        Blend [_SrcFactor] [_DstFactor]
        Tags { 
            "RenderType"="Transparent" 
            "Queue" = "Transparent"
        }
        LOD 100

        Pass
        {
            Cull off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float test : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Param;
            half4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                float3 cameraVector = normalize(mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)));
                float3 yVector = float3(0, 1, 0);
                float3 xVector = normalize(cross(cameraVector, yVector));
                yVector = cross(xVector, cameraVector);
                float4x4 objectMatrix = float4x4(
                    xVector.x, yVector.x, cameraVector.x, 0,
                    xVector.y, yVector.y, cameraVector.y, 0,
                    xVector.z, yVector.z, cameraVector.z, 0,
                    0, 0, 0, 1
                );
                o.vertex = mul(objectMatrix, v.vertex);
                o.vertex = mul(unity_ObjectToWorld, o.vertex);
                o.vertex = mul(unity_MatrixV, o.vertex);
                o.vertex = mul(UNITY_MATRIX_P, o.vertex);

                int frame = floor(_Time.y * _Param.z);
                float row = floor(frame / _Param.x) / _Param.y;
                float column = (frame % _Param.x) / _Param.x;
                o.uv = v.uv / _Param.xy + float2(column, row);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                half4 col = tex2D(_MainTex, i.uv) * _Color;
                col.rgb *= col.a;
                return col;
                //return i.test;
            }
            ENDCG
        }
    }
}
