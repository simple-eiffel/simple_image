note
	description: "[
		A mask: one 8-bit channel (0 = none, 255 = full), in C memory.

		Masks carry cutouts, halos, shadows and outlines. A solid-color layer drawn as a
		mask plus a color fill (IMG_CANVAS.fill_through) is exact (debate 04: within 0.2
		levels of a float premultiplied blur), so shadows and glows are mask work, never
		RGBA blurs.

		Usage:
			halo := person.alpha
			halo.grow (6)
			halo.blur (8)
			canvas.fill_through (halo, 0xFFFFD34D, x, y)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	IMG_MASK

inherit
	ANY
		redefine
			copy,
			is_equal
		end

	IMG_KERNELS
		export
			{NONE} all
		undefine
			copy,
			is_equal
		end

create
	make,
	make_filled,
	make_from_floats

feature {NONE} -- Initialization

	make (a_width, a_height: INTEGER)
			-- Empty (all 0) mask of `a_width' x `a_height'.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			width := a_width
			height := a_height
			stb := (create {SIMPLE_STB}.make).create_image (a_width, a_height, 1)
			ensure_memory (stb.is_valid)
		ensure
			width_set: width = a_width
			height_set: height = a_height
			usable: is_usable
			empty: count_at_least (1) = 0
		end

	make_filled (a_width, a_height: INTEGER; a_value: NATURAL_8)
			-- Mask of `a_width' x `a_height' with every value `a_value'.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			make (a_width, a_height)
			fill (a_value)
		ensure
			filled: value (0, 0) = a_value
		end

	make_from_floats (a_floats: POINTER; a_width, a_height: INTEGER)
			-- Mask from `a_width' x `a_height' float32 values at `a_floats', stretched so the
			-- lowest becomes 0 and the highest 255 (how rembg reads a segmentation output).
		require
			floats_exist: a_floats /= default_pointer
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			make (a_width, a_height)
			c_floats_to_mask (a_floats, pixel_count, values)
		ensure
			width_set: width = a_width
			height_set: height = a_height
		end

feature -- Access

	width: INTEGER
			-- Width in pixels.

	height: INTEGER
			-- Height in pixels.

	pixel_count: INTEGER
			-- Number of values.
		do
			Result := width * height
		end

	values: POINTER
			-- Address of the first value (rows packed, one byte each). Valid until `destroy'.
		require
			usable: is_usable
		do
			Result := stb.data
		ensure
			exists: Result /= default_pointer
		end

	value (a_x, a_y: INTEGER): NATURAL_8
			-- Value at (`a_x', `a_y').
		require
			usable: is_usable
			x_in: a_x >= 0 and a_x < width
			y_in: a_y >= 0 and a_y < height
		do
			Result := c_get_value (values, width, a_x, a_y)
		end

	count_at_least (a_level: INTEGER): INTEGER
			-- Number of values >= `a_level'.
		require
			usable: is_usable
			level_in_range: a_level >= 0 and a_level <= 255
		do
			Result := c_count_at_least (values, pixel_count, a_level)
		ensure
			in_range: Result >= 0 and Result <= pixel_count
		end

	bounds (a_level: INTEGER): TUPLE [x, y, width, height: INTEGER]
			-- Smallest rectangle holding every value >= `a_level' (all 0 when there is none):
			-- where the person is in a cutout mask.
		require
			usable: is_usable
			level_in_range: a_level >= 1 and a_level <= 255
		local
			l_out: MANAGED_POINTER
		do
			create l_out.make (16)
			c_bounds (values, width, height, a_level, l_out.item)
			Result := [l_out.read_integer_32 (0), l_out.read_integer_32 (4), l_out.read_integer_32 (8), l_out.read_integer_32 (12)]
		ensure
			empty_or_inside: Result.width = 0 or else is_inside (Result.x, Result.y, Result.width, Result.height)
			empty_when_none: (Result.width = 0) = (count_at_least (a_level) = 0)
		end

	last_piece_size: INTEGER
			-- Size of the piece kept by the last `keep_largest_piece' (0 when there was none).

feature -- Status

	is_usable: BOOLEAN
			-- Are the values still allocated (not destroyed)?
		do
			Result := stb.is_valid
		end

	is_inside (a_x, a_y, a_width, a_height: INTEGER): BOOLEAN
			-- Does the rectangle lie wholly inside the mask?
		do
			Result := a_x >= 0 and a_y >= 0 and a_width > 0 and a_height > 0
				and a_x + a_width <= width and a_y + a_height <= height
		end

feature -- Values

	set_value (a_x, a_y: INTEGER; a_value: NATURAL_8)
			-- Set the value at (`a_x', `a_y').
		require
			usable: is_usable
			x_in: a_x >= 0 and a_x < width
			y_in: a_y >= 0 and a_y < height
		do
			c_set_value (values, width, a_x, a_y, a_value)
		ensure
			set: value (a_x, a_y) = a_value
		end

	fill (a_value: NATURAL_8)
			-- Set every value to `a_value'.
		require
			usable: is_usable
		do
			c_fill_bytes (values, pixel_count, a_value)
		ensure
			corner_set: value (0, 0) = a_value
			far_corner_set: value (width - 1, height - 1) = a_value
		end

feature -- Filters

	blur (a_radius: INTEGER)
			-- Soften with three box passes of `a_radius'.
		require
			usable: is_usable
			radius_not_negative: a_radius >= 0
		do
			if a_radius > 0 then
				ensure_memory (c_blur_gray (values, width, height, a_radius) = 1)
			end
		end

	grow (a_amount: INTEGER)
			-- Widen the mask by `a_amount' pixels (largest value over a square).
		require
			usable: is_usable
			amount_not_negative: a_amount >= 0
		do
			if a_amount > 0 then
				ensure_memory (c_grow (values, width, height, a_amount, True) = 1)
			end
		end

	shrink (a_amount: INTEGER)
			-- Narrow the mask by `a_amount' pixels (smallest value over a square).
		require
			usable: is_usable
			amount_not_negative: a_amount >= 0
		do
			if a_amount > 0 then
				ensure_memory (c_grow (values, width, height, a_amount, False) = 1)
			end
		end

	threshold (a_level: INTEGER)
			-- Make values >= `a_level' 255 and the rest 0.
		require
			usable: is_usable
			level_in_range: a_level >= 0 and a_level <= 255
		do
			c_threshold (values, pixel_count, a_level)
		ensure
			hard: count_at_least (1) = count_at_least (255)
		end

	invert
			-- Replace each value v with 255 - v.
		require
			usable: is_usable
		do
			c_invert (values, pixel_count)
		ensure
			corner_inverted: value (0, 0) = (255 - old value (0, 0)).to_natural_8
		end

	flood_fill (a_x, a_y: INTEGER; a_value: NATURAL_8)
			-- Set the 4-connected region of values equal to the one at (`a_x', `a_y') to `a_value'.
		require
			usable: is_usable
			x_in: a_x >= 0 and a_x < width
			y_in: a_y >= 0 and a_y < height
		do
			ensure_memory (c_flood_fill (values, width, height, a_x, a_y, a_value.to_integer_32) >= 0)
		ensure
			seed_set: value (a_x, a_y) = a_value
		end

	keep_largest_piece (a_level: INTEGER)
			-- Keep only the largest 4-connected piece of values >= `a_level' (with its soft edge,
			-- up to 2 pixels out); clear every other piece. Removes specks from a cutout.
		require
			usable: is_usable
			level_in_range: a_level >= 1 and a_level <= 255
		local
			l_size: INTEGER
		do
			l_size := c_keep_largest (values, width, height, a_level)
			ensure_memory (l_size >= 0)
			last_piece_size := l_size
		ensure
			only_the_piece: count_at_least (a_level) = last_piece_size
		end

