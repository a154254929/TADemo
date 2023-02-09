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

    [MenuItem("Assets/�������������ͼ")]
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
        titleContent = new GUIContent("�������������ͼ");
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
    /// ���Ʊ༭��UI
    private void OnGUI()
    {
        GUI.skin.label.wordWrap = true;
        using (new EditorGUILayout.HorizontalScope())
        {
            prefab = EditorGUILayout.ObjectField("�����Ԥ����", prefab, typeof(GameObject), true) as GameObject;
        }

        if (prefab == null) DrawWarning("��Ҫָ�������Ԥ����");
        else if (previousPrefab != prefab) OnPrefabChanged();

        if (prefab != null && !string.IsNullOrEmpty(GetPrefabPath()))
        {
            outputFolder = EditorGUILayout.ObjectField("Output Folder", outputFolder, typeof(Object), false);
        }
        GUILayout.Space(1);
        using (new GUILayout.ScrollViewScope(new Vector2()))
        {
            GUILayout.Label("<b>Ҫ����Ķ���</b>");
            for (int i = 0; i < animClips.Count; i++)
            {
                GUILayout.BeginHorizontal();
                {
                    var previous = animClips[i];
                    animClips[i] = (AnimationClip)EditorGUILayout.ObjectField(animClips[i], typeof(AnimationClip), false);

                    if (GUILayout.Button("ɾ��", GUILayout.Width(32)))
                    {
                        animClips.RemoveAt(i);
                        GUILayout.EndHorizontal();
                        break;
                    }
                }
                GUILayout.EndHorizontal();
            }
            if (GUILayout.Button("��Ӷ���"))
            {
                animClips.Add(null);
            }
            using (new EditorGUILayout.HorizontalScope())
            {
                if (animAvatar == null)
                    GetAvatar();
                animAvatar = EditorGUILayout.ObjectField("����", animAvatar, typeof(Avatar), true) as Avatar;
            }
        }
        if (prefab != null)
        {
            GUILayout.Space(10);
            int bakeCount = animClips.Count(q => q != null);
            GUI.enabled = bakeCount > 0;
            var c = GUI.color;
            GUI.color = new Color(128 / 255f, 234 / 255f, 255 / 255f, 1);
            if (GUILayout.Button(string.Format("����{0}�ݶ���", bakeCount), GUILayout.Height(30)))
                CreateGPUSkinningTexture();
            if (GUILayout.Button(string.Format("������Ϣ"), GUILayout.Height(30)))
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

    #region �Զ��庯��

    /// ѡ��Ԥ����ı�ʱ�Ļص�
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

    /// ����ѡ�е�Ԥ�����·��
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

    /// ����������ͼʱ�Ķ���������
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

    /// ���ö������Ӷ����hideFlags
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

    /// �滻�����е������ַ�
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
    /// ����������������ͼ
    private void CreateGPUSkinningTexture()
    {
        RuntimeAnimatorController bakeController = null;
        try
        {
            string assetPath = GetPrefabPath();
            if (string.IsNullOrEmpty(assetPath))
            {
                EditorUtility.DisplayDialog("GPUSkinning", string.Format("�޷���ȡ{0}��·��", prefab.name), "OK");
                return;
            }
            if (outputFolder == null)
            {
                EditorUtility.DisplayDialog("GPUSkinning", "�޷����ص���·������ȷ������·����ȷ��", "OK");
                return;
            }
            string assetFolder = AssetDatabase.GetAssetPath(outputFolder);
            if (string.IsNullOrEmpty(assetFolder))
            {
                EditorUtility.DisplayDialog("GPUSkinning", "�޷����ص����ļ���", "OK");
                return;
            }

            int animCount = 0;
            GameObject sampleGO = Instantiate(prefab, Vector3.zero, Quaternion.identity);
            skinnedRenderer = sampleGO.GetComponent<SkinnedMeshRenderer>();
            if (skinnedRenderer == null) skinnedRenderer = sampleGO.GetComponentInChildren<SkinnedMeshRenderer>();
            if (skinnedRenderer == null)
            {
                /// ȷ�����ද��ʱ��ģ����Ϣ
                DestroyImmediate(sampleGO);
                throw new System.Exception("Ԥ����û��skinnedMeshRenderer");
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
                //ö��Ҫ��Ⱦ�Ķ���
                for (int i = 0; i < animClips.Count; ++i)
                {
                    AnimationClip animClip = animClips[i];
                    //����������60֡Ϊ��
                    int bakeFrames = Mathf.CeilToInt(animClip.length * 60);
                    float lastFrameTime = 0;
                    List<List<Matrix4x4>> boneMatrixsList = new List<List<Matrix4x4>>();
                    for (int j = 0; j < bakeFrames; j++)
                    {
                        float bakeDelta = Mathf.Clamp01((float)j / bakeFrames);
                        EditorUtility.DisplayProgressBar("�������������ͼ", string.Format("���������������:{0} ��{1}֡", animClip.name, j), bakeDelta);
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
            EditorUtility.DisplayDialog("�������", string.Format("�����������{0}", e), "OK");
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