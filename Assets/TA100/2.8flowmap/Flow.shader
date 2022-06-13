Shader "Unlit/Flow"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        _FlowMap("Flow Map", 2D) = "White" {}

        _FlowSpeed("Flow Speed", range(0, 10.0)) = 1
        _TimeSpeed("Time Speed", range(0, 10.0)) = 1

        [Toggle]_reverse_flow("Reverse Flow",int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma shader_feature _REVERSE_FLOW_ON

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
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _FlowMap;
            //float4 _FlowMap_ST;

            float _FlowSpeed;
            float _TimeSpeed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                // sample the texture
                //float3 flowDir = (tex2D(_FlowMap, i.uv) * 2.0 - 1.0) * _FlowSpeed;
                float3 flowDir = (tex2D(_FlowMap, float2(i.uv.x, 1.0 - i.uv.y)) * 2.0 - 1.0) * _FlowSpeed;
                flowDir.y *= -1.0;

                #ifdef _REVERSE_FLOW_ON
                    flowDir *= -1;
                #endif

                float phase0 = frac(_Time.y * 0.1 * _TimeSpeed);
                float phase1 = frac(_Time.y * 0.1 * _TimeSpeed + 0.5);
                float flowLerp = abs((0.5 - phase0) / 0.5);

                fixed3 col0 = tex2D(_MainTex, i.uv - flowDir.xy * phase0);
                fixed3 col1 = tex2D(_MainTex, i.uv - flowDir.xy * phase1);

                fixed4 col = fixed4(lerp(col0, col1, flowLerp), 1.0);
                //fixed4 col = fixed4(tex2D(_FlowMap, i.uv).rgb, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
