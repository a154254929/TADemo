Shader "Unlit/SSAO"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
    #include "UnityCG.cginc"

    struct v2fSSAO
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float4 screenPos : TEXCOORD1;
        float3 viewVec : TEXCOORD2;
    };
	#define MAX_SAMPLE_KERNEL_COUNT 64

	int _Num;

    sampler2D _MainTex;
    sampler2D _CameraDepthNormalsTexture;
	sampler2D _NoiseTex;
	float4 _SampleKernelArray[MAX_SAMPLE_KERNEL_COUNT];
	float _SampleKernelCount;
	float _SampleKeneralRadius;
	float _DepthBiasValue;
	float _RangeStrength;
	float _AOStrength;

    v2fSSAO vertSSAO (appdata_img v)
    {
        v2fSSAO o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;
        o.screenPos = ComputeScreenPos(o.vertex);
                
        float4 ndcPos = (o.screenPos / o.screenPos.w) * 2 - 1;
        float far = _ProjectionParams.z;
        float3 clipVec = float3(ndcPos.x, ndcPos.y, 1.0) * far;
        o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz;

        return o;
    }

    fixed4 fragSSAO (v2fSSAO i) : SV_Target
    {
		//return fixed4(1.0, 1.0, 1.0, 1.0) * _RangeStrength; 
        fixed4 col = tex2D(_MainTex, i.uv);
        float3 viewNormal;
        float liner01Depth;
        float4 depthNormal = tex2Dproj(_CameraDepthNormalsTexture, i.screenPos);
        DecodeDepthNormal(depthNormal, liner01Depth, viewNormal);

		
        float3 viewPos = i.viewVec * liner01Depth;
        float3 worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
        viewNormal = normalize(viewNormal) * float3(1, 1, -1);

		float2 noiseScale = _ScreenParams.xy / 4.0;
		float2 noiseUV = i.uv * noiseScale;
		//randvec法线半球的随机向量
		float3 randVec = tex2D(_NoiseTex, noiseUV).xyz;

        //float3 randVec = normalize(float3(1, 1, 1));
        float3 tangent = normalize(randVec - viewNormal * dot(randVec, viewNormal));
        float3 binormal = cross(viewNormal, tangent);
        float3x3 TBN = float3x3(tangent, binormal, viewNormal); 
		//采样核心
		float ao = 0;
		int sampleCount = _SampleKernelCount;//每个像素点上的采样次数
		//https://blog.csdn.net/qq_39300235/article/details/102460405
		for(int i=0;i<sampleCount;i++){
			//随机向量，转化至法线切线空间中
			float3 randomVec = mul(_SampleKernelArray[i].xyz,TBN);
			
			//ao权重
			//float weight = smoothstep(0,0.2,length(randomVec.xy));
			
			//计算随机法线半球后的向量
			float3 randomPos = viewPos + randomVec * _SampleKeneralRadius;
			//转换到屏幕坐标
			float3 rclipPos = mul((float3x3)unity_CameraProjection, randomPos);
			float2 rscreenPos = (rclipPos.xy / rclipPos.z) * 0.5 + 0.5;

			float randomDepth;
			float3 randomNormal;
			float4 rcdn = tex2D(_CameraDepthNormalsTexture, rscreenPos);
			DecodeDepthNormal(rcdn, randomDepth, randomNormal);
			
			//判断累加ao值
			float range = smoothstep(0.0, 1.0, _SampleKeneralRadius / abs(randomDepth - liner01Depth));//randomDepth - liner01Depth > _RangeStrength ? 0.0 : 1.0;
			float selfCheck = (randomDepth + _DepthBiasValue) < liner01Depth ? 1.0 : 0.0;

			//采样点的深度值和样本深度比对前后关系
			ao += range * selfCheck;// * weight;
			//ao += range * weight;
		}
		ao = ao/sampleCount;
		ao = max(0.0, 1 - ao * _AOStrength);

		return float4(ao,ao,ao,1);

    }
	
	//Blur
	float _BilaterFilterFactor;
	float2 _MainTex_TexelSize;
	float2 _BlurRadius;

	float3 GetNormal(float2 uv)
	{
		float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);	
		return DecodeViewNormalStereo(cdn);
	}

	half CompareNormal(float3 nor1,float3 nor2)
	{
		return smoothstep(_BilaterFilterFactor,1.0,dot(nor1,nor2));
	}

    fixed4 fragBlur (v2fSSAO i) : SV_Target
	{
		//_MainTex_TexelSize -> https://forum.unity.com/threads/_maintex_texelsize-whats-the-meaning.110278/
		float2 delta = _MainTex_TexelSize.xy * _BlurRadius.xy;
		
		float2 uv = i.uv;
		float2 uv0a = i.uv - delta;
		float2 uv0b = i.uv + delta;	
		float2 uv1a = i.uv - 2.0 * delta;
		float2 uv1b = i.uv + 2.0 * delta;
		float2 uv2a = i.uv - 3.0 * delta;
		float2 uv2b = i.uv + 3.0 * delta;
		
		float3 normal = GetNormal(uv);
		float3 normal0a = GetNormal(uv0a);
		float3 normal0b = GetNormal(uv0b);
		float3 normal1a = GetNormal(uv1a);
		float3 normal1b = GetNormal(uv1b);
		float3 normal2a = GetNormal(uv2a);
		float3 normal2b = GetNormal(uv2b);
		
		fixed4 col = tex2D(_MainTex, uv);
		fixed4 col0a = tex2D(_MainTex, uv0a);
		fixed4 col0b = tex2D(_MainTex, uv0b);
		fixed4 col1a = tex2D(_MainTex, uv1a);
		fixed4 col1b = tex2D(_MainTex, uv1b);
		fixed4 col2a = tex2D(_MainTex, uv2a);
		fixed4 col2b = tex2D(_MainTex, uv2b);
		
		half w = 0.37004405286;
		half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
		half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		half w2b = CompareNormal(normal, normal2b) * 0.11453744493;
		
		half3 result;
		result = w * col.rgb;
		result += w0a * col0a.rgb;
		result += w0b * col0b.rgb;
		result += w1a * col1a.rgb;
		result += w1b * col1b.rgb;
		result += w2a * col2a.rgb;
		result += w2b * col2b.rgb;
		
		result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		return fixed4(result, 1.0);
	}
	
	sampler2D _AOTex;

	fixed4 fragComposite(v2fSSAO i) : SV_Target
	{
		fixed4 col = tex2D(_MainTex, i.uv);
		fixed4 ao = tex2D(_AOTex, i.uv);
		col.rgb *= ao.r;
		return col;
	}

    ENDCG
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        

        Pass
        {
            CGPROGRAM
            #pragma vertex vertSSAO
            #pragma fragment fragSSAO
            ENDCG
        }

		pass{
            CGPROGRAM
            #pragma vertex vertSSAO
            #pragma fragment fragBlur
            ENDCG
		
		}

		pass{
            CGPROGRAM
            #pragma vertex vertSSAO
            #pragma fragment fragComposite
            ENDCG
		}


    }
}
