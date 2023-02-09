Shader "Unlit/GpuInstancing"
{
    Properties
    {
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
        _MainTex ("Texture", 2D) = "white" {}
		_Ramp ("Toon Ramp (RGB)", 2D) = "gray" {} 
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
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            
            sampler2D _MainTex;
            sampler2D _Ramp;

            UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                float3 lighrDir = normalize(_WorldSpaceLightPos0);
                float3 noraml = normalize(i.normal);
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 setColor = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                float halfLambert = dot(lighrDir, noraml) * 0.5 + 0.5;
                fixed4 result = fixed4(setColor.rgb *  tex2D(_Ramp, float2(halfLambert, halfLambert)).rgb * col.rgb, setColor.a) * 2;
                return result;
            }
            ENDCG
        }
    }
}
