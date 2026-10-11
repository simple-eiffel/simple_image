note
	description: "[
		simple_image - image editing in Eiffel: load, filter, mask, compose, save.

		Images (IMG_IMAGE) are straight RGBA8 and masks (IMG_MASK) one 8-bit channel, both in
		C memory; every operation is an Eiffel feature with contracts over a C kernel. Drawing
		(text, shapes, layers) goes through IMG_CANVAS on simple_cairo. Files go through
		simple_stb (PNG, JPEG, BMP, TGA, GIF and more in; PNG and JPEG out).

		The design came out of the 2026-10-11 debate cycle in .eiffel-workflow/debate/.

		Usage:
			images: SIMPLE_IMAGE
			create images.make
			if attached images.load ("frame.png") as al_frame then
				al_frame.enhance_contrast (1.15)
				if al_frame.is_opaque and then al_frame.save_jpg ("frame.jpg", 92) then ... end
			else
				print (images.last_error)
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_IMAGE

create
	make

feature {NONE} -- Initialization

	make
			-- Ready to load and create images.
		do
			create stb.make
			last_error := ""
		ensure
			no_error: not has_error
		end

feature -- Loading

	load (a_path: READABLE_STRING_GENERAL): detachable IMG_IMAGE
			-- The image in the file `a_path' as RGBA, or Void (see `last_error').
		require
			path_not_empty: not a_path.is_empty
			narrow_path: a_path.is_valid_as_string_8
		local
			l_stb: STB_IMAGE
		do
			l_stb := stb.load_rgba (a_path)
			if l_stb.is_valid and then l_stb.channels = 4 then
				create Result.make_from_stb (l_stb)
				last_error := ""
			else
				last_error := "cannot load " + a_path.to_string_8 + ": " + l_stb.error_message
				l_stb.destroy
			end
		ensure
			error_when_void: Result = Void implies has_error
			no_error_when_loaded: Result /= Void implies not has_error
		end

	load_mask (a_path: READABLE_STRING_GENERAL): detachable IMG_MASK
			-- The file `a_path' read as one gray channel, or Void (see `last_error').
		require
			path_not_empty: not a_path.is_empty
			narrow_path: a_path.is_valid_as_string_8
		do
			if attached load (a_path) as al_image then
				Result := gray_of (al_image)
				al_image.destroy
			end
		ensure
			error_when_void: Result = Void implies has_error
		end

feature -- Creation

	new_image (a_width, a_height: INTEGER): IMG_IMAGE
			-- A transparent image.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make (a_width, a_height)
		end

	new_mask (a_width, a_height: INTEGER): IMG_MASK
			-- An empty mask.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make (a_width, a_height)
		end

	new_canvas (a_width, a_height: INTEGER): IMG_CANVAS
			-- A transparent color canvas.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make (a_width, a_height)
		end

	new_mask_canvas (a_width, a_height: INTEGER): IMG_CANVAS
			-- An empty mask canvas: what is drawn on it becomes a mask.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			create Result.make_mask (a_width, a_height)
		ensure
			mask: Result.is_mask
		end

	canvas_from (a_image: IMG_IMAGE): IMG_CANVAS
			-- A color canvas holding a copy of `a_image'.
		require
			image_usable: a_image.is_usable
		do
			create Result.make_from (a_image)
		end

	gray_of (a_image: IMG_IMAGE): IMG_MASK
			-- A mask of `a_image''s gray levels (alpha ignored).
		require
			image_usable: a_image.is_usable
		local
			l_gray: IMG_IMAGE
		do
			l_gray := a_image.twin
			l_gray.enhance_color (0)
			create Result.make (a_image.width, a_image.height)
			copy_red_to (l_gray, Result)
			l_gray.destroy
		end

feature -- Status

	last_error: STRING
			-- Why the last load failed ("" when it did not).

	has_error: BOOLEAN
			-- Did the last load fail?
		do
			Result := not last_error.is_empty
		end

	version: STRING = "0.1.0"
			-- Library version.

feature {NONE} -- Implementation

	stb: SIMPLE_STB
			-- Loader.

	copy_red_to (a_image: IMG_IMAGE; a_mask: IMG_MASK)
			-- Copy `a_image''s red channel into `a_mask'.
		require
			same_size: a_image.width = a_mask.width and a_image.height = a_mask.height
		do
			c_copy_red (a_image.pixels, a_image.pixel_count, a_mask.values)
		end

	c_copy_red (a_p: POINTER; a_n: INTEGER; a_m: POINTER)
		external "C inline"
		alias "{ size_t i; for (i = 0; i < (size_t) $a_n; i++) ((unsigned char *) $a_m)[i] = ((const unsigned char *) $a_p)[i * 4]; }"
		end

invariant
	error_not_void: last_error /= Void

end
