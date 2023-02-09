#pragma warning disable 0642
#pragma warning disable 0618

using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using UnityEditor.Animations;

/// <summary>
/// Editor Window for MeshAnimator baking
/// </summary>
public class GPUSkinningBoneGenerator : EditorWindow
{
    [SerializeField]
    private GameObject prefab;
    [SerializeField]
    private GameObject previousPrefab;
    [SerializeField]
    private List<AnimationClip> animClips = new List<AnimationClip>();
    [SerializeField]
    private SkinnedMeshRenderer skinnedRenderer;
    [SerializeField]
    private Object outputFolder;
    [SerializeField]
    private Animator animator;
    [SerializeField]
    private RuntimeAnimatorController animController;
    [SerializeField]
    private Avatar animAvatar;

    private List<AnimationClip> clipsCache = new List<AnimationClip>();

    private static GPUSkinningBoneGenerator window;
    private static GPUSkinningBoneGenerator Instance;

    [MenuItem("Assets/烘培骨骼动画贴图")]
    static void MakeWindow()
    {
        window = GetWindow(typeof(GPUSkinningBoneGenerator)) as GPUSkinningBoneGenerator;
        if (window.prefab != Selection.activeGameObject)
        {
            window.prefab = null;
            window.OnEnable();
        }
    }
    private Dictionary<string, bool> bakeAnims = new Dictionary<string, bool>();
    /// Reload the target prefab
    private void OnEnable()
    {
        Instance = this;
        titleContent = new GUIContent("烘培骨骼动画贴图");
        if (prefab == null && Selection.activeGameObject)
        {
            prefab = Selection.activeGameObject;
            OnPrefabChanged();
        }
    }
    private void OnDisable()
    {

    }
    #region GUI
    /// 绘制编辑器UI
    private void OnGUI()
    {
        GUI.skin.label.wordWrap = true;
        using (new EditorGUILayout.HorizontalScope())
        {
            prefab = EditorGUILayout.ObjectField("烘培的预制体", prefab, typeof(GameObject), true) as GameObject;
        }

        if (prefab == null) DrawWarning("需要指定烘培的预制体");
        else if (previousPrefab != prefab) OnPrefabChanged();

        if (prefab != null && !string.IsNullOrEmpty(GetPrefabPath()))
        {
            outputFolder = EditorGUILayout.ObjectField("Output Folder", outputFolder, typeof(Object), false);
        }
        GUILayout.Space(1);
        using (new GUILayout.ScrollViewScope(new Vector2()))
        {
            GUILayout.Label("<b>要烘培的动画</b>");
            for (int i = 0; i < animClips.Count; i++)
            {
                GUILayout.BeginHorizontal();
                {
                    var previous = animClips[i];
                    animClips[i] = (AnimationClip)EditorGUILayout.ObjectField(animClips[i], typeof(AnimationClip), false);

                    if (GUILayout.Button("删除", GUILayout.Width(32)))
                    {
                        animClips.RemoveAt(i);
                        GUILayout.EndHorizontal();
                        break;
                    }
                }
                GUILayout.EndHorizontal();
            }
            if (GUILayout.Button("添加动画"))
            {
                animClips.Add(null);
            }
            using (new EditorGUILayout.HorizontalScope())
            {
                if (animAvatar == null)
                    GetAvatar();
                animAvatar = EditorGUILayout.ObjectField("骨骼", animAvatar, typeof(Avatar), true) as Avatar;
            }
        }
        if (prefab != null)
        {
            GUILayout.Space(10);
            int bakeCount = animClips.Count(q => q != null);
            GUI.enabled = bakeCount > 0;
            var c = GUI.color;
            GUI.color = new Color(128 / 255f, 234 / 255f, 255 / 255f, 1);
            if (GUILayout.Button(string.Format("烘培{0}份动画", bakeCount), GUILayout.Height(30)))
                CreateGPUSkinningTexture();
            if (GUILayout.Button(string.Format("骨骼信息"), GUILayout.Height(30)))
                PrintBonesInfo();
            GUI.color = c;
            GUI.enabled = true;
        }
    }
    private void DrawWarning(string text)
    {
        int w = (int)Mathf.Lerp(300, 900, text.Length / 200f);
        using (new EditorGUILayout.HorizontalScope(GUILayout.MinHeight(30)))
        {
            var style = new GUIStyle(GUI.skin.FindStyle("CN EntryWarnIcon"));
            style.margin = new RectOffset();
            style.contentOffset = new Vector2();
            GUILayout.Box("", style, GUILayout.Width(15), GUILayout.Height(15));
            var textStyle = new GUIStyle(GUI.skin.label);
            textStyle.contentOffset = new Vector2(10, Instance.position.width < w ? 0 : 5);
            GUILayout.Label(text, textStyle);
        }
    }

