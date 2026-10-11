note
	description: "[
		A drawing surface: cairo, reached by copying (debate 04: cairo is a seam, not the store).

		Images and masks are copied in once per placed layer (premultiplied on the way in)
		and the result is copied out once at the end (unpremultiplied). Opaque results copy
		out within 0.8 levels; A8 masks copy both ways exactly.

		A color canvas holds ARGB32; a mask canvas holds A8, so text or shapes drawn on it
		become a mask (`to_mask'): the way to make text shadows and glows.

		Usage:
			canvas := (create {SIMPLE_IMAGE}.make).canvas_from (background)
			canvas.fill_through (halo, 0xFFFFD34D, 40, 60)
			canvas.place (person, 40, 60)
			canvas.context.select_font ("Impact", ...).set_font_size (120)...
			result := canvas.to_image
			canvas.destroy
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	IMG_CANVAS

inherit
	IMG_KERNELS
		export
			{NONE} all
		end

create
	make,
	make_mask,
	make_from

feature {NONE} -- Initialization

	make (a_width, a_height: INTEGER)
			-- Transparent color canvas of `a_width' x `a_height'.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			width := a_width
			height := a_height
			create surface.make_with_format ({SIMPLE_CAIRO}.Format_argb32, a_width, a_height)
			ensure_memory (surface.is_valid)
			create context.make (surface)
		ensure
			width_set: width = a_width
			height_set: height = a_height
			color: not is_mask
		end

	make_mask (a_width, a_height: INTEGER)
			-- Empty mask canvas (A8) of `a_width' x `a_height': whatever is drawn becomes coverage.
		require
			width_positive: a_width > 0
			height_positive: a_height > 0
		do
			width := a_width
			height := a_height
			is_mask := True
			create surface.make_with_format ({SIMPLE_CAIRO}.Format_a8, a_width, a_height)
			ensure_memory (surface.is_valid)
			create context.make (surface)
		ensure
			width_set: width = a_width
			height_set: height = a_height
			mask: is_mask
		end

	make_from (a_image: IMG_IMAGE)
			-- Color canvas holding a copy of `a_image'.
		require
			image_usable: a_image.is_usable
		do
			make (a_image.width, a_image.height)
			surface.flush.do_nothing
			c_to_cairo (a_image.pixels, width, height, surface.data, surface.stride)
			surface.mark_dirty.do_nothing
		ensure
			width_set: width = a_image.width
			height_set: height = a_image.height
		end

feature -- Access

	width: INTEGER
			-- Width in pixels.

	height: INTEGER
			-- Height in pixels.

	is_mask: BOOLEAN
			-- Is this an A8 mask canvas (rather than ARGB32 color)?

	context: CAIRO_CONTEXT
			-- For text, shapes and paths (simple_cairo).

feature -- Status

	is_usable: BOOLEAN
			-- Not yet destroyed?
		do
			Result := surface.is_valid and context.is_valid
		end

feature -- Drawing

	place (a_image: IMG_IMAGE; a_x, a_y: REAL_64)
			-- Paint `a_image' over the canvas with its top-left corner at (`a_x', `a_y').
		require
			usable: is_usable
			color_canvas: not is_mask
			image_usable: a_image.is_usable
		local
			l_layer: CAIRO_SURFACE
		do
			create l_layer.make_with_format ({SIMPLE_CAIRO}.Format_argb32, a_image.width, a_image.height)
			ensure_memory (l_layer.is_valid)
			l_layer.flush.do_nothing
			c_to_cairo (a_image.pixels, a_image.width, a_image.height, l_layer.data, l_layer.stride)
			l_layer.mark_dirty.do_nothing
			context.save.set_source_surface (l_layer, a_x, a_y).paint.restore.do_nothing
			l_layer.destroy
		end

	place_sized (a_image: IMG_IMAGE; a_x, a_y: REAL_64; a_width, a_height: INTEGER)
			-- Paint `a_image' scaled to `a_width' x `a_height' (Lanczos-3) at (`a_x', `a_y').
		require
			usable: is_usable
			color_canvas: not is_mask
			image_usable: a_image.is_usable
			width_positive: a_width > 0
			height_positive: a_height > 0
		local
			l_scaled: IMG_IMAGE
		do
			if a_width = a_image.width and a_height = a_image.height then
				place (a_image, a_x, a_y)
			else
				l_scaled := a_image.resized (a_width, a_height)
				place (l_scaled, a_x, a_y)
				l_scaled.destroy
			end
		end

	fill_through (a_mask: IMG_MASK; a_color: NATURAL_32; a_x, a_y: REAL_64)
			-- Paint `a_color' (0xAARRGGBB) through `a_mask' placed at (`a_x', `a_y'):
			-- halos, shadows, glows and text shadows.
		require
			usable: is_usable
			mask_usable: a_mask.is_usable
		local
			l_coverage: CAIRO_SURFACE
		do
			create l_coverage.make_with_format ({SIMPLE_CAIRO}.Format_a8, a_mask.width, a_mask.height)
			ensure_memory (l_coverage.is_valid)
			l_coverage.flush.do_nothing
			c_copy_rows (a_mask.values, a_mask.width, l_coverage.data, l_coverage.stride, a_mask.width, a_mask.height)
			l_coverage.mark_dirty.do_nothing
			context.save.set_color_rgba (channel (a_color, 16), channel (a_color, 8), channel (a_color, 0),
				channel (a_color, 24)).mask_surface (l_coverage, a_x, a_y).restore.do_nothing
			l_coverage.destroy
		end

	fill (a_color: NATURAL_32)
			-- Paint the whole canvas with `a_color' (0xAARRGGBB) over what is there.
		require
			usable: is_usable
		do
			context.save.set_color_rgba (channel (a_color, 16), channel (a_color, 8), channel (a_color, 0),
				channel (a_color, 24)).paint.restore.do_nothing
		end

feature -- Results

	to_image: IMG_IMAGE
			-- A new image holding the canvas (straight alpha).
		require
			usable: is_usable
			color_canvas: not is_mask
		do
			create Result.make (width, height)
			surface.flush.do_nothing
			c_from_cairo (surface.data, surface.stride, width, height, Result.pixels)
		ensure
			same_size: Result.width = width and Result.height = height
		end

	to_mask: IMG_MASK
			-- A new mask holding the canvas's coverage.
		require
			usable: is_usable
			mask_canvas: is_mask
		do
			create Result.make (width, height)
			surface.flush.do_nothing
			c_copy_rows (surface.data, surface.stride, Result.values, width, width, height)
		ensure
			same_size: Result.width = width and Result.height = height
		end

feature -- Removal

	destroy
			-- Release the cairo context and surface.
		do
			context.destroy
			surface.destroy
		ensure
			gone: not is_usable
		end

feature {NONE} -- Implementation

	surface: CAIRO_SURFACE
			-- The pixels (premultiplied ARGB32, or A8).

	channel (a_color: NATURAL_32; a_shift: INTEGER): REAL_64
			-- The 8-bit channel of `a_color' at `a_shift', as 0.0-1.0.
		require
			valid_shift: a_shift = 0 or a_shift = 8 or a_shift = 16 or a_shift = 24
		do
			Result := ((a_color |>> a_shift) & 0xFF).to_real_64 / 255.0
		ensure
			in_range: Result >= 0.0 and Result <= 1.0
		end

invariant
	positive_size: width > 0 and height > 0

end
