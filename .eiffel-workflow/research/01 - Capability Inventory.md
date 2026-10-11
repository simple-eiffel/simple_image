# Capability inventory (2026-10-11)

*From a read-only agent pass over the libraries' source (128k tokens, citations are file:line in D:\prod). Spot-checked: simple_stb write_jpg (stb_image.e:319, quality 1-100).*

## simple_cairo 1.17.2 (depends on base only; cairo.dll on PATH)
- ARGB32 image surfaces: `CAIRO_SURFACE.make (w,h)` cairo_surface.e:30; pixel access `data` :137, `stride` :129, `flush` :234, `mark_dirty` :243 (used by simple_ocr_capture ocr_figure_finder.e:374).
- PNG both ways: `make_from_png` :65, `write_png` :272.
- Text: toy API by family name (`select_font` cairo_context.e:548, `show_text` :571); font face only from HFONT/LOGFONTW (cairo_font_face.e:74/83). **No .ttf by path. No `cairo_text_path` / `glyph_path`** (so no outlined text). Measuring: `text_extents` :600, `font_extents` :616.
- Paths: move/line/curve/arc/rectangle/rounded_rectangle/close; stroke/fill/paint/paint_alpha; clip; 29 operators (`set_operator` :369); `set_source_surface` :389, `mask_surface` :409, groups :827; transforms :443-501; `CAIRO_SURFACE_PATTERN` with Filter_best/Filter_gaussian (cairo_pattern.e:60,91,94). **No `cairo_pattern_set_matrix`** (scale through the context).
- **No blur, no morphology, no pixel filters.**
- Memory layout: premultiplied ARGB32 (BGRA bytes on little-endian).

## simple_stb (depends on base only)
- Vendors stb_image.h + stb_image_write.h (Clib\simple_stb.h:19-20).
- Load file: `SIMPLE_STB.load` :58, `load_rgb` / `load_rgba` :68/78, `image_info` :150. Memory decode exists in C (h:76), unbound.
- `STB_IMAGE`: `data` :91, `stride` :83, `channels` :73; `write_png`, `write_bmp`, `write_tga`, `write_jpg (file, quality)` :283-319.
- **Straight (non-premultiplied) RGB(A)**: nothing converts to or from cairo's premultiplied BGRA. **No resize.**

## simple_onnx (onnxruntime 1.17.3, CPU-only DLL)
- Inference is implemented: load model (simple_onnx.e:26), session (onnx_session.e:79), any-rank float32 tensors (`create_shape` :137, `create_tensor_float32` :101, `set_data_from_array` onnx_tensor.e:218), `execute` :112 (input/output 0), `execute_multi` :161 (returns only the first output), outputs `to_array` :284.
- Gaps: CPU only (provider setting ignored); input/output shapes and dtypes never filled (onnx_model.e:142); f16/bool tensors return null; `to_ort_value` hands Eiffel array memory to ORT without pinning (GC move risk). **No test runs a real model.**

## simple_ffmpeg
- CLI mode works (process wrapper): `extract_frame (video, t, out_file)` ffmpeg_cli.e:211, probe, transcode, resize_video. SDK mode (raw frames) is declarations only, no C behind it.

## simple_vision
- Vision2-based (`SV_IMAGE` wraps EV_PIXMAP, PNG save only). GUI-bound: unsuitable here.

## Not present anywhere
- WIC, GDI+, libpng, libjpeg: zero hits (simple_shaping states "ZERO WIC, ZERO COM").
