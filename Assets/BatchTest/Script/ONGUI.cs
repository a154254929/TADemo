using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ONGUI : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void OnGUI()
    {
        Rect rect = new Rect(50, 200, 200, 200);
        GUI.Label(rect, "I am GUI");
        rect.y += 100;
        GUI.Label(rect, "I am GUI");
    }
}
