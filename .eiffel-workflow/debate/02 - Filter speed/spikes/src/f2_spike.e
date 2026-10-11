note
	description: "[
		Spike F2 (2026-10-11): pure Eiffel versus inline C for the two heaviest filters, on a
		1280x720 RGBA image: a Gaussian-equivalent blur (three passes of a running-sum box blur,
		horizontal then vertical, radius 13) and a grow of the alpha (separable max filter, size 17).
		Both versions compute the same pixels (checksums compared). Times are the best of five.
	]"

class
	F2_SPIKE

create
	make

feature {NONE} -- Initialization

	Width: INTEGER = 1280
	Height: INTEGER = 720
	Radius: INTEGER = 13
	Grow: INTEGER = 8
			-- Max filter size 17 = 2 * 8 + 1.

	make
		local
			l_rgba, l_a, l_b, l_alpha, l_c, l_d: SPECIAL [NATURAL_8]
			l_best, l_t: REAL_64
			l_run, l_sum_e, l_sum_c: INTEGER
		do
			l_rgba := test_image
			create l_a.make_filled (0, l_rgba.count)
			create l_b.make_filled (0, l_rgba.count)
			create l_alpha.make_filled (0, Width * Height)
			create l_c.make_filled (0, Width * Height)
			create l_d.make_filled (0, Width * Height)
			fill_alpha (l_alpha)

				-- Blur, Eiffel.
			l_best := 1.0e9
			from l_run := 1 until l_run > 5 loop
				l_a.copy_data (l_rgba, 0, 0, l_rgba.count)
				l_t := now_ms
				blur_eiffel (l_a, l_b)
				l_best := l_best.min (now_ms - l_t)
				l_run := l_run + 1
			end
			l_sum_e := checksum (l_a)
			print ("blur 1280x720 RGBA, 3 box passes r=13, Eiffel: " + l_best.truncated_to_integer.out + " ms%N")
				-- Blur, C.
			l_best := 1.0e9
			from l_run := 1 until l_run > 5 loop
				l_a.copy_data (l_rgba, 0, 0, l_rgba.count)
				l_t := now_ms
				blur_c (l_a, l_b)
				l_best := l_best.min (now_ms - l_t)
				l_run := l_run + 1
			end
			l_sum_c := checksum (l_a)
			print ("blur, inline C: " + l_best.truncated_to_integer.out + " ms; same pixels: " + (l_sum_e = l_sum_c).out + "%N")

				-- Grow, Eiffel.
			l_best := 1.0e9
			from l_run := 1 until l_run > 5 loop
				l_t := now_ms
				grow_h_eiffel (l_alpha, l_c)
				grow_v_eiffel (l_c, l_d)
				l_best := l_best.min (now_ms - l_t)
				l_run := l_run + 1
			end
			l_sum_e := checksum (l_d)
			print ("grow alpha 1280x720, size 17, Eiffel: " + l_best.truncated_to_integer.out + " ms%N")
				-- Grow, C.
			l_best := 1.0e9
			from l_run := 1 until l_run > 5 loop
				l_t := now_ms
				c_grow_h (l_alpha.base_address, l_c.base_address, Width, Height, Grow)
				c_grow_v (l_c.base_address, l_d.base_address, Width, Height, Grow)
				l_best := l_best.min (now_ms - l_t)
				l_run := l_run + 1
			end
			l_sum_c := checksum (l_d)
			print ("grow, inline C: " + l_best.truncated_to_integer.out + " ms; same pixels: " + (l_sum_e = l_sum_c).out + "%N")
		end

