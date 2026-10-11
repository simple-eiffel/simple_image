"""Spike F4 harness (2026-10-11). 'prep' writes the u2net_human_seg input tensor for a real frame and
Python onnxruntime's reference output; 'check' compares the Eiffel spike's output with the reference.

Usage: python f4_prep_and_check.py prep|check <work_dir> [frame.png]
"""
import sys, os, time
import numpy as np
from PIL import Image

MODEL = r"C:\Users\LJR19\.rembg\models\u2net_human_seg\u2net_human_seg.onnx"
mode, work = sys.argv[1], sys.argv[2]
os.makedirs(work, exist_ok=True)

if mode == "prep":
    import onnxruntime as ort
    frame = sys.argv[3]
    # rembg's preprocessing (BaseSession.normalize), verbatim in numpy
    im = Image.open(frame).convert("RGB").crop((400, 400, 1400, 1080)).resize((320, 320), Image.Resampling.LANCZOS)
    a = np.array(im) / max(np.max(np.array(im)), 1e-6)
    mean, std = (0.485, 0.456, 0.406), (0.229, 0.224, 0.225)
    t = np.zeros((320, 320, 3))
    for c in range(3):
        t[:, :, c] = (a[:, :, c] - mean[c]) / std[c]
    t = np.expand_dims(t.transpose((2, 0, 1)), 0).astype(np.float32)
    t.tofile(os.path.join(work, "in.f32"))
    s = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    t0 = time.perf_counter()
    out = s.run(None, {s.get_inputs()[0].name: t})[0]
    print("python onnxruntime %s: %.0f ms" % (ort.__version__, (time.perf_counter() - t0) * 1000))
    out.astype(np.float32).tofile(os.path.join(work, "ref.f32"))
    print("wrote in.f32 (%d floats) and ref.f32 (%d floats)" % (t.size, out.size))
else:
    ref = np.fromfile(os.path.join(work, "ref.f32"), dtype=np.float32)
    got = np.fromfile(os.path.join(work, "out.f32"), dtype=np.float32)
    print("sizes: ref %d, eiffel %d" % (ref.size, got.size))
    if ref.size == got.size:
        d = np.abs(ref - got)
        print("max abs diff %.3e, mean abs diff %.3e" % (d.max(), d.mean()))
        norm = lambda p: (p - p.min()) / (p.max() - p.min())
        mr, mg = norm(ref) > 0.5, norm(got) > 0.5
        iou = (mr & mg).sum() / max((mr | mg).sum(), 1)
        print("mask IoU at 0.5: %.5f (person pixels: ref %d, eiffel %d)" % (iou, mr.sum(), mg.sum()))
