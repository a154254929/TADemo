using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class GPUSkinningAsset_Bone : ScriptableObject
{
    //烘培出来的贴图
    public Texture2D[] textures;
    //烘培贴图的大小
    public Vector2Int textureSize;
    //动画在三个轴上的缩放
    public Vector3 animScalar;
    //动画时长
    public float animTime;
    //动画贴图数
    public int textureCount;
    //骨骼数
    public int boneCount;

#if UNITY_EDITOR
    [System.NonSerialized]
    // 顶点位置数组
    private List<List<Matrix4x4>> BoneBakeData;
    public void CreateBakedAssets(string path, List<List<Matrix4x4>> BonesMatList, float animationClipTime)
    {
        animScalar = Vector3.zero;
        animTime = animationClipTime;
        BoneBakeData = BonesMatList;
        int TEX_SIZE = 256;
        textureSize = new Vector2Int(TEX_SIZE, TEX_SIZE);
        if (BonesMatList.Count > 0) boneCount = BonesMatList[0].Count;
        int frameBoneCount = boneCount * BonesMatList.Count;
        float[] scaler = new float[3];
        // generate texture
        for (int frameIndex = 0; frameIndex < BonesMatList.Count; frameIndex++)
        {
            List<Matrix4x4> BonesMat = BonesMatList[frameIndex];
            for (int boneIdx = 0; boneIdx < BonesMat.Count; boneIdx++)
            {
                //Debug.LogError(vert.ToString() + ":" + meshFrame[vert]);
                int arrayPos = (frameIndex * BonesMat.Count) + boneIdx;
                Matrix4x4 frameBone = BonesMat[boneIdx];

                scaler[0] = Math.Max(scaler[0], System.Math.Abs(frameBone.m03));
                scaler[1] = Math.Max(scaler[1], System.Math.Abs(frameBone.m13));
                scaler[2] = Math.Max(scaler[2], System.Math.Abs(frameBone.m23));
            }
        }
        animScalar = new Vector3((float)scaler[0], (float)scaler[1], (float)scaler[2]);
        List<Texture2D> bakeTextures = new List<Texture2D>();
        int xPos = 0;
        int yPos = 0;
        int textureIndex = 0;
        int pixelsLeft = textureSize.x * textureSize.y;
        int bonesLeftInFrame = frameBoneCount;
        bakeTextures.Add(new Texture2D(textureSize.x, textureSize.y, TextureFormat.RGBAHalf, false, false));
        for (int frameIndex = 0; frameIndex < BonesMatList.Count; frameIndex++)
        {
            for (int boneIdx = 0; boneIdx < BonesMatList[frameIndex].Count; boneIdx++)
            {
                Matrix4x4 data = BonesMatList[frameIndex][boneIdx];
                data.m00 = data.m00 * 0.5f + 0.5f;
                data.m01 = data.m01 * 0.5f + 0.5f;
                data.m02 = data.m02 * 0.5f + 0.5f;
                data.m03 = data.m03 / scaler[0] * 0.5f + 0.5f;
                data.m10 = data.m10 * 0.5f + 0.5f;
                data.m11 = data.m11 * 0.5f + 0.5f;
                data.m12 = data.m12 * 0.5f + 0.5f;
                data.m13 = data.m13 / scaler[1] * 0.5f + 0.5f;
                data.m20 = data.m20 * 0.5f + 0.5f;
                data.m21 = data.m21 * 0.5f + 0.5f;
                data.m22 = data.m22 * 0.5f + 0.5f;
                data.m23 = data.m23 / scaler[2] * 0.5f + 0.5f;
                Color[] colors = new Color[]{
                    new Color(data.m00, data.m01, data.m02, data.m03),
                    new Color(data.m10, data.m11, data.m12, data.m13),
                    new Color(data.m20, data.m21, data.m22, data.m23),
                    new Color(data.m30, data.m31, data.m32, data.m33)
                };
                if (yPos == textureSize.y)
                {
                    xPos++;
                    yPos = 0;
                    if (xPos == textureSize.x)
                    {
                        xPos = 0;
                        textureIndex++;
                        bakeTextures.Add(new Texture2D(textureSize.x, textureSize.y, TextureFormat.RGBAHalf, false, false));
                    }
                }
                bakeTextures[textureIndex].SetPixel(xPos, yPos, colors[0]);
                bakeTextures[textureIndex].SetPixel(xPos, yPos + 1, colors[1]);
                bakeTextures[textureIndex].SetPixel(xPos, yPos + 2, colors[2]);
                bakeTextures[textureIndex].SetPixel(xPos, yPos + 3, colors[3]);
                yPos += 4;
            }
        }
        var existingTextures = UnityEditor.AssetDatabase.LoadAllAssetsAtPath(path).Where(a => a is Texture2D).ToArray();
        for (int t = 0; t < bakeTextures.Count; t++)
        {
            bakeTextures[t].name = string.Format("{0}_{1}", this.name, t);
            foreach (var existing in existingTextures)
                DestroyImmediate(existing, true);
            UnityEditor.AssetDatabase.AddObjectToAsset(bakeTextures[t], this);
        }
        textures = bakeTextures.ToArray();
        textureCount = textures.Length;
    }
#endif

}
