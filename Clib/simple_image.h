/*
 * simple_image.h - per-pixel kernels for simple_image (2026-10-11).
 *
 * Pure functions only: no mutable statics (each generated C file that includes
 * this header gets its own copy of every static, so state here would fork).
 *
 * Images are straight (non-premultiplied) RGBA8, rows packed (stride = w * 4).
 * Masks are one 8-bit channel, rows packed (stride = w).
 * Any kernel that mixes neighbouring RGBA pixels premultiplies in float inside
 * the loop and stores straight (debate 04 verdict, kernel rule).
 * Every allocating kernel returns 1 on success, 0 when memory ran out.
 */
#ifndef SIMPLE_IMAGE_H
#define SIMPLE_IMAGE_H

#include <stdlib.h>
#include <string.h>
#include <math.h>

static unsigned char img_clamp_byte (double v) {
	if (v <= 0.0) return 0;
	if (v >= 255.0) return 255;
	return (unsigned char) (v + 0.5);
}

/* ---------- float box blur (three passes ~ gaussian), edge pixels repeated ---------- */

static void img_box_h_f (const float *s, float *d, int w, int h, int ch, int r) {
	int y, x, c, i;
	double div = (double) (2 * r + 1);
	for (y = 0; y < h; y++) {
		const float *row = s + (size_t) y * w * ch;
		float *out = d + (size_t) y * w * ch;
		for (c = 0; c < ch; c++) {
			double sum = 0.0;
			for (i = -r; i <= r; i++) { int xi = i < 0 ? 0 : (i > w - 1 ? w - 1 : i); sum += row[xi * ch + c]; }
			for (x = 0; x < w; x++) {
				int xl = x - r < 0 ? 0 : x - r;
				int xr = x + r + 1 > w - 1 ? w - 1 : x + r + 1;
				out[x * ch + c] = (float) (sum / div);
				sum += row[xr * ch + c] - row[xl * ch + c];
			}
		}
	}
}

static void img_box_v_f (const float *s, float *d, int w, int h, int ch, int r) {
	int y, x, c, i;
	size_t stride = (size_t) w * ch;
	double div = (double) (2 * r + 1);
	for (x = 0; x < w; x++) {
		for (c = 0; c < ch; c++) {
			size_t col = (size_t) x * ch + c;
			double sum = 0.0;
			for (i = -r; i <= r; i++) { int yi = i < 0 ? 0 : (i > h - 1 ? h - 1 : i); sum += s[yi * stride + col]; }
			for (y = 0; y < h; y++) {
				int yt = y - r < 0 ? 0 : y - r;
				int yb = y + r + 1 > h - 1 ? h - 1 : y + r + 1;
				d[y * stride + col] = (float) (sum / div);
				sum += s[yb * stride + col] - s[yt * stride + col];
			}
		}
	}
}

static int img_blur_f (float *f, int w, int h, int ch, int r) {
	int pass;
	float *t = (float *) malloc (sizeof (float) * (size_t) w * h * ch);
	if (!t) return 0;
	for (pass = 0; pass < 3; pass++) {
		img_box_h_f (f, t, w, h, ch, r);
		img_box_v_f (t, f, w, h, ch, r);
	}
	free (t);
	return 1;
}

/* ---------- premultiply / unpremultiply between bytes and floats ---------- */

static void img_rgba_to_premul_f (const unsigned char *p, size_t n, float *f) {
	size_t i;
	for (i = 0; i < n; i++) {
		const unsigned char *q = p + i * 4;
		float a = (float) q[3];
		f[i * 4] = q[0] * a / 255.0f;
		f[i * 4 + 1] = q[1] * a / 255.0f;
		f[i * 4 + 2] = q[2] * a / 255.0f;
		f[i * 4 + 3] = a;
	}
}

static void img_premul_f_to_rgba (const float *f, size_t n, unsigned char *p) {
	size_t i;
	for (i = 0; i < n; i++) {
		const float *g = f + i * 4;
		unsigned char *q = p + i * 4;
		double a = g[3];
		if (a > 1e-6) {
			q[0] = img_clamp_byte (g[0] * 255.0 / a);
			q[1] = img_clamp_byte (g[1] * 255.0 / a);
			q[2] = img_clamp_byte (g[2] * 255.0 / a);
		} else {
			q[0] = 0; q[1] = 0; q[2] = 0;
		}
		q[3] = img_clamp_byte (a);
	}
}

