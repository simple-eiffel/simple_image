# 02 - Filter speed: VERDICT (settled by spike)

*2026-10-11. Mode: settled-by-spike. Main thread; no seats.*

**Claim under test:** the filters can be written in pure Eiffel and stay under 150 ms each on a 1280x720 image,
or else need inline C kernels.

**The run** (`spikes/f2_spike.ecf`, `spikes/src/f2_spike.e`; the same algorithms both ways, checksums equal):

| 1280x720, best of 5 | Eiffel, contracts on (ec.sh test) | C, contracts on | Eiffel, lean (ec.sh release) | C, lean |
|---|---|---|---|---|
| Blur: 3 running-sum box passes each way, radius 13, RGBA | 148 ms | 41 ms | 61 ms | 58 ms |
| Grow alpha: separable max filter, size 17 | 80 ms | 18 ms | 18 ms | 18 ms |

Logs: `f2_run_contracts_on.log`, `f2_run_lean.log`. Same pixels in every pair (`same pixels: True`).

**Reading:** without contracts the Eiffel loops run as fast as C; the 3.6-4.4x gap is the per-access contract
checks on SPECIAL. The ecosystem ships contract-checked F_code (ec.sh test is the default and the apps' build), so
that is the case that counts.

**Decision:** per-pixel kernels (blur, grow/shrink, point operations, flood fill, resize, premultiply) are
**inline C**, called from Eiffel routines that carry the contracts (sizes, bounds, channel counts) once per call.
**ESTABLISHED** for the build mode the ecosystem ships. Confidence 0.9, rootedness 0.95.

**Overturn triggers:** a build-mode policy change (lean builds for releases); an Eiffel kernel written with
contracts off per class (`<option><assertions/>` without precondition for one cluster) that measures within 1.2x of C.

**Do not assume:**
- That pure Eiffel is "too slow": lean, it ties C. The cost is contract checking per pixel.
- That a blur's cost grows with its radius: running-sum box passes are radius-independent; only morphology (naive
  max over the window) grows with size (van Herk/Gil-Werman would make it constant if sizes above ~20 appear).
