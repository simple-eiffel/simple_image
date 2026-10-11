# Gaps and forks (2026-10-11)

## The gaps, named (what the Python does that no simple_* library does)

| # | Gap | Python today | Owner |
|---|---|---|---|
| G1 | **Pixel bridge**: straight RGBA (stb) to and from premultiplied BGRA (cairo), one image type the tools share | numpy/PIL arrays | simple_image |
| G2 | **Blur**: Gaussian, radius 1.5-40, on RGBA and on alpha alone | ImageFilter.GaussianBlur (12) | simple_image |
| G3 | **Morphology**: grow and shrink alpha (max/min filter, sizes 3-19) | MaxFilter/MinFilter (9) | simple_image |
| G4 | **Connected piece**: keep what touches a seed (flood fill on a mask) | ImageDraw.floodfill (2) | simple_image |
| G5 | **Point operations**: threshold, scale alpha, brightness, contrast | point / ImageEnhance (14) | simple_image |
| G6 | **High-quality resize** (Lanczos-class) of RGBA and of a mask | resize LANCZOS (6) | simple_image (or cairo's filter) |
| G7 | **Outlined text**: text as a path, stroked black then filled | draw.text stroke_width (9) | simple_cairo (`cairo_text_path`) |
| G8 | **The person cutout**: u2net_human_seg pre/post-processing and a verified run | rembg | simple_image_ai (+ simple_onnx fixes) |
| G9 | **Tensor memory safety**: ORT reads Eiffel array memory unpinned | (n/a) | simple_onnx |

Not gaps (already covered): JPEG/PNG read and write (simple_stb, quality 1-100); compositing, paths, rounded
rectangles, clipping, font measuring (simple_cairo); video frames (ffmpeg CLI); fonts by family name (Impact,
Arial Black, Georgia are installed system fonts, so .ttf-by-path is not needed now).

## The forks (design decisions with rival answers)

### F1. Where the pixels live (costly to reverse: the public API shape) -> DEBATE
- **A. Own buffer**: simple_image's `IMG_IMAGE` keeps straight RGBA bytes; filters work on it; it converts to a
  cairo surface for drawing and text, and back.
- **B. Cairo surface is the image**: `IMG_IMAGE` wraps a cairo ARGB32 surface (premultiplied); filters work on
  its pixels in place; stb only at load and save.
- **C. Filters inside simple_cairo**: add blur/morphology/point ops to CAIRO_SURFACE; simple_image is only a thin
  facade (or not needed).
- Criteria: no lost precision (premultiplication rounding on soft alpha edges), conversions per typical pipeline,
  API simplicity for the thumbnail use, memory, SCOOP-friendliness, fits "fill gaps in the owning library".

### F2. How the filters run -> SETTLE BY SPIKE
Pure Eiffel loops vs inline C kernels. One run decides it: a 1280x720 RGBA Gaussian blur (radius 20) and a
max-filter (size 17), timed in F_code. Criterion: under 150 ms each (the composer runs a dozen filters).

### F3. Resize quality -> SETTLE BY SPIKE
Cairo's Filter_best scaling vs a Lanczos-3 kernel of our own, on the 320x320 mask scaled to 1000x680 and the
frame scaled down. Criterion: mean absolute difference from PIL's Lanczos under 2 levels of 255.

### F4. The cutout runs in Eiffel -> SETTLE BY SPIKE
simple_onnx as it is runs u2net_human_seg on a real frame; the mask matches rembg's (IoU >= 0.98 at threshold 128)
and the time is noted. If the unpinned-memory risk (G9) shows, that run says so.
