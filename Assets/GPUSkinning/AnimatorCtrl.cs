using UnityEditor.Animations;
using UnityEngine;

public class AnimatorCtrl : MonoBehaviour
{
    public Animator animator;
    public AnimatorController animatorController;
    public AnimationClip animation;
    [Range(0, 1)]
    public float animationSlider;
    private float lastAnimTime = 0;
    public bool DebugOn = false;
    // Start is called before the first frame update
    void Start()
    {
        animator = gameObject.GetComponent<Animator>();
        if (animator == null) animator = gameObject.AddComponent<Animator>(); 
        if(animator.runtimeAnimatorController == null)
        {
            animatorController = new AnimatorController();
            animatorController.name = "Ctrl";
            animatorController.AddLayer("Layer0");
            animator.runtimeAnimatorController = animatorController;
        }
        else
        {
            animatorController = (AnimatorController)animator.runtimeAnimatorController;
            if(animatorController.layers.Length < 1) animatorController.AddLayer("Layer0");
        }
        if (animation != null)
        {
            AnimatorState state = animatorController.layers[0].stateMachine.AddState(animation.name);
            state.motion = animation;
            animator.speed = .0f;
        }
        //Debug.LogError(animation.length);
        if (DebugOn)
        {
            Invoke("DebugOnMethod", 0.1f);
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (animationSlider != lastAnimTime)
        {
            animator.Play(animation.name, 0, animationSlider);
            lastAnimTime = animationSlider;
        }
    }

    void DebugOnMethod()
    {
        SkinnedMeshRenderer skinnedMesh = gameObject.GetComponent<SkinnedMeshRenderer>();
        if (skinnedMesh == null) skinnedMesh = gameObject.GetComponentInChildren<SkinnedMeshRenderer>();
        if (skinnedMesh != null)
        {
            int totalFrame = (int)animation.length * 60;
            GameObject goParent = new GameObject("Parent");
            animator.speed = 1.0f;
            animator.Play(animation.name, 0, 0f);
            float deltaTime = animation.length / totalFrame;
            for (int i = 0; i < totalFrame; ++i)
            {
                animator.Update(deltaTime);
                GameObject go = new GameObject();
                Mesh mesh = new Mesh();
                MeshFilter mf = go.AddComponent<MeshFilter>();
                mf.sharedMesh = mesh;
                skinnedMesh.BakeMesh(mesh);
                MeshRenderer mr = go.AddComponent<MeshRenderer>();
                mr.sharedMaterial = skinnedMesh.sharedMaterial;
                go.transform.position = gameObject.transform.position - (i + 1) * 3 * Vector3.right;
                Quaternion eular = new Quaternion();
                eular.eulerAngles = new Vector3(-90, 0, 0);
                go.transform.rotation = eular;
                go.transform.SetParent(goParent.transform);
                dfs(skinnedMesh.rootBone, goParent.transform);
            }
            animator.speed = .0f;
        }
    }

    void dfs(Transform bone, Transform parent)
    {
        GameObject boneGo = new GameObject(bone.name);
        boneGo.transform.localScale = bone.transform.localScale;
        boneGo.transform.rotation = bone.transform.rotation;
        boneGo.transform.position = bone.transform.position;
        boneGo.transform.SetParent(parent);
        for(int i = 0; i < bone.childCount; ++i)
        {
            dfs(bone.GetChild(i), boneGo.transform);
        }
    }
}
