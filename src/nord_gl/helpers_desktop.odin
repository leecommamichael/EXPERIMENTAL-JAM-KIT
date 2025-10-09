#+build !js
package nord_gl
// Helper for loading shaders into a program

import "core:os"
import "core:fmt"
import "core:strings"
import "base:runtime"
_ :: fmt
_ :: runtime


EShader_Type :: enum int {
	NONE = 0x0000,
	FRAGMENT_SHADER        = 0x8B30,
	VERTEX_SHADER          = 0x8B31,
	SHADER_LINK            = -1, // @Note: Not an OpenGL constant, but used for error checking.
}


@(private, thread_local)
last_compile_error_message: []byte
@(private, thread_local)
last_link_error_message: []byte

@(private, thread_local)
last_compile_error_type: EShader_Type
@(private, thread_local)
last_link_error_type: EShader_Type

get_last_error_messages :: proc() -> (compile_message: string, compile_type: EShader_Type, link_message: string, link_type: EShader_Type) {
	compile_message = string(last_compile_error_message[:max(0, len(last_compile_error_message)-1)])
	compile_type = last_compile_error_type
	link_message = string(last_link_error_message[:max(0, len(last_link_error_message)-1)])
	link_type = last_link_error_type
	return
}

get_last_error_message :: proc() -> (compile_message: string, compile_type: EShader_Type) {
	compile_message = string(last_compile_error_message[:max(0, len(last_compile_error_message)-1)])
	compile_type = last_compile_error_type
	return
}

// Shader checking and linking checking are identical
// except for calling differently named GL functions
// it's a bit ugly looking, but meh
INFO_LOG_LENGTH :: 0x8B84
when NGL_DEBUG {
	@private
	check_error :: proc(
		id: uint, type: EShader_Type, status: uint,
		iv_func: proc (uint, uint, [^]int),
		log_func: proc (uint) -> string, 
		loc := #caller_location,
	) -> (success: bool) {
		result, info_log_length: int
		iv_func(id, status, &result)
		iv_func(id, INFO_LOG_LENGTH, &info_log_length)

		if result == 0 {
			if log_func == GetShaderInfoLog {
				delete(last_compile_error_message)
				last_compile_error_message = make([]byte, info_log_length)
				last_compile_error_type = type

				log_func(id)
				if len(last_compile_error_message) > 0 {
					fmt.printf("Error in %v:\n%s", type, string(last_compile_error_message[0:len(last_compile_error_message)-1]));
				} else {
					fmt.printf("Error in %v:\n.", type);
				}
			} else {

				delete(last_link_error_message)
				last_link_error_message = make([]byte, info_log_length)
				last_compile_error_type = type

				log_func(id)
				if len(last_compile_error_message) > 0 {
					fmt.printf("Error in %v:\n%s", type, string(last_compile_error_message[0:len(last_compile_error_message)-1]));
				} else {
					fmt.printf("Error in %v:\n.", type);
				}
			}

			return false
		}

		return true
	}
} else {
	@private
	check_error :: proc(
		id: uint, type: EShader_Type, status: uint,
		iv_func: proc (uint, uint, [^]int),
		log_func: proc (uint) -> string,
	) -> (success: bool) {
		result, info_log_length: int
		iv_func(id, status, &result)
		iv_func(id, INFO_LOG_LENGTH, &info_log_length)

		if result == 0 {
			if log_func == GetShaderInfoLog {
				delete(last_compile_error_message)
				last_compile_error_message = make([]u8, info_log_length)
				last_link_error_type = type

				log_func(id)
				fmt.eprintf("Error in %v:\n%s", type, string(last_compile_error_message[0:len(last_compile_error_message)-1]))
			} else {
				delete(last_link_error_message)
				last_link_error_message = make([]u8, info_log_length)
				last_link_error_type = type

				log_func(id)
				fmt.eprintf("Error in %v:\n%s", type, string(last_link_error_message[0:len(last_link_error_message)-1]))

			}

			return false
		}

		return true
	}
}

// Compiling shaders are identical for any shader (vertex, geometry, fragment, tesselation, (maybe compute too))
compile_shader_from_source :: proc(shader_data: string, shader_type: EShader_Type) -> (shader_id: Shader, ok: bool) {
	shader_id = CreateShader(cast(Shader_Type)shader_type)
	ShaderSource(shader_id, shader_data)
	CompileShader(shader_id)

	check_error(cast(uint)shader_id, shader_type, COMPILE_STATUS, GetShaderiv, GetShaderInfoLog) or_return
	ok = true
	return
}

// only used once, but I'd just make a subprocedure(?) for consistency
create_and_link_program :: proc(shader_ids: []Shader) -> (program_id: Program, ok: bool) {
	program_id = CreateProgram()
	for id in shader_ids {
		AttachShader(program_id, id)
	}
	LinkProgram(program_id)

	check_error(cast(uint)program_id, EShader_Type.SHADER_LINK, LINK_STATUS, GetProgramiv, GetProgramInfoLog) or_return
	ok = true
	return
}

load_shaders_file :: proc(vs_filename, fs_filename: string) -> (program_id: Program, ok: bool) {
	vs_data := os.read_entire_file(vs_filename) or_return
	defer delete(vs_data)
	
	fs_data := os.read_entire_file(fs_filename) or_return
	defer delete(fs_data)

	return load_shaders_source(string(vs_data), string(fs_data))
}

load_shaders_source :: proc(vs_source, fs_source: string) -> (program_id: Program, ok: bool) {
	// actual function from here
	vertex_shader_id := compile_shader_from_source(vs_source, EShader_Type.VERTEX_SHADER) or_return
	defer DeleteShader(vertex_shader_id)

	fragment_shader_id := compile_shader_from_source(fs_source, EShader_Type.FRAGMENT_SHADER) or_return
	defer DeleteShader(fragment_shader_id)

	return create_and_link_program([]Shader{vertex_shader_id, fragment_shader_id})
}

load_shaders :: proc{load_shaders_file}
