# 04 - Where the pixels live: VERDICT

*2026-10-11. Fresh adjudicator (Opus). Code-lite, 5 agents. Locked inputs: verdicts 01 (onnx cutout), 02 (C kernels), 03 (Lanczos-3).*

## 0. Declarations
| Item | Ruling |
|---|---|
| ROE read | General Research ROE **v1.0** (gated 2026-10-06), in full. Theological ROE not read |
| Condition | **C3** without the executed-evidence proposal (BLUE and RED in separate contexts; no named human engaged). **C2** with it (K1 discharged by executed runs, P1-raw) |
| Interest | None (not AI tooling); no -i |
| My reads / S6 | Raw: simple_cairo `cairo_context.e:409` (`mask_surface`), `simple_cairo.e:248` (A8), `cairo_surface.e:139-248`; simple_stb `stb_image.e:36-60,330-345`, `simple_stb.h:34-53`. One spike. Register leaned B (S6); verdict goes against it |

## 1. Procedural rulings
| Item | Ruling |
|---|---|
| Ripe (Rule 8) | Yes. BLUE conceded K1, K3, K4 and moved to H; the only live conflict (K2) is derived on both sides: tie |
| Claim 1 | Composite (G1). Split: (a) "premultiplied *storage* is more faithful" **DISPROVEN**; (b) "A/D must blur incorrectly" **DISPROVEN** (premultiplying in float inside the kernel, or blurring a mask, is exact) |
| Claim 2 | Split: (a) straight I/O with no conversion **supported** (stb straight, cairo.h:388); (b) "a conversion at every drawing step" **UNSUPPORTED** (one copy per placed layer) |
| Claim 4 | Split, "your claim is two claims": D's **storage** (STB_IMAGE buffer) is separable from D's **op ownership** (ops in simple_stb). BLUE's rebuttal rejected both on K4 and "no resize". Neither reason reaches storage: resize is our Lanczos kernel (verdict 03), and K4 objects only to ops in a codec binding |
| H relabel (16-D) | H = **A** + float-premultiplied kernels. No criterion was added. Using D's storage is a declared composition of two filed pathways, not a new pathway |

## 2. External confrontation
| Kind | Items |
|---|---|
| Executed (P1-raw) | `k1_alpha.log` (Gather), `red_hybrid.log` (RED), **`adj_mask_fill.log` (mine)**: a solid-colour layer blurred as an 8-bit mask and filled through it is within max **0.20** / mean 0.014 levels of a float premultiplied blur (identity error 2.8e-14). Naive straight blur on transparent black is off by max **50** / mean 3.02 |
| Read raw | cairo.h:388 (premultiplied); simple_cairo and simple_stb sources (above) |
| Unread (no weight) | Maintainers (none engaged); W3C last 7k chars; A8 stride rules; stb 1-channel writers |

## 3. Scored ledger (confidence / rootedness)
| Item | Status | Conf | Root | Decisive record |
|---|---|---|---|---|
| **H: straight RGBA in C memory, ops in simple_image** | **PREFERRED** | 0.80 | 0.85 | red_hybrid: alpha 1-10 error 0.25 vs B's 30.35; flattened error max 0.5 vs 0.8 |
| B: cairo surface is the image | UNSUPPORTED | 0.25 | 0.80 | Loses at every alpha band; 8-bit only; still needs a mask type; flush/mark_dirty write-back has no ecosystem user |
| C: ops in simple_cairo | UNSUPPORTED | 0.15 | 0.70 | Has B's losses; a blur is not cairo API, so its owning library is not the binding |
| D as filed: ops in simple_stb | UNSUPPORTED | 0.30 | 0.75 | K4. Its storage component is **adopted** (below) |
| A-naive: straight RGBA blur | DISPROVEN for transparent-black layers | 0.90 | 0.90 | D4 R 90.6 vs 255; adj spike max 50 |
| K1: straight storage + float or mask kernels beat 8-bit premultiplied storage | ESTABLISHED | 0.90 | 0.90 | Three executed runs |
| Solid layers (halo, shadow, text shadow) as masks are exact | ESTABLISHED | 0.90 | 0.85 | adj spike; `mask_surface` exists |
| K2: H about equal to B in conversions | PREFERRED (derived) | 0.55 | 0.60 | Gather section 5 by reading; not timed |
| Claim 5: C memory | Supported | 0.85 | 0.85 | simple_stb.h:50 malloc; G9 |
| SCOOP handoff (any pathway) | UNTESTED | - | - | - |

