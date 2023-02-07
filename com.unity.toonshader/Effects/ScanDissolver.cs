using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UTSCustom
{
    public class ScanDissolver : MonoBehaviour
    {
        public Vector4 origin;
        public Color color;
        public float range = 1f;
        public float scanDuration = 1f;
        public List<Material> targets = new List<Material>();


        // Start is called before the first frame update
        void Start()
        {
            foreach (var target in targets)
            {
                target.SetColor("_ScanDisColor", color);
                target.SetVector("_ScanDisOrigin", origin);
                target.SetFloat("_ScanDisRange", 0f);
            }
        }

        private void OnValidate()
        {
            foreach (var target in targets)
            {
                target.SetVector("_ScanDisOrigin", origin);
                target.SetColor("_ScanDisColor", color);
                target.SetFloat("_ScanDisRange", range);
            }
        }

        // Update is called once per frame
        void Update()
        {
            if (Input.GetKeyDown(KeyCode.Space))
            {
                StartCoroutine(DoScan(scanDuration, Time.deltaTime));
            }
        }

        IEnumerator DoScan(float duration, float dt)
        {
            float elapsed = 0f;
            while (elapsed < duration)
            {
                float currentRange = elapsed * range / duration;
                foreach (var target in targets)
                {
                    target.SetFloat("_ScanDisRange", currentRange);
                }
                yield return null;
                elapsed += dt;
            }
        }
    }
}
