# 03 - Resize quality: VERDICT (settled by spike)

*2026-10-11. Mode: settled-by-spike. Main thread; no seats.*

**Claim under test:** cairo's Filter_best scaling is good enough for the cutout's resizes, or a Lanczos-3 kernel of
our own is needed. Criterion fixed before the run: mean absolute difference from PIL's LANCZOS under 2 levels of 255.

**The run** (`spikes/f3_spike.ecf`, `spikes/src/f3_spike.e`, `f3_prep_and_check.py`; inputs: the Reel 4 frame
crop and the F4 spike's real model mask):

| Against PIL LANCZOS | cairo 1.17.2 Filter_best | Lanczos-3, inline C (PIL's method) |
|---|---|---|
| A. 320x320 mask up to 1000x680 (gray) | mean 0.363, **max 61**, 1.32% of pixels off by more than 8 | mean 0.011, max 4, none off by more than 8 |
| B. 1000x680 RGB down to 320x320 | mean 0.350, max 21, 0.08% off by more than 8 | mean 0.135, max 3, none |
| Time (contracts on) | 16 ms (A), 27 ms (B) | 6 ms (A), 8 ms (B) |

Logs: `f3_eiffel_run.log`, `f3_check.log`.

**Reading:** both pass the mean criterion, but cairo's worst errors sit on the mask's edge (the cutout's outline,
where a halo would show); the Lanczos kernel is within 4 levels everywhere and 2-3x faster.

**Decision:** simple_image owns a separable **Lanczos-3 resize in inline C** (PIL's method: support widened by
the shrink factor, normalized weights). Cairo's scaling stays acceptable for drawing-time transforms (placing a
picture at a scale inside a composition), not for masks or model inputs. **ESTABLISHED** for these two cases.
Confidence 0.9, rootedness 0.95.

**Overturn triggers:** a resize case outside these (extreme shrink, over 10x, or alpha with premultiplication) where
the kernel's error exceeds 4; a cairo upgrade with a different Filter_best.

**Do not assume:**
- That cairo's Filter_best is Lanczos: on this build its edge errors reach 61 levels.
- That intermediate rounding matches PIL exactly: the kernel keeps floats between passes (PIL rounds to 8 bits), hence the small residual.
