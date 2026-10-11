note
	description: "[
		Tests for simple_image. Each kernel is pinned by a property that the wrong design would
		fail: soft edges keep their color after blur and resize (a straight 8-bit blur darkens
		them), the blur matches an independent float reference within 1 level (the kernel rule),
		and the cairo seam round-trips opaque pixels exactly.
	]"
	author: "Larry Rix"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Images

	test_make_is_transparent
			-- A new image is transparent black, with packed rows.
		local
			l_image: IMG_IMAGE
		do
			create l_image.make (7, 5)
			assert ("width", l_image.width = 7)
			assert ("height", l_image.height = 5)
			assert ("stride", l_image.stride = 28)
			assert ("transparent black", l_image.pixel (6, 4) = 0)
			assert ("not opaque", not l_image.is_opaque)
			l_image.destroy
			assert ("destroyed", not l_image.is_usable)
		end

	test_pixel_round_trip
			-- set_pixel and pixel agree on 0xAARRGGBB, and fill reaches every pixel.
		local
			l_image: IMG_IMAGE
		do
			create l_image.make_filled (4, 3, 0xFF102030)
			assert ("filled", l_image.pixel (3, 2) = 0xFF102030)
			assert ("opaque", l_image.is_opaque)
			l_image.set_pixel (1, 1, 0x80A0B0C0)
			assert ("pixel set", l_image.pixel (1, 1) = 0x80A0B0C0)
			assert ("neighbor untouched", l_image.pixel (2, 1) = 0xFF102030)
		end

	test_twin_is_independent
			-- A twin has its own pixels.
		local
			l_image, l_copy: IMG_IMAGE
		do
			create l_image.make_filled (6, 6, 0xFF0000FF)
			l_copy := l_image.twin
			assert ("equal at first", l_copy.is_equal (l_image))
			l_copy.set_pixel (0, 0, 0xFFFFFFFF)
			assert ("original untouched", l_image.pixel (0, 0) = 0xFF0000FF)
			assert ("now different", not l_copy.is_equal (l_image))
			l_copy.destroy
			assert ("original still usable", l_image.is_usable)
		end

	test_cropped
			-- Cropping copies the rectangle, for images and masks.
		local
			l_image, l_part: IMG_IMAGE
			l_mask, l_mask_part: IMG_MASK
		do
			create l_image.make (10, 10)
			l_image.set_pixel (3, 4, 0xFF123456)
			l_image.set_pixel (4, 5, 0x7F654321)
			l_part := l_image.cropped (3, 4, 2, 2)
			assert ("size", l_part.width = 2 and l_part.height = 2)
			assert ("top left", l_part.pixel (0, 0) = 0xFF123456)
			assert ("bottom right", l_part.pixel (1, 1) = 0x7F654321)
			create l_mask.make (10, 10)
			l_mask.set_value (7, 8, 200)
			l_mask_part := l_mask.cropped (6, 7, 3, 3)
			assert ("mask value", l_mask_part.value (1, 1) = 200)
		end

	test_set_alpha_keeps_color
			-- alpha and set_alpha round-trip; color under alpha 0 is kept (a cutout can be re-grown).
		local
			l_image: IMG_IMAGE
			l_mask: IMG_MASK
		do
			create l_image.make_filled (8, 8, 0xFF00FF00)
			create l_mask.make (8, 8)
			l_mask.set_value (2, 2, 77)
			l_image.set_alpha (l_mask)
			assert ("alpha read back", l_image.alpha.is_equal (l_mask))
			assert ("soft pixel", l_image.pixel (2, 2) = 0x4D00FF00)
			assert ("color kept under alpha 0", l_image.pixel (0, 0) = 0x0000FF00)
		end

	test_flatten_onto
			-- Half-transparent red over white becomes opaque pink.
		local
			l_image: IMG_IMAGE
		do
			create l_image.make_filled (3, 3, 0x80FF0000)
			l_image.flatten_onto (0xFFFFFF)
			assert ("opaque", l_image.is_opaque)
			assert ("pink: " + l_image.pixel (1, 1).to_hex_string, l_image.pixel (1, 1) = 0xFFFF7F7F)
		end

