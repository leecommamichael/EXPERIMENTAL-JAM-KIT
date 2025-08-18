#+build !js
package nord_gl

import "base:intrinsics"
import "core:strings"

BufferData :: proc {
	Buffer_Data_Many,
	Buffer_Data_One,
}

// @Experts: Careful of that default for the buffer usage, but you knew that ;)
Buffer_Data_Many :: #force_inline proc (
	target: Buffer_Binding_Target,
	src: []$T, 
	usage: Buffer_Usage_Hint = .DYNAMIC_DRAW,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if len(src) == 0 {
			_bad_input("BufferData called with no data.", _loc)
			return
		}
	}
	glBufferData(cast(uint) target, size_of(T) * len(src), raw_data(src), cast(uint) usage)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

Buffer_Data_One :: #force_inline proc (
	target: Buffer_Binding_Target,
	src: ^$T,
	usage: Buffer_Usage_Hint = .DYNAMIC_DRAW, 
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if src == nil {
			_bad_input("BufferData called with nil.", _loc)
			return
		}
	}
	glBufferData(cast(uint) target, size_of(T), src, cast(uint) usage)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BufferSubData :: proc {
	Buffer_SubData_Many,
	Buffer_SubData_One,
}

Buffer_SubData_Many :: #force_inline proc (
	target: Buffer_Binding_Target,
	offset: uintptr,
	src: []$T, 
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if len(src) == 0 {
			_bad_input("BufferSubData called with no data.", _loc)
			return
		}
	}
	glBufferSubData(cast(uint) target, cast(int) offset, size_of(T) * len(src), raw_data(src))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

Buffer_SubData_One :: #force_inline proc (
	target: Buffer_Binding_Target,
	offset: uintptr,
	src: ^$T,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if src == nil {
			_bad_input("BufferSubData called with nil.", _loc)
			return
		}
	}
	glBufferSubData(cast(uint) target, cast(int) offset, size_of(T), src)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




// @Experts: As you can see, offset is not a rawptr to CPU memory. For WebGL2 compatibility.
DrawElementsInstanced :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	offset: int,
	instance_count: int,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	offset := cast(rawptr) cast(uintptr) offset
	glDrawElementsInstanced(
		cast(uint) mode,
		count,
		cast(uint) type,
		offset,
		instance_count)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




DrawElements :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	indices: uintptr = 0,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glDrawElements(
		cast(uint) mode,
		count,
		cast(uint) type,
		indices = cast(rawptr) indices)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




GenBuffers :: proc {
	GenBuffersMany,
	GenBuffersOne
}

