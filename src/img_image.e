note
	description: "[
		An image: straight (non-premultiplied) RGBA, 8 bits per channel, in C memory.

		The pixels live in a private STB_IMAGE (simple_stb), so loading and saving need no
		conversion, and straight storage keeps colour at every alpha level (debate 04: a
		premultiplied 8-bit store loses a mean of 30 levels of colour at alpha 1-10).
		Every editing operation lives here; drawing (text, shapes, placing layers) goes
		through IMG_CANVAS, which copies into cairo and back.

		Colours are NATURAL_32 words 0xAARRGGBB with straight alpha.

		Usage:
			image := (create {SIMPLE_IMAGE}.make).load ("photo.jpg")
			image.enhance_contrast (1.2)
			image.vignette (0.4)
			if image.save_jpg ("out.jpg", 92) then ... end
			image.destroy      -- or leave it to the garbage collector
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	IMG_IMAGE

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
	make_filled

create {SIMPLE_IMAGE, IMG_IMAGE, IMG_MASK, IMG_CANVAS}
	make_from_stb

feature {NONE} -- Initialization

	make (a_width, a_height: INTEGER)
			-- Transparent black image of `a_width' x `a_height'.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			width := a_width
			height := a_height
			stb := (create {SIMPLE_STB}.make).create_rgba (a_width, a_height)
			ensure_memory (stb.is_valid)
		ensure
			width_set: width = a_width
			height_set: height = a_height
			usable: is_usable
		end

	make_filled (a_width, a_height: INTEGER; a_colour: NATURAL_32)
			-- Image of `a_width' x `a_height' filled with `a_colour' (0xAARRGGBB).
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			make (a_width, a_height)
			fill (a_colour)
		ensure
			width_set: width = a_width
			height_set: height = a_height
			filled: pixel (0, 0) = a_colour
		end

	make_from_stb (a_stb: STB_IMAGE)
			-- Image owning the pixels of `a_stb' (4 channels).
		require
			stb_valid: a_stb.is_valid
			four_channels: a_stb.channels = 4
			packed: a_stb.stride = a_stb.width * 4
		do
			stb := a_stb
			width := a_stb.width
			height := a_stb.height
		ensure
			owns_it: stb = a_stb
		end

feature -- Access

	width: INTEGER
			-- Width in pixels.

	height: INTEGER
			-- Height in pixels.

	stride: INTEGER
			-- Bytes per row (rows are packed).
		do
			Result := width * 4
		ensure
			packed: Result = width * 4
		end

	pixel_count: INTEGER
			-- Number of pixels.
		do
			Result := width * height
		end

	pixels: POINTER
			-- Address of the first pixel (R, G, B, A bytes, rows packed). Valid until `destroy'.
		require
			usable: is_usable
		do
			Result := stb.data
		ensure
			exists: Result /= default_pointer
		end

	pixel (a_x, a_y: INTEGER): NATURAL_32
			-- Colour at (`a_x', `a_y') as 0xAARRGGBB, straight alpha.
		require
			usable: is_usable
			x_in: a_x >= 0 and a_x < width
			y_in: a_y >= 0 and a_y < height
		do
			Result := c_get_argb (pixels, width, a_x, a_y)
		end

	alpha: IMG_MASK
			-- A new mask holding this image's alpha channel.
		require
			usable: is_usable
		do
			create Result.make (width, height)
			c_alpha_to_mask (pixels, pixel_count, Result.values)
		ensure
			same_size: Result.width = width and Result.height = height
		end

feature -- Status

	is_usable: BOOLEAN
			-- Are the pixels still allocated (not destroyed)?
		do
			Result := stb.is_valid
		end

	is_opaque: BOOLEAN
			-- Is every pixel fully opaque (alpha 255)?
		require
			usable: is_usable
		do
			Result := c_is_opaque (pixels, pixel_count)
		end

	is_inside (a_x, a_y, a_width, a_height: INTEGER): BOOLEAN
			-- Does the rectangle lie wholly inside the image?
		do
			Result := a_x >= 0 and a_y >= 0 and a_width > 0 and a_height > 0
				and a_x + a_width <= width and a_y + a_height <= height
		end

feature -- Pixels

	set_pixel (a_x, a_y: INTEGER; a_colour: NATURAL_32)
			-- Set the colour at (`a_x', `a_y') to `a_colour' (0xAARRGGBB).
		require
			usable: is_usable
			x_in: a_x >= 0 and a_x < width
			y_in: a_y >= 0 and a_y < height
		do
			c_set_argb (pixels, width, a_x, a_y, a_colour)
		ensure
			set: pixel (a_x, a_y) = a_colour
		end

	fill (a_colour: NATURAL_32)
			-- Set every pixel to `a_colour' (0xAARRGGBB).
		require
			usable: is_usable
		do
			c_fill_rgba (pixels, pixel_count, a_colour)
		ensure
			corner_set: pixel (0, 0) = a_colour
			far_corner_set: pixel (width - 1, height - 1) = a_colour
		end

	set_alpha (a_mask: IMG_MASK)
			-- Use `a_mask' as the alpha channel. Colour under alpha 0 is kept.
		require
			usable: is_usable
			mask_usable: a_mask.is_usable
			same_size: a_mask.width = width and a_mask.height = height
		do
			c_mask_to_alpha (pixels, pixel_count, a_mask.values)
		ensure
			corner_alpha: (pixel (0, 0) |>> 24).to_natural_8 = a_mask.value (0, 0)
		end

feature -- Filters

	blur (a_radius: INTEGER)
			-- Blur with three box passes of `a_radius' (close to a gaussian of sigma ~ `a_radius').
			-- Colour is premultiplied in float inside the kernel, so soft edges keep their colour.
		require
			usable: is_usable
			radius_not_negative: a_radius >= 0
		do
			if a_radius > 0 then
				ensure_memory (c_blur_rgba (pixels, width, height, a_radius) = 1)
			end
		end

	enhance_brightness (a_factor: REAL_64)
			-- Scale brightness: 0 gives black, 1 leaves the image as it is (PIL ImageEnhance.Brightness).
		require
			usable: is_usable
			factor_not_negative: a_factor >= 0
		do
			c_enhance (pixels, pixel_count, 1, a_factor, 0)
		end

	enhance_contrast (a_factor: REAL_64)
			-- Scale contrast about the mean gray: 0 gives flat gray, 1 leaves the image (PIL ImageEnhance.Contrast).
		require
			usable: is_usable
			factor_not_negative: a_factor >= 0
		do
			c_enhance (pixels, pixel_count, 2, a_factor, c_mean_gray (pixels, pixel_count))
		end

	enhance_color (a_factor: REAL_64)
			-- Scale saturation: 0 gives grayscale, 1 leaves the image (PIL ImageEnhance.Color).
		require
			usable: is_usable
			factor_not_negative: a_factor >= 0
		do
			c_enhance (pixels, pixel_count, 3, a_factor, 0)
		end

	vignette (a_strength: REAL_64)
			-- Darken toward the corners: a corner keeps 1 - `a_strength' of its brightness.
		require
			usable: is_usable
			strength_in_range: a_strength >= 0 and a_strength <= 1
		do
			c_vignette (pixels, width, height, a_strength)
		end

	flatten_onto (a_background: NATURAL_32)
			-- Composite onto the opaque colour `a_background' (0x__RRGGBB); the result is opaque.
		require
			usable: is_usable
		do
			c_flatten (pixels, pixel_count, ((a_background |>> 16) & 0xFF).to_integer_32,
				((a_background |>> 8) & 0xFF).to_integer_32, (a_background & 0xFF).to_integer_32)
		ensure
			opaque: is_opaque
		end

feature -- New images

	cropped (a_x, a_y, a_width, a_height: INTEGER): IMG_IMAGE
			-- A new image of the given rectangle.
		require
			usable: is_usable
			inside: is_inside (a_x, a_y, a_width, a_height)
		do
			create Result.make (a_width, a_height)
			c_copy_rows (pixels + (a_y * stride + a_x * 4), stride, Result.pixels, Result.stride, a_width * 4, a_height)
		ensure
			sized: Result.width = a_width and Result.height = a_height
			first_pixel: Result.pixel (0, 0) = pixel (a_x, a_y)
		end

	resized (a_width, a_height: INTEGER): IMG_IMAGE
			-- A new image scaled to `a_width' x `a_height' with Lanczos-3 (debate 03 verdict),
			-- premultiplied in float so soft edges keep their colour.
		require
			usable: is_usable
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make (a_width, a_height)
			ensure_memory (c_resize_rgba (pixels, width, height, Result.pixels, a_width, a_height) = 1)
		ensure
			sized: Result.width = a_width and Result.height = a_height
		end

feature -- Files

	save_png (a_path: READABLE_STRING_GENERAL): BOOLEAN
			-- Write as PNG (alpha kept); True on success.
		require
			usable: is_usable
			path_not_empty: not a_path.is_empty
			narrow_path: a_path.is_valid_as_string_8
		do
			Result := stb.write_png (a_path)
		end

	save_jpg (a_path: READABLE_STRING_GENERAL; a_quality: INTEGER): BOOLEAN
			-- Write as JPEG at `a_quality' (1-100); True on success. JPEG has no alpha, so flatten first.
		require
			usable: is_usable
			opaque: is_opaque
			path_not_empty: not a_path.is_empty
			narrow_path: a_path.is_valid_as_string_8
			quality_in_range: a_quality >= 1 and a_quality <= 100
		do
			Result := stb.write_jpg (a_path, a_quality)
		end

feature -- Duplication and comparison

	copy (a_other: like Current)
			-- Make this image a separate copy of `a_other''s pixels.
		do
			if a_other /= Current then
				width := a_other.width
				height := a_other.height
				stb := a_other.stb.duplicate
				ensure_memory (stb.is_valid)
			end
		end

	is_equal (a_other: like Current): BOOLEAN
			-- Same size and same pixels?
		do
			if a_other = Current then
				Result := True
			elseif is_usable and a_other.is_usable and width = a_other.width and height = a_other.height then
				Result := c_same_bytes (pixels, a_other.pixels, pixel_count * 4)
			end
		end

feature -- Removal

	destroy
			-- Free the pixels now (the garbage collector frees them otherwise).
		do
			stb.destroy
		ensure
			gone: not is_usable
		end

feature {IMG_IMAGE} -- Implementation

	stb: STB_IMAGE
			-- Owner of the pixels.

invariant
	positive_size: width > 0 and height > 0
	stb_matches: is_usable implies (stb.width = width and stb.height = height and stb.channels = 4)

end