## 4. Deployment lines
| Rely on | Do not rely on |
|---|---|
| Straight 8-bit RGBA keeps colour at every alpha level | Any cairo round trip of a soft-alpha layer to keep colour at alpha < 11 |
| Blur, resize or grow of a solid-colour layer done as a mask blur plus a colour fill | A straight blur of RGBA that has transparent black under alpha 0 |
| Premultiplied copy into cairo for an opaque output (error at most 0.8 levels) | The K2 counts or the seam's speed: derived, not measured |
| A8 copies in and out of cairo, which do no premultiply | STB_IMAGE freeing itself: it has no dispose, only `destroy` (stb_image.e:332) |

## 5. THE DECISION: H, PREFERRED (conf 0.80 / root 0.85)
**simple_image owns straight (non-premultiplied) pixels in C memory and every editing operation. cairo is a drawing seam it copies into. stb does I/O only. onnx sits in simple_image_ai.**

| Class (library) | Representation and role |
|---|---|
| `IMG_IMAGE` (simple_image) | Straight RGBA8, 4 channels as an invariant. Storage is a private `STB_IMAGE` (malloc'd `stb_image_data`: data, w, h, channels, stride), loaded with 4 channels requested. Exposes `pixels: POINTER`, `stride`, never the STB_IMAGE. `load`, `make (w, h)`, `save_png`, `save_jpg (q)` (requires `is_opaque`, or call `flatten_onto (colour)` first), `destroy`, plus a dispose guard. Ops (commands, CQS): `blur`, point ops (brightness, contrast, colour), `vignette`, `crop`, `resized (w, h)`, `alpha: IMG_MASK`, `set_alpha (m)` (RGB under alpha 0 is kept), `flatten_onto`. **Rule:** any kernel that mixes neighbouring RGBA pixels with alpha below 255 premultiplies in float inside the loop and stores straight |
| `IMG_MASK` (simple_image) | One 8-bit channel, stored in STB_IMAGE with 1 channel. `blur`, `grow (n)`, `shrink (n)` (max/min), `threshold`, `flood_fill`, `invert`, `resized`, `from_floats (ptr, w, h)` |
| `IMG_KERNELS` (simple_image) | Inline-C externals only: box blur, max/min, point ops, flood fill, Lanczos-3, premultiply-copy, unpremultiply-copy (verdicts 02 and 03). The Eiffel callers check contracts once per call |
| `IMG_CANVAS` (simple_image) | Owns a `CAIRO_SURFACE` (ARGB32, or A8 for mask drawing) and a `CAIRO_CONTEXT`. `make_from (image)` copies in, premultiplying; the surface is flushed before and marked dirty after. `place (image, x, y, scale)` copies into a temp surface, then `set_source_surface` + paint (cairo scaling is allowed here, per verdict 03). `fill_through (mask, colour, x, y)` copies into A8, then `mask_surface`. `context` is for text and shapes. `to_image` / `to_mask` copy out (exact for opaque or A8) |
| simple_cairo | Gains `cairo_text_path` (outlined text) only. Kernels never go here |
| `IMG_CUTOUT` (simple_image_ai, on simple_image + simple_onnx) | `mask_for (image): IMG_MASK`: Lanczos down to 320x320, normalize into a C float buffer it owns (a copy, which sidesteps G9), one session from `create_session` (no `load` after it; verdict 01), output 0 -> `from_floats` -> Lanczos up -> the caller runs `set_alpha` |

Pipeline: pixel work happens on IMG_IMAGE and IMG_MASK; one canvas per variant; each layer is placed once; each halo, shadow and text shadow is a mask (text is drawn into an A8 canvas, then `to_mask`, `blur`, `fill_through`); one `to_image` at the end, then `save_jpg`. Dependencies: simple_image -> simple_stb, simple_cairo; simple_image_ai -> simple_image, simple_onnx. Acyclic; simple_stb unchanged.

| Overturn trigger (GR-23) | Effect |
|---|---|
| A measured 1280x720 variant where seam copies exceed 5% of wall time and cannot be batched | Reopens B |
| A seam spike where premultiply copy-in plus flush/mark_dirty misrenders | Reopens B or the seam design |
| STB_IMAGE cannot create or write 1 channel, or has a stride other than w x channels | Storage moves to IMG's own malloc buffer (internal change, API unchanged) |
| A required RGBA op that is neither a mask nor float-premultiplied measures over 1 level against a float reference | Reopens the kernel rule |

## 6. Do not assume
| Statement | Why |
|---|---|
| A cairo ARGB32 surface stores a cutout losslessly | DISPROVEN: alpha 1-10 mean 30.35, max 217 (red_hybrid); round-trip max 127 (k1) |
| Straight RGBA blur is safe | DISPROVEN on transparent black: R 90.6 vs 255; max 50 (adj spike) |
| ocr_figure_finder.e:374 is a write-back precedent | Pipeline error: flush only, no `mark_dirty` |
| simple_cairo wraps `create_for_data` / `cairo_text_path` | Neither does (0 hits). Zero-copy is impossible; the seam is a copy |
| The K2 conversion counts are measured | Derived by reading |
| STB_IMAGE frees itself, or its writers handle 1 channel | Explicit `destroy` only; the 1-channel writers are unread |
| W3C states a rule for blur or resize | None found (P2-m, partial read) |
| SCOOP handoff is safe | UNTESTED |

## 7. Verification queue
1. Eiffel seam spike: make_from, place, A8 `fill_through`, to_image at 1280x720. Compare with the numpy reference (within 1 level) and time it (trigger 1 and 2).
2. STB_IMAGE with 1 channel: create, stride, write_png (trigger 3).
3. Lanczos-3 on RGBA with soft alpha, premultiplied in float (verdict 03's own trigger).
4. A real cutout: RGB under alpha 0 after `set_alpha`, then a blur of the placed person.
5. SCOOP: pass an IMG_IMAGE between processors.
6. One full variant end to end against the PIL thumbnail.

## 8. Consequences for spec
| Change | Kind |
|---|---|
| The four IMG_IMAGE invariants: channels = 4, straight alpha, stride = w x 4, C memory | Requirement |
| A test pins the kernel rule: soft-alpha blur within 1 level of a float reference | Requirement |
| Shadows, halos and outlines are masks plus `fill_through`, never RGBA blurs | Requirement |
| simple_cairo: `cairo_text_path`; simple_image_ai is a separate library | Scope |
| Leaks if `destroy` is skipped; flush/mark_dirty has no tested user; one copy per placed layer | Risk / cost |

## 9. Open items for Larry
1. Adopt H as adjudicated? (adoption only; the technical grounds are above)
2. *(proposal)* Executed evidence counts as external confrontation, giving C2 instead of C3.

**Pipeline log:** `find spikes -name EIFGENs` was empty and spikes/ held no *.exe/*.obj/*.lib/*.dll, both checked before writing; nothing deleted. Added `spikes/adj_mask_fill.py` and `.log`. Rerun without `-I` (numpy import failed; own script). No errors beyond RED's :374 pipeline error.

## Larry's gate
APPROVED 2026-10-11: "1. yes" (adopt H as adjudicated). Item 2 (executed evidence counts as external confrontation): APPROVED 2026-10-11 ("I thought the spikes proved the points one way or the other and not just AI or human guessing, speculation, or opinion?"), safeguard: output pasted and the run could have failed. This cycle grades **C2**.
