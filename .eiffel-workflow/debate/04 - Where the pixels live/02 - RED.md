# 02 - RED (lens: simplicity-first, then evidence-against-B per S6)
Spike: `spikesed_hybrid.py`+`.log` (numpy, soft-alpha blob, colour kept under alpha, box blur r=6; P1-raw).

## RED-1 Deflationary
| Datum (P1-raw) | Result |
|---|---|
| Output alpha 1-10 (n=18988), mean level error vs float | B 8-bit premult storage **30.35** (max 217); straight storage + float inside kernel (call it H) **0.25**; naive straight blur 2.53 |
| Output alpha 11-50 / 51-254 | B 3.40 / 0.74; H 0.25 / 0.26; naive straight 1.13 / 0.66 |
| Flattened over grey (the JPEG output) | max error B 0.8, H 0.5 levels; mean B 0.211, H 0.040 |

- **Gather's K1(b) fringe (R 90.6 vs 255) needs colour = transparent black outside the disk.** A cutout whose RGB persists under soft alpha (my run) shows naive straight blur only 2.5 levels off. D4 stands as measured but is the worst case; the real fringe depends on what the cutout writes under alpha 0 (untested; unverified either way).
- For flattened-opaque output B and H are both under one level: **B's storage loss never shows in the JPEG**, so B's stated K1 edge over A is about zero for this use, and B's loss only bites if PNG-with-alpha is saved.
- B pays for: premultiply at load, a lossy `save_png`, `keep_straight_source`, a separate `IMG_MASK`, flush/mark_dirty on every kernel, cairo under every pixel op.
- **Hybrid H = A with premultiplied-only kernels:** straight RGBA in C memory; kernels premultiply in float inside the loop (the 3 RGBA-colour sites: halo, shadow, text shadow); alpha-only and opaque kernels need no conversion. Cairo gets one premultiply copy only for the drawing pass (Gather section 5: 1 + 1 conversions). **It collapses to A**, with a one-line rule "RGBA colour blurs premultiply internally". H beats B on K1 (0.25 vs 30.35 at alpha 1-10) and ties on K2 if drawing is batched.

## RED-2 Acceleration
| Pressure | Effect |
|---|---|
| 10x size / count | Conversion cost scales with pixels: A/H pay O(1) full-image passes if batched; B pays one at load and save. Cairo ARGB32 is capped at 8 bits per channel, so 16-bit or float inputs force a lossy step in B at load. |
| 16-bit/float | stb header has float and 16-bit loaders (stb_image.h), but `STB_IMAGE` wraps 8-bit only (stb_image.e: `data`, `channels` 1-4). Cairo has no float surface. Only A/H can grow a float buffer without a rewrite. Low-alpha loss (30 levels mean at alpha 1-10) is the 8-bit-premult cost B cannot buy back. |
| AI helpers (masks, depth, upscalers) | Want single-channel or float tensors. B plans a separate `IMG_MASK` (so B already needs a second pixel type, defeating K3 "one image type"). `STB_IMAGE` already supports channels 1-4 (stb_image.e:73-81) and `create_image (w,h,channels)`/`copy_image` (simple_stb.e:109, stb_image.e:256). |
| SCOOP | simple_cairo ECF declares `scoop use=thread` (simple_cairo.ecf:16); a cairo surface has explicit flush/dirty state plus `destroy`; handing it between processors is "one owner" only by convention. A plain malloc buffer with a size, stride and channel count is trivially separable.  SCOOP: UNTESTED. |
| cairo/stb version moves | B ties layout to cairo's (`cairo.h:388`); A/H keep one conversion seam. |

## RED-3 Provenance audit of BLUE (GR-12/18/19)
| BLUE claim | Level | Finding |
|---|---|---|
| "ocr_figure_finder.e:374" uses flush/mark_dirty protocol | Gather row D2 + BLUE | **Pipeline error.** Raw read of line 374: only `a_page.flush.do_nothing`. `mark_dirty` appears nowhere in that file (Grep). No in-ecosystem precedent for write-back. |
| "Cairo A8 surface unverified in simple_cairo" | BLUE hedge | Resolvable: `make_with_format` accepts 0..3 (`cairo_surface.e:41-46`), `Format_a8 = 2` (`simple_cairo.e:248`). A8 exists; BLUE need not own a malloc'd mask (but stride/padding rules unread). |
| "`cairo_text_path` absent in simple_cairo" | BLUE | **Confirmed.** Declared in `cairo.h:1502`; zero hits in `*.e` in simple_cairo. |
| "Kernels run on cairo `data` in place" | BLUE | `data` exists (`cairo_surface.e:137`) but there is **no wrapper for `cairo_image_surface_create_for_data`** (header only, `cairo.h:2557`): an own buffer cannot be handed to cairo zero-copy, which also bounds A (copy needed at the seam). |
| "A/D batched 1+1, B 0 mid-pipeline" | Gather section 5 | Derived by reading, not measured. Stands as derived; unscored. |
| K3 "one image type" for B | BLUE | Argued, unscored; contradicted by its own `IMG_MASK`. |
| "compositing uses premult value, accurate to under one level" | BLUE | Matches my flattened run (max 0.8). Stands. It also removes B's own K1 advantage over H. |
| Source/title/pipeline errors | | Source: none. Title: none. **Pipeline: 1** (the :374 citation). |

## Champions (on the record)
- **For A:** Straight RGBA matches what stb loads, what PNG stores, and what the ONNX matte writes; filters need premultiply only where colour is blurred over alpha, which is three sites. Owns its buffer, so float, single-channel and SCOOP separation are open. Wins K1 (H run), K4 (new library, thin bindings). Weak: cairo seam; mitigate with one batched pass.
- **For C:** If cairo is the pixel store anyway, putting blur/morphology in `CAIRO_SURFACE` fills a gap in the owning library (Gather: "No blur, no morphology"), which Larry's rule says to do. Gives every simple_cairo client the kernels. Weak: cohesion (a binding becomes an image library) and it inherits B's 8-bit premultiplied loss.
- **For D:** `STB_IMAGE` already has `data`, `stride`, `channels` 1-4, `create_image`, `copy_image`, `set_pixel`, `fill_rect`, four writers (stb_image.e:19-20, 283-319): the least new code and nothing to premultiply at I/O. Weak: no resize in simple_stb, and kernels in a codec binding blur K4. If cohesion is waived, D plus a kernels class is H with no new pixel type.

## Standing
RED holds: **PREFERRED H (A with premultiplied-only kernels)** over B for this use; overturn trigger: a measured thumbnail run showing the cutout's RGB under alpha 0 is black (then D4's fringe is real for A-naive) AND batched drawing cannot be arranged.