static int img_blur_rgba (unsigned char *p, int w, int h, int r) {
	size_t n = (size_t) w * h;
	float *f = (float *) malloc (sizeof (float) * n * 4);
	if (!f) return 0;
	img_rgba_to_premul_f (p, n, f);
	if (!img_blur_f (f, w, h, 4, r)) { free (f); return 0; }
	img_premul_f_to_rgba (f, n, p);
	free (f);
	return 1;
}

static int img_blur_gray (unsigned char *p, int w, int h, int r) {
	size_t i, n = (size_t) w * h;
	float *f = (float *) malloc (sizeof (float) * n);
	if (!f) return 0;
	for (i = 0; i < n; i++) f[i] = (float) p[i];
	if (!img_blur_f (f, w, h, 1, r)) { free (f); return 0; }
	for (i = 0; i < n; i++) p[i] = img_clamp_byte (f[i]);
	free (f);
	return 1;
}

/* ---------- grow (max) / shrink (min) of a mask over a (2g+1) square ---------- */

static int img_grow (unsigned char *p, int w, int h, int g, int is_max) {
	int y, x, i;
	unsigned char *t = (unsigned char *) malloc ((size_t) w * h);
	if (!t) return 0;
	for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
		int lo = x - g < 0 ? 0 : x - g, hi = x + g > w - 1 ? w - 1 : x + g;
		unsigned char m = p[(size_t) y * w + lo];
		for (i = lo + 1; i <= hi; i++) {
			unsigned char v = p[(size_t) y * w + i];
			if (is_max ? v > m : v < m) m = v;
		}
		t[(size_t) y * w + x] = m;
	}
	for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
		int lo = y - g < 0 ? 0 : y - g, hi = y + g > h - 1 ? h - 1 : y + g;
		unsigned char m = t[(size_t) lo * w + x];
		for (i = lo + 1; i <= hi; i++) {
			unsigned char v = t[(size_t) i * w + x];
			if (is_max ? v > m : v < m) m = v;
		}
		p[(size_t) y * w + x] = m;
	}
	free (t);
	return 1;
}

/* ---------- Lanczos-3 resize of float pixels (separable, PIL's way; debate 03 verdict) ---------- */

static double img_lanczos3 (double t) {
	double pt;
	if (t == 0.0) return 1.0;
	if (t <= -3.0 || t >= 3.0) return 0.0;
	pt = 3.14159265358979323846 * t;
	return 3.0 * sin (pt) * sin (pt / 3.0) / (pt * pt);
}

/* Weights for one output position: returns the count, fills lo and wt (normalized). */
static int img_lanczos_weights (int pos, int in_size, int out_size, double *wt, int max_n, int *lo_out) {
	double scale = (double) in_size / out_size, fs = scale < 1.0 ? 1.0 : scale, support = 3.0 * fs;
	double center = (pos + 0.5) * scale, wsum = 0.0;
	int lo = (int) (center - support + 0.5), hi = (int) (center + support + 0.5), n, i;
	if (lo < 0) lo = 0;
	if (hi > in_size) hi = in_size;
	n = hi - lo;
	if (n > max_n) n = max_n;
	for (i = 0; i < n; i++) { wt[i] = img_lanczos3 ((i + lo - center + 0.5) / fs); wsum += wt[i]; }
	for (i = 0; i < n; i++) wt[i] /= (wsum == 0.0 ? 1.0 : wsum);
	*lo_out = lo;
	return n;
}

static int img_lanczos_f (const float *in, int w, int h, int ch, float *out, int ow, int oh) {
	int x, y, c, i, n, lo;
	int max_n = (int) (6.0 * ((double) w / ow > (double) h / oh ? (double) w / ow : (double) h / oh)) + 8;
	double *wt;
	float *tmp;
	if (max_n < 8) max_n = 8;
	wt = (double *) malloc (sizeof (double) * max_n);
	tmp = (float *) malloc (sizeof (float) * (size_t) ow * h * ch);
	if (!wt || !tmp) { free (wt); free (tmp); return 0; }
	for (x = 0; x < ow; x++) {
		n = img_lanczos_weights (x, w, ow, wt, max_n, &lo);
		for (y = 0; y < h; y++) for (c = 0; c < ch; c++) {
			double s = 0.0;
			for (i = 0; i < n; i++) s += wt[i] * in[((size_t) y * w + lo + i) * ch + c];
			tmp[((size_t) y * ow + x) * ch + c] = (float) s;
		}
	}
	for (y = 0; y < oh; y++) {
		n = img_lanczos_weights (y, h, oh, wt, max_n, &lo);
		for (x = 0; x < ow; x++) for (c = 0; c < ch; c++) {
			double s = 0.0;
			for (i = 0; i < n; i++) s += wt[i] * tmp[((size_t) (lo + i) * ow + x) * ch + c];
			out[((size_t) y * ow + x) * ch + c] = (float) s;
		}
	}
	free (wt);
	free (tmp);
	return 1;
}

