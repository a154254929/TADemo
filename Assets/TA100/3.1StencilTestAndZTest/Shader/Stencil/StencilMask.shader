Shader "FX/StencilMask" {
	Properties{

		_ID("Mask ID", Int) = 1
	}
	SubShader{
            //�ڲ�͸���������Ⱦ
		Tags{ "RenderType" = "Opaque" "Queue" = "Geometry+1" }
		//Cull Off
		ColorMask 0 //��ɫ���֣�0����ʲô���������Ҳ����ѡ��RGBA,RGB,R,G,B,A
		ZWrite off	//	�ر����д��	
		Stencil{
				Ref[_ID]
				Comp always	//Ĭ��keep
				Pass replace //Ĭ��keep
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