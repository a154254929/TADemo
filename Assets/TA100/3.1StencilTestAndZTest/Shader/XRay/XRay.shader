Shader "Unlit/XRay"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        CGINCLUDE   //先写好CGINCLUDE 方便多PASS的使用
        #include "UnityCG.cginc"
        fixed4 _Color;
        struct v2f{
            float3 normal : NORMAL;
            float3 viewDir : TEXCOORD0;
            fixed4 clr  : COLOR;
            float4 pos : SV_POSITION;
        };
        v2f vertXray(appdata_base v) {
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.viewDir = ObjSpaceViewDir(v.vertex);  //在模型空间上计算夹角
            o.normal = v.normal;
            float3 normal = normalize(v.normal);
            float3 viewDir = normalize(o.viewDir);
            float NdotV = dot(normal, viewDir);
            float rim = 1 - abs(NdotV);
            o.clr = _Color * rim; 
            return o;
        }
        fixed4 fragXray(v2f i) : SV_TARGET {
            return i.clr;      
        }
        sampler2D _MainTex;
        float4 _MainTex_ST;
        struct v2f2 {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;     
        };
        v2f2 vertNormal(appdata_base v) {
            v2f2 o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
            return o;
        }
        fixed4 fragNormal(v2f2 i) :SV_TARGET {
            return tex2D(_MainTex, i.uv);
        }
        
        
        ENDCG
        //XRay
        //Pass{
        //    ZWrite On
        //    ColorMask 0
        //    Ztest Always
        //}
        Pass {
            Tags {"RenderType" ="Transparent" "Queue" = "Transparent"}
            Blend SrcAlpha One           
            ZTest Greater
            ZWrite Off
            CGPROGRAM
            #pragma vertex vertXray
            #pragma fragment fragXray
            ENDCG
        }
        Pass {
            Tags {"RenderType" ="Opaque"}
            ZTest LEqual
            ZWrite On
            CGPROGRAM
            
            #pragma vertex vertNormal
            #pragma fragment fragNormal
            ENDCG     
        }
    }
}