static int img_resize_rgba (const unsigned char *in, int w, int h, unsigned char *out, int ow, int oh) {
	float *fi = (float *) malloc (sizeof (float) * (size_t) w * h * 4);
	float *fo = (float *) malloc (sizeof (float) * (size_t) ow * oh * 4);
	size_t i, n = (size_t) ow * oh;
	if (!fi || !fo) { free (fi); free (fo); return 0; }
	img_rgba_to_premul_f (in, (size_t) w * h, fi);
	if (!img_lanczos_f (fi, w, h, 4, fo, ow, oh)) { free (fi); free (fo); return 0; }
	for (i = 0; i < n; i++) {
		/* Lanczos rings: keep premultiplied colour within [0, alpha] before dividing */
		float a = fo[i * 4 + 3];
		int c;
		if (a < 0.0f) a = 0.0f;
		if (a > 255.0f) a = 255.0f;
		fo[i * 4 + 3] = a;
		for (c = 0; c < 3; c++) {
			if (fo[i * 4 + c] < 0.0f) fo[i * 4 + c] = 0.0f;
			if (fo[i * 4 + c] > a) fo[i * 4 + c] = a;
		}
	}
	img_premul_f_to_rgba (fo, n, out);
	free (fi);
	free (fo);
	return 1;
}

static int img_resize_gray (const unsigned char *in, int w, int h, unsigned char *out, int ow, int oh) {
	float *fi = (float *) malloc (sizeof (float) * (size_t) w * h);
	float *fo = (float *) malloc (sizeof (float) * (size_t) ow * oh);
	size_t i, n = (size_t) ow * oh;
	if (!fi || !fo) { free (fi); free (fo); return 0; }
	for (i = 0; i < (size_t) w * h; i++) fi[i] = (float) in[i];
	if (!img_lanczos_f (fi, w, h, 1, fo, ow, oh)) { free (fi); free (fo); return 0; }
	for (i = 0; i < n; i++) out[i] = img_clamp_byte (fo[i]);
	free (fi);
	free (fo);
	return 1;
}

/* ---------- point operations (PIL ImageEnhance: blend with a degenerate image) ---------- */

static double img_gray_of (const unsigned char *q) {
	return (q[0] * 299.0 + q[1] * 587.0 + q[2] * 114.0) / 1000.0;
}

static double img_mean_gray (const unsigned char *p, size_t n) {
	size_t i;
	double sum = 0.0;
	for (i = 0; i < n; i++) sum += floor (img_gray_of (p + i * 4));
	return n == 0 ? 0.0 : floor (sum / n + 0.5);
}

/* mode 1 brightness (degenerate black), 2 contrast (degenerate mean gray), 3 colour (degenerate own gray) */
static void img_enhance (unsigned char *p, size_t n, int mode, double f, double mean) {
	size_t i;
	int c;
	for (i = 0; i < n; i++) {
		unsigned char *q = p + i * 4;
		double d = mode == 1 ? 0.0 : (mode == 2 ? mean : img_gray_of (q));
		for (c = 0; c < 3; c++) q[c] = img_clamp_byte (d + (q[c] - d) * f);
	}
}

static void img_vignette (unsigned char *p, int w, int h, double strength) {
	int x, y, c;
	double cx = w / 2.0, cy = h / 2.0;
	for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
		unsigned char *q = p + ((size_t) y * w + x) * 4;
		double dx = (x + 0.5 - cx) / cx, dy = (y + 0.5 - cy) / cy;
		double k = 1.0 - strength * (dx * dx + dy * dy) / 2.0;
		if (k < 0.0) k = 0.0;
		for (c = 0; c < 3; c++) q[c] = img_clamp_byte (q[c] * k);
	}
}

