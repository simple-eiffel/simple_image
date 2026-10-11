# Changelog

All notable changes to simple_image will be documented in this file.

## [0.2.0] - 2026-10-11

### Added
- IMG_MASK.bounds (level): the smallest rectangle holding the values at or above a level
  (where the person is in a cutout), from a C kernel.

### Changed
- File names may hold any Unicode character (needs simple_stb 1.2.0); the ASCII-only
  preconditions are gone. Tests: bounds, and a PNG round trip through a name with an
  en dash and curly quotes. 29 tests.

## [0.1.0] - 2026-10-11

### Added
- IMG_IMAGE: straight RGBA8 in C memory (a private STB_IMAGE): pixel access, fill, blur
  (three box passes, premultiplied in float), Lanczos-3 resize (premultiplied in float),
  crop, brightness, contrast, color (PIL ImageEnhance), vignette, flatten, alpha and
  set_alpha (color under alpha 0 kept), copy/is_equal on the pixels, PNG/JPEG save.
- IMG_MASK: one 8-bit channel: blur, grow, shrink, threshold, invert, flood fill,
  keep_largest_piece (with its soft edge), resize, crop, make_from_floats (min-max),
  gray PNG save.
- IMG_CANVAS: the cairo seam: make_from, place, place_sized, fill_through (color through
  a mask), fill, to_image; mask canvases (A8) with to_mask.
- SIMPLE_IMAGE facade: load, load_mask, new_image, new_mask, new_canvas, new_mask_canvas,
  canvas_from, gray_of.
- Clib/simple_image.h: the C kernels (pure functions, no mutable statics).
- 27 tests, including an independent float reference for the blur (within 1 level),
  soft-edge color after blur and resize, an exact canvas round trip for opaque pixels,
  and a 1280x720 seam timing (8 ms).
- Design record: .eiffel-workflow/ (research, four forks, three settled by spike, one by
  a debate cycle; adopted by Larry 2026-10-11).
