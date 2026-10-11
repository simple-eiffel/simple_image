note
	description: "Test application runner for simple_image (run from the library root: writes data/output/)"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run all tests.
		local
			l_tests: LIB_TESTS
		do
			create l_tests
			io.put_string ("simple_image test runner%N")
			io.put_string ("========================%N%N")

			io.put_string ("Images:%N")
			run_test (agent l_tests.test_make_is_transparent, "test_make_is_transparent")
			run_test (agent l_tests.test_pixel_round_trip, "test_pixel_round_trip")
			run_test (agent l_tests.test_twin_is_independent, "test_twin_is_independent")
			run_test (agent l_tests.test_cropped, "test_cropped")
			run_test (agent l_tests.test_set_alpha_keeps_colour, "test_set_alpha_keeps_colour")
			run_test (agent l_tests.test_flatten_onto, "test_flatten_onto")

			io.put_string ("Filters:%N")
			run_test (agent l_tests.test_blur_keeps_colour_at_soft_edges, "test_blur_keeps_colour_at_soft_edges")
			run_test (agent l_tests.test_blur_matches_float_reference, "test_blur_matches_float_reference")
			run_test (agent l_tests.test_resize_keeps_solid_colour, "test_resize_keeps_solid_colour")
			run_test (agent l_tests.test_resize_keeps_colour_at_soft_edges, "test_resize_keeps_colour_at_soft_edges")
			run_test (agent l_tests.test_enhance, "test_enhance")
			run_test (agent l_tests.test_vignette, "test_vignette")

			io.put_string ("Masks:%N")
			run_test (agent l_tests.test_grow_and_shrink, "test_grow_and_shrink")
			run_test (agent l_tests.test_mask_blur_keeps_total, "test_mask_blur_keeps_total")
			run_test (agent l_tests.test_threshold_and_invert, "test_threshold_and_invert")
			run_test (agent l_tests.test_flood_fill, "test_flood_fill")
			run_test (agent l_tests.test_keep_largest_piece, "test_keep_largest_piece")
			run_test (agent l_tests.test_mask_from_floats, "test_mask_from_floats")

			io.put_string ("Canvas (the cairo seam):%N")
			run_test (agent l_tests.test_canvas_round_trip_is_exact, "test_canvas_round_trip_is_exact")
			run_test (agent l_tests.test_canvas_place_half_alpha, "test_canvas_place_half_alpha")
			run_test (agent l_tests.test_canvas_fill_through, "test_canvas_fill_through")
			run_test (agent l_tests.test_outlined_title_with_shadow, "test_outlined_title_with_shadow")
			run_test (agent l_tests.test_seam_timing_1280x720, "test_seam_timing_1280x720")

			io.put_string ("Files and memory:%N")
			run_test (agent l_tests.test_png_round_trip, "test_png_round_trip")
			run_test (agent l_tests.test_mask_png_round_trip, "test_mask_png_round_trip")
			run_test (agent l_tests.test_load_failure_reports, "test_load_failure_reports")
			run_test (agent l_tests.test_collector_frees_images, "test_collector_frees_images")

			io.put_string ("%N========================%N")
			io.put_string ("Results: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				io.put_string ("TESTS FAILED%N")
			else
				io.put_string ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Implementation

	passed: INTEGER
			-- Number of passed tests

	failed: INTEGER
			-- Number of failed tests

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
			l_exc: detachable EXCEPTION
		do
			if not l_retried then
				a_test.call (Void)
				io.put_string ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			l_exc := (create {EXCEPTION_MANAGER}).last_exception
			if attached l_exc as al_exc then
				io.put_string ("  FAIL: " + a_name + " [" + al_exc.generator + ": " + al_exc.tag.out + "]%N")
			else
				io.put_string ("  FAIL: " + a_name + " [unknown]%N")
			end
			failed := failed + 1
			l_retried := True
			retry
		end

end