static void img_flatten (unsigned char *p, size_t n, int br, int bg, int bb) {
	size_t i;
	for (i = 0; i < n; i++) {
		unsigned char *q = p + i * 4;
		int a = q[3];
		q[0] = (unsigned char) ((q[0] * a + br * (255 - a) + 127) / 255);
		q[1] = (unsigned char) ((q[1] * a + bg * (255 - a) + 127) / 255);
		q[2] = (unsigned char) ((q[2] * a + bb * (255 - a) + 127) / 255);
		q[3] = 255;
	}
}

static int img_is_opaque (const unsigned char *p, size_t n) {
	size_t i;
	for (i = 0; i < n; i++) if (p[i * 4 + 3] != 255) return 0;
	return 1;
}

static void img_fill_rgba (unsigned char *p, size_t n, unsigned int argb) {
	size_t i;
	for (i = 0; i < n; i++) {
		p[i * 4] = (unsigned char) ((argb >> 16) & 0xFF);
		p[i * 4 + 1] = (unsigned char) ((argb >> 8) & 0xFF);
		p[i * 4 + 2] = (unsigned char) (argb & 0xFF);
		p[i * 4 + 3] = (unsigned char) ((argb >> 24) & 0xFF);
	}
}

static unsigned int img_get_argb (const unsigned char *p, int w, int x, int y) {
	const unsigned char *q = p + ((size_t) y * w + x) * 4;
	return ((unsigned int) q[3] << 24) | ((unsigned int) q[0] << 16) | ((unsigned int) q[1] << 8) | q[2];
}

static void img_set_argb (unsigned char *p, int w, int x, int y, unsigned int argb) {
	img_fill_rgba (p + ((size_t) y * w + x) * 4, 1, argb);
}

static void img_alpha_to_mask (const unsigned char *p, size_t n, unsigned char *m) {
	size_t i;
	for (i = 0; i < n; i++) m[i] = p[i * 4 + 3];
}

static void img_mask_to_alpha (unsigned char *p, size_t n, const unsigned char *m) {
	size_t i;
	for (i = 0; i < n; i++) p[i * 4 + 3] = m[i];
}

/* ---------- the cairo seam: straight RGBA8 <-> premultiplied ARGB32 (native word) ---------- */

static void img_to_cairo (const unsigned char *p, int w, int h, unsigned char *dst, int dst_stride) {
	int x, y;
	for (y = 0; y < h; y++) {
		unsigned int *row = (unsigned int *) (dst + (size_t) y * dst_stride);
		for (x = 0; x < w; x++) {
			const unsigned char *q = p + ((size_t) y * w + x) * 4;
			unsigned int a = q[3];
			unsigned int r = (q[0] * a + 127) / 255, g = (q[1] * a + 127) / 255, b = (q[2] * a + 127) / 255;
			row[x] = (a << 24) | (r << 16) | (g << 8) | b;
		}
	}
}

static void img_from_cairo (const unsigned char *src, int src_stride, int w, int h, unsigned char *p) {
	int x, y;
	for (y = 0; y < h; y++) {
		const unsigned int *row = (const unsigned int *) (src + (size_t) y * src_stride);
		for (x = 0; x < w; x++) {
			unsigned int v = row[x], a = v >> 24;
			unsigned char *q = p + ((size_t) y * w + x) * 4;
			if (a == 0) {
				q[0] = 0; q[1] = 0; q[2] = 0; q[3] = 0;
			} else {
				unsigned int r = (v >> 16) & 0xFF, g = (v >> 8) & 0xFF, b = v & 0xFF;
				r = (r * 255 + a / 2) / a; g = (g * 255 + a / 2) / a; b = (b * 255 + a / 2) / a;
				q[0] = (unsigned char) (r > 255 ? 255 : r);
				q[1] = (unsigned char) (g > 255 ? 255 : g);
				q[2] = (unsigned char) (b > 255 ? 255 : b);
				q[3] = (unsigned char) a;
			}
		}
	}
}

static void img_copy_rows (const unsigned char *s, int s_stride, unsigned char *d, int d_stride, int row_bytes, int h) {
	int y;
	for (y = 0; y < h; y++) memcpy (d + (size_t) y * d_stride, s + (size_t) y * s_stride, (size_t) row_bytes);
}

/* ---------- mask operations ---------- */