feature -- New masks

	cropped (a_x, a_y, a_width, a_height: INTEGER): IMG_MASK
			-- A new mask of the given rectangle.
		require
			usable: is_usable
			inside: is_inside (a_x, a_y, a_width, a_height)
		do
			create Result.make (a_width, a_height)
			c_copy_rows (values + (a_y * width + a_x), width, Result.values, a_width, a_width, a_height)
		ensure
			sized: Result.width = a_width and Result.height = a_height
			first_value: Result.value (0, 0) = value (a_x, a_y)
		end

	resized (a_width, a_height: INTEGER): IMG_MASK
			-- A new mask scaled to `a_width' x `a_height' with Lanczos-3 (debate 03 verdict).
		require
			usable: is_usable
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make (a_width, a_height)
			ensure_memory (c_resize_gray (values, width, height, Result.values, a_width, a_height) = 1)
		ensure
			sized: Result.width = a_width and Result.height = a_height
		end

feature -- Files

	save_png (a_path: READABLE_STRING_GENERAL): BOOLEAN
			-- Write as a grayscale PNG; True on success.
		require
			usable: is_usable
			path_not_empty: not a_path.is_empty
		do
			Result := stb.write_png (a_path)
		end

feature -- Duplication and comparison

	copy (a_other: like Current)
			-- Make this mask a separate copy of `a_other''s values.
		do
			if a_other /= Current then
				width := a_other.width
				height := a_other.height
				last_piece_size := a_other.last_piece_size
				stb := a_other.stb.duplicate
				ensure_memory (stb.is_valid)
			end
		end

	is_equal (a_other: like Current): BOOLEAN
			-- Same size and same values?
		do
			if a_other = Current then
				Result := True
			elseif is_usable and a_other.is_usable and width = a_other.width and height = a_other.height then
				Result := c_same_bytes (values, a_other.values, pixel_count)
			end
		end

feature -- Removal

	destroy
			-- Free the values now (the garbage collector frees them otherwise).
		do
			stb.destroy
		ensure
			gone: not is_usable
		end

feature {IMG_MASK} -- Implementation

	stb: STB_IMAGE
			-- Owner of the values.

feature {NONE} -- Byte access

	c_get_value (a_p: POINTER; a_w, a_x, a_y: INTEGER): NATURAL_8
		external "C inline"
		alias "return ((const unsigned char *) $a_p)[(size_t) $a_y * $a_w + $a_x];"
		end

	c_set_value (a_p: POINTER; a_w, a_x, a_y: INTEGER; a_value: NATURAL_8)
		external "C inline"
		alias "((unsigned char *) $a_p)[(size_t) $a_y * $a_w + $a_x] = (unsigned char) $a_value;"
		end

	c_fill_bytes (a_p: POINTER; a_n: INTEGER; a_value: NATURAL_8)
		external "C inline use <string.h>"
		alias "memset ((void *) $a_p, (int) $a_value, (size_t) $a_n);"
		end

invariant
	positive_size: width > 0 and height > 0
	stb_matches: is_usable implies (stb.width = width and stb.height = height and stb.channels = 1)
	piece_size_not_negative: last_piece_size >= 0

end