feature -- Filters

	test_blur_keeps_color_at_soft_edges
			-- A red square on transparent black, blurred: every visible pixel is still pure red.
			-- A straight 8-bit blur fails this (its edges turn dark red: R 90 instead of 255).
		local
			l_image: IMG_IMAGE
			x, y, l_soft: INTEGER
			l_pixel: NATURAL_32
		do
			create l_image.make (40, 40)
			fill_rect (l_image, 10, 10, 20, 20, 0xFFFF0000)
			l_image.blur (4)
			from y := 0 until y >= 40 loop
				from x := 0 until x >= 40 loop
					l_pixel := l_image.pixel (x, y)
					if channel (l_pixel, 24) > 0 then
						assert ("red at " + x.out + "," + y.out + ": " + l_pixel.to_hex_string,
							channel (l_pixel, 16) >= 254 and channel (l_pixel, 8) <= 1 and channel (l_pixel, 0) <= 1)
						if channel (l_pixel, 24) < 255 then
							l_soft := l_soft + 1
						end
					end
					x := x + 1
				end
				y := y + 1
			end
			assert ("soft edge exists: " + l_soft.out, l_soft > 100)
		end

	test_blur_matches_float_reference
			-- The kernel rule: an RGBA blur over soft alpha is within 1 level of a float
			-- premultiplied reference written independently here (direct window sums).
		local
			l_image: IMG_IMAGE
			l_reference: ARRAY [INTEGER]
			x, y, c, l_diff, l_worst: INTEGER
		do
			l_image := noise_image (24, 16, True)
			l_reference := reference_blur (l_image, 2)
			l_image.blur (2)
			from y := 0 until y >= 16 loop
				from x := 0 until x >= 24 loop
					from c := 0 until c > 3 loop
						l_diff := (byte_of (l_image, x, y, c) - l_reference [((y * 24 + x) * 4 + c) + 1]).abs
						l_worst := l_worst.max (l_diff)
						c := c + 1
					end
					x := x + 1
				end
				y := y + 1
			end
			assert ("within 1 level, worst " + l_worst.out, l_worst <= 1)
		end

	test_resize_keeps_solid_color
			-- Lanczos weights sum to 1: a solid image resizes to exactly the same color.
		local
			l_image, l_small: IMG_IMAGE
			x, y: INTEGER
			l_same: BOOLEAN
		do
			create l_image.make_filled (30, 20, 0xFF336699)
			l_small := l_image.resized (17, 11)
			l_same := True
			from y := 0 until y >= 11 loop
				from x := 0 until x >= 17 loop
					l_same := l_same and l_small.pixel (x, y) = 0xFF336699
					x := x + 1
				end
				y := y + 1
			end
			assert ("solid kept", l_same)
			assert ("upscale too", l_image.resized (61, 43).pixel (40, 30) = 0xFF336699)
		end

	test_resize_keeps_color_at_soft_edges
			-- Resizing a red square on transparent black keeps every visible pixel pure red.
		local
			l_image, l_small: IMG_IMAGE
			x, y: INTEGER
			l_pixel: NATURAL_32
		do
			create l_image.make (40, 40)
			fill_rect (l_image, 10, 10, 20, 20, 0xFFFF0000)
			l_small := l_image.resized (17, 17)
			from y := 0 until y >= 17 loop
				from x := 0 until x >= 17 loop
					l_pixel := l_small.pixel (x, y)
					if channel (l_pixel, 24) > 0 then
						assert ("red at " + x.out + "," + y.out + ": " + l_pixel.to_hex_string,
							channel (l_pixel, 16) >= 254 and channel (l_pixel, 8) <= 1 and channel (l_pixel, 0) <= 1)
					end
					x := x + 1
				end
				y := y + 1
			end
		end

	test_enhance
			-- Brightness, contrast and color follow PIL ImageEnhance.
		local
			l_image: IMG_IMAGE
		do
			create l_image.make_filled (4, 4, 0xFF808080)
			l_image.enhance_brightness (0.5)
			assert ("brightness halves", l_image.pixel (0, 0) = 0xFF404040)

			create l_image.make_filled (4, 4, 0xFFFF0000)
			l_image.enhance_color (0)
			assert ("color 0 is gray: " + l_image.pixel (0, 0).to_hex_string, l_image.pixel (0, 0) = 0xFF4C4C4C)

			create l_image.make_filled (4, 2, 0xFF000000)
			fill_rect (l_image, 0, 1, 4, 1, 0xFFC8C8C8)
			l_image.enhance_contrast (0)
			assert ("contrast 0 is the mean: " + l_image.pixel (0, 0).to_hex_string, l_image.pixel (0, 0) = 0xFF646464)
			assert ("everywhere", l_image.pixel (3, 1) = 0xFF646464)
		end

	test_vignette
			-- The center keeps its brightness; a corner keeps about 1 - strength of it.
		local
			l_image: IMG_IMAGE
			l_corner: INTEGER
		do
			create l_image.make_filled (41, 41, 0xFFC8C8C8)
			l_image.vignette (0.5)
			assert ("center kept", l_image.pixel (20, 20) = 0xFFC8C8C8)
			l_corner := channel (l_image.pixel (0, 0), 16)
			assert ("corner darkened: " + l_corner.out, l_corner > 100 and l_corner < 110)
			assert ("alpha untouched", channel (l_image.pixel (0, 0), 24) = 255)
		end

feature -- Masks

	test_grow_and_shrink
			-- One pixel grown by 2 is a 5x5 square; shrunk by 2 it is one pixel again.
		local
			l_mask: IMG_MASK
		do
			create l_mask.make (21, 21)
			l_mask.set_value (10, 10, 255)
			l_mask.grow (2)
			assert ("5x5: " + l_mask.count_at_least (255).out, l_mask.count_at_least (255) = 25)
			assert ("corner of square", l_mask.value (8, 8) = 255)
			l_mask.shrink (2)
			assert ("one pixel: " + l_mask.count_at_least (255).out, l_mask.count_at_least (255) = 1)
		end

	test_mask_blur_keeps_total
			-- A blur moves coverage around but keeps its total (away from the edges).
		local
			l_mask: IMG_MASK
			l_before, l_after: INTEGER
		do
			create l_mask.make (40, 40)
			fill_mask_rect (l_mask, 15, 15, 10, 10, 255)
			l_before := mask_sum (l_mask)
			l_mask.blur (2)
			l_after := mask_sum (l_mask)
			assert ("total kept: " + l_before.out + " vs " + l_after.out, (l_after - l_before).abs <= 400)
			assert ("softened", l_mask.value (15, 15) < 255 and l_mask.value (14, 14) > 0)
		end

	test_threshold_and_invert
			-- threshold makes a hard mask; invert flips it.
		local
			l_mask: IMG_MASK
		do
			create l_mask.make (4, 1)
			l_mask.set_value (0, 0, 10)
			l_mask.set_value (1, 0, 127)
			l_mask.set_value (2, 0, 128)
			l_mask.set_value (3, 0, 250)
			l_mask.threshold (128)
			assert ("hard", l_mask.value (1, 0) = 0 and l_mask.value (2, 0) = 255)
			l_mask.invert
			assert ("inverted", l_mask.value (0, 0) = 255 and l_mask.value (3, 0) = 0)
		end

	test_flood_fill
			-- Filling inside a closed ring fills its 8x8 interior only.
		local
			l_mask: IMG_MASK
		do
			create l_mask.make (20, 20)
			fill_mask_rect (l_mask, 5, 5, 10, 1, 255)
			fill_mask_rect (l_mask, 5, 14, 10, 1, 255)
			fill_mask_rect (l_mask, 5, 5, 1, 10, 255)
			fill_mask_rect (l_mask, 14, 5, 1, 10, 255)
			l_mask.flood_fill (10, 10, 128)
			assert ("ring + interior: " + l_mask.count_at_least (128).out, l_mask.count_at_least (128) = 100)
			assert ("outside untouched", l_mask.value (0, 0) = 0)
			assert ("interior filled", l_mask.value (6, 6) = 128)
		end

	test_keep_largest_piece
			-- The big piece and its soft edge survive; the speck and the speck's edge go.
		local
			l_mask: IMG_MASK
		do
			create l_mask.make (40, 40)
			fill_mask_rect (l_mask, 2, 2, 10, 10, 255)
			fill_mask_rect (l_mask, 30, 30, 3, 3, 255)
			l_mask.set_value (12, 5, 100)
			l_mask.set_value (33, 30, 100)
			l_mask.keep_largest_piece (128)
			assert ("piece size: " + l_mask.last_piece_size.out, l_mask.last_piece_size = 100)
			assert ("speck gone", l_mask.value (31, 31) = 0)
			assert ("soft edge kept", l_mask.value (12, 5) = 100)
			assert ("speck edge gone", l_mask.value (33, 30) = 0)
		end

	test_mask_from_floats
			-- Floats are stretched lowest -> 0, highest -> 255 (rembg's normalization).
		local
			l_floats: MANAGED_POINTER
			l_mask: IMG_MASK
		do
			create l_floats.make (6 * 4)
			l_floats.put_real_32 (-2.0, 0)
			l_floats.put_real_32 (0.0, 4)
			l_floats.put_real_32 (2.0, 8)
			l_floats.put_real_32 (4.0, 12)
			l_floats.put_real_32 (6.0, 16)
			l_floats.put_real_32 (6.0, 20)
			create l_mask.make_from_floats (l_floats.item, 3, 2)
			assert ("lowest", l_mask.value (0, 0) = 0)
			assert ("quarter", l_mask.value (1, 0) = 64)
			assert ("half", l_mask.value (2, 0) = 128)
			assert ("highest", l_mask.value (2, 1) = 255)
		end

feature -- Canvas

	test_canvas_round_trip_is_exact
			-- Opaque pixels go into cairo and back unchanged.
		local
			l_image: IMG_IMAGE
			l_canvas: IMG_CANVAS
		do
			l_image := noise_image (64, 48, False)
			create l_canvas.make_from (l_image)
			assert ("exact", l_canvas.to_image.is_equal (l_image))
			l_canvas.destroy
		end

	test_canvas_place_half_alpha
			-- Half-transparent red placed over white gives pink (cairo OVER), within 1 level.
		local
			l_white, l_layer, l_result: IMG_IMAGE
			l_canvas: IMG_CANVAS
			l_pixel: NATURAL_32
		do
			create l_white.make_filled (10, 10, 0xFFFFFFFF)
			create l_layer.make_filled (4, 4, 0x80FF0000)
			create l_canvas.make_from (l_white)
			l_canvas.place (l_layer, 3, 3)
			l_result := l_canvas.to_image
			l_pixel := l_result.pixel (4, 4)
			assert ("pink: " + l_pixel.to_hex_string, channel (l_pixel, 16) = 255 and (channel (l_pixel, 8) - 127).abs <= 1
				and (channel (l_pixel, 0) - 127).abs <= 1 and channel (l_pixel, 24) = 255)
			assert ("outside untouched", l_result.pixel (0, 0) = 0xFFFFFFFF)
			l_canvas.destroy
		end

	test_canvas_fill_through
			-- A color painted through a mask lands only where the mask is.
		local
			l_white: IMG_IMAGE
			l_mask: IMG_MASK
			l_canvas: IMG_CANVAS
			l_result: IMG_IMAGE
		do
			create l_white.make_filled (20, 20, 0xFFFFFFFF)
			create l_mask.make (10, 10)
			fill_mask_rect (l_mask, 2, 2, 6, 6, 255)
			create l_canvas.make_from (l_white)
			l_canvas.fill_through (l_mask, 0xFF000000, 5, 5)
			l_result := l_canvas.to_image
			assert ("inside black", l_result.pixel (10, 10) = 0xFF000000)
			assert ("outside white", l_result.pixel (0, 0) = 0xFFFFFFFF)
			assert ("mask edge white", l_result.pixel (6, 6) = 0xFFFFFFFF)
			l_canvas.destroy
		end

	test_outlined_title_with_shadow
			-- The thumbnail recipe: text drawn on a mask canvas becomes a blurred shadow, then the
			-- title is stroked black and filled white (cairo text_path). Writes data/output/title.jpg.
		local
			l_images: SIMPLE_IMAGE
			l_background, l_result: IMG_IMAGE
			l_shadow_canvas, l_canvas: IMG_CANVAS
			l_shadow: IMG_MASK
			l_white, l_black: INTEGER
		do
			create l_images.make
			create l_background.make_filled (420, 160, 0xFF2A4D7A)
			l_background.vignette (0.6)

			l_shadow_canvas := l_images.new_mask_canvas (420, 160)
			l_shadow_canvas.context.select_font ("Arial", l_shadow_canvas.context.Slant_normal, l_shadow_canvas.context.Weight_bold)
				.set_font_size (90).move_to (20, 120).text_path ("TITLE").fill.do_nothing
			l_shadow := l_shadow_canvas.to_mask
			l_shadow_canvas.destroy
			assert ("text became a mask: " + l_shadow.count_at_least (128).out, l_shadow.count_at_least (128) > 2000)
			l_shadow.grow (3)
			l_shadow.blur (5)

			l_canvas := l_images.canvas_from (l_background)
			l_canvas.fill_through (l_shadow, 0xC0000000, 6, 6)
			l_canvas.context.select_font ("Arial", l_canvas.context.Slant_normal, l_canvas.context.Weight_bold)
				.set_font_size (90).move_to (20, 120).text_path ("TITLE").do_nothing
			l_canvas.context.set_color_rgb (0, 0, 0).set_line_width (8).set_line_join (l_canvas.context.Join_round).stroke_preserve
				.set_color_rgb (1, 1, 1).fill.do_nothing
			l_result := l_canvas.to_image
			l_canvas.destroy

			l_white := count_color (l_result, 0xFFFFFFFF)
			l_black := count_color (l_result, 0xFF000000)
			assert ("white fill: " + l_white.out, l_white > 2000)
			assert ("black outline: " + l_black.out, l_black > 1000)
			assert ("opaque", l_result.is_opaque)
			assert ("jpg written", l_result.save_jpg (output_path ("title.jpg"), 92))
		end

	test_seam_timing_1280x720
			-- Verification queue 1: one thumbnail variant's seam at full size, timed against a blur.
			-- (Overturn trigger: seam copies above 5% of a variant's wall time.)
		local
			l_background, l_layer, l_result: IMG_IMAGE
			l_halo: IMG_MASK
			l_canvas: IMG_CANVAS
			l_t0, l_seam, l_blur: REAL_64
		do
			l_background := noise_image (1280, 720, False)
			l_layer := noise_image (600, 700, True)
			l_halo := l_layer.alpha
			l_t0 := now_ms
			l_canvas := (create {SIMPLE_IMAGE}.make).canvas_from (l_background)
			l_canvas.fill_through (l_halo, 0xFFFFD34D, 40, 10)
			l_canvas.place (l_layer, 40, 10)
			l_result := l_canvas.to_image
			l_seam := now_ms - l_t0
			l_canvas.destroy
			l_t0 := now_ms
			l_halo.blur (12)
			l_blur := now_ms - l_t0
			io.put_string ("    seam (copy in, fill_through, place, copy out): " + l_seam.truncated_to_integer.out
				+ " ms; one 600x700 mask blur: " + l_blur.truncated_to_integer.out + " ms%N")
			assert ("result size", l_result.width = 1280 and l_result.height = 720)
			assert ("seam under a second", l_seam < 1000)
		end

feature -- Files and memory

	test_png_round_trip
			-- An image with soft alpha survives a PNG round trip exactly.
		local
			l_image: IMG_IMAGE
		do
			l_image := noise_image (33, 21, True)
			assert ("written", l_image.save_png (output_path ("round_trip.png")))
			if attached (create {SIMPLE_IMAGE}.make).load (output_path ("round_trip.png")) as al_back then
				assert ("same pixels", al_back.is_equal (l_image))
			else
				assert ("loaded", False)
			end
		end

	test_mask_png_round_trip
			-- A mask saved as gray PNG loads back as the same mask.
		local
			l_mask: IMG_MASK
		do
			create l_mask.make (17, 9)
			fill_mask_rect (l_mask, 3, 2, 8, 5, 200)
			l_mask.set_value (0, 0, 13)
			assert ("written", l_mask.save_png (output_path ("mask.png")))
			if attached (create {SIMPLE_IMAGE}.make).load_mask (output_path ("mask.png")) as al_back then
				assert ("same values", al_back.is_equal (l_mask))
			else
				assert ("loaded", False)
			end
		end

	test_load_failure_reports
			-- A missing file gives Void and a reason.
		local
			l_images: SIMPLE_IMAGE
		do
			create l_images.make
			assert ("void", l_images.load ("data/input/no_such_file.png") = Void)
			assert ("reason given", l_images.has_error)
		end

	test_collector_frees_images
			-- Images and masks left undestroyed are freed by the garbage collector.
		local
			l_image: IMG_IMAGE
			l_mask: IMG_MASK
			l_memory: MEMORY
			i: INTEGER
		do
			create l_memory
			create l_image.make (1, 1)
			create l_mask.make (1, 1)
			from i := 1 until i > 300 loop
				create l_image.make (512, 512)
				create l_mask.make (512, 512)
				if i \\ 50 = 0 then
					l_memory.full_collect
				end
				i := i + 1
			end
			l_memory.full_collect
			assert ("still working", l_image.is_usable and l_mask.is_usable)
		end

feature {NONE} -- Helpers

	channel (a_color: NATURAL_32; a_shift: INTEGER): INTEGER
			-- The 8-bit channel of `a_color' at `a_shift'.
		do
			Result := ((a_color |>> a_shift) & 0xFF).to_integer_32
		end

	byte_of (a_image: IMG_IMAGE; a_x, a_y, a_c: INTEGER): INTEGER
			-- Channel `a_c' (0 R, 1 G, 2 B, 3 A) of the pixel at (`a_x', `a_y').
		local
			l_pixel: NATURAL_32
		do
			l_pixel := a_image.pixel (a_x, a_y)
			inspect a_c
			when 0 then Result := channel (l_pixel, 16)
			when 1 then Result := channel (l_pixel, 8)
			when 2 then Result := channel (l_pixel, 0)
			else Result := channel (l_pixel, 24)
			end
		end

	fill_rect (a_image: IMG_IMAGE; a_x, a_y, a_width, a_height: INTEGER; a_color: NATURAL_32)
			-- Set a rectangle of pixels.
		local
			x, y: INTEGER
		do
			from y := a_y until y >= a_y + a_height loop
				from x := a_x until x >= a_x + a_width loop
					a_image.set_pixel (x, y, a_color)
					x := x + 1
				end
				y := y + 1
			end
		end

	fill_mask_rect (a_mask: IMG_MASK; a_x, a_y, a_width, a_height: INTEGER; a_value: NATURAL_8)
			-- Set a rectangle of values.
		local
			x, y: INTEGER
		do
			from y := a_y until y >= a_y + a_height loop
				from x := a_x until x >= a_x + a_width loop
					a_mask.set_value (x, y, a_value)
					x := x + 1
				end
				y := y + 1
			end
		end

	mask_sum (a_mask: IMG_MASK): INTEGER
			-- Sum of all values.
		local
			x, y: INTEGER
		do
			from y := 0 until y >= a_mask.height loop
				from x := 0 until x >= a_mask.width loop
					Result := Result + a_mask.value (x, y).to_integer_32
					x := x + 1
				end
				y := y + 1
			end
		end

	count_color (a_image: IMG_IMAGE; a_color: NATURAL_32): INTEGER
			-- Pixels exactly `a_color'.
		local
			x, y: INTEGER
		do
			from y := 0 until y >= a_image.height loop
				from x := 0 until x >= a_image.width loop
					if a_image.pixel (x, y) = a_color then
						Result := Result + 1
					end
					x := x + 1
				end
				y := y + 1
			end
		end

	noise_image (a_width, a_height: INTEGER; a_soft_alpha: BOOLEAN): IMG_IMAGE
			-- Deterministic pseudo-random pixels; with `a_soft_alpha' a quarter are fully
			-- transparent and the rest vary in alpha, else all opaque.
		do
			create Result.make (a_width, a_height)
			c_noise (Result.pixels, Result.pixel_count, a_soft_alpha)
		end

	c_noise (a_p: POINTER; a_n: INTEGER; a_soft: BOOLEAN)
			-- Linear congruential pixels (C, so full-size test images take no time).
		external
			"C inline"
		alias
			"[
				unsigned int seed = 12345u; size_t i; unsigned char *p = (unsigned char *) $a_p;
				for (i = 0; i < (size_t) $a_n; i++) {
					unsigned int a;
					seed = seed * 1103515245u + 12345u;
					a = seed >> 24;
					if (!$a_soft) a = 255; else if (a < 64) a = 0;
					p[i * 4] = (unsigned char) ((seed >> 16) & 255); p[i * 4 + 1] = (unsigned char) ((seed >> 8) & 255);
					p[i * 4 + 2] = (unsigned char) (seed & 255); p[i * 4 + 3] = (unsigned char) a;
				}
			]"
		end

	reference_blur (a_image: IMG_IMAGE; a_radius: INTEGER): ARRAY [INTEGER]
			-- Independent float reference: premultiply, three passes of direct box sums
			-- (edge pixels repeated) horizontally then vertically, unpremultiply, round.
		local
			l_w, l_h, x, y, c, i, l_pass, l_xi: INTEGER
			l_f, l_t: ARRAY [REAL_64]
			l_sum, l_a: REAL_64
		do
			l_w := a_image.width
			l_h := a_image.height
			create l_f.make_filled (0, 1, l_w * l_h * 4)
			create l_t.make_filled (0, 1, l_w * l_h * 4)
			from y := 0 until y >= l_h loop
				from x := 0 until x >= l_w loop
					l_a := byte_of (a_image, x, y, 3)
					from c := 0 until c > 2 loop
						l_f [(y * l_w + x) * 4 + c + 1] := byte_of (a_image, x, y, c) * l_a / 255
						c := c + 1
					end
					l_f [(y * l_w + x) * 4 + 4] := l_a
					x := x + 1
				end
				y := y + 1
			end
			from l_pass := 1 until l_pass > 3 loop
				from y := 0 until y >= l_h loop
					from x := 0 until x >= l_w loop
						from c := 0 until c > 3 loop
							l_sum := 0
							from i := - a_radius until i > a_radius loop
								l_xi := (x + i).max (0).min (l_w - 1)
								l_sum := l_sum + l_f [(y * l_w + l_xi) * 4 + c + 1]
								i := i + 1
							end
							l_t [(y * l_w + x) * 4 + c + 1] := l_sum / (2 * a_radius + 1)
							c := c + 1
						end
						x := x + 1
					end
					y := y + 1
				end
				from y := 0 until y >= l_h loop
					from x := 0 until x >= l_w loop
						from c := 0 until c > 3 loop
							l_sum := 0
							from i := - a_radius until i > a_radius loop
								l_xi := (y + i).max (0).min (l_h - 1)
								l_sum := l_sum + l_t [(l_xi * l_w + x) * 4 + c + 1]
								i := i + 1
							end
							l_f [(y * l_w + x) * 4 + c + 1] := l_sum / (2 * a_radius + 1)
							c := c + 1
						end
						x := x + 1
					end
					y := y + 1
				end
				l_pass := l_pass + 1
			end
			create Result.make_filled (0, 1, l_w * l_h * 4)
			from i := 0 until i >= l_w * l_h loop
				l_a := l_f [i * 4 + 4]
				from c := 0 until c > 2 loop
					if l_a > 1.0e-6 then
						Result [i * 4 + c + 1] := to_byte (l_f [i * 4 + c + 1] * 255 / l_a)
					end
					c := c + 1
				end
				Result [i * 4 + 4] := to_byte (l_a)
				i := i + 1
			end
		end

	to_byte (a_value: REAL_64): INTEGER
			-- `a_value' rounded into 0..255.
		do
			Result := (a_value + 0.5).floor.max (0).min (255)
		end

	output_path (a_name: STRING): STRING
			-- data/output/`a_name', creating the folder when needed.
		local
			l_dir: DIRECTORY
		do
			create l_dir.make ("data/output")
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end
			Result := "data/output/" + a_name
		end

	now_ms: REAL_64
			-- A millisecond clock.
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
