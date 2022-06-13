Shader "Unlit/MetalMetarilWithBrdf"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
        _IndirectDiffuseValue("IndirectAiffuseValue",float)=0.5
        _IndirectSpecularValue("IndirectSpecularValue",float) = 0.5
    }
 
        SubShader
    {
        Tags{ "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        LOD 100
        Pass
 
    {
        CGPROGRAM
       #pragma vertex vert
       #pragma fragment frag
       #include "UnityCG.cginc"
       #include "Lighting.cginc"
 
       sampler2D _MainTex;
       half _Glossiness;
       half _Metallic;
       fixed4 _Color;
       float _IndirectDiffuseValue;
       float _IndirectSpecularValue;       
 
    struct OutPut
    {
        fixed3 Albedo;      
        fixed3 Normal;      
        half3 Emission;
        half Metallic;                                                          
        half Smoothness;    
        half Occlusion;     
        fixed Alpha;   
        half3 viewDir;
        fixed3 lightDir;
 
    };
    half DisneyDiffuse_Custom(half NdotV, half NdotL, half LdotH, half perceptualRoughness)
    {
        half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
        half lightScatter = (1 + (fd90 - 1) * Pow5(1 - NdotL));
        half viewScatter = (1 + (fd90 - 1) * Pow5(1 - NdotV));
        return lightScatter * viewScatter;
    }
    inline half SmithJointGGXVisibilityTerm_Custom(half NdotL, half NdotV, half roughness)
    {
#if 0    //原版(理论基础)
        // Original formulation:
        //  lambda_v    = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
        //  lambda_l    = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
        //  G           = 1 / (1 + lambda_v + lambda_l);
        //return (2.0f * NdotL * NdotV) / ((4.0f * NdotL * NdotV) * (lambda_v + lambda_l + 1e-5f));
        //这里计算了Cook-Torrance的微表面高光BRDF公式的G项和4(nl)(nv)(分母项),还剩D项和F项
        half a = roughness;
        half a2 = a * a;
        half lambdaV = NdotL * sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
        half lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);
        return 0.5f / (lambdaV + lambdaL + 1e-5f);  
#else    //简版(实际使用)
        half a = roughness;
        half lambdaV = NdotL * (NdotV * (1 - a) + a);
        half lambdaL = NdotV * (NdotL * (1 - a) + a);
 
        return 0.5f / (lambdaV + lambdaL + 1e-5f);
#endif
    }
    inline half GGXTerm_Custom(half NdotH, half roughness)//这里计算D项   D=α²/(π((N·M)²(α²-1)+1)²)
    {
        half a2 = roughness * roughness;
        half d = (NdotH * a2 - NdotH) * NdotH + 1.0f;
        return UNITY_INV_PI * a2 / (d * d + 1e-7f); 
                                                    
    }
    inline half3 FresnelTerm_Custom(half3 F0, half cosA)//这里计算F项 菲涅耳 Schlick公式: Fschlick(v,h)=cspec+(1−cspec)(1−(v⋅h))5
    {
        half t = Pow5(1 - cosA);   
        return F0 + (1 - F0) * t;
    }
    inline half3 FresnelLerp_Custom(half3 F0, half3 F90, half cosA)
    {
        half t = Pow5(1 - cosA);   
        return lerp(F0, F90, t);
    }
    half4 BRDF_Unity_PBS_Custom(OutPut s, half3 specColor, half oneMinusReflectivity)
    {
        half perceptualRoughness = 1-s.Smoothness;  //preroughness
        half3 halfDir = Unity_SafeNormalize(s.lightDir + s.viewDir);
        half nv = abs(dot(s.Normal, s.viewDir));                
        half nl = saturate(dot(s.Normal, s.lightDir));
        half nh = saturate(dot(s.Normal, halfDir));
        half lv = saturate(dot(s.lightDir, s.viewDir));
        half lh = saturate(dot(s.lightDir, halfDir));
        half diffuseTerm = DisneyDiffuse_Custom(nv, nl, lh, perceptualRoughness) * nl;  //漫反射部分D
        half roughness = perceptualRoughness*perceptualRoughness;// preroughness²
 
        //---------Cook-Torrance BRDF公式:  f(l,v)=D(h)F(v,h)G(l,v,h)/(4(n⋅l)(n⋅v))
        half V = SmithJointGGXVisibilityTerm_Custom(nl, nv, roughness);
        half D = GGXTerm_Custom(nh, roughness);
        half specularTerm = V*D * UNITY_PI; 
        specularTerm = max(0, specularTerm * nl);   //Torrance-Sparrow model，高光部分G
 
        half3 F = FresnelTerm_Custom(specColor, lh);//菲涅耳F
                
        //各部分权重和融合计算
        half surfaceReduction = 1.0 / (roughness*roughness + 1.0);
        specularTerm *= any(specColor) ? 1.0 : 0.0;
        half grazingTerm = saturate(s.Smoothness + (1 - oneMinusReflectivity));
        half3 Fidentity = FresnelLerp_Custom(specColor, grazingTerm, nv);
        half3 color = s.Albedo * (_IndirectDiffuseValue + _LightColor0.rgb * diffuseTerm)+ specularTerm *  _LightColor0.rgb * F+ surfaceReduction *_IndirectSpecularValue *Fidentity;
        return half4(color, 1);
    }
 
    inline half4 LightingStandard_Custom(OutPut s)
    {
        s.Normal = normalize(s.Normal);    
        half3 specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic);//金属颜色差值
        half oneMinusReflectivity=unity_ColorSpaceDielectricSpec.a*(1 - s.Metallic);  //unity_ColorSpaceDielectricSpec定义在UnityCG.cginc中
        s.Albedo = s.Albedo*oneMinusReflectivity;
        half4 c = BRDF_Unity_PBS_Custom(s, specColor, oneMinusReflectivity);
        return c;
    }
    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 worldNormal : TEXCOORD1;
        float3 worldPos : TEXCOORD2;
        float2 uv:TEXCOORD0;
    };
    v2f vert(appdata_full v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        o.worldNormal = UnityObjectToWorldNormal(v.normal);
        o.uv = v.texcoord;
        return o;
    }
 
    fixed4 frag(v2f i) : SV_Target
    {
        fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
        fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
        //-------配置OutPut结构体
        OutPut o;
        fixed4 col = tex2D(_MainTex, i.uv)*_Color;
        o.Albedo = col.rgb;
        o.Metallic = _Metallic;
        o.Smoothness = _Glossiness;
        o.Normal = i.worldNormal;
        o.viewDir = worldViewDir;
        o.lightDir = lightDir;
        fixed4 c=0;
        c+= LightingStandard_Custom(o);
        return c;
    }
        ENDCG
    }
    }
    FallBack"Diffuse"
}