static void img_threshold (unsigned char *p, size_t n, int level) {
	size_t i;
	for (i = 0; i < n; i++) p[i] = p[i] >= level ? 255 : 0;
}

static void img_invert (unsigned char *p, size_t n) {
	size_t i;
	for (i = 0; i < n; i++) p[i] = (unsigned char) (255 - p[i]);
}

static int img_count_at_least (const unsigned char *p, size_t n, int level) {
	size_t i;
	int c = 0;
	for (i = 0; i < n; i++) if (p[i] >= level) c++;
	return c;
}

/* Fill the 4-connected region of pixels equal to the seed's value; returns the count (-1: no memory). */
static int img_flood_fill (unsigned char *p, int w, int h, int sx, int sy, int value) {
	int seed = p[(size_t) sy * w + sx], count = 0;
	size_t top = 0;
	int *stack;
	if (seed == value) return 0;
	stack = (int *) malloc (sizeof (int) * (size_t) w * h);
	if (!stack) return -1;
	p[(size_t) sy * w + sx] = (unsigned char) value;
	stack[top++] = sy * w + sx;
	while (top > 0) {
		int at = stack[--top], x = at % w, y = at / w;
		count++;
		if (x > 0 && p[at - 1] == seed) { p[at - 1] = (unsigned char) value; stack[top++] = at - 1; }
		if (x < w - 1 && p[at + 1] == seed) { p[at + 1] = (unsigned char) value; stack[top++] = at + 1; }
		if (y > 0 && p[at - w] == seed) { p[at - w] = (unsigned char) value; stack[top++] = at - w; }
		if (y < h - 1 && p[at + w] == seed) { p[at + w] = (unsigned char) value; stack[top++] = at + w; }
	}
	free (stack);
	return count;
}

/*
 * Keep only the largest 4-connected piece of pixels >= level. Pixels of other pieces become 0;
 * pixels below level survive only within 2 pixels of the kept piece (its soft edge).
 * Returns the kept piece's size (-1: no memory).
 */
static int img_keep_largest (unsigned char *p, int w, int h, int level) {
	size_t n = (size_t) w * h, i;
	int *label = (int *) calloc (n, sizeof (int));
	int *stack = (int *) malloc (sizeof (int) * n);
	int next = 0, best = 0, best_size = 0, x, y, dx, dy;
	if (!label || !stack) { free (label); free (stack); return -1; }
	for (i = 0; i < n; i++) {
		if (p[i] >= level && label[i] == 0) {
			size_t top = 0;
			int size = 0;
			next++;
			label[i] = next;
			stack[top++] = (int) i;
			while (top > 0) {
				int at = stack[--top];
				x = at % w; y = at / w;
				size++;
				if (x > 0 && p[at - 1] >= level && !label[at - 1]) { label[at - 1] = next; stack[top++] = at - 1; }
				if (x < w - 1 && p[at + 1] >= level && !label[at + 1]) { label[at + 1] = next; stack[top++] = at + 1; }
				if (y > 0 && p[at - w] >= level && !label[at - w]) { label[at - w] = next; stack[top++] = at - w; }
				if (y < h - 1 && p[at + w] >= level && !label[at + w]) { label[at + w] = next; stack[top++] = at + w; }
			}
			if (size > best_size) { best_size = size; best = next; }
		}
	}
	for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
		size_t at = (size_t) y * w + x;
		if (label[at] != best) {
			int is_near = 0;
			if (label[at] == 0 && best != 0) {
				for (dy = -2; dy <= 2 && !is_near; dy++) for (dx = -2; dx <= 2 && !is_near; dx++) {
					int xx = x + dx, yy = y + dy;
					if (xx >= 0 && xx < w && yy >= 0 && yy < h && label[(size_t) yy * w + xx] == best) is_near = 1;
				}
			}
			if (!is_near) p[at] = 0;
		}
	}
	free (label);
	free (stack);
	return best_size;
}

/* Min-max normalize n floats into bytes (rembg's way: (v - min) / (max - min)). */
static void img_floats_to_mask (const float *f, size_t n, unsigned char *m) {
	size_t i;
	float lo = f[0], hi = f[0];
	for (i = 1; i < n; i++) { if (f[i] < lo) lo = f[i]; if (f[i] > hi) hi = f[i]; }
	for (i = 0; i < n; i++) m[i] = hi > lo ? img_clamp_byte ((f[i] - lo) / (hi - lo) * 255.0) : 0;
}

#endif
