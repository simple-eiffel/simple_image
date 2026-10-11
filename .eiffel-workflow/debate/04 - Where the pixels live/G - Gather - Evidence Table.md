# G - Gather - Evidence Table (2026-10-11)
Tiers: P1-raw read/run this cycle; P2-m summarizer-read (ceiling 0.70).

## 1. Open discovery (GR-20): premultiplied vs straight alpha
| # | Source (tier, P, version, as-of) | What it says | Path/URL |
|---|---|---|---|
| D1 | cairo.h comment, T1, P1-raw, cairo 1.17.2, 2026-10-11 | ARGB32: "Pre-multiplied alpha is used. (That is, 50% transparent red is 0x80800000, not 0x80ff0000.)" | D:\prod\simple_cairo\Clib\cairo.h:388-392 |
| D2 | cairo manual, T1 vendor, P2-m, 2026-10-11 | Same ARGB32 sentence; get_data needs `cairo_surface_flush()` before read, `mark_dirty()` after write | https://www.cairographics.org/manual/cairo-Image-Surfaces.html |
| D3 | W3C Compositing 1, T1 standard, P2-m (first 100k of 107k chars), 2026-10-11 | Sec 5.1: premultiplied is "more efficient to store"; co = cs + cb(1-as); un-premultiply Co = co/ao. Sec 10: "blending calculations must not use pre-multiplied color values". **No statement found on blur or resize** (last 7k chars unread) | https://www.w3.org/TR/compositing-1/ |
| D4 | Spike K1(b), P1-raw | Blur on straight RGBA over a transparent-black background darkens edge colour (section 2) | spikes\k1_alpha.log |

Neither D1-D3 states a rule for blur or resize; D4 is the only blur datum.

## 2. K1 spike (executed; `spikes\k1_alpha.py`, log `spikes\k1_alpha.log`; numpy venv python)
| Test | Result (P1-raw) |
|---|---|
| (a) 8-bit premultiply (c*a/255 rounded), unpremultiply (c*255/a rounded), all c 0-255, a 1-254 | max error **127** levels, mean **1.47** |
| By alpha band | a 1-3: max 127, mean 38.8 / a 1-10: max 127, mean 18.6 / a 11-50: max 12, mean 2.48 / a 51-127: max 2, mean 0.74 / a 128-254: max 1, mean 0.25 |
| a=1 | only 2 distinct output colour levels (0 and 255): colour destroyed at alpha 1-3 |
| (b) 64x64 red (255,0,0) disk r=14, transparent black (0,0,0,0) outside, box blur r=4; 624 pixels with alpha 10-200 | (i) straight channels blurred independently: edge R mean **90.6**, min 13 (true 255), darkened. (ii) premultiply, blur, unpremultiply: edge R mean **255.0**, min 255 |

Caveat: (b) uses transparent BLACK outside; cutouts keeping person colour under alpha 0 were not tested.

## 3. Filed claims: evidence bearing on each
| Claim | For | Against / limits |
|---|---|---|
| 1 B best on K1 | D4: straight blur (A, D) darkens edges, R 90.6 vs 255; D1: cairo storage is premultiplied | A/D can blur a premultiplied temporary copy (spike (ii) is exactly that). In the thumbnail script most filters run on the alpha channel alone (lines 50-51, 98-99) or opaque RGB (line 70), where straight = premultiplied; RGBA colour blur occurs on solid-colour+alpha layers (halo line 88, shadow lines 100-101, text shadow line 116). Round-trip loss is large only at alpha < 11 |
| 2 A/D simple I/O, pay per drawing step | stb straight RGBA (inventory 01); cairo premultiplied (D1) | Count depends on batching the drawing into one cairo pass (section 5) |
| 3 C owning library or K4 against | inventory 01: CAIRO_SURFACE "No blur, no morphology, no pixel filters"; simple_cairo depends on base only | No datum on cohesion; a policy ruling, not data |
| 4 D least code, K4 against | inventory 01: STB_IMAGE has data :91, stride :83, channels :73, write_png/bmp/tga/jpg; **no resize** | G6 resize and G7 outlined text (no `cairo_text_path` in simple_cairo) still need other code |
| 5 C memory required | G9: simple_onnx `to_ort_value` hands Eiffel array memory to ORT unpinned (inventory 01); cairo `data` cairo_surface.e:137; STB_IMAGE `data` :91 | No datum read on whether Eiffel arrays can be pinned; not found = unverified |

## 4. K1-K6 by pathway
| K | A own straight | B cairo surface | C ops in simple_cairo | D reuse STB_IMAGE |
|---|---|---|---|---|
| K1 | straight filters: edge darkening unless premult temp copy; alpha-only filters unaffected | premultiplied in place: blur correct; colour at alpha 1-10 not recoverable on unpremultiply | as B | as A |
| K2 | section 5 | section 5 | as B | as A |
| K3, K6 | not evidenced / not measured this cycle | | | |
| K4 | new simple_image owns ops; bindings stay thin | simple_image depends on simple_cairo + simple_stb | simple_cairo gains non-cairo ops | simple_stb (codec) gains ops |
| K5 | own C buffer (new code) | cairo owns memory; flush/mark_dirty protocol (D2), used at ocr_figure_finder.e:374 | as B | STB_IMAGE owns C memory; free protocol not read |

## 5. K2: `D:\prod\scripts\python\youtube_thumb_compose.py` (PIL, straight RGBA throughout)
Steps per variant: background (opaque RGB: resize, blur, brightness, vignette) `.convert("RGBA")` -> paste_icon (halo layer, blur, 2 composites) -> paste_person (resize; alpha-only max/blur; `convert("RGB")` to enhance, `merge` back; 3 composites) -> struck line -> scoreboard (blurred shadow panel, shapes, text) -> per text line: blurred shadow layer + composite + stroked text -> `convert("RGB").save(95)`. At load: frame RGB, cutout RGBA.
| Count | Value |
|---|---|
| Today (PIL), full-image format conversions per variant | **3** (RGB->RGBA; RGBA->RGB for enhance, merged back; RGBA->RGB for save); plus 2 at load |
| A/D, one cairo batch (pixel ops first, one cairo session for all drawing) | 1 premultiply + 1 flatten at save (derived by reading; not measured) |
| A/D, cairo per drawing step | roughly 12+ premultiply/unpremultiply pairs (derived; not measured) |
| B | premultiply at load (frame, cutout), 0 mid-pipeline, 1 flatten to opaque at save (derived) |

## Notable
1. Cairo's contract is premultiplied (header, P1-raw); straight blur of a transparent-black disk darkened edge R from 255 to a mean 90.6, while premultiplied blur kept 255.0 (executed).
2. The 8-bit round trip loses up to 127 levels but only at alpha < 11 (mean 18.6 at alpha 1-10); at alpha 128-254 the maximum is 1 level.
3. In the thumbnail script most blurs and max-filters run on the alpha channel alone or on opaque RGB, where the straight/premultiplied difference does not arise; no source read states a rule for resize.
