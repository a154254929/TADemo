//曲面细分Demo1
Shader "Unlit/TessShader"
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

        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            ////定义2个函数 hull domain
            #pragma hull hullProgram
            #pragma domain ds
            //#pragma geometry geo
            #pragma vertex tessvert
            #pragma fragment frag

            #include "UnityCG.cginc"
            //引入曲面细分的头文件
            #include "Tessellation.cginc" 

            
            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            //几何着色器输出
            struct geometryOutput
            {
	            float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            geometryOutput vertexOutput(float3 pos, float2 uv)
            {
	            geometryOutput o;
	            o.pos = UnityObjectToClipPos(pos);
                o.uv = uv;
	            return o;
            }

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

            VertexOutput vert (VertexInput v)
            //这个函数应用在domain函数中，用来空间转换的函数
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.tangent = v.tangent;
                o.normal = v.normal;
                return o;
            }
            half4 _TopColor;
            half4 _BottomColor;

            float _BendRotationRandom;

            float _BladeHeight;
            float _BladeHeightRandom;	
            float _BladeWidth;
            float _BladeWidthRandom;

            //有些硬件不支持曲面细分着色器，定义了该宏就能够在不支持的硬件上不会变粉，也不会报错
            #ifdef UNITY_CAN_COMPILE_TESSELLATION
                //顶点着色器结构的定义
                struct TessVertex{
                    float4 vertex : INTERNALTESSPOS;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float2 uv : TEXCOORD0;
                };

                struct OutputPatchConstant { 
                    //不同的图元，该结构会有所不同
                    //该部分用于Hull Shader里面
                    //定义了patch的属性
                    //Tessellation Factor和Inner Tessellation Factor
                    float edge[3] : SV_TESSFACTOR;
                    //float edge[2] : SV_TESSFACTOR;
                    float inside  : SV_INSIDETESSFACTOR;
                };

                TessVertex tessvert (VertexInput v){
                    //顶点着色器函数
                    TessVertex o;
                    o.vertex  = v.vertex;
                    o.normal  = v.normal;
                    o.tangent = v.tangent;
                    o.uv      = v.uv;
                    return o;
                }

                float _TessellationUniform;

                sampler2D _MainTex;
                float4 _MainTex_ST;
                OutputPatchConstant hsconst (InputPatch<TessVertex,3> patch){
                    //定义曲面细分的参数
                    OutputPatchConstant o;
                    o.edge[0] = _TessellationUniform;
                    o.edge[1] = _TessellationUniform;
                    o.edge[2] = _TessellationUniform;
                    o.inside  = _TessellationUniform;
                    return o;
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
                VertexOutput ds (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3>patch,float3 bary :SV_DOMAINLOCATION)
                //bary:重心坐标
                {
                    VertexInput v;
                    v.vertex = patch[0].vertex*bary.x + patch[1].vertex*bary.y + patch[2].vertex*bary.z;
			        v.tangent = patch[0].tangent*bary.x + patch[1].tangent*bary.y + patch[2].tangent*bary.z;
			        v.normal = patch[0].normal*bary.x + patch[1].normal*bary.y + patch[2].normal*bary.z;
			        v.uv = patch[0].uv*bary.x + patch[1].uv*bary.y + patch[2].uv*bary.z;

                    VertexOutput o = vert (v);
                    return o;
                    return v;
                }
            #endif

            [maxvertexcount(3)]
            void geo(triangle VertexInput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
            {
                float3 pos = IN[0].vertex;
                float2 uv = IN[0].uv;
                float3 tangent = normalize(IN[0].tangent.xyz);
                float3 normal = normalize(IN[0].normal);
                float3 binormal = normalize(cross(normal, tangent)) * IN[0].tangent.w;

                float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
                float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
            
                float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
                float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));
                float3x3 TBNMatrix = float3x3(
	                tangent.x, binormal.x, normal.x,
	                tangent.y, binormal.y, normal.y,
	                tangent.z, binormal.z, normal.z
	            );
                float3x3 transformationMatrix = mul(mul(TBNMatrix, facingRotationMatrix), bendRotationMatrix);

                float3 vertexOffset = float3(width, 0, 0);
                triStream.Append(vertexOutput(pos + mul(transformationMatrix, vertexOffset), float2(0, 0)));
                vertexOffset = float3(-width, 0, 0);
                triStream.Append(vertexOutput(pos + mul(transformationMatrix, vertexOffset), float2(1, 0)));
                vertexOffset = float3(0, 0, height);
                triStream.Append(vertexOutput(pos + mul(transformationMatrix, vertexOffset), float2(0.5, 1)));
            }

            float4 frag (geometryOutput i) : SV_Target
            {
                return fixed4(1, 1, 1, 1);
                //return lerp(_BottomColor, _TopColor, i.uv.y);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}