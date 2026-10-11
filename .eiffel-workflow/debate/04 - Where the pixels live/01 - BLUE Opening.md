# 01 - BLUE Opening (champions B)

## Declarations
| Item | Declaration |
|---|---|
| Lens (GR-7) | Ecosystem-reuse / fewest-seams: one pixel store for the whole pipeline, drawing native, kernels in C (F2 settled) |
| Structure (GR-9) | Case for B is a **rope** of three independent strands: S-fidelity (D1, D4: blur is correct in place), S-conversions (section 5 counts), S-ownership (inventory 01 + K4). Each stands alone; B is not a chain through any one of them. Claim 1 is a **chain** (storage is premultiplied -> blur needs premultiplied -> A/D need extra copy); it is weakened below. |
| Composition (G1-G5) | "B is simpler *and* more correct" is filed as two claims: (i) K1 correct in place; (ii) K2/K3 fewer conversions. Scored separately; neither averaged. I do not pre-split claims 1-5; as filed numbers stand. |
| Provenance (S1) | All rows below cite Gather rows (P1-raw D1, D4, spike section 2; P2-m D2, D3; derived section 5). Section 5 B and A/D-batched counts are **derived by reading, not measured**. K3, K6: **no evidence this cycle**; my scores there are argued, unscored (P3 never scores). |

## Concessions (GR-2)
| Datum | Status | Effect on B |
|---|---|---|
| Spike (a): 8-bit round trip max 127 levels, mean 18.6 at alpha 1-10, 2 levels at a=1 | **Stands.** Colour at alpha 1-10 is unrecoverable on unpremultiply; colour under alpha 0 is not stored at all | Claim 1 confidence down: B loses information A/D keep |
| Gather section 3 claim 1: A/D can blur a premultiplied temp copy (spike (ii) is exactly that) | **Stands.** "A/D must blur incorrectly" is overstated: they may convert around each blur | Claim 1 reduces to a cost claim (conversions), not a correctness claim |
| Thumbnail script: most blurs are alpha-only or opaque RGB (lines 50-51, 98-99, 70) | **Stands.** The straight/premultiplied difference arises only in halo, shadow, text shadow (lines 88, 100-101, 116) | K1 advantage of B is narrow in this use |

**When the 127-level loss matters:** only if something reads colour back (unpremultiply) at alpha < 11 and shows it. Compositing uses the premultiplied value directly, which is accurate to under one level of true contribution (colour x alpha/255 cannot exceed 10% of 255 there). Our terminal output is a flattened opaque JPEG (section 5, one flatten at save): pixels at alpha 1-10 contribute under 4% and are not read back. It bites in two places only: (1) saving a cutout as straight RGBA PNG; (2) colour fringe inside near-transparent hair edges after a *re-extraction*.
**Mitigations in the design:** (a) the matte is kept in its own `IMG_MASK` (full 8-bit alpha), so the alpha channel is never degraded; (b) `save_png` of RGBA is documented lossy below alpha 11 and offers `keep_straight_source` (retain the loaded stb buffer until first mutation, so an untouched load-and-save round trip is bit-exact); (c) a test pins the bound (max error at alpha>=11 is 12 levels, at >=51 is 2: spike table).

## Proposed shape of B
| Class | Owns | Notes |
|---|---|---|
| `IMG_IMAGE` (simple_image) | one `CAIRO_SURFACE` ARGB32 (via simple_cairo), width, height, stride | Pixels live in cairo C memory (cairo_surface.e `data`, inventory 01); `pixels_pointer` does flush before, `mark_dirty` after every kernel (D2 protocol, used at ocr_figure_finder.e:374) |
| `IMG_KERNELS` (inline C, one class of externals) | blur, grow/shrink, flood fill, point ops, Lanczos-3 resize, premultiply/unpremultiply | Per F2/F3 verdicts |
| `IMG_MASK` | single-channel 8-bit alpha buffer in malloc'd C memory (own stride) | Kernels blur/grow/shrink run on it directly (straight = premultiplied for one channel, so no conversion). `apply_to (img)` multiplies into the surface; `from_alpha (img)` extracts. Cairo A8 surface is a possible backing, **unverified** in simple_cairo this cycle; plan owns the buffer instead |
| `IMG_CODEC` | calls simple_stb `STB_IMAGE` | `load (path)`: stb straight RGBA -> premultiply into new surface (once). `save_jpg` flattens on a colour (opaque, no unpremultiply). `save_png` unpremultiplies (lossy rule above) |
| `IMG_CUTOUT` (adapter) | simple_onnx session (F1 settled) | Surface RGB -> float tensor in a C buffer (copy, so the unpinned `to_ort_value` hazard, G9, does not touch the surface); model output -> `IMG_MASK` -> `apply_to` |
| Text/shapes/layers | `CAIRO_CONTEXT` on the same surface | Native; no conversion. Outlined text needs `cairo_text_path`, absent in simple_cairo: gap filled in **simple_cairo** (K4), not here |
Dependency direction: simple_image -> simple_cairo, simple_stb, simple_onnx; none depend back. Lifetime: `dispose` destroys the surface; one owner, handed whole between processors.

## Alignment ledger (score 0-5; evidence rows by id)
| K | Evidence rows | A | B | C | D | Reason (B) |
|---|---|---|---|---|---|---|
| K1 | D1, D4, spike (a), (b); section 3 claim 1; script lines 50-51, 70, 88, 98-101, 116 | 3 | 4 | 4 | 3 | In-place premultiplied blur is correct (R 255.0 vs 90.6). A/D can match with temp copies. B pays the alpha<11 loss; held at 4, not 5 |
| K2 | Section 5 counts | 3 | 5 | 5 | 3 | B: 0 mid-pipeline conversions (derived). A/D batched: 1+1; per drawing step: 12+ (derived) |
| K3 | none (argued) | 2 | 4 | 3 | 2 | One image type for blur->composite->text->save; A/D/C expose two |
| K4 | Section 4 K4 row; inventory 01 | 4 | 4 | 2 | 2 | Gaps filled in the owning lib: cairo gaps in simple_cairo, ops in a new image library. C/D put image processing in a binding. |
| K5 | Section 4 K5 row; D2; G9 | 3 | 4 | 4 | 3 | Cairo memory is C memory, no GC move; flush/mark_dirty is a known cost. D's free protocol unread |
| K6 | none (argued) | 3 | 3 | 3 | 4 | Premultiply/surface glue is small; kernels are the same everywhere. D wins on cost, honestly |

**Deployment line:** rely on B for opaque and alpha-only pipelines and for all composite/draw steps; do not rely on it to preserve colour at alpha < 11 or under alpha 0 (use the straight source buffer for that).
**Overturn trigger:** a measured run showing A/D-batched within 5% of B's wall time with no visible fringe moves K2 to parity.
