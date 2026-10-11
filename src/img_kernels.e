note
	description: "[
		The per-pixel kernels of simple_image: inline-C calls into Clib/simple_image.h.

		Inherited (non-conforming) by IMG_IMAGE, IMG_MASK and IMG_CANVAS, which check their
		contracts once per call and leave the pixel loops to C (debate 02 verdict: Eiffel
		loops with contracts on ran 3.6-4.4 times slower than the same loops in C).
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	IMG_KERNELS

feature {NONE} -- Memory

	ensure_memory (a_ok: BOOLEAN)
			-- Raise when an allocating kernel ran out of memory.
		local
			l_exception: DEVELOPER_EXCEPTION
		do
			if not a_ok then
				create l_exception
				l_exception.set_description ("simple_image: out of memory")
				l_exception.raise
			end
		end

feature {NONE} -- Kernels: blur, grow, resize

	c_blur_rgba (a_p: POINTER; a_w, a_h, a_r: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_blur_rgba ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, (int) $a_r);"
		end

	c_blur_gray (a_p: POINTER; a_w, a_h, a_r: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_blur_gray ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, (int) $a_r);"
		end

	c_grow (a_p: POINTER; a_w, a_h, a_g: INTEGER; a_is_max: BOOLEAN): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_grow ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, (int) $a_g, $a_is_max ? 1 : 0);"
		end

	c_resize_rgba (a_in: POINTER; a_w, a_h: INTEGER; a_out: POINTER; a_ow, a_oh: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_resize_rgba ((const unsigned char *) $a_in, (int) $a_w, (int) $a_h, (unsigned char *) $a_out, (int) $a_ow, (int) $a_oh);"
		end

	c_resize_gray (a_in: POINTER; a_w, a_h: INTEGER; a_out: POINTER; a_ow, a_oh: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_resize_gray ((const unsigned char *) $a_in, (int) $a_w, (int) $a_h, (unsigned char *) $a_out, (int) $a_ow, (int) $a_oh);"
		end

feature {NONE} -- Kernels: point operations

	c_mean_gray (a_p: POINTER; a_n: INTEGER): REAL_64
		external "C inline use %"simple_image.h%""
		alias "return img_mean_gray ((const unsigned char *) $a_p, (size_t) $a_n);"
		end

	c_enhance (a_p: POINTER; a_n, a_mode: INTEGER; a_factor, a_mean: REAL_64)
		external "C inline use %"simple_image.h%""
		alias "img_enhance ((unsigned char *) $a_p, (size_t) $a_n, (int) $a_mode, $a_factor, $a_mean);"
		end

	c_vignette (a_p: POINTER; a_w, a_h: INTEGER; a_strength: REAL_64)
		external "C inline use %"simple_image.h%""
		alias "img_vignette ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, $a_strength);"
		end

	c_flatten (a_p: POINTER; a_n, a_r, a_g, a_b: INTEGER)
		external "C inline use %"simple_image.h%""
		alias "img_flatten ((unsigned char *) $a_p, (size_t) $a_n, (int) $a_r, (int) $a_g, (int) $a_b);"
		end

	c_is_opaque (a_p: POINTER; a_n: INTEGER): BOOLEAN
		external "C inline use %"simple_image.h%""
		alias "return (EIF_BOOLEAN) img_is_opaque ((const unsigned char *) $a_p, (size_t) $a_n);"
		end

	c_fill_rgba (a_p: POINTER; a_n: INTEGER; a_argb: NATURAL_32)
		external "C inline use %"simple_image.h%""
		alias "img_fill_rgba ((unsigned char *) $a_p, (size_t) $a_n, (unsigned int) $a_argb);"
		end

	c_get_argb (a_p: POINTER; a_w, a_x, a_y: INTEGER): NATURAL_32
		external "C inline use %"simple_image.h%""
		alias "return (EIF_NATURAL_32) img_get_argb ((const unsigned char *) $a_p, (int) $a_w, (int) $a_x, (int) $a_y);"
		end

	c_set_argb (a_p: POINTER; a_w, a_x, a_y: INTEGER; a_argb: NATURAL_32)
		external "C inline use %"simple_image.h%""
		alias "img_set_argb ((unsigned char *) $a_p, (int) $a_w, (int) $a_x, (int) $a_y, (unsigned int) $a_argb);"
		end

	c_alpha_to_mask (a_p: POINTER; a_n: INTEGER; a_m: POINTER)
		external "C inline use %"simple_image.h%""
		alias "img_alpha_to_mask ((const unsigned char *) $a_p, (size_t) $a_n, (unsigned char *) $a_m);"
		end

	c_mask_to_alpha (a_p: POINTER; a_n: INTEGER; a_m: POINTER)
		external "C inline use %"simple_image.h%""
		alias "img_mask_to_alpha ((unsigned char *) $a_p, (size_t) $a_n, (const unsigned char *) $a_m);"
		end

feature {NONE} -- Kernels: the cairo seam and copies

	c_to_cairo (a_p: POINTER; a_w, a_h: INTEGER; a_dst: POINTER; a_dst_stride: INTEGER)
		external "C inline use %"simple_image.h%""
		alias "img_to_cairo ((const unsigned char *) $a_p, (int) $a_w, (int) $a_h, (unsigned char *) $a_dst, (int) $a_dst_stride);"
		end

	c_from_cairo (a_src: POINTER; a_src_stride, a_w, a_h: INTEGER; a_p: POINTER)
		external "C inline use %"simple_image.h%""
		alias "img_from_cairo ((const unsigned char *) $a_src, (int) $a_src_stride, (int) $a_w, (int) $a_h, (unsigned char *) $a_p);"
		end

	c_copy_rows (a_s: POINTER; a_s_stride: INTEGER; a_d: POINTER; a_d_stride, a_row_bytes, a_h: INTEGER)
		external "C inline use %"simple_image.h%""
		alias "img_copy_rows ((const unsigned char *) $a_s, (int) $a_s_stride, (unsigned char *) $a_d, (int) $a_d_stride, (int) $a_row_bytes, (int) $a_h);"
		end

	c_same_bytes (a_a, a_b: POINTER; a_n: INTEGER): BOOLEAN
		external "C inline use <string.h>"
		alias "return (EIF_BOOLEAN) (memcmp ((const void *) $a_a, (const void *) $a_b, (size_t) $a_n) == 0);"
		end

feature {NONE} -- Kernels: masks

	c_threshold (a_p: POINTER; a_n, a_level: INTEGER)
		external "C inline use %"simple_image.h%""
		alias "img_threshold ((unsigned char *) $a_p, (size_t) $a_n, (int) $a_level);"
		end

	c_invert (a_p: POINTER; a_n: INTEGER)
		external "C inline use %"simple_image.h%""
		alias "img_invert ((unsigned char *) $a_p, (size_t) $a_n);"
		end

	c_count_at_least (a_p: POINTER; a_n, a_level: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_count_at_least ((const unsigned char *) $a_p, (size_t) $a_n, (int) $a_level);"
		end

	c_flood_fill (a_p: POINTER; a_w, a_h, a_x, a_y, a_value: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_flood_fill ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, (int) $a_x, (int) $a_y, (int) $a_value);"
		end

	c_keep_largest (a_p: POINTER; a_w, a_h, a_level: INTEGER): INTEGER
		external "C inline use %"simple_image.h%""
		alias "return img_keep_largest ((unsigned char *) $a_p, (int) $a_w, (int) $a_h, (int) $a_level);"
		end

	c_floats_to_mask (a_f: POINTER; a_n: INTEGER; a_m: POINTER)
		external "C inline use %"simple_image.h%""
		alias "img_floats_to_mask ((const float *) $a_f, (size_t) $a_n, (unsigned char *) $a_m);"
		end

end