GenBuffersMany :: proc (
	out: []Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glGenBuffers(cast(int)len(out), cast(^uint)&out[0])
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

GenBuffersOne :: proc (
	out: ^Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glGenBuffers(1, cast(^uint)out)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




GenVertexArrays :: proc {
	GenVertexArraysMany,
	GenVertexArraysOne, 
}

GenVertexArraysMany :: proc (
	out: []VertexArrayObject,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(cast(int)len(out), cast([^]uint)raw_data(out))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

GenVertexArraysOne :: proc (
	out: ^VertexArrayObject,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(1, cast(^uint)out)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




// :: proc () -> (err: Error = .NO_ERROR)
// when NGL_VALIDATE { return validate(_loc) } else { return }
BindBuffer :: proc (
	target: Buffer_Type,
	buffer: Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBuffer(cast(uint) target, cast(uint) buffer)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BindBufferBase :: proc (
	target,
	index: uint,
	buffer: Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBufferBase(target, index, cast(uint)buffer)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BindBufferRange :: proc (
	target, index: uint,
	buffer: Buffer,
	offset, size: int,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBufferRange(target, index, cast(uint)buffer, offset, size)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BindVertexArray :: proc (
	vao: VertexArrayObject,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindVertexArray(cast(uint) vao)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}


/*
The WebGL API supports vertex attribute data strides up to 255 bytes.
VertexAttribPointer generates an INVALID_VALUE error
  if the value for the stride parameter exceeds 255.
*/
VertexAttributePointer :: proc {
	VertexAttribPointer,
	VertexAttribIPointer,
}

VertexAttribPointer :: proc (
	index: uint,
	size: int,
	type: Data_Type,
	normalized: bool,
	stride: int,
	offset: uintptr,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribPointer(index, size, cast(uint)type, normalized, stride, offset)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

VertexAttribIPointer :: proc (
	index: uint,
	size: int,
	type: Data_Type,
	stride: int,
	offset: uintptr,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribIPointer(index, size, cast(uint)type, stride, offset)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




// WebGL mimics KHR_robust_access (bounds checking)
EnableVertexAttribArray :: proc (
	index: uint,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glEnableVertexAttribArray(index)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}



// Generates INVALID_VALUE if index > MAX_VERTEX_ATTRIBS
VertexAttribDivisor :: proc (
	index,
	divisor: uint,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribDivisor(index, divisor)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




Clear :: proc (mask: Clear_Buffer_Mask) {
	glClear(transmute(uint)mask)
}




ClearColor :: proc (r,g,b,a: GLfloat) {
	glClearColor(r,g,b,a)
}




Enable :: proc (cap: Capability) {
	glEnable(cast(uint) cap)
}



/*
In the WebGL API, constant color and constant alpha cannot be used together as source and destination factors.
BlendFunc() will generate an INVALID_OPERATION error if:
- one of the two factors is set to CONSTANT_COLOR or ONE_MINUS_CONSTANT_COLOR 
  and the other to CONSTANT_ALPHA or ONE_MINUS_CONSTANT_ALPHA.
BlendFuncSeparate() will generate an INVALID_OPERATION error if:
- srcRGB is set to CONSTANT_COLOR or ONE_MINUS_CONSTANT_COLOR 
  and dstRGB is set to CONSTANT_ALPHA or ONE_MINUS_CONSTANT_ALPHA or vice versa.
*/
BlendFunc :: proc (src: Blending_Factor_Src, dst: Blending_Factor_Dest) -> Error {
	glBlendFunc(cast(uint)src, cast(uint)dst)
	return .NO_ERROR
}




/*
The WebGL API does not support depth ranges with where the near plane is greater the far plane.
DepthRange will generate an INVALID_OPERATION error if zNear is greater than zFar.
*/
DepthRange :: proc {
	_DepthRange,  // Desktop 2.0+, WebGL
	DepthRangef, // ES 2.0, Desktop 4.1+, 
}

_DepthRange :: proc (near, far: f64) -> Error {
	glDepthRange(cast(GLfloat)near, cast(GLfloat)far)
	return .NO_ERROR
}

DepthRangef :: proc (near, far: f32) -> Error {
	// DepthRangef is not always available on desktop, easier to emulate.
	glDepthRange(near, far)
	return .NO_ERROR
}




CullFace :: proc (mode: Cull_Face_Mode) {
	glCullFace(cast(uint)mode)
}




FrontFace :: proc (cw_or_ccw: Vertex_Winding_Order) {
	glFrontFace(cast(uint)cw_or_ccw)
}




UseProgram :: proc (
	program: Program,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glUseProgram(cast(uint) program)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




GetProgramInfoLog :: proc (program: uint) -> string {
	log_length: int
	GetProgramiv(program, cast(uint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetProgramInfoLog(program, log_length, &log_length, raw_data(log_bytes))
	return string(log_bytes[:log_length])
}




GetShaderInfoLog :: proc (shader: uint) -> string {
	log_length: int
	GetShaderiv(shader, cast(uint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetShaderInfoLog(shader, log_length, &log_length, raw_data(log_bytes))
	return string(log_bytes[:log_length])
}




CreateShader :: proc (type: Shader_Type) -> Shader {
	return cast(Shader) glCreateShader(cast(uint)type)
}




CreateProgram :: proc () -> Program {
	return cast(Program)glCreateProgram()
}




GetProgramiv :: proc (program: uint, pname: uint, params: [^]int) {
	glGetProgramiv(program, pname, params)
}




GetShaderiv :: proc (shader: uint, pname: uint, params: [^]int) {
	glGetShaderiv(shader, pname, params)
}




DeleteShader :: proc (s: Shader) {
	glDeleteShader(cast(uint)s)
}



// WebGL can't do more than 1 at a time...
ShaderSource :: proc (s: Shader, src: string) {
	shader_data := cast(cstring) raw_data(src)
	shader_len := cast(int) len(src)
	glShaderSource(cast(uint)s, 1, &shader_data, &shader_len)
}




CompileShader :: proc (s: Shader) {
	glCompileShader(cast(uint) s)
}




AttachShader :: proc (p: Program, s: Shader) {
	glAttachShader(cast(uint)p, cast(uint)s)
}




LinkProgram :: proc (p: Program) {
	glLinkProgram(cast(uint)p)
}




UniformBlockBinding :: proc (p: Program, index, binding: uint) {
	glUniformBlockBinding(cast(uint) p, index, binding)
}




GetUniformBlockIndex :: proc (p: Program, block_name: string) -> uint {
	block_name: cstring = strings.clone_to_cstring(block_name)
	defer { delete(block_name) }
	return glGetUniformBlockIndex(cast(uint)p, block_name)
}




TexImage2D :: proc {
	TexImage2D_One,
	TexImage2D_Many
}

TexImage2D_One :: proc (
	target: Texture_2D_Target,
	level: int,
	internalformat: int,
	width, height: int,
	format: uint, // TODO scoped enum
	type: uint,
	data: ^$T,
	_loc := #caller_location
) -> ( err: Error = .NO_ERROR ) {
	glTexImage2D(
		cast(GLenum) target,
		level,
		internalformat,
		width, height,
		0, // border
		format,
		type,
		data)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

TexImage2D_Many :: proc (
	target: Texture_2D_Target,
	level: int,
	internalformat: int,
	width, height: int,
	format: uint, // TODO scoped enum
	type: uint,
	data: $Indistinct/[]$T,
	_loc := #caller_location
) -> ( err: Error = .NO_ERROR ) {
	glTexImage2D(
		cast(GLenum) target,
		level,
		internalformat,
		width, height,
		0, // border
		format,
		type,
		raw_data(data))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}



// Desktop(target: uint, level: int, xoffset: int, yoffset: int, width: int, height: int, format: uint, type: uint,            pixels: rawptr)
// JS     (target: uint, level: int, xoffset,      yoffset,      width,      height: int, format,       type: uint, size: int, data:   rawptr)
TexSubImage2D :: proc (
	target: Texture_2D_Target,
	level: int,
	xoffset, yoffset: int,
	width, height: int,
	format: uint, // TODO scoped enum
	type: uint,
	data: $Indistinct/[]$T,
	_loc := #caller_location
) -> ( err: Error = .NO_ERROR ) {
	glTexSubImage2D(
		cast(GLenum) target,
		level,
		xoffset, yoffset,
		width, height,
		format,
		type,
		raw_data(data))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}



//////////////////////////////////////////////////////////////////////
// Platform-Specific Stuff Below
//////////////////////////////////////////////////////////////////////
// Not Web, need unified way of querying support.
MAJOR_VERSION :: 0x821B
MINOR_VERSION :: 0x821C
GetParameter :: proc {
	GetIntegerv,
	GetInteger64v,
}
GetIntegerv :: proc (pname: Integerv_Parameter) -> (value: int) {
	glGetIntegerv(cast(uint)pname, &value)
	return
}

GetInteger64v :: proc (pname: Integer64v_Parameter) -> (value: i64) {
	glGetInteger64v(cast(uint)pname, &value)
	return
}


Viewport :: proc (x: int, y: int, width: int, height: int) {
	glViewport(x, y, width, height)
}

GetError :: proc () -> GLenum {
	return glGetError()
}

