using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace FSG.MeshAnimator
{
    public class RandomGenerate : MonoBehaviour
    {
        public GameObject[] gamePrafabs;
        [Range(1, 10000)]
        public int objCount = 1;
        public bool showGUI = true;
        private string[] optionsDesc =
        {
        "Animator组件播放动画",
        "Shader播放动画"
        };

        private string fps;
        private int selectedOption = 1;
        private int guiOffset = 0;
        private int previousFrame = 0;
        private int previousSelection = 0;
        private int maxSize = 10000;
        private string[] meshAnimationNames = {
            "Idle",
            "Attack1",
            "Attack2",
        };
        public float radius = 100;
        public Vector2 radiusScaler = Vector2.one;
        private List<GameObject> listObj = new List<GameObject>();
        // Start is called before the first frame update
        void Start()
        {
            SpawnCrowd();
            InvokeRepeating("UpdateFPS", 0.0001f, 1f);
        }

        // Update is called once per frame
        void Update()
        {

        }


        void OnGUI()
        {
            if (!showGUI)
                return;
            GUI.skin.label.richText = true;
            GUILayout.BeginArea(new Rect(Screen.width * 0.025f, Screen.height * 0.025f + (guiOffset * Mathf.Max(150f, Screen.height * 0.15f)) + (10 * guiOffset), Screen.width * 0.3f, Mathf.Max(150f, Screen.height * 0.15f)), GUI.skin.box);
            {
                GUI.color = Color.white;
                if (optionsDesc.Length > 1)
                {
                    GUI.color = selectedOption == 0 ? Color.green : Color.white;
                    for (int i = 0; i < optionsDesc.Length; i++)
                    {
                        GUI.color = selectedOption == i ? Color.green : Color.white;
                        if (GUILayout.Button(optionsDesc[i]))
                        {
                            previousSelection = selectedOption;
                            selectedOption = i;
                            SpawnCrowd();
                        }
                    }
                    GUI.color = Color.white;
                }
                else
                {
                    GUILayout.Label("<color=white><size=19><b>" + optionsDesc[0] + "</b></size></color>");
                }
                int size = objCount;
                GUILayout.Label("<color=white><size=19><b>Crowd Size: " + objCount + "</b></size></color>");
                objCount = (int)GUILayout.HorizontalSlider(objCount, 1, maxSize);
                if (size != objCount)
                {
                    CancelInvoke("SpawnCrowd");
                    Invoke("SpawnCrowd", 1);
                }
                else
                {
                    GUILayout.Label("<color=white><size=19><b>FPS: " + fps + "</b></size></color>");
                }
            }
            GUILayout.EndArea();
        }
        void SpawnCrowd()
        {
            int startIndex = 0;
            if (previousSelection == selectedOption)
            {
                startIndex = listObj.Count;
                int toRemove = listObj.Count - objCount;
                if (toRemove > 0)
                {
                    for (int i = 0; i < toRemove; i++)
                    {
                        if (listObj[i]) Destroy(listObj[i]);
                    }
                    listObj.RemoveRange(0, toRemove);
                }
            }
            else
            {
                foreach (var obj in listObj)
                    if (obj) Destroy(obj);
                listObj.Clear();
            }
            previousSelection = selectedOption;

            for (int i = startIndex; i < objCount; i++)
            {
                Vector3 rand = Random.insideUnitCircle * radius;
                Vector3 position = new Vector3(rand.x, 0, rand.y);
                var g = Instantiate(gamePrafabs[selectedOption], position, Quaternion.Euler(0, Random.Range(0, 361), 0), transform);
                if (g.GetComponent<Animator>())
                {
                    int animationIndex = Random.Range(0, meshAnimationNames.Length);
                    Debug.Log(animationIndex);
                    g.GetComponent<Animator>().SetInteger("Anim", animationIndex);
                }
                else if (g.GetComponent<MeshAnimatorBase>())
                {
                    MeshAnimatorBase ma = g.GetComponent<MeshAnimatorBase>();
                    int animationIndex = Random.Range(0, meshAnimationNames.Length);
                    ma.defaultAnimation = ma.animations[animationIndex];
                    ma.Play(animationIndex);
                    ma.SetTimeNormalized(Random.value, true);
                }
                listObj.Add(g);
            }
        }
        void UpdateFPS()
        {
            fps = ((Time.frameCount - previousFrame) / 1f).ToString("00.00");
            previousFrame = Time.frameCount;
        }
    }
}
