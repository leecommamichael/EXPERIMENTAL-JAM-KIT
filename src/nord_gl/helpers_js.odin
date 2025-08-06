package nord_gl

import "core:fmt"

load_shaders_source :: proc(vs_sources, fs_sources: string) -> (program: Program, ok: bool) {
	ok = true

	vs := CreateShader(.VERTEX_SHADER)
	fs := CreateShader(.FRAGMENT_SHADER)
	defer DeleteShader(vs)
	defer DeleteShader(fs)
	ShaderSource(vs, vs_sources)
	ShaderSource(fs, fs_sources)

	compile_status: int
	CompileShader(vs)
	GetShaderiv(vs, cast(uint) Shader_Parameter_Name.COMPILE_STATUS, &compile_status)
	if compile_status == 0 {
		err := GetShaderInfoLog(vs)
		fmt.eprintln("Vertex shader did not compile successfully", err)
		ok = false
		return
	}

	CompileShader(fs)
	GetShaderiv(fs, cast(uint) Shader_Parameter_Name.COMPILE_STATUS, &compile_status)
	if compile_status == 0 {
		err := GetShaderInfoLog(fs)
		fmt.eprintln("Fragment shader did not compile successfully", err)
		ok = false
		return
	}

	program = CreateProgram()
	defer if !ok { glDeleteProgram(program) }

	AttachShader(program, vs)
	AttachShader(program, fs)
	LinkProgram(program)
	glDetachShader(program, vs)
	glDetachShader(program, fs)

	if glGetProgramParameter(program, LINK_STATUS) == 0 {
		err := GetProgramInfoLog(program)
		fmt.eprintln("Shader program did not link successfully", err)
		ok = false
		return
	}

	return

}
