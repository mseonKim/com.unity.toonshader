using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UTSCustom
{
    public class SDFFaceForwardProvider : MonoBehaviour
    {
        public Transform headFront;
        public Transform headBack;
        public Material faceMaterial;
        private string sdfPropertyName = "_FaceForward";

        void OnValidate()
        {
            if (headFront != null && headBack != null)
            {
                Vector3 dir = headFront.position - headBack.position;
                faceMaterial.SetVector(sdfPropertyName, dir.normalized);
            }
        }

        // Update is called once per frame
        void Update()
        {
            if (headFront != null && headBack != null)
            {
                Vector3 dir = headFront.position - headBack.position;
                faceMaterial.SetVector(sdfPropertyName, dir.normalized);
            }
        }
    }
}
