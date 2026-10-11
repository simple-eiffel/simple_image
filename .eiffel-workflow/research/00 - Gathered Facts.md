# simple_image / simple_image_ai: gathered facts

*2026-10-11. Inputs for the design debate. Every item here was executed or read raw this session (P1-raw) unless marked.*

## The goal

Replace the Python image work around simple_prompter (YouTube thumbnails, the Facebook Reel cover,
the person cutout) with Eiffel, as two simple_* libraries (names agreed with Larry 2026-10-11):

- **simple_image**: image editing, no AI. Open and save, pixels, crop and resize, filters, layering, text and shapes.
- **simple_image_ai**: AI helpers on simple_onnx. First helper: the person cutout (what rembg does today).

Larry, 2026-10-11: "Within this range, I think we will find that the tools are image-editing tools with AI-helpers."

## What the Python does today (the requirements)

Counted from `D:\prod\scripts\python\youtube_thumb_compose.py` and the reel kit prototype
(`scratchpad\reelkit\build_reel_kit.py`), PIL calls by frequency:

| Operation | Calls | Used for |
|---|---|---|
| GaussianBlur | 12 | blurred backdrop (radius 14-40), soft outline edge (1.5), drop shadow (22-26) |
| Image.new / convert / split / merge / putalpha | 12/13/12/2/5 | RGBA buffers, separating and replacing the alpha channel |
| alpha_composite / composite (with mask) | 10/3 | layering: shadow, white outline, person, icon, text onto the backdrop |
| ImageFont.truetype + draw.text (stroke_width, anchor) | 10/9 | Impact / Arial Black / Georgia text with black outline, centred |
| textlength / textbbox | 2/1 | fit text to a width (shrink until it fits) |
| MaxFilter / MinFilter (sizes 3-19) | 7/2 | grow the alpha for the white outline; close pinholes (morphological dilate/erode) |
| resize (LANCZOS) / crop / paste | 6/3/1 | scale the cutout, crop the frame, place the icon |
| point (threshold, scale alpha) | 6 | alpha to a hard mask; fade shadow to 85% |
| ImageEnhance Brightness / Contrast | 5/3 | darken the backdrop, brighten the person slightly |
| rectangle / rounded_rectangle / line / ellipse / polygon (mask) | 3/3/3/1/2 | strike-through line, gold frame, vignette, chair-removal polygon |
| floodfill | 2 | keep the piece of the alpha connected to a seed (drop chair scraps) |
| Image.open / save | 5/3 | PNG frames in (from ffmpeg), JPEG out (quality 92), PNG out |

Video frames come from ffmpeg (PNG), which Eiffel already drives (simple_process).

## The AI helper's recipe (rembg u2net_human_seg, read raw from rembg's installed source)

- Model file: `C:\Users\LJR19\.rembg\models\u2net_human_seg\u2net_human_seg.onnx` (175,997,641 bytes).
- Input `input.1`: float32 `[1, 3, 320, 320]`. Preprocess: RGB, resize to 320x320 (Lanczos), divide by the
  image's max value, per channel `(x - mean) / std` with mean (0.485, 0.456, 0.406), std (0.229, 0.224, 0.225), HWC to CHW.
- Outputs: 7 tensors, each float32 `[1, 1, 320, 320]`; rembg uses the first (`1959`).
- Postprocess: `(pred - min) / (max - min)`, times 255 to an 8-bit mask, resize back to the image size (Lanczos), apply as alpha.
- Measured cost in Python today: about 2-3 s per frame on CPU (from the thumbnail runs, informal).

## Ecosystem facts already established this session

- simple_process: `SIMPLE_ASYNC_PROCESS.start_in_directory` exists (working folder); `SIMPLE_PIPED_PROCESS` merges stderr into stdout by default.
- ffmpeg 8.x is on PATH and already the program's video engine.
- simple_cairo: drawing library (3,705 lines). Capability inventory: see `01 - Capability Inventory.md`.
- simple_onnx: classes ONNX_SESSION, ONNX_TENSOR, ONNX_MODEL, ONNX_PROVIDER... and `lib/onnxruntime`. Whether inference
  runs end to end: see the inventory.

## Constraints (standing rules)

- simple_* only; fill gaps in the owning simple_* library; no ISE libraries beyond base/testing (and time).
- Inline C in Eiffel externals; no separate .c files.
- SCOOP-compatible, void-safe, DBC; invariants O(1).
- No Python in the product.
- Windows 11 is the platform.