    private void PrintBonesInfo()
    {
        Debug.LogError(prefab.GetComponentInChildren<SkinnedMeshRenderer>().sharedMesh.bindposes.Length);
    }
    #endregion

    #region 自定义函数

    /// 选中预制体改变时的回调
    private void OnPrefabChanged()
    {
        if (Application.isPlaying)
        {
            return;
        }
        animator = null;
        animAvatar = null;
        if (prefab != null)
        {
            bakeAnims.Clear();
        }
        previousPrefab = prefab;
    }

    /// 返回选中的预制体的路径
    private string GetPrefabPath()
    {
        string assetPath = AssetDatabase.GetAssetPath(prefab);
        if (string.IsNullOrEmpty(assetPath))
        {
            Object parentObject = PrefabUtility.GetCorrespondingObjectFromSource(prefab);
            assetPath = AssetDatabase.GetAssetPath(parentObject);
        }
        return assetPath;
    }

    /// 创建烘培贴图时的动画控制器
    private UnityEditor.Animations.AnimatorController CreateBakeController()
    {
        //string tempPath = "Assets/TempBakeController.controller";
        //string bakeName = AssetDatabase.GenerateUniqueAssetPath(tempPath);
        //AnimatorController controller = AnimatorController.CreateAnimatorControllerAtPath(bakeName);
        AnimatorController controller = new AnimatorController();
        controller.name = "AnimationCtrl";
        controller.AddLayer("Layer0");
        AnimatorStateMachine baseStateMachine = controller.layers[0].stateMachine;
        foreach (var clip in animClips)
        {
            var state = baseStateMachine.AddState(clip.name);
            state.motion = clip;
        }
        return controller;
    }

    /// Return the Avatar if available from the prefab
    private Avatar GetAvatar()
    {
        if (animAvatar)
            return animAvatar;
        var objs = EditorUtility.CollectDependencies(new Object[] { prefab }).ToList();
        foreach (var obj in objs.ToArray())
            objs.AddRange(AssetDatabase.LoadAllAssetRepresentationsAtPath(AssetDatabase.GetAssetPath(obj)));
        objs.RemoveAll(q => q is Avatar == false || q == null);
        if (objs.Count > 0)
            animAvatar = objs[0] as Avatar;
        return animAvatar;
    }

    /// 设置对象及其子对象的hideFlags
    private void SetChildFlags(Transform t, HideFlags flags)
    {
        Queue<Transform> q = new Queue<Transform>();
        q.Enqueue(t);
        for (int i = 0; i < t.childCount; i++)
        {
            Transform c = t.GetChild(i);
            q.Enqueue(c);
            SetChildFlags(c, flags);
        }
        while (q.Count > 0)
        {
            q.Dequeue().gameObject.hideFlags = flags;
        }
    }

    /// 替换名称中的特殊字符
    private string FormatClipName(string name)
    {
        string badChars = "!@#$%%^&*()=+}{[]'\";:|";
        for (int i = 0; i < badChars.Length; i++)
        {
            name = name.Replace(badChars[i], '_');
        }
        return name;
    }
    #endregion

