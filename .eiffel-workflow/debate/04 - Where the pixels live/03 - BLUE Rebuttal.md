# 03 - BLUE Rebuttal (lens unchanged: fewest seams; pathway changed, see Standing)

## Challenged data (GR-5: all engaged)
| # | RED datum (tier) | Action | Evidence / effect |
|---|---|---|---|
| 1 | `ocr_figure_finder.e:374` cited as flush/mark_dirty precedent (RED-3) | **Concede, pipeline error** (mine, carried from Gather D2 row) | Re-read (P1-raw): line 374 is only `a_page.flush.do_nothing`; Grep `mark_dirty` in that file: 0 hits. The protocol is documented in `cairo_surface.e:140,243` but has **no in-ecosystem write-back user**. B's flush/dirty discipline is untested code |
| 2 | Low-alpha loss: B 30.35 mean (max 217) at alpha 1-10 vs H 0.25 (`spikes\red_hybrid.log`, P1-raw) | **Concede, stands** | Log re-read: lines match RED's table. My opening held K1 B at 4; drop to 3. B is strictly lossier than straight+float kernel at every alpha band (3.40 vs 0.25; 0.74 vs 0.26) |
| 3 | Flattened JPEG: B max 0.8, H 0.5 levels | **Concede, stands** | Log line 4-5. B's K1 edge over H for opaque output is nil; my claim 1 (B better on K1) is **withdrawn as filed**: A/H meet K1 at least as well. As-filed number (0.6 conf) stays on record, not revised upward |
| 4 | D4 fringe (R 90.6) needs transparent-BLACK outside; real cutouts keep RGB under soft alpha, naive straight blur only 2.53 | **Concede the narrowing; add a point against B** | Not run on the real model (no matte this cycle: UNTESTED). By my own design B's `apply_to` premultiplies the matte into the surface, which **discards** RGB under alpha 0 that straight storage keeps. That is a B cost, not a benefit |
| 5 | Cairo A8 exists (`make_with_format` 0..3, `Format_a8 = 2`) | **Concede** (my "unverified" resolved) | Stride/padding rules unread: unverified. IMG_MASK can be A8 or malloc; no longer a reason for B |
| 6 | No wrapper for `cairo_image_surface_create_for_data` | **Verified** (Grep `create_for_data` in simple_cairo `*.e`: 0 files) | Bounds H: the seam is one copy (premultiply-into the surface's own `data`, flush/mark_dirty around it). Cost of H is one batched copy-in and one flatten, as Gather section 5 counts |
| 7 | `cairo_text_path` absent | **Agree** | SHARED gap, not discriminating; fill in simple_cairo |
| 8 | K3 "one image type" contradicted by `IMG_MASK` | **Concede** | B and H both expose image + mask; K3 B 4 -> 3, ties A |
| 9 | 16-bit/float growth: cairo is 8-bit; STB_IMAGE wraps 8-bit only | **Concede as structural** | Needs a future float path; H owns its buffer, B cannot. Untested need, but B closes the door |
| 10 | SCOOP separation | **Narrow** | Both UNTESTED; unscored |

Conflict (H vs B conversion counts): both derived from Gather section 5, unmeasured; pixel ops precede drawing in the script, so one batch is available: tie.

## Ledger (revised, 0-5; unscored where no evidence)
| K | A/H | B | C | D |
|---|---|---|---|---|
| K1 | 4 | 3 | 3 | 3 (no float kernels) |
| K2 | 4 | 5 | 5 | 3 |
| K3 | 3 | 3 | 3 | 2 |
| K4 | 4 | 3 | 2 | 2 |
| K5 | 4 | 3 | 3 | 3 |
| K6 | 3 | 3 | 3 | 4 |
K4 B 4->3: no write-back precedent (row 1).

## Standing
| Item | Statement |
|---|---|
| Pathway I now champion | **H (A with float-inside kernels)**: `IMG_IMAGE` = straight RGBA in C memory (reusing STB_IMAGE memory is D, rejected on K4 and no resize); kernels premultiply in float where colour is blurred over alpha; one batched copy-in to a cairo surface for text/shapes/layers; `cairo_text_path` added to simple_cairo |
| What of B survives | Cairo for drawing; `IMG_MASK` single-channel kernels; Lanczos-3 and kernels in one C class |
| Status | H: PREFERRED (wins only vs rivals considered; GR-4). B: UNSUPPORTED on K1 as filed |
| Deployment line | Rely on H for load/save without premultiply loss and for float growth; do not rely on its K2 count (derived, unmeasured) or on the real-cutout fringe (UNTESTED) |
| Overturn trigger | A measured thumbnail run where batched drawing cannot be arranged, or copy-in cost exceeds 5% of wall time, restores B |
