#!/usr/bin/env python3
"""Convert the pinned upstream SAM decoder outputs to FLOAT32; weights stay FLOAT16.

Requires coremltools 9.0. Input and output must be different directories.
The input is Apple's unmodified package pinned in sam2-manifest.json upstream_sha256.
"""
import argparse
import hashlib
from pathlib import Path


def convert(source: Path, destination: Path) -> None:
    import coremltools as ct
    from coremltools.proto.FeatureTypes_pb2 import ArrayFeatureType

    if source.resolve() == destination.resolve():
        raise ValueError("Use a separate output directory to preserve the upstream model")
    model_file = source / "Data/com.apple.CoreML/model.mlmodel"
    expected = "24bd23b9267c8ccc172a5370bc3507d4e11f7a33ba14d529dfd904e7ebf50847"
    if hashlib.sha256(model_file.read_bytes()).hexdigest() != expected:
        raise ValueError("Expected the pinned upstream SAM2 Tiny decoder")
    model = ct.models.MLModel(str(source), skip_model_load=True)
    spec = model.get_spec()
    names = ("low_res_masks", "scores")
    # Reserve the public names for the final cast, avoiding an internal-variable collision.
    for name in names:
        ct.models.utils.rename_feature(spec, name, "raw_" + name, rename_inputs=False)
    renamed = ct.models.MLModel(spec, weights_dir=model.weights_dir, skip_model_load=True)
    converted = ct.models.utils.change_input_output_tensor_type(
        renamed, from_type=ArrayFeatureType.FLOAT16, to_type=ArrayFeatureType.FLOAT32
    )
    spec = converted.get_spec()
    for name in names:
        ct.models.utils.rename_feature(spec, "raw_" + name + "_to_fp32", name, rename_inputs=False)
    result = ct.models.MLModel(spec, weights_dir=converted.weights_dir, skip_model_load=True)
    result.save(str(destination))
    relative = "Data/com.apple.CoreML/weights/weight.bin"
    if (source / relative).read_bytes() != (destination / relative).read_bytes():
        raise RuntimeError("Conversion unexpectedly changed the learned weights")
    print("Prepared FLOAT32 outputs with byte-identical FLOAT16 weights")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    convert(args.source, args.destination)
