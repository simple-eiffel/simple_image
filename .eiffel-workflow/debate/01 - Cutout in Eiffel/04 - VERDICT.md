# 01 - Cutout in Eiffel: VERDICT (settled by spike)

*2026-10-11. Mode: settled-by-spike (Budget rule 2). One run on the main thread; no seats.*

**Claim:** simple_onnx as it is runs rembg's u2net_human_seg model correctly from Eiffel.

**The run** (`spikes/`: `f4_spike.ecf`, `src/f4_spike.e`, `f4_prep_and_check.py`, logs):
1. Python wrote the model's input tensor for a real frame (Reel 4, 1000x680 crop, rembg's own preprocessing) and
   Python onnxruntime 1.23.2's first output (`f4_prep.log`: 239 ms).
2. The Eiffel spike (simple_onnx, onnxruntime 1.17.3 CPU, ec.sh test build with contracts on) loaded the model
   (303 ms), ran it three times (204, 169, 165 ms) and wrote its first output (`f4_eiffel_run.log`).
3. Comparison (`f4_check.log`): 102,400 floats each; **max abs diff 5.4e-7**, mean 1.5e-8; mask IoU at 0.5
   **1.00000** (51,186 person pixels in both).

**Decision:** simple_image_ai runs the cutout through simple_onnx. **ESTABLISHED** (executed, P1-raw, the
disconfirming outcome was possible and did not occur). Confidence 0.95, rootedness 0.95.

**Found on the way:** `SIMPLE_ONNX.create_session` returns a session that is already loaded; calling `load`
again violates its `not_already_loaded` precondition. simple_image_ai must not call `load` after `create_session`.

**Overturn triggers:** an onnxruntime DLL upgrade; a frame where the masks differ (IoU < 0.98); a crash or wrong
output across many runs in one process (would be the unpinned-memory risk, G9, showing).

**Do not assume:**
- That G9 (Eiffel array memory handed to ORT unpinned) is harmless: it did not show in three runs; fix it in simple_onnx anyway (copy into C memory).
- That GPU is available: the shipped onnxruntime.dll is CPU-only; the 165-204 ms here is CPU.
- That `execute` reads any output but the first: it returns output 0 only (enough for rembg's recipe).