    #region Baking Methods
    /// 采样动画，烘培贴图
    private void CreateGPUSkinningTexture()
    {
        RuntimeAnimatorController bakeController = null;
        try
        {
            string assetPath = GetPrefabPath();
            if (string.IsNullOrEmpty(assetPath))
            {
                EditorUtility.DisplayDialog("GPUSkinning", string.Format("无法获取{0}的路径", prefab.name), "OK");
                return;
            }
            if (outputFolder == null)
            {
                EditorUtility.DisplayDialog("GPUSkinning", "无法加载导出路径，请确保导出路径正确。", "OK");
                return;
            }
            string assetFolder = AssetDatabase.GetAssetPath(outputFolder);
            if (string.IsNullOrEmpty(assetFolder))
            {
                EditorUtility.DisplayDialog("GPUSkinning", "无法加载导出文件夹", "OK");
                return;
            }

            int animCount = 0;
            GameObject sampleGO = Instantiate(prefab, Vector3.zero, Quaternion.identity);
            skinnedRenderer = sampleGO.GetComponent<SkinnedMeshRenderer>();
            if (skinnedRenderer == null) skinnedRenderer = sampleGO.GetComponentInChildren<SkinnedMeshRenderer>();
            if (skinnedRenderer == null)
            {
                /// 确保烘培动画时有模型信息
                DestroyImmediate(sampleGO);
                throw new System.Exception("预制体没有skinnedMeshRenderer");
            }
            else
            {
                animator = sampleGO.GetComponent<Animator>();
                if (animator == null) animator = sampleGO.GetComponentInChildren<Animator>();
                if (animator == null) animator = sampleGO.AddComponent<Animator>();
                bakeController = CreateBakeController();
                animator.runtimeAnimatorController = bakeController;
                animator.avatar = GetAvatar();
                animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
                GameObject asset = new GameObject(prefab.name + "_GPUSkinning");
                int boneCount = 0;
                Transform rootMotionBaker = new GameObject().transform;
                //枚举要渲染的动画
                for (int i = 0; i < animClips.Count; ++i)
                {
                    AnimationClip animClip = animClips[i];
                    //这里我们以60帧为例
                    int bakeFrames = Mathf.CeilToInt(animClip.length * 60);
                    float lastFrameTime = 0;
                    List<List<Matrix4x4>> boneMatrixsList = new List<List<Matrix4x4>>();
                    for (int j = 0; j < bakeFrames; j++)
                    {
                        float bakeDelta = Mathf.Clamp01((float)j / bakeFrames);
                        EditorUtility.DisplayProgressBar("烘培骨骼动画贴图", string.Format("烘培骨骼动画动画:{0} 第{1}帧", animClip.name, j), bakeDelta);
                        float animationTime = bakeDelta * animClip.length;
                        if (animClip.isHumanMotion || !animClip.legacy)
                        {
                            float normalizedTime = animationTime / animClip.length;
                            string stateName = animClip.name;
                            animator.Play(stateName, 0, normalizedTime);
                            if (lastFrameTime == 0)
                            {
                                float nextBakeDelta = Mathf.Clamp01(((float)(j + 1) / bakeFrames));
                                float nextAnimationTime = nextBakeDelta * animClip.length;
                                lastFrameTime = animationTime - nextAnimationTime;
                            }
                            animator.Update(animationTime - lastFrameTime);
                            lastFrameTime = animationTime;
                        }
                        else
                        {
                            GameObject sampleObject = sampleGO;
                            Animation legacyAnimation = sampleObject.GetComponentInChildren<Animation>();
                            if (animator && animator.gameObject != sampleObject)
                                sampleObject = animator.gameObject;
                            else if (legacyAnimation && legacyAnimation.gameObject != sampleObject)
                                sampleObject = legacyAnimation.gameObject;
                            animClip.SampleAnimation(sampleObject, animationTime);
                        }
                        List<Matrix4x4> boneMatrixs1 = new List<Matrix4x4>();
                        List<Matrix4x4> boneMatrixs2 = new List<Matrix4x4>();
                        for (int k = 0; k < skinnedRenderer.bones.Length; ++k)
                        {
                            boneMatrixs1.Add(TransformBone(skinnedRenderer.bones[k], skinnedRenderer.sharedMesh.bindposes[k], false));
                            boneMatrixs2.Add(skinnedRenderer.bones[k].localToWorldMatrix * skinnedRenderer.sharedMesh.bindposes[k]);
                        }
                        Mesh bakeMesh = new Mesh();
                        skinnedRenderer.BakeMesh(bakeMesh);
                        BoneWeight bw = skinnedRenderer.sharedMesh.boneWeights[1145];
                        Vector3 vertex = skinnedRenderer.sharedMesh.vertices[1145];
                        Vector3 finalPos1 = boneMatrixs1[bw.boneIndex0].MultiplyPoint(vertex) * bw.weight0 +
                            boneMatrixs1[bw.boneIndex1].MultiplyPoint(vertex) * bw.weight1 +
                            boneMatrixs1[bw.boneIndex2].MultiplyPoint(vertex) * bw.weight2 +
                            boneMatrixs1[bw.boneIndex3].MultiplyPoint(vertex) * bw.weight3;
                        Vector3 finalPos2 = boneMatrixs2[bw.boneIndex0].MultiplyPoint(vertex) * bw.weight0 +
                            boneMatrixs2[bw.boneIndex1].MultiplyPoint(vertex) * bw.weight1 +
                            boneMatrixs2[bw.boneIndex2].MultiplyPoint(vertex) * bw.weight2 +
                            boneMatrixs2[bw.boneIndex3].MultiplyPoint(vertex) * bw.weight3;
                        Debug.LogError("realPos: " + skinnedRenderer.gameObject.transform.localToWorldMatrix.MultiplyPoint(bakeMesh.vertices[1145]) +
                                        "\ntestpos1: " + finalPos1 +
                                        "\ntestpos1: " + finalPos2 +
                                        "\nmatrix: " + boneMatrixs2[bw.boneIndex0]);

                        // debug only
                        //Instantiate(sampleGO, j * Vector3.right, Quaternion.identity);
                        boneMatrixsList.Add(boneMatrixs1);
                        boneCount = boneMatrixs1.Count;
                    }
                    string name = string.Format("{0}/{1}_GPUSkinningBoneAsset.asset", assetFolder, FormatClipName(animClip.name));
                    GPUSkinningAsset_Bone gpuAssetB = ScriptableObject.CreateInstance<GPUSkinningAsset_Bone>();
                    AssetDatabase.CreateAsset(gpuAssetB, name);
                    gpuAssetB.CreateBakedAssets(name, boneMatrixsList, animClip.length);
                    animCount++;
                }
                DestroyImmediate(rootMotionBaker.gameObject);
                DestroyImmediate(asset);
            }
            DestroyImmediate(sampleGO);
            EditorUtility.ClearProgressBar();
        }
        catch (System.Exception e)
        {
            EditorUtility.ClearProgressBar();
            EditorUtility.DisplayDialog("烘培错误", string.Format("流程有误，详见{0}", e), "OK");
            Debug.LogException(e);
        }
        finally
        {
            if (bakeController)
            {
                //AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(bakeController));
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
    }

    public Matrix4x4 TransformBone(Transform bone, Matrix4x4 mat, bool debugOn)
    {
        if(debugOn) Debug.LogError(mat);
        Matrix4x4 mat4x4 = Matrix4x4.TRS(bone.localPosition, bone.localRotation, bone.localScale) * mat;
        if (bone.parent != null) mat4x4 = TransformBone(bone.parent, mat4x4, debugOn);
        return mat4x4;
    }

    #endregion
}