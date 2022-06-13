// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Grass"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _TopColor("Top Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BottomColor("Bottom Color", Color) = (1.0, 1.0, 1.0, 1.0)
        //草的倾斜度
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        //草的宽度
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        //草的高度
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightRandom("Blade Height Random", Float) = 0.3

        //细分着色器细分次数
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1

        //风(扰动贴图)
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength("Wind Strength", Float) = 1

        _BladeForward("Blade Forward Amount", Float) = 0.38
        _BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        CGINCLUDE
        
        #pragma multi_compile_fwdbase
        #define BLADE_SEGMENTS 3

        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        #include "Tessellation.cginc"

        //顶点着色器输入
        struct vertexInput
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };

        //顶点输出
        struct vertexOutput
        {
            float4 vertex : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };

        //细分着色器输入
        struct TessVertex{
            float4 vertex : INTERNALTESSPOS;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };

        //细分着色器Patch
        struct OutputPatchConstant { 
            float edge[3] : SV_TESSFACTOR;
            float inside  : SV_INSIDETESSFACTOR;
        };

        //几何着色器输出
        struct geometryOutput
        {
	        float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 worldPos : TEXCOORD1;
            float3 normal :NORMAL;
            //unityShadowCoord4 _ShadowCoord : TEXCOORD1;
            SHADOW_COORDS(2)
        };

        //随机数（伪随机）
        float rand(float3 seed)
        {
            return frac(sin(dot(seed.xyz, float3(12.9899, 78.233, 53.539))) * 43758.5453);
        }

        float3x3 AngleAxis3x3(float angle, float3 axis)
        {
            float c, s;
            sincos(angle, s, c);

            float t = 1.0 - c;
            float x = axis.x;
            float y = axis.y;
            float z = axis.z;

            return float3x3(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c
            );
        }

        //sampler2D _MainTex;
        //float4 _MainTex_ST;
        half4 _TopColor;
        half4 _BottomColor;

        float _BendRotationRandom;

        float _BladeHeight;
        float _BladeHeightRandom;	
        float _BladeWidth;
        float _BladeWidthRandom;
        
        float _TessellationUniform;
        
        sampler2D _WindDistortionMap;
        float4 _WindDistortionMap_ST;
        float2 _WindFrequency;
        float _WindStrength;
        
        float _BladeForward;
        float _BladeCurve;

        TessVertex vert (vertexInput v)
        {
            TessVertex o;
            //o.vertex = UnityObjectToClipPos(v.vertex);
            o.vertex = v.vertex;
            o.uv = v.uv;
            o.normal = v.normal;
            o.tangent = v.tangent;
            return o;
        }
        
        OutputPatchConstant hsconst (InputPatch<TessVertex,3> patch){
            //定义曲面细分的参数
            OutputPatchConstant o;
            o.edge[0] = _TessellationUniform;
            o.edge[1] = _TessellationUniform;
            o.edge[2] = _TessellationUniform;
            o.inside  = _TessellationUniform;
            return o;
        }

        geometryOutput VertexOutput(float3 pos, float2 uv, float3 normal)
        {
	        geometryOutput o;
	        o.pos = UnityObjectToClipPos(pos);
            o.uv = uv;
            o.worldPos = mul(unity_ObjectToWorld, pos);
            o.normal = UnityObjectToWorldNormal(normal);
            TRANSFER_SHADOW(o);
            //o._ShadowCoord = ComputeScreenPos(o.pos);
	        return o;
        }

	    geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv, float3x3 transformMatrix)
	    {
		    float3 tangentPoint = float3(width, forward, height);

            float3 tangentNormal = float3(0, -1, forward);
            float3 localNormal = mul(transformMatrix, tangentNormal);

		    float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
		    return VertexOutput(localPosition, uv, localNormal);
	    }

        [UNITY_domain("tri")]//确定图元，quad,triangle,isoline等
        [UNITY_partitioning("integer")]//拆分edge的规则，integer,pow2,fractional_odd,fractional_even
        [UNITY_outputtopology("triangle_cw")]// point,line,triangle_cw,triangle_ccw
        [UNITY_patchconstantfunc("hsconst")]//一个patch一共有三个点，但是这三个点都共用这个函数
        [UNITY_outputcontrolpoints(3)]      //不同的图元会对应不同的控制点
              
        TessVertex hullProgram (InputPatch<TessVertex,3> patch,uint id : SV_OutputControlPointID){
            //定义hullshaderV函数
            return patch[id];
        }

        [UNITY_domain("tri")]//同样需要定义图元
        vertexInput ds (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3>patch,float3 bary :SV_DOMAINLOCATION)
        //bary:重心坐标
        {
            vertexInput v;
            v.vertex = patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z;
            //v.vertex = UnityObjectToClipPos(patch[0].vertex * bary.x + patch[1].vertex * bary.y + patch[2].vertex * bary.z);
			v.tangent = patch[0].tangent*bary.x + patch[1].tangent * bary.y + patch[2].tangent*bary.z;
			v.normal = patch[0].normal * bary.x + patch[1].normal * bary.y + patch[2].normal * bary.z;
			v.uv = patch[0].uv*bary.x + patch[1].uv*bary.y + patch[2].uv*bary.z;

            //vertexOutput o = vert (v);
            return v;
        }


        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geo(triangle vertexInput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
        {
            float3 pos = IN[0].vertex;
            float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
		    float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
		    float3 wind = normalize(float3(windSample.x, windSample.y, 0));//Wind Vector
            float3 tangent = normalize(IN[0].tangent.xyz);
            float3 normal = normalize(IN[0].normal);
            float3 binormal = normalize(cross(normal, tangent)) * IN[0].tangent.w;

            float height = rand(pos.zyx) * _BladeHeightRandom + _BladeHeight;
            float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
            
            float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
            float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));
            float3x3 TBNMatrix = float3x3(
	            tangent.x, binormal.x, normal.x,
	            tangent.y, binormal.y, normal.y,
	            tangent.z, binormal.z, normal.z
	        );
		    float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);
            float3x3 randomRotationMatrix = mul(TBNMatrix, facingRotationMatrix);
            float3x3 transformationMatrix = mul(mul(mul(TBNMatrix, facingRotationMatrix), bendRotationMatrix), windRotation);
            
            float forward = rand(pos.xyz) * _BladeForward;
            for (int i = 0; i < BLADE_SEGMENTS; i++)
            {
	            float t = i / (float)BLADE_SEGMENTS;
                float segmentHeight = height * t;
	            float segmentWidth = width * (1 - t);

                float segmentForward = pow(t, _BladeCurve) * forward;

                triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), i == 0 ? randomRotationMatrix : transformationMatrix));
                triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), i == 0 ? randomRotationMatrix : transformationMatrix));
            }
            triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));
        }

        half4 frag (geometryOutput i, float facing : VFACE) : SV_Target
        {
            UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
            float3 lightDir = _WorldSpaceLightPos0 - i.worldPos;
            float3 normal = facing > 0 ? i.normal : -i.normal;

            float lambert = lerp(0.6, 1, saturate(dot(i.normal, lightDir)));
            return lerp(_BottomColor, _TopColor, i.uv.y * atten * lambert);
            //return SHADOW_ATTENUATION(i);
            //return atten;
        }

        ENDCG

        Pass
        {
            Tags{"LightMode" = "ForwardBase"}
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain ds
            #pragma geometry geo
            #pragma fragment frag
            ENDCG
        }
        Pass{
            Tags{"LightMode" = "ShadowCaster"}
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hullProgram
            #pragma domain ds
            #pragma geometry geo
            #pragma fragment tmpfrag
            
            half4 tmpfrag (geometryOutput i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                SHADOW_CASTER_FRAGMENT(i)
                //return half4(1, 1, 1, 1);
            }
            ENDCG
        
        }
    }
    Fallback "Diffuse"
}
