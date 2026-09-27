# SAM 2 Tiny — offline garment cutouts

The three unmodified FLOAT16 Core ML packages come from [Apple's SAM 2 Tiny conversion](https://huggingface.co/apple/coreml-sam2-tiny/tree/6d04587b4937500c26afbdeeb9777a336efaeef6), revision `6d04587b4937500c26afbdeeb9777a336efaeef6`.

Upstream SAM 2: [Meta's repository](https://github.com/facebookresearch/sam2). Licensed under Apache 2.0; see `SAM2-LICENSE.txt`. `sam2-manifest.json` pins the source and SHA-256 of every model-package file. Model packages total approximately 79.6 MB. Xcode compiles them into bundled `.mlmodelc` resources through the existing synchronized assets group. No model download or photo upload occurs at runtime.

## Model contract

- Image encoder: 1024 × 1024 RGB image; normalization is baked into the model.
- Prompt encoder: FLOAT16 `points` (1 × N × 2, top-left coordinates in 1024-pixel space) and positive `labels` (1 × N).
- Mask decoder: image embedding, two high-resolution feature maps, sparse/dense prompt embeddings. Outputs three 256 × 256 logit masks and predicted mask-quality scores.
- `SAMGarmentSegmenter` serializes inference and caches the models using Core ML CPU/GPU compute units.

## Integrity check

Run from the repository root:

```python
import hashlib, json
from pathlib import Path
root = Path("assets/Models")
manifest = json.loads((root / "sam2-manifest.json").read_text())
for name, expected in manifest["sha256"].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
```
