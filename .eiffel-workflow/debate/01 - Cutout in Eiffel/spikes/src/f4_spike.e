note
	description: "[
		Spike F4 (2026-10-11): does simple_onnx run u2net_human_seg correctly? Reads the input
		tensor written by f4_prep_and_check.py (in.f32, 1x3x320x320), runs the model, writes the
		first output (out.f32, 1x1x320x320) and the times. Usage: f4_spike <model.onnx> <work_dir>
	]"

class
	F4_SPIKE

create
	make

feature {NONE} -- Initialization

	make
		local
			l_args: ARGUMENTS_32
			l_onnx: SIMPLE_ONNX
			l_input: ONNX_TENSOR
			l_values: ARRAY [REAL_32]
			l_result: ONNX_RESULT
			l_t0, l_t1, l_t2: REAL_64
			l_run: INTEGER
		do
			create l_args
			if l_args.argument_count < 2 then
				print ("usage: f4_spike <model.onnx> <work_dir>%N")
			else
				create l_onnx.make
				l_values := read_floats (l_args.argument (2) + {STRING_32} "\in.f32", 307_200)
				print ("input floats: " + l_values.count.out + "%N")
				l_t0 := now_ms
				if attached l_onnx.load_model (l_args.argument (1).to_string_8) as al_model
					and then attached l_onnx.create_session (al_model) as al_session then
					if not al_session.is_loaded then
						al_session.load
					end
					l_t1 := now_ms
					print ("model loaded: " + al_session.is_loaded.out + " in " + (l_t1 - l_t0).truncated_to_integer.out + " ms%N")
					l_input := l_onnx.create_tensor_float32 (l_onnx.create_shape (<<1, 3, 320, 320>>))
					l_input.set_data_from_array (l_values)
					from l_run := 1 until l_run > 3 loop
						l_t1 := now_ms
						l_result := al_session.execute (l_input)
						l_t2 := now_ms
						print ("run " + l_run.out + ": " + (l_t2 - l_t1).truncated_to_integer.out + " ms, success " + l_result.is_success.out + "%N")
						if attached l_result.output_tensor as al_out then
							if l_run = 1 then
								print ("output floats: " + al_out.to_array.count.out + "%N")
								write_floats (l_args.argument (2) + {STRING_32} "\out.f32", al_out.to_array)
							end
						else
							print ("error: " + l_result.error_message + "%N")
						end
						l_run := l_run + 1
					end
				else
					print ("could not load the model or create a session%N")
				end
			end
		end

feature {NONE} -- Files

	read_floats (a_path: READABLE_STRING_32; a_count: INTEGER): ARRAY [REAL_32]
			-- `a_count' little-endian float32 values from `a_path'.
		local
			l_file: RAW_FILE
			l_buffer: MANAGED_POINTER
			i: INTEGER
		do
			create Result.make_filled (0, 1, a_count)
			create l_file.make_with_name (a_path)
			l_file.open_read
			create l_buffer.make (a_count * 4)
			l_file.read_to_managed_pointer (l_buffer, 0, a_count * 4)
			l_file.close
			from i := 0 until i >= a_count loop
				Result [i + 1] := l_buffer.read_real_32 (i * 4)
				i := i + 1
			end
		end

	write_floats (a_path: READABLE_STRING_32; a_values: ARRAY [REAL_32])
		local
			l_file: RAW_FILE
			l_buffer: MANAGED_POINTER
			i: INTEGER
		do
			create l_buffer.make (a_values.count * 4)
			from i := 0 until i >= a_values.count loop
				l_buffer.put_real_32 (a_values [a_values.lower + i], i * 4)
				i := i + 1
			end
			create l_file.make_with_name (a_path)
			l_file.open_write
			l_file.put_managed_pointer (l_buffer, 0, a_values.count * 4)
			l_file.close
		end

	now_ms: REAL_64
		external
			"C inline use <windows.h>"
		alias
			"LARGE_INTEGER f, c; QueryPerformanceFrequency (&f); QueryPerformanceCounter (&c); return (EIF_REAL_64) c.QuadPart * 1000.0 / (EIF_REAL_64) f.QuadPart;"
		end

end
