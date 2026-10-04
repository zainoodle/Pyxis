# SAM 2 Tiny — offline garment cutouts

The three FLOAT16 Core ML packages originate from [Apple's SAM 2 Tiny conversion](https://huggingface.co/apple/coreml-sam2-tiny/tree/6d04587b4937500c26afbdeeb9777a336efaeef6), revision `6d04587b4937500c26afbdeeb9777a336efaeef6`.

Upstream SAM 2: [Meta's repository](https://github.com/facebookresearch/sam2). Licensed under Apache 2.0; see `SAM2-LICENSE.txt`. `sam2-manifest.json` pins both the upstream source hashes and the shipped hashes. The decoder has a compatibility conversion described below; its learned weights are byte-identical to upstream. Model packages total approximately 79.6 MB. Xcode compiles them into bundled `.mlmodelc` resources through the existing synchronized assets group. No model download or photo upload occurs at runtime.

## Model contract

- Image encoder: 1024 × 1024 RGB image; normalization is baked into the model.
- Prompt encoder: FLOAT16 `points` (1 × N × 2, top-left coordinates in 1024-pixel space) and positive `labels` (1 × N).
- Mask decoder: image embedding, two high-resolution feature maps, sparse/dense prompt embeddings. Outputs three 256 × 256 logit masks and predicted mask-quality scores as FLOAT32; internal computations and learned weights remain FLOAT16.
- `SAMGarmentSegmenter` serializes inference and caches the models using Core ML CPU/GPU compute units on physical devices and CPU-only inference in Simulator.

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

## iOS output compatibility

The upstream decoder produced all-zero FLOAT16 mask outputs on iOS 26.5/27 Simulator, even with plausible confidence scores. The shipped decoder adds FLOAT32 output casts. This changes the output representation, not the learned weights or acceptance thresholds. Model specification 8 / CoreML7 (iOS 17) remains unchanged. Simulator uses CPU inference because its GPU path also produced divergent confidence scores; physical-device numerical and performance validation remains required.

Reproduce from the pinned **upstream** decoder in a separate directory with `coremltools==9.0`:

```sh
python scripts/prepare_sam_decoder.py /path/to/upstream/SAM2TinyMaskDecoderFLOAT16.mlpackage /path/to/output/SAM2TinyMaskDecoderFLOAT16.mlpackage
```

The script checks the upstream model hash and asserts that learned weights remain byte-identical. Core ML package manifest UUIDs may vary between runs; the shipped manifest records the actual installed package hashes. Never overwrite the upstream input. Check inference with and without Vision hints using the optional integration test, then import an opaque photo in native iOS; macOS success alone is insufficient.
