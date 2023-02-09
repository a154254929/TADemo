using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class GPUSkinningBoneSetter : MonoBehaviour
{
    public GPUSkinningAsset_Bone[] Animations;
    public int NowPlayIndex = 0;
    public Mesh mesh;
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
        for (int i = 0; i < Animations.Length; ++i)
        {
            GPUSkinningAsset_Bone Animation = Animations[i];
            AnimStartMap.Add(texCount);
            for (int j = 0; j < Animation.textureCount; ++j)
            {
                Texture2D tex = Animation.textures[j];
                if (copyTextureSupport == UnityEngine.Rendering.CopyTextureSupport.None) texArray.SetPixels(tex.GetPixels(0), texCount, 0);
                else Graphics.CopyTexture(tex, 0, 0, texArray, texCount, 0);
                texCount++;
            }
        }
        //如果使用SetPixels的话需要Apply一下
        if (copyTextureSupport == UnityEngine.Rendering.CopyTextureSupport.None) texArray.Apply();
        mat = render.sharedMaterial;
        mat.SetTexture("_AnimationTex", texArray);
        if(mesh.boneWeights.Length > 0)
        {
            List<Vector2> uv1 = new List<Vector2>();
            List<Vector2> uv2 = new List<Vector2>();
            List<Vector2> uv3 = new List<Vector2>();
            List<Vector2> uv4 = new List<Vector2>();
            for(int i = 0; i < mesh.vertexCount; ++i)
            {
                int nowIndex = System.Math.Min(i, mesh.boneWeights.Length);
                BoneWeight bw = mesh.boneWeights[nowIndex];
                uv1.Add(new Vector2(bw.boneIndex0, bw.weight0));
                uv2.Add(new Vector2(bw.boneIndex1, bw.weight1));
                uv3.Add(new Vector2(bw.boneIndex2, bw.weight2));
                uv4.Add(new Vector2(bw.boneIndex3, bw.weight3));
            }
            mesh.SetUVs(1, uv1);
            mesh.SetUVs(2, uv2);
            mesh.SetUVs(3, uv3);
            mesh.SetUVs(4, uv4);
            gameObject.GetComponent<MeshFilter>().sharedMesh = mesh;
        }
    }


    private void PlayAnima(int idx)
    {
        GPUSkinningAsset_Bone Animation = Animations[idx];
        if (Animation != null)
        {
            render.GetPropertyBlock(matBlock);
            //matBlock.SetInt("_AnimationTexIndex", AnimStartMap[idx]);
            matBlock.SetVector("_Scale", Animation.animScalar);
            matBlock.SetFloat("_AnimationSize", Animation.animTime);
            matBlock.SetInt("_FPS", 60);
            matBlock.SetInt("_BoneNum", Animation.boneCount);
            matBlock.SetVector("_TextureSize", new Vector4(Animation.textureSize.x, Animation.textureSize.y, 0, 0));
            //matBlock.SetFloat("_AnimationStartTime", Random.Range(0.0f, Animation.animTime));
            //matBlock.SetFloat("_AnimationScale", Random.Range(0.8f, 1.3f));
            render.SetPropertyBlock(matBlock);
        }
    }
}
