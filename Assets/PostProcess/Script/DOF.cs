using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DOF : PostEffectBase
{
    private Camera cam;
    public Shader DOFShader;
    private Material DOFMaterial;
    const int circleOfConfusionPass = 0;
    const int preFilterPass = 1;
    const int bokehPass = 2;
    const int postFilterPass = 3;
    const int combinePass = 4;

    [Range(0.1f, 100f)]
    public float focusDistance = 10f;

    [Range(0.1f, 10f)]
    public float focusRange = 3f;

    [Range(1f, 10f)]
    public float bokehRadius = 4f;


    public Material material
    {
        get
        {
            DOFMaterial = CheckShaderAndCreateMaterial(DOFShader, DOFMaterial);
            return DOFMaterial;
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        cam = this.GetComponent<Camera>();
        cam.depthTextureMode |= DepthTextureMode.Depth;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(material != null)
        {


            material.SetFloat("_BokehRadius", bokehRadius);
            material.SetFloat("_FocusDistance", focusDistance);
            material.SetFloat("_FocusRange", focusRange);

            RenderTexture coc = RenderTexture.GetTemporary(
                    source.width, source.height, 0,
                    RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear
                );
            int width = source.width / 2;
            int height = source.height / 2;
            RenderTextureFormat format = source.format;
            RenderTexture dof0 = RenderTexture.GetTemporary(width, height, 0, format);
            RenderTexture dof1 = RenderTexture.GetTemporary(width, height, 0, format);
            material.SetTexture("_COCTexure", coc);
            material.SetTexture("_DOFTexure", dof0);


            Graphics.Blit(source, coc, material, circleOfConfusionPass);
            material.SetTexture("_COCTexture", coc);
            Graphics.Blit(source, dof0, material, preFilterPass);
            Graphics.Blit(dof0, dof1, material, bokehPass);
            Graphics.Blit(dof1, dof0, material, postFilterPass);
            //Graphics.Blit(dof0, destination);
            material.SetTexture("_DOFTexture", dof0);
            Graphics.Blit(source, destination, material, combinePass);

            RenderTexture.ReleaseTemporary(coc);
            RenderTexture.ReleaseTemporary(dof0);
            RenderTexture.ReleaseTemporary(dof1);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }
}
