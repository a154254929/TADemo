using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class GPUSkinningSetter : MonoBehaviour
{
    public GPUSkinningAsset[] Animations;
    public int NowPlayIndex = 0;
    private MeshRenderer render;
    private MaterialPropertyBlock matBlock;
    private Material mat;
    private Texture2DArray texArray;
    private List<int> AnimStartMap = new List<int>();
    // Start is called before the first frame update
    void Start()
    {
        SetInfo();
        int playIdx = Random.Range(0, Animations.Length);
        NowPlayIndex = playIdx;
        PlayAnima(playIdx);
    }

    private void SetInfo()
    {
        if (render == null) render = gameObject.GetComponent<MeshRenderer>();
        if (matBlock == null) matBlock = new MaterialPropertyBlock();
        int totalTex = 0;
        for (int i = 0; i < Animations.Length; ++i) totalTex += Animations[i].textureCount;
         //查看是否支持Graphics.CopyTexture,尽量使用Graphics.CopyTexture，因为它比SetPixels耗时更短
         CopyTextureSupport copyTextureSupport = SystemInfo.copyTextureSupport;
        texArray = new Texture2DArray(Animations[0].textureSize.x, Animations[0].textureSize.y, totalTex, Animations[0].textures[0].format, false, false);
        texArray.filterMode = FilterMode.Point;
        DontDestroyOnLoad(texArray);
        int texCount = 0;
        for(int i = 0; i < Animations.Length; ++i)
        {
            GPUSkinningAsset Animation = Animations[i];
            AnimStartMap.Add(texCount);
            for (int j = 0; j < Animation.textureCount; ++j)
            {
                Texture2D tex = Animation.textures[j];
                if (copyTextureSupport == UnityEngine.Rendering.CopyTextureSupport.None) texArray.SetPixels(tex.GetPixels(0), texCount, 0);
                else Graphics.CopyTexture(tex, 0, 0, texArray, texCount, 0);
                texCount ++;
            }
        }
        //如果使用SetPixels的话需要Apply一下
        if (copyTextureSupport == UnityEngine.Rendering.CopyTextureSupport.None) texArray.Apply();
        mat = render.sharedMaterial;
        mat.SetTexture("_AnimationTex", texArray);
        Debug.Log(texArray.depth);
    }

    private void PlayAnima(int idx)
    {
        GPUSkinningAsset Animation = Animations[idx];
        if(Animation != null)
        {
            render.GetPropertyBlock(matBlock);
            matBlock.SetInt("_AnimationTexIndex", AnimStartMap[idx]);
            matBlock.SetVector("_Scale", Animation.animScalar);
            matBlock.SetFloat("_AnimationSize", Animation.animTime);
            matBlock.SetInt("_FPS", 60);
            matBlock.SetInt("_VertexNum", Animation.vertexCount);
            matBlock.SetVector("_TextureSize", new Vector4(Animation.textureSize.x, Animation.textureSize.y, 0, 0));
            matBlock.SetFloat("_AnimationStartTime", Random.Range(0.0f, Animation.animTime));
            matBlock.SetFloat("_AnimationScale", Random.Range(0.8f, 1.3f));
            render.SetPropertyBlock(matBlock);
        }
    }
}
