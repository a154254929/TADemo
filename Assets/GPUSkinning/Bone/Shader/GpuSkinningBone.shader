Shader "Unlit/GpuSkinningBone"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AnimationTex("Texture", 2DArray) = ""{}                //动画贴图
        _Scale("Scale", Vector) = (1, 1, 1, 0)                  //x, y, z轴的缩放
        _AnimationSize("Animation Size", float) = 0             //动画长度
        _FPS("FPS", int) = 0                                    //FPS
        _BoneNum("Bone Num", Int) = 0                           //骨骼数
        _TextureSize("Texture Size", Vector) = (0, 0, 0, 0)     //动画贴图大小
        [IntRange]_Bone("Bone",Range(1,4)) = 1
        _NowFrame("Now Frame",Range(0,1)) = 0
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

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 bone1 : TEXCOORD1;
                float2 bone2 : TEXCOORD2;
                float2 bone3 : TEXCOORD3;
                float2 bone4 : TEXCOORD4;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            UNITY_DECLARE_TEX2DARRAY(_AnimationTex);
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Scale;
            float _AnimationSize;
            int _FPS;
            int _BoneNum;
            float4 _TextureSize;
            float _Bone;
            float _NowFrame;

            float4x4 getTransMat(int boneIndex)
            {
                int nowFrame = floor(_FPS * _AnimationSize * _NowFrame);
                int nowBone = nowFrame * _BoneNum + boneIndex;
                int nowBoneIndex = nowBone * 4;
                int nowBoneColumn0 = nowBoneIndex % _TextureSize.y;
                int nowBoneRow0 = floor(nowBoneIndex / _TextureSize.y);
                float u = nowBoneRow0 * 1.0f / _TextureSize.x;
                int nowBoneColumn1 = nowBoneColumn0 + 1;
                int nowBoneColumn2 = nowBoneColumn1 + 1;
                int nowBoneColumn3 = nowBoneColumn2 + 1;
                float4 row0 = UNITY_SAMPLE_TEX2DARRAY_LOD(_AnimationTex, float3(u, nowBoneColumn0 * 1.0f / _TextureSize.y, 0), 0);
                row0.xyz = row0.xyz * 2.0f - 1.0f;
                row0.w = (row0.w* 2.0f - 1.0f) * _Scale.x ;
                float4 row1 = UNITY_SAMPLE_TEX2DARRAY_LOD(_AnimationTex, float3(u, nowBoneColumn1 * 1.0f / _TextureSize.y, 0), 0);
                row1.xyz = row1.xyz * 2.0f - 1.0f;
                row1.w = (row1.w * 2.0f - 1.0f) * _Scale.y;
                float4 row2 = UNITY_SAMPLE_TEX2DARRAY_LOD(_AnimationTex, float3(u, nowBoneColumn2 * 1.0f / _TextureSize.y, 0), 0);
                row2.xyz = row2.xyz * 2.0f - 1.0f;
                row2.w = (row2.w * 2.0f - 1.0f) * _Scale.z;
                float4 row3 = UNITY_SAMPLE_TEX2DARRAY_LOD(_AnimationTex, float3(u, nowBoneColumn3 * 1.0f / _TextureSize.y, 0), 0);
                return float4x4(row0, row1, row2, row3);
                //return tex2Dlod(_AnimationTex, float4(nowBoneRow0 * 1.0f / _TextureSize.x, nowBoneColumn0 * 1.0f / _TextureSize.y, 0, 0));
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(
                    mul(getTransMat(v.bone1.x), v.vertex) * v.bone1.y + 
                    mul(getTransMat(v.bone2.x), v.vertex) * v.bone2.y + 
                    mul(getTransMat(v.bone3.x), v.vertex) * v.bone3.y + 
                    mul(getTransMat(v.bone4.x), v.vertex) * v.bone4.y 
                );
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}