feature {NONE} -- Eiffel kernels

	blur_eiffel (a_image, a_scratch: SPECIAL [NATURAL_8])
			-- Three box passes each way, result back in `a_image'.
		local
			i: INTEGER
		do
			from i := 1 until i > 3 loop
				box_h (a_image, a_scratch)
				box_v (a_scratch, a_image)
				i := i + 1
			end
		end

	box_h (a_src, a_dst: SPECIAL [NATURAL_8])
		local
			y, x, c, i, l_sum, l_row, l_div: INTEGER
		do
			l_div := 2 * Radius + 1
			from y := 0 until y >= Height loop
				l_row := y * Width * 4
				from c := 0 until c > 3 loop
					l_sum := 0
					from i := -Radius until i > Radius loop
						l_sum := l_sum + a_src [l_row + i.max (0).min (Width - 1) * 4 + c].to_integer_32
						i := i + 1
					end
					from x := 0 until x >= Width loop
						a_dst [l_row + x * 4 + c] := (l_sum // l_div).to_natural_8
						l_sum := l_sum - a_src [l_row + (x - Radius).max (0) * 4 + c].to_integer_32
							+ a_src [l_row + (x + Radius + 1).min (Width - 1) * 4 + c].to_integer_32
						x := x + 1
					end
					c := c + 1
				end
				y := y + 1
			end
		end

	box_v (a_src, a_dst: SPECIAL [NATURAL_8])
		local
			y, x, c, i, l_sum, l_col, l_stride, l_div: INTEGER
		do
			l_div := 2 * Radius + 1
			l_stride := Width * 4
			from x := 0 until x >= Width loop
				from c := 0 until c > 3 loop
					l_col := x * 4 + c
					l_sum := 0
					from i := -Radius until i > Radius loop
						l_sum := l_sum + a_src [i.max (0).min (Height - 1) * l_stride + l_col].to_integer_32
						i := i + 1
					end
					from y := 0 until y >= Height loop
						a_dst [y * l_stride + l_col] := (l_sum // l_div).to_natural_8
						l_sum := l_sum - a_src [(y - Radius).max (0) * l_stride + l_col].to_integer_32
							+ a_src [(y + Radius + 1).min (Height - 1) * l_stride + l_col].to_integer_32
						y := y + 1
					end
					c := c + 1
				end
				x := x + 1
			end
		end

	grow_h_eiffel (a_src, a_dst: SPECIAL [NATURAL_8])
		local
			y, x, i, l_row: INTEGER
			l_max: NATURAL_8
		do
			from y := 0 until y >= Height loop
				l_row := y * Width
				from x := 0 until x >= Width loop
					l_max := 0
					from i := (x - Grow).max (0) until i > (x + Grow).min (Width - 1) loop
						l_max := l_max.max (a_src [l_row + i])
						i := i + 1
					end
					a_dst [l_row + x] := l_max
					x := x + 1
				end
				y := y + 1
			end
		end

	grow_v_eiffel (a_src, a_dst: SPECIAL [NATURAL_8])
		local
			y, x, i: INTEGER
			l_max: NATURAL_8
		do
			from y := 0 until y >= Height loop
				from x := 0 until x >= Width loop
					l_max := 0
					from i := (y - Grow).max (0) until i > (y + Grow).min (Height - 1) loop
						l_max := l_max.max (a_src [i * Width + x])
						i := i + 1
					end
					a_dst [y * Width + x] := l_max
					x := x + 1
				end
				y := y + 1
			end
		end

feature {NONE} -- C kernels (the same algorithms)

	blur_c (a_image, a_scratch: SPECIAL [NATURAL_8])
		local
			i: INTEGER
		do
			from i := 1 until i > 3 loop
				c_box_h (a_image.base_address, a_scratch.base_address, Width, Height, Radius)
				c_box_v (a_scratch.base_address, a_image.base_address, Width, Height, Radius)
				i := i + 1
			end
		end

	c_box_h (a_src, a_dst: POINTER; a_w, a_h, a_r: INTEGER)
		external
			"C inline"
		alias
			"[
				unsigned char *s = (unsigned char *) $a_src, *d = (unsigned char *) $a_dst;
				int w = $a_w, h = $a_h, r = $a_r, div = 2 * r + 1, y, x, c, i;
				for (y = 0; y < h; y++) {
					int row = y * w * 4;
					for (c = 0; c < 4; c++) {
						int sum = 0;
						for (i = -r; i <= r; i++) { int xi = i < 0 ? 0 : (i > w - 1 ? w - 1 : i); sum += s[row + xi * 4 + c]; }
						for (x = 0; x < w; x++) {
							int xl = x - r < 0 ? 0 : x - r, xr = x + r + 1 > w - 1 ? w - 1 : x + r + 1;
							d[row + x * 4 + c] = (unsigned char) (sum / div);
							sum += s[row + xr * 4 + c] - s[row + xl * 4 + c];
						}
					}
				}
			]"
		end

	c_box_v (a_src, a_dst: POINTER; a_w, a_h, a_r: INTEGER)
		external
			"C inline"
		alias
			"[
				unsigned char *s = (unsigned char *) $a_src, *d = (unsigned char *) $a_dst;
				int w = $a_w, h = $a_h, r = $a_r, div = 2 * r + 1, stride = w * 4, y, x, c, i;
				for (x = 0; x < w; x++) {
					for (c = 0; c < 4; c++) {
						int col = x * 4 + c, sum = 0;
						for (i = -r; i <= r; i++) { int yi = i < 0 ? 0 : (i > h - 1 ? h - 1 : i); sum += s[yi * stride + col]; }
						for (y = 0; y < h; y++) {
							int yt = y - r < 0 ? 0 : y - r, yb = y + r + 1 > h - 1 ? h - 1 : y + r + 1;
							d[y * stride + col] = (unsigned char) (sum / div);
							sum += s[yb * stride + col] - s[yt * stride + col];
						}
					}
				}
			]"
		end

	c_grow_h (a_src, a_dst: POINTER; a_w, a_h, a_g: INTEGER)
		external
			"C inline"
		alias
			"[
				unsigned char *s = (unsigned char *) $a_src, *d = (unsigned char *) $a_dst;
				int w = $a_w, h = $a_h, g = $a_g, y, x, i;
				for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
					int lo = x - g < 0 ? 0 : x - g, hi = x + g > w - 1 ? w - 1 : x + g; unsigned char m = 0;
					for (i = lo; i <= hi; i++) if (s[y * w + i] > m) m = s[y * w + i];
					d[y * w + x] = m;
				}
			]"
		end

	c_grow_v (a_src, a_dst: POINTER; a_w, a_h, a_g: INTEGER)
		external
			"C inline"
		alias
			"[
				unsigned char *s = (unsigned char *) $a_src, *d = (unsigned char *) $a_dst;
				int w = $a_w, h = $a_h, g = $a_g, y, x, i;
				for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
					int lo = y - g < 0 ? 0 : y - g, hi = y + g > h - 1 ? h - 1 : y + g; unsigned char m = 0;
					for (i = lo; i <= hi; i++) if (s[i * w + x] > m) m = s[i * w + x];
					d[y * w + x] = m;
				}
			]"
		end

feature {NONE} -- Test data

	test_image: SPECIAL [NATURAL_8]
			-- A deterministic 1280x720 RGBA pattern with edges and gradients.
		local
			i, x, y: INTEGER
		do
			create Result.make_filled (0, Width * Height * 4)
			from y := 0 until y >= Height loop
				from x := 0 until x >= Width loop
					i := (y * Width + x) * 4
					Result [i] := ((x * 7 + y * 3) \\ 256).to_natural_8
					Result [i + 1] := (if (x // 40 + y // 40) \\ 2 = 0 then 230 else 20 end).to_natural_8
					Result [i + 2] := ((x * y) \\ 251).to_natural_8
					Result [i + 3] := (if (x - 640) * (x - 640) + (y - 360) * (y - 360) < 250 * 250 then 255 else 0 end).to_natural_8
					x := x + 1
				end
				y := y + 1
			end
		end

	fill_alpha (a_alpha: SPECIAL [NATURAL_8])
		local
			x, y: INTEGER
		do
			from y := 0 until y >= Height loop
				from x := 0 until x >= Width loop
					a_alpha [y * Width + x] := (if (x - 640) * (x - 640) + (y - 360) * (y - 360) < 250 * 250 then 255 else (x \\ 97).to_integer_32 end).to_natural_8
					x := x + 1
				end
				y := y + 1
			end
		end

	checksum (a_data: SPECIAL [NATURAL_8]): INTEGER
		local
			i: INTEGER
		do
			from i := 0 until i >= a_data.count loop
				Result := (Result * 31 + a_data [i].to_integer_32) \\ 1_000_000_007
				i := i + 1
			end
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
