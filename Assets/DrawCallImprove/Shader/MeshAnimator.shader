Shader "Unlit/MeshAnimator"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ShadowTent ("ShadowTent", float) = 0.5
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

            #include "AutoLight.cginc"
            #include "UnityCG.cginc"

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
            float4 _MainTex_ST;
            UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float, _ShadowTent)
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                // sample the texture
                float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                float shaowTend = UNITY_ACCESS_INSTANCED_PROP(Props, _ShadowTent);
                float halfLambert = dot(i.normal, light_dir) * shaowTend + (1.0 - shaowTend);
                fixed4 col = fixed4(tex2D(_MainTex, i.uv).xyz * clamp(smoothstep(0.2, 0.4, halfLambert), 0.4, 1), 1.0);
                return col;
            }
            ENDCG
        }
    }
}
