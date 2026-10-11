# 04 - Where the pixels live: Fork Register

*2026-10-11. Code-lite cycle (5 agents). ROE: General Research ROE v1.0; seats read `C:\Users\LJR19\.claude\skills\eiffel-debate\ROE-CARD.md` (v1.0, gated).*

## Context (read these by path; do not re-derive)
- Goal and requirements: `D:\prod\simple_image\.eiffel-workflow\research\00 - Gathered Facts.md`
- What exists: `...\research\01 - Capability Inventory.md`
- Gaps G1-G9 and forks: `...\research\02 - Gaps and Forks.md`
- Settled by spike (locked inputs, do not reopen): `...\debate\01 - Cutout in Eiffel\04 - VERDICT.md` (simple_onnx runs the
  cutout exactly), `...\02 - Filter speed\04 - VERDICT.md` (per-pixel kernels in inline C), `...\03 - Resize quality\04 - VERDICT.md`
  (our own Lanczos-3 in C; cairo scaling only for drawing-time placement).

## The decision
What is simple_image's image: where do its pixels live, in what format, and which library owns the editing operations
(blur, grow/shrink alpha, flood fill, point operations, resize, premultiply conversion)?

## The pathways
- **A. Own straight-alpha buffer.** `IMG_IMAGE` in simple_image holds straight (non-premultiplied) RGBA bytes in C
  memory. Filters run on it. To draw text, shapes or layers it converts to a cairo surface (premultiply) and back.
  stb loads and saves it directly (stb is straight RGBA).
- **B. Cairo surface is the image.** `IMG_IMAGE` in simple_image wraps a cairo ARGB32 surface (premultiplied BGRA).
  Filters run on its pixels in place; drawing and layering are native cairo; stb at the edges only (premultiply on
  load, unpremultiply on save).
- **C. The operations go into simple_cairo.** CAIRO_SURFACE gains blur, grow/shrink, flood fill, point ops, resize;
  simple_image is a thin facade over simple_cairo + simple_stb (or is not needed).
- **D. Reuse simple_stb's buffer** (the simplest thing that could work): STB_IMAGE already owns straight RGBA pixels
  and file I/O; add the operations to simple_stb (or wrap STB_IMAGE); cairo only for text and shapes.

## Criteria (fixed before evidence; each with its measure)
| # | Criterion | Measure |
|---|---|---|
| K1 | Fidelity | (a) round-trip error of premultiply/unpremultiply on soft alpha (levels, at alpha 1-254); (b) blur of RGBA with transparent regions: colour fringe at alpha edges (straight-alpha blur darkens/tints edges unless done premultiplied) |
| K2 | Conversions | full-image format conversions in the thumbnail pipeline (`youtube_thumb_compose.py`'s steps) per pathway |
| K3 | API simplicity | image types a client handles; calls for "blur this cutout's alpha, outline it, place it on the backdrop, draw outlined text, save JPEG" |
| K4 | Ecosystem fit | "fill gaps in the owning simple_* library"; library cohesion (simple_cairo = cairo binding, simple_stb = stb binding); dependency direction (no cycles) |
| K5 | Memory, lifetime, SCOOP | C memory (not moved by the GC, safe to hand to C kernels and ORT); explicit destroy vs dispose; an image passed between processors |
| K6 | Cost | rough lines of Eiffel + C to build and maintain |

## Filed claims (quantity and modality fixed now)
1. B meets K1 better than A and D in every pipeline with transparency, because correct blur and compositing need premultiplied pixels; A/D must either convert around each blur or blur incorrectly.
2. A and D have the simplest load/save path (no conversion at I/O) but pay a conversion at every drawing step (K2).
3. C puts image processing inside a binding library (K4 against), or is the "owning library" (K4 for); the seats must rule which.
4. D is the least new code (K6) but makes a codec binding own image processing (K4).
5. Any pathway's image must live in C memory (K5) to be handed to inline C kernels and onnxruntime safely.

## S6 / assert-before-retrieve (declared)
The orchestrator leans **B** (cairo surface as the image, operations in simple_image). Every search for B is
confirmation-seeking by sequence; seats should weight evidence against B accordingly.

## Budget plan (Larry's go: 2026-10-11, "go")
| Seat | Agent type | Model | Cap |
|---|---|---|---|
| G - Gather (may run one small numeric spike for K1) | debate-seat | Sonnet | 6 KB |
| 01 - BLUE opening (champions B) | debate-seat | Sonnet | 6 KB |
| 02 - RED (RED-1 deflationary, RED-2 acceleration, RED-3 provenance; champions for A, C, D) | debate-seat | Sonnet | 6 KB |
| 03 - BLUE rebuttal (challenged items only) | debate-seat | Sonnet | 4 KB |
| 04 - VERDICT | debate-adjudicator | Opus | 10 KB |
Estimate 150-200k tokens. Orchestrating session: Opus (stated per Budget rule 1). Spikes F2-F4 ran on the main thread before the cycle.
