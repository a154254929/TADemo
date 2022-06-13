Shader "FX/StencilMask" {
	Properties{

		_ID("Mask ID", Int) = 1
	}
	SubShader{
            //在不透明物体后渲染
		Tags{ "RenderType" = "Opaque" "Queue" = "Geometry+1" }
		//Cull Off
		ColorMask 0 //颜色遮罩，0就是什么都不输出，也可以选择：RGBA,RGB,R,G,B,A
		ZWrite off	//	关闭深度写入	
		Stencil{
				Ref[_ID]
				Comp always	//默认keep
				Pass replace //默认keep
               	//Fail keep
                //ZFail keep
		}
		Pass{
			CGINCLUDE
			struct appdata {
				float4 vertex : POSITION;
			};
			struct v2f {
				float4 pos : SV_POSITION;
			};

	
			v2f vert(appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}
			half4 frag(v2f i) : SV_Target{
				return half4(1,1,1,1);
			}
			ENDCG
		}
	}
}