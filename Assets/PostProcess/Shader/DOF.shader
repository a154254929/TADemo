Shader "Unlit/DOF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        CGINCLUDE
        #include "UnityCG.cginc"
        
        sampler2D _MainTex;
        float4 _MainTex_TexelSize;
        sampler2D _CameraDepthTexture;
        sampler2D _COCTexture;
        sampler2D _DOFTexture;
        float _FocusDistance;
        float _FocusRange;
        float _BokehRadius;

        float _power;

        struct v2fDepth{
            float4 pos : SV_POSITION;
            float4 screenPos : TEXCOORD0;
            float2 uv : TEXCOORD1;
        };

        v2fDepth vertDepth(appdata_img v)
        {
            v2fDepth o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.screenPos = ComputeScreenPos(o.pos);
            o.uv = v.texcoord;
            
            return o;
        }

        struct v2f
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        v2f VertexProgram(appdata_img v)
        {
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;
            return o;
        }

        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragCoc

            fixed4 fragCoc(v2fDepth i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, i.screenPos);
			    depth = LinearEyeDepth(depth);

                float coc = (depth - _FocusDistance) / _FocusRange;
				coc = clamp(coc, -1, 1) * _BokehRadius;
				return coc;
            }
            ENDCG
        }

        Pass {
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half Weigh (half3 c) {
					return 1 / (1 + max(max(c.r, c.g), c.b));
				}

				half4 FragmentProgram (v2f i) : SV_Target {
					float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;

					half3 s0 = tex2D(_MainTex, i.uv + o.xy).rgb;
					half3 s1 = tex2D(_MainTex, i.uv + o.zy).rgb;
					half3 s2 = tex2D(_MainTex, i.uv + o.xw).rgb;
					half3 s3 = tex2D(_MainTex, i.uv + o.zw).rgb;

					half w0 = Weigh(s0);
					half w1 = Weigh(s1);
					half w2 = Weigh(s2);
					half w3 = Weigh(s3);

					half3 color = s0 * w0 + s1 * w1 + s2 * w2 + s3 * w3;
					color /= max(w0 + w1 + w2 + s3, 0.00001);

					half coc0 = tex2D(_COCTexture, i.uv + o.xy).r;
					half coc1 = tex2D(_COCTexture, i.uv + o.zy).r;
					half coc2 = tex2D(_COCTexture, i.uv + o.xw).r;
					half coc3 = tex2D(_COCTexture, i.uv + o.zw).r;

					half cocMin = min(min(min(coc0, coc1), coc2), coc3);
					half cocMax = max(max(max(coc0, coc1), coc2), coc3);
					half coc = cocMax >= -cocMin ? cocMax : cocMin;
					//return fixed4(tex2D(_MainTex, i.uv).rgb, coc);
					return half4(color, coc);
				}
			ENDCG
        }

        Pass {
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				#define BOKEH_KERNEL_MEDIUM

				// From https://github.com/Unity-Technologies/PostProcessing/
				// blob/v2/PostProcessing/Shaders/Builtins/DiskKernels.hlsl
				#if defined(BOKEH_KERNEL_SMALL)
					static const int kernelSampleCount = 16;
					static const float2 kernel[kernelSampleCount] = {
						float2(0, 0),
						float2(0.54545456, 0),
						float2(0.16855472, 0.5187581),
						float2(-0.44128203, 0.3206101),
						float2(-0.44128197, -0.3206102),
						float2(0.1685548, -0.5187581),
						float2(1, 0),
						float2(0.809017, 0.58778524),
						float2(0.30901697, 0.95105654),
						float2(-0.30901703, 0.9510565),
						float2(-0.80901706, 0.5877852),
						float2(-1, 0),
						float2(-0.80901694, -0.58778536),
						float2(-0.30901664, -0.9510566),
						float2(0.30901712, -0.9510565),
						float2(0.80901694, -0.5877853),
					};
				#elif defined (BOKEH_KERNEL_MEDIUM)
					static const int kernelSampleCount = 22;
					static const float2 kernel[kernelSampleCount] = {
						float2(0, 0),
						float2(0.53333336, 0),
						float2(0.3325279, 0.4169768),
						float2(-0.11867785, 0.5199616),
						float2(-0.48051673, 0.2314047),
						float2(-0.48051673, -0.23140468),
						float2(-0.11867763, -0.51996166),
						float2(0.33252785, -0.4169769),
						float2(1, 0),
						float2(0.90096885, 0.43388376),
						float2(0.6234898, 0.7818315),
						float2(0.22252098, 0.9749279),
						float2(-0.22252095, 0.9749279),
						float2(-0.62349, 0.7818314),
						float2(-0.90096885, 0.43388382),
						float2(-1, 0),
						float2(-0.90096885, -0.43388376),
						float2(-0.6234896, -0.7818316),
						float2(-0.22252055, -0.974928),
						float2(0.2225215, -0.9749278),
						float2(0.6234897, -0.7818316),
						float2(0.90096885, -0.43388376),
					};
				#endif

				half Weigh (half coc, half radius) {
					return saturate((coc - radius + 2) / 2);
				}

				half4 FragmentProgram (v2f i) : SV_Target {
					half coc = tex2D(_MainTex, i.uv).a;
					
					half3 bgColor = 0, fgColor = 0;
					half bgWeight = 0, fgWeight = 0;
					for (int k = 0; k < kernelSampleCount; k++) {
						float2 o = kernel[k] * _BokehRadius;
						half radius = length(o);
						o *= _MainTex_TexelSize.xy;
						half4 s = tex2D(_MainTex, i.uv + o);

						half bgw = Weigh(max(0, min(s.a, coc)), radius);
						bgColor += s.rgb * bgw;
						bgWeight += bgw;

						half fgw = Weigh(-s.a, radius);
						fgColor += s.rgb * fgw;
						fgWeight += fgw;
					}
					bgColor *= 1 / (bgWeight + (bgWeight == 0));
					fgColor *= 1 / (fgWeight + (fgWeight == 0));
					half bgfg =
						min(1, fgWeight * 3.14159265359 / kernelSampleCount);
					half3 color = lerp(bgColor, fgColor, bgfg);
					return half4(color, bgfg);
				}
			ENDCG
		}
		
		Pass { 
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (v2f i) : SV_Target {
					float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;
					half4 s =
						tex2D(_MainTex, i.uv + o.xy) +
						tex2D(_MainTex, i.uv + o.zy) +
						tex2D(_MainTex, i.uv + o.xw) +
						tex2D(_MainTex, i.uv + o.zw);
					return s * 0.25;
				}
			ENDCG
		}

        Pass {
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (v2f i) : SV_Target {
					half4 source = tex2D(_MainTex, i.uv);
					half coc = tex2D(_COCTexture, i.uv).r;
					half4 dof = tex2D(_DOFTexture, i.uv);

					half dofStrength = smoothstep(0.1, 1, abs(coc));
					half3 color = lerp(
						source.rgb, dof.rgb,
						dofStrength + dof.a - dofStrength * dof.a
					);
					return half4(color, source.a);
				}
			ENDCG
		}
    }
}
