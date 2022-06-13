//����ϸ��Demo1
Shader "Unlit/TessShader"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _TopColor("Top Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BottomColor("Bottom Color", Color) = (1.0, 1.0, 1.0, 1.0)
        //�ݵ���б��
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
        //�ݵĿ��
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        //�ݵĸ߶�
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
            ////����2������ hull domain
            #pragma hull hullProgram
            #pragma domain ds
            //#pragma geometry geo
            #pragma vertex tessvert
            #pragma fragment frag

            #include "UnityCG.cginc"
            //��������ϸ�ֵ�ͷ�ļ�
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

            //������ɫ�����
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

            //�������α�����
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
            //�������Ӧ����domain�����У������ռ�ת���ĺ���
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

            //��ЩӲ����֧������ϸ����ɫ���������˸ú���ܹ��ڲ�֧�ֵ�Ӳ���ϲ����ۣ�Ҳ���ᱨ��
            #ifdef UNITY_CAN_COMPILE_TESSELLATION
                //������ɫ���ṹ�Ķ���
                struct TessVertex{
                    float4 vertex : INTERNALTESSPOS;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float2 uv : TEXCOORD0;
                };

                struct OutputPatchConstant { 
                    //��ͬ��ͼԪ���ýṹ��������ͬ
                    //�ò�������Hull Shader����
                    //������patch������
                    //Tessellation Factor��Inner Tessellation Factor
                    float edge[3] : SV_TESSFACTOR;
                    //float edge[2] : SV_TESSFACTOR;
                    float inside  : SV_INSIDETESSFACTOR;
                };

                TessVertex tessvert (VertexInput v){
                    //������ɫ������
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
                    //��������ϸ�ֵĲ���
                    OutputPatchConstant o;
                    o.edge[0] = _TessellationUniform;
                    o.edge[1] = _TessellationUniform;
                    o.edge[2] = _TessellationUniform;
                    o.inside  = _TessellationUniform;
                    return o;
                }

                [UNITY_domain("tri")]//ȷ��ͼԪ��quad,triangle,isoline��
                [UNITY_partitioning("integer")]//���edge�Ĺ���integer,pow2,fractional_odd,fractional_even
                [UNITY_outputtopology("triangle_cw")]// point,line,triangle_cw,triangle_ccw
                [UNITY_patchconstantfunc("hsconst")]//һ��patchһ���������㣬�����������㶼�����������
                [UNITY_outputcontrolpoints(3)]      //��ͬ��ͼԪ���Ӧ��ͬ�Ŀ��Ƶ�
              
                TessVertex hullProgram (InputPatch<TessVertex,3> patch,uint id : SV_OutputControlPointID){
                    //����hullshaderV����
                    return patch[id];
                }

                [UNITY_domain("tri")]//ͬ����Ҫ����ͼԪ
                VertexOutput ds (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3>patch,float3 bary :SV_DOMAINLOCATION)
                //bary:��������
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