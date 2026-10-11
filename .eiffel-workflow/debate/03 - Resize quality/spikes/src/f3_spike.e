note
	description: "[
		Spike F3 (2026-10-11): cairo's Filter_best scaling versus a Lanczos-3 kernel (inline C, PIL's
		method: support widened by the shrink factor, weights normalized, separable) for the cutout's two
		resizes. Reads the raw inputs from f3_prep_and_check.py and writes one output per method.
		Usage: f3_spike <work_dir>
	]"

class
	F3_SPIKE

create
	make

feature {NONE} -- Initialization

	make
		local
			l_args: ARGUMENTS_32
			l_dir: STRING_32
			l_in, l_out: SPECIAL [NATURAL_8]
			l_t: REAL_64
		do
			create l_args
			l_dir := l_args.argument (1)
				-- Case A: gray mask 320x320 up to 1000x680.
			l_in := read_bytes (l_dir + {STRING_32} "\a_in_320.gray", 320 * 320)
			l_t := now_ms
			l_out := cairo_resize (l_in, 320, 320, 1, 1000, 680)
			print ("A cairo " + (now_ms - l_t).truncated_to_integer.out + " ms%N")
			write_bytes (l_dir + {STRING_32} "\a_cairo_1000x680.gray", l_out)
			create l_out.make_filled (0, 1000 * 680)
			l_t := now_ms
			c_lanczos (l_in.base_address, 320, 320, 1, l_out.base_address, 1000, 680)
			print ("A lanczos " + (now_ms - l_t).truncated_to_integer.out + " ms%N")
			write_bytes (l_dir + {STRING_32} "\a_lanczos_1000x680.gray", l_out)
				-- Case B: RGB frame 1000x680 down to 320x320.
			l_in := read_bytes (l_dir + {STRING_32} "\b_in_1000x680.rgb", 1000 * 680 * 3)
			l_t := now_ms
			l_out := cairo_resize (l_in, 1000, 680, 3, 320, 320)
			print ("B cairo " + (now_ms - l_t).truncated_to_integer.out + " ms%N")
			write_bytes (l_dir + {STRING_32} "\b_cairo_320.rgb", l_out)
			create l_out.make_filled (0, 320 * 320 * 3)
			l_t := now_ms
			c_lanczos (l_in.base_address, 1000, 680, 3, l_out.base_address, 320, 320)
			print ("B lanczos " + (now_ms - l_t).truncated_to_integer.out + " ms%N")
			write_bytes (l_dir + {STRING_32} "\b_lanczos_320.rgb", l_out)
		end

feature {NONE} -- Cairo

	cairo_resize (a_in: SPECIAL [NATURAL_8]; a_w, a_h, a_channels, a_out_w, a_out_h: INTEGER): SPECIAL [NATURAL_8]
			-- `a_in' (gray or RGB) scaled by cairo with Filter_best (opaque, so premultiplying changes nothing).
		local
			l_src, l_dst: CAIRO_SURFACE
			l_ctx: CAIRO_CONTEXT
			l_pattern: CAIRO_SURFACE_PATTERN
		do
			create l_src.make (a_w, a_h)
			l_src.flush.do_nothing
			c_pack (a_in.base_address, a_w, a_h, a_channels, l_src.data, l_src.stride)
			l_src.mark_dirty.do_nothing
			create l_dst.make (a_out_w, a_out_h)
			create l_ctx.make (l_dst)
			l_ctx.scale (a_out_w / a_w, a_out_h / a_h).do_nothing
			create l_pattern.make_from_surface (l_src)
			l_pattern.set_filter ({CAIRO_PATTERN}.Filter_best).do_nothing
			l_ctx.set_pattern (l_pattern).do_nothing
			l_ctx.paint.do_nothing
			l_dst.flush.do_nothing
			create Result.make_filled (0, a_out_w * a_out_h * a_channels)
			c_unpack (l_dst.data, l_dst.stride, a_out_w, a_out_h, a_channels, Result.base_address)
			l_ctx.destroy
			l_pattern.destroy
			l_src.destroy
			l_dst.destroy
		end

	c_pack (a_in: POINTER; a_w, a_h, a_ch: INTEGER; a_data: POINTER; a_stride: INTEGER)
			-- Gray or RGB bytes into opaque ARGB32 (0xAARRGGBB words).
		external "C inline"
		alias "[
			unsigned char *in = (unsigned char *) $a_in; int x, y, w = $a_w, h = $a_h, ch = $a_ch;
			for (y = 0; y < h; y++) {
				unsigned int *row = (unsigned int *) ((unsigned char *) $a_data + y * $a_stride);
				for (x = 0; x < w; x++) {
					unsigned char *p = in + (y * w + x) * ch;
					unsigned int r = p[0], g = ch == 3 ? p[1] : p[0], b = ch == 3 ? p[2] : p[0];
					row[x] = 0xFF000000u | (r << 16) | (g << 8) | b;
				}
			}
		]"
		end

	c_unpack (a_data: POINTER; a_stride, a_w, a_h, a_ch: INTEGER; a_out: POINTER)
		external "C inline"
		alias "[
			unsigned char *out = (unsigned char *) $a_out; int x, y, w = $a_w, h = $a_h, ch = $a_ch;
			for (y = 0; y < h; y++) {
				unsigned int *row = (unsigned int *) ((unsigned char *) $a_data + y * $a_stride);
				for (x = 0; x < w; x++) {
					unsigned int v = row[x]; unsigned char *p = out + (y * w + x) * ch;
					p[0] = (unsigned char) ((v >> 16) & 0xFF);
					if (ch == 3) { p[1] = (unsigned char) ((v >> 8) & 0xFF); p[2] = (unsigned char) (v & 0xFF); }
				}
			}
		]"
		end

feature {NONE} -- Lanczos-3

	c_lanczos (a_in: POINTER; a_w, a_h, a_ch: INTEGER; a_out: POINTER; a_ow, a_oh: INTEGER)
			-- Separable Lanczos-3 resize (horizontal into floats, then vertical), PIL's way.
		external "C inline use <math.h>, <stdlib.h>"
		alias "[
			unsigned char *in = (unsigned char *) $a_in, *out = (unsigned char *) $a_out;
			int w = $a_w, h = $a_h, ch = $a_ch, ow = $a_ow, oh = $a_oh, x, y, c, i;
			float *tmp = (float *) malloc (sizeof (float) * ow * h * ch);
			/* horizontal */
			{
				double scale = (double) w / ow, fs = scale < 1.0 ? 1.0 : scale, support = 3.0 * fs;
				for (x = 0; x < ow; x++) {
					double center = (x + 0.5) * scale; int lo = (int) (center - support + 0.5), hi = (int) (center + support + 0.5);
					double wsum = 0, wt[512]; int n;
					if (lo < 0) lo = 0; if (hi > w) hi = w; n = hi - lo; if (n > 512) n = 512;
					for (i = 0; i < n; i++) {
						double t = (i + lo - center + 0.5) / fs, v;
						if (t == 0.0) v = 1.0; else if (t <= -3.0 || t >= 3.0) v = 0.0;
						else { double pt = 3.14159265358979323846 * t; v = 3.0 * sin (pt) * sin (pt / 3.0) / (pt * pt); }
						wt[i] = v; wsum += v;
					}
					for (i = 0; i < n; i++) wt[i] /= (wsum == 0 ? 1 : wsum);
					for (y = 0; y < h; y++) for (c = 0; c < ch; c++) {
						double s = 0; for (i = 0; i < n; i++) s += wt[i] * in[(y * w + lo + i) * ch + c];
						tmp[(y * ow + x) * ch + c] = (float) s;
					}
				}
			}
			/* vertical */
			{
				double scale = (double) h / oh, fs = scale < 1.0 ? 1.0 : scale, support = 3.0 * fs;
				for (y = 0; y < oh; y++) {
					double center = (y + 0.5) * scale; int lo = (int) (center - support + 0.5), hi = (int) (center + support + 0.5);
					double wsum = 0, wt[512]; int n;
					if (lo < 0) lo = 0; if (hi > h) hi = h; n = hi - lo; if (n > 512) n = 512;
					for (i = 0; i < n; i++) {
						double t = (i + lo - center + 0.5) / fs, v;
						if (t == 0.0) v = 1.0; else if (t <= -3.0 || t >= 3.0) v = 0.0;
						else { double pt = 3.14159265358979323846 * t; v = 3.0 * sin (pt) * sin (pt / 3.0) / (pt * pt); }
						wt[i] = v; wsum += v;
					}
					for (i = 0; i < n; i++) wt[i] /= (wsum == 0 ? 1 : wsum);
					for (x = 0; x < ow; x++) for (c = 0; c < ch; c++) {
						double s = 0; for (i = 0; i < n; i++) s += wt[i] * tmp[((lo + i) * ow + x) * ch + c];
						s = s < 0 ? 0 : (s > 255 ? 255 : s);
						out[(y * ow + x) * ch + c] = (unsigned char) (s + 0.5);
					}
				}
			}
			free (tmp);
		]"
		end

feature {NONE} -- Files

	read_bytes (a_path: READABLE_STRING_32; a_count: INTEGER): SPECIAL [NATURAL_8]
		local
			l_file: RAW_FILE
			l_buffer: MANAGED_POINTER
		do
			create l_file.make_with_name (a_path)
			l_file.open_read
			create l_buffer.make (a_count)
			l_file.read_to_managed_pointer (l_buffer, 0, a_count)
			l_file.close
			create Result.make_filled (0, a_count)
			Result.base_address.memory_copy (l_buffer.item, a_count)
		end

	write_bytes (a_path: READABLE_STRING_32; a_data: SPECIAL [NATURAL_8])
		local
			l_file: RAW_FILE
			l_buffer: MANAGED_POINTER
		do
			create l_buffer.make (a_data.count)
			l_buffer.item.memory_copy (a_data.base_address, a_data.count)
			create l_file.make_with_name (a_path)
			l_file.open_write
			l_file.put_managed_pointer (l_buffer, 0, a_data.count)
			l_file.close
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
