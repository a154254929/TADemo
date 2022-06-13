using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SSAO : PostEffectBase
{
    private Camera cam;
    public Shader SSAOShader;
    private Material SSAOMaterial;
    [Range(0f, 1f)]
    public float aoStrength = 0f;
    [Range(4, 64)]
    public int SampleKernelCount = 64;
    private List<Vector4> sampleKernelList = new List<Vector4>();
    [Range(0.0001f, 10f)]
    public float sampleKeneralRadius = 0.01f;
    [Range(0.0001f, 1f)]
    public float rangeStrength = 0.001f;
    public float depthBiasValue;
    public Texture Nosie;//噪声贴图

    [Range(0, 2)]
    public int DownSample = 0;

    [Range(1, 4)]
    public int BlurRadius = 2;
    [Range(0, 0.2f)]
    public float bilaterFilterStrength = 0.2f;
    public bool OnlyShowAO = false;

    [Range(0, 63)]
    public int vecNum = 0;
    public Material material
    {
        get
        {
            SSAOMaterial = CheckShaderAndCreateMaterial(SSAOShader, SSAOMaterial);
            return SSAOMaterial;
        }
    }

    private void Start()
    {
        cam = this.GetComponent<Camera>();
        cam.depthTextureMode |= DepthTextureMode.DepthNormals;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (material != null)
        {
            GenerateAOSampleKernel();
            int rtW = source.width >> DownSample;
            int rtH = source.height >> DownSample;

            //AO
            RenderTexture aoRT = RenderTexture.GetTemporary(rtW, rtH, 0);
            material.SetVectorArray("_SampleKernelArray", sampleKernelList.ToArray());
            material.SetFloat("_RangeStrength", rangeStrength);
            material.SetFloat("_AOStrength", aoStrength);
            material.SetFloat("_SampleKernelCount", sampleKernelList.Count);
            material.SetFloat("_SampleKeneralRadius", sampleKeneralRadius);
            material.SetFloat("_DepthBiasValue", depthBiasValue);
            material.SetTexture("_NoiseTex", Nosie);
            material.SetInt("_Num", vecNum);
            Graphics.Blit(source, aoRT, material, 0);
            //Graphics.Blit(aoRT, destination);
            //return;
            ////Blur
            RenderTexture blurRT = RenderTexture.GetTemporary(rtW, rtH, 0);
            material.SetFloat("_BilaterFilterFactor", 1.0f - bilaterFilterStrength);
            material.SetVector("_BlurRadius", new Vector4(BlurRadius, 0, 0, 0));
            Graphics.Blit(aoRT, blurRT, material, 1);
            //Graphics.Blit(source, blurRT, material, 1);

            material.SetVector("_BlurRadius", new Vector4(0, BlurRadius, 0, 0));
            if (OnlyShowAO)
            {
                Graphics.Blit(blurRT, destination, material, 1);
            }
            else
            {
                Graphics.Blit(blurRT, aoRT, material, 1);
                material.SetTexture("_AOTex", aoRT);
                Graphics.Blit(source, destination, material, 2);
            }

            RenderTexture.ReleaseTemporary(aoRT);
            RenderTexture.ReleaseTemporary(blurRT);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }
    private void GenerateAOSampleKernel()
    {
        if (SampleKernelCount == sampleKernelList.Count)
            return;
        sampleKernelList.Clear();
        for (int i = 0; i < SampleKernelCount; i++)
        {
            var vec = new Vector4(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(0, 1.0f), 1.0f);
            vec.Normalize();
            var scale = (float)i / SampleKernelCount;
            //使分布符合二次方程的曲线
            scale = Mathf.Lerp(0.01f, 1.0f, scale * scale);
            vec *= scale;
            sampleKernelList.Add(vec);
        }
    }
}
