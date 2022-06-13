Shader "Unlit/ZprePass"
{
    Properties
    {
        _BasicColor("Basic Color", Color) = (1.0, 1.0, 1.0, 1.0)

        _CameraDistance("Camera Distance", float) = 0.5
        _TransparentPower("Transparent Power", range(1, 16)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        pass
        {
            Cull Off
            ZTest LEqual
            ZWrite On
            ColorMask 0
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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(0, 0, 0, 0);
            }
            ENDCG
        }
        Pass
        {
            blend SrcAlpha OneMinusSrcAlpha
            Cull Front
            ZTest Equal
            ZWrite off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)

            };

            fixed4 _BasicColor;
            float _CameraDistance;
            float _TransparentPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 lightDir = normalize(_WorldSpaceLightPos0);
                float3 worldNormal = normalize(i.normal);
                float3 cameraPos = _WorldSpaceCameraPos.xyz - i.worldPos;

                float distance = saturate(sqrt(cameraPos.x * cameraPos.x + cameraPos.y * cameraPos.y + cameraPos.z * cameraPos.z) / max(_CameraDistance, 0.01));

                //float lambert = saturate(dot(worldNormal, lightDir)) * SHADOW_ATTENUATION(i);
                float lambert = (dot(worldNormal, lightDir) * 0.5 + 0.5) * SHADOW_ATTENUATION(i);

                return fixed4(_BasicColor.rgb * lambert, pow(distance, _TransparentPower));
            }
            ENDCG
        }
        Pass
        {
            blend SrcAlpha OneMinusSrcAlpha
            ZTest Equal
            ZWrite off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)

            };

            fixed4 _BasicColor;
            float _CameraDistance;
            float _TransparentPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 lightDir = normalize(_WorldSpaceLightPos0);
                float3 worldNormal = normalize(i.normal);
                float3 cameraPos = _WorldSpaceCameraPos.xyz - i.worldPos;

                float distance = saturate(sqrt(cameraPos.x * cameraPos.x + cameraPos.y * cameraPos.y + cameraPos.z * cameraPos.z) / max(_CameraDistance, 0.01));

                //float lambert = saturate(dot(worldNormal, lightDir)) * SHADOW_ATTENUATION(i);
                float lambert = (dot(worldNormal, lightDir) * 0.5 + 0.5) * SHADOW_ATTENUATION(i);

                return fixed4(_BasicColor.rgb * lambert, pow(distance, _TransparentPower));
            }
            ENDCG
        }
    }
}
