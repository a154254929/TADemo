using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class GPUSkinningAsset : ScriptableObject
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
    //顶点数
    public int vertexCount;

#if UNITY_EDITOR
    [System.NonSerialized]
    // 顶点位置数组
    private List<List<Vector3>> frameBakeData;
    // 顶点法线数组
    private List<List<Vector3>> normalBakeData;
    public void CreateBakedAssets(string path, List<List<Vector3>> framePositions, List<List<Vector3>> frameNormals, float animationClipTime)
    {
        animScalar = Vector3.zero;
        animTime = animationClipTime;
        vertexCount = framePositions[0].Count;
        frameBakeData = framePositions;
        normalBakeData = frameNormals;
        int TEX_SIZE = 1024;
        int frameVertexCount = vertexCount * frameBakeData.Count * 2;
        textureSize = new Vector2Int(TEX_SIZE, TEX_SIZE);
        if (frameBakeData.Count > 0) vertexCount = frameBakeData[0].Count;
        double[][] offsets = new double[vertexCount * frameBakeData.Count][];
        double[] scaler = new double[3];
        // generate texture
        for (int frameIndex = 0; frameIndex < frameBakeData.Count; frameIndex++)
        {
            List<Vector3> meshFrame = frameBakeData[frameIndex];
            List<Vector3> meshNormal = normalBakeData[frameIndex];
            for (int vert = 0; vert < meshFrame.Count; vert++)
            {
                //Debug.LogError(vert.ToString() + ":" + meshFrame[vert]);
                int arrayPos = (frameIndex * meshFrame.Count) + vert;
                Vector3 framePos = meshFrame[vert];
                Vector3 frameNormal = Vector3.zero;
                if (meshNormal.Count > vert)frameNormal = meshNormal[vert];
                double[] data = new double[6]
                {
                        framePos.x,
                        framePos.y,
                        framePos.z,
                        frameNormal.x,
                        frameNormal.y,
                        frameNormal.z
                };
                offsets[arrayPos] = data;

                scaler[0] = Math.Max(scaler[0], System.Math.Abs(data[0]));
                scaler[1] = Math.Max(scaler[1], System.Math.Abs(data[1]));
                scaler[2] = Math.Max(scaler[2], System.Math.Abs(data[2]));
            }
        }
        animScalar = new Vector3((float)scaler[0], (float)scaler[1], (float)scaler[2]);
        List<Texture2D> bakeTextures = new List<Texture2D>();
        int xPos = 0;
        int yPos = 0;
        int textureIndex = 0;
        int frame = 0;
        int pixelsLeft = textureSize.x * textureSize.y;
        int verticesLeftInFrame = vertexCount * 2;
        for (int vert = 0; vert < offsets.Length; vert++)
        {
            double[] data = offsets[vert];
            if (data == null) continue;
            for (int s = 0; s < data.Length; s++)
            {
                data[s] /= s < 3 ? scaler[s] : 1.0f;
                data[s] = data[s] * 0.5d + 0.5d;
            }

            for (int c = 0; c < data.Length; c += 3)
            {
                Color color = new Color((float)data[c + 0], (float)data[c + 1], (float)data[c + 2], 1);
                if (yPos == textureSize.y)
                {
                    xPos++;
                    yPos = 0;
                    if (xPos == textureSize.x)
                    {
                        xPos = 0;
                        textureIndex++;
                        pixelsLeft = textureSize.x * textureSize.y;
                    }
                }
                if (bakeTextures.Count <= textureIndex)
                {
                    bakeTextures.Add(new Texture2D(textureSize.x, textureSize.y, TextureFormat.RGBAHalf, false, false));
                }
                Texture2D bakeTexture = bakeTextures[textureIndex];
                bakeTexture.SetPixel(xPos, yPos, color);
                yPos++;

                pixelsLeft--;
                verticesLeftInFrame--;
                // 让同一帧的顶点和法线数据在同一张贴图里
                if (verticesLeftInFrame == 0)
                {
                    verticesLeftInFrame = vertexCount * 2;
                    frame++;
                    if (pixelsLeft < vertexCount * 2)
                    {
                        textureIndex++;
                        pixelsLeft = textureSize.x * textureSize.y;
                        xPos = 0;
                        yPos = 0;
                    }
                }
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
