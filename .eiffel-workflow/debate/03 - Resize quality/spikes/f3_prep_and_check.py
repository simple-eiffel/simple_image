"""Spike F3 harness (2026-10-11). 'prep' writes raw 8-bit inputs and PIL LANCZOS references for the two
resizes the cutout needs; 'check' scores the Eiffel spike's outputs (mean and max absolute difference).

Case A: the model's 320x320 mask enlarged to 1000x680 (gray).
Case B: the 1000x680 RGB frame crop shrunk to 320x320 (the model input).
Usage: python f3_prep_and_check.py prep|check <work_dir> [frame.png] [mask.f32]
"""
import sys, os
import numpy as np
from PIL import Image

mode, work = sys.argv[1], sys.argv[2]
p = lambda n: os.path.join(work, n)
if mode == "prep":
    frame, mask_f32 = sys.argv[3], sys.argv[4]
    crop = Image.open(frame).convert("RGB").crop((400, 400, 1400, 1080))
    np.array(crop, dtype=np.uint8).tofile(p("b_in_1000x680.rgb"))
    np.array(crop.resize((320, 320), Image.Resampling.LANCZOS), dtype=np.uint8).tofile(p("b_ref_320.rgb"))
    m = np.fromfile(mask_f32, dtype=np.float32).reshape(320, 320)
    m = ((m - m.min()) / (m.max() - m.min()) * 255).astype(np.uint8)
    m.tofile(p("a_in_320.gray"))
    np.array(Image.fromarray(m, "L").resize((1000, 680), Image.Resampling.LANCZOS), dtype=np.uint8).tofile(p("a_ref_1000x680.gray"))
    print("prep done")
else:
    for case, ref, n in (("A mask up", "a_ref_1000x680.gray", 1000 * 680), ("B frame down", "b_ref_320.rgb", 320 * 320 * 3)):
        r = np.fromfile(p(ref), dtype=np.uint8).astype(np.int32)
        for method in ("cairo", "lanczos"):
            f = p(ref.replace("_ref_", "_" + method + "_"))
            if not os.path.exists(f):
                print("%-12s %-8s missing" % (case, method)); continue
            g = np.fromfile(f, dtype=np.uint8).astype(np.int32)
            if g.size != n:
                print("%-12s %-8s wrong size %d" % (case, method, g.size)); continue
            d = np.abs(r - g)
            print("%-12s %-8s mean abs diff %.3f  max %d  (pixels off by >8: %.3f%%)" % (case, method, d.mean(), d.max(), (d > 8).mean() * 100))
