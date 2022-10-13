using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotate : MonoBehaviour
{
    public float RotateSpeedX = 0;
    public float RotateSpeedY = 0;
    public float RotateSpeedZ = 0;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        float rotateDegreeX = Time.deltaTime * RotateSpeedX;
        float rotateDegreeY = Time.deltaTime * RotateSpeedY;
        float rotateDegreeZ = Time.deltaTime * RotateSpeedZ;
        this.transform.Rotate(Vector3.right, rotateDegreeX, Space.World);
        this.transform.Rotate(Vector3.up, rotateDegreeY, Space.World);
        this.transform.Rotate(Vector3.forward, rotateDegreeZ, Space.World);
    }
}
