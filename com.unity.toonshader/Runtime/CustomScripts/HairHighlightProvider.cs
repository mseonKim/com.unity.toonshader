using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UTSCustom
{
    public class HairHighlightProvider : MonoBehaviour
    {
        public Transform headWorldTransform;
        public Transform headUpWorldTransform;
        public Material hairMaterial;
        private string headPosPropertyName = "_HeadWorldPos";
        private string headUpDirPropertyName = "_HeadUpWorldDir";

        void OnValidate()
        {
            if (headWorldTransform != null && headUpWorldTransform != null)
            {
                Vector3 headUpDir = headUpWorldTransform.position - headWorldTransform.position;
                hairMaterial.SetVector(headPosPropertyName, headWorldTransform.position);
                hairMaterial.SetVector(headUpDirPropertyName, headUpDir.normalized);
            }
        }

        void Update()
        {
            if (headWorldTransform != null && headUpWorldTransform != null)
            {
                Vector3 headUpDir = headUpWorldTransform.position - headWorldTransform.position;
                hairMaterial.SetVector(headPosPropertyName, headWorldTransform.position);
                hairMaterial.SetVector(headUpDirPropertyName, headUpDir.normalized);
            }
        }
    }
}
