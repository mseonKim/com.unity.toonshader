using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UTSCustom
{
    public class SDFFaceForwardProvider : MonoBehaviour
    {
        public Transform headFront;
        public Transform headCenter;
        public Transform headUp;
        public Material faceMaterial;
        private string faceForwardVectorString = "_FaceForward";
        private string faceUpVectorString = "_FaceUp";

        void OnValidate()
        {
            if (headFront != null && headCenter != null)
            {
                Vector3 dir = headFront.position - headCenter.position;
                faceMaterial.SetVector(faceForwardVectorString, dir.normalized);
            }
        }

        // Update is called once per frame
        void Update()
        {
            if (headFront != null && headCenter != null)
            {
                Vector3 dir = headFront.position - headCenter.position;
                faceMaterial.SetVector(faceForwardVectorString, dir.normalized);
            }

            if (headUp != null && headCenter != null)
            {
                Vector3 dir = headUp.position - headCenter.position;
                faceMaterial.SetVector(faceUpVectorString, dir.normalized);
            }
        }
    }
}
