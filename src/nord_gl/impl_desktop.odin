#+build !js
package nord_gl

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
	glBufferData(cast(u32) target, size_of(T) * len(src), raw_data(src), cast(u32) usage)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
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
	glBufferData(cast(u32) target, size_of(T), src, cast(u32) usage)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




// @Experts: As you can see, offset is not a rawptr to CPU memory. For WebGL2 compatibility.
DrawElementsInstanced :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  i32,
	type:   Index_Type,
	offset: int,
	instance_count: i32
) -> (err: Error = .NO_ERROR) {
	offset := cast(rawptr) cast(uintptr) offset
	glDrawElementsInstanced(
		cast(u32) mode,
		count,
		cast(u32) type,
		offset,
		instance_count)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




DrawElements :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  i32,
	type:   Index_Type,
	indices: uintptr = 0,
) -> (err: Error = .NO_ERROR) {
	glDrawElements(
		cast(u32) mode,
		count,
		cast(u32) type,
		indices = cast(rawptr) indices)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




GenBuffers :: proc {
	GenBuffersMany,
	GenBuffersOne
}

GenBuffersMany :: proc (out: []Buffer) -> (err: Error = .NO_ERROR) {
	glGenBuffers(cast(i32)len(out), cast(^u32)&out[0])
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}

GenBuffersOne :: proc (out: ^Buffer) -> (err: Error = .NO_ERROR) {
	glGenBuffers(1, cast(^u32)out)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




GenVertexArrays :: proc {
	GenVertexArraysMany,
	GenVertexArraysOne, 
}

GenVertexArraysMany :: proc (out: []Buffer) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(cast(i32)len(out), cast([^]u32)raw_data(out))
	when NGL_DEBUG { return cast(Error) glGetError() }
}

GenVertexArraysOne :: proc (out: ^Buffer) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(1, cast(^u32)out)
	when NGL_DEBUG { return cast(Error) glGetError() }
}




// :: proc () -> (err: Error = .NO_ERROR)
// when NGL_DEBUG { return cast(Error) glGetError() } else { return }
BindBuffer :: proc (target: Buffer_Type, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBuffer(cast(u32) target, cast(u32) buffer)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




BindBufferBase :: proc (target, index: u32, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBufferBase(target, index, cast(u32)buffer)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}





BindBufferRange :: proc (
	target, index: u32,
	buffer: Buffer,
	offset, size: int) -> (err: Error = .NO_ERROR) {
	glBindBufferRange(target, index, cast(u32)buffer, offset, size)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}





BindVertexArray :: proc (vao: Buffer) -> (err: Error = .NO_ERROR) {
	glBindVertexArray(cast(u32) vao)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
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
	index: u32,
	size: i32,
	type: Data_Type,
	normalized: bool,
	stride: i32,
	offset: uintptr
) -> (err: Error = .NO_ERROR) {
	glVertexAttribPointer(index, size, cast(u32)type, normalized, stride, offset)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}

VertexAttribIPointer :: proc (
	index: u32,
	size: i32,
	type: Data_Type,
	stride: i32,
	offset: uintptr
) -> (err: Error = .NO_ERROR) {
	glVertexAttribIPointer(index, size, cast(u32)type, stride, offset)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




// WebGL mimics KHR_robust_access (bounds checking)
EnableVertexAttribArray :: proc (index: u32) -> (err: Error = .NO_ERROR) {
	glEnableVertexAttribArray(index)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}



// Generates INVALID_VALUE if index > MAX_VERTEX_ATTRIBS
VertexAttribDivisor :: proc (index, divisor: u32) -> (err: Error = .NO_ERROR) {
	glVertexAttribDivisor(index, divisor)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}




Clear :: proc (mask: Clear_Buffer_Mask) {
	glClear(transmute(u32)mask)
}




ClearColor :: glClearColor




Enable :: proc (cap: Capability) {
	glEnable(cast(u32) cap)
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
	glBlendFunc(cast(u32)src, cast(u32)dst)
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
	glDepthRange(near, far)
	return .NO_ERROR
}

DepthRangef :: proc (near, far: f32) -> Error {
	// DepthRangef is not always available on desktop, easier to emulate.
	glDepthRange(cast(f64)near, cast(f64)far)
	return .NO_ERROR
}




CullFace :: proc (mode: Cull_Face_Mode) {
	glCullFace(cast(u32)mode)
}




FrontFace :: proc (cw_or_ccw: Vertex_Winding_Order) {
	glFrontFace(cast(u32)cw_or_ccw)
}




UseProgram :: proc (program: Program) -> (err: Error = .NO_ERROR) {
	glUseProgram(cast(u32) program)
	when NGL_DEBUG { return cast(Error) glGetError() } else { return }
}



// These aren't on Web
GetProgramInfoLog :: glGetProgramInfoLog
GetShaderInfoLog :: glGetShaderInfoLog




CreateShader :: proc (type: Shader_Type) -> Shader {
	return cast(Shader) glCreateShader(cast(u32)type)
}




CreateProgram :: proc () -> Program {
	return cast(Program)glCreateProgram()
}




GetProgramiv :: glGetProgramiv
GetShaderiv :: glGetShaderiv




DeleteShader :: proc (s: Shader) {
	glDeleteShader(cast(u32)s)
}



// WebGL can't do more than 1 at a time...
ShaderSource :: proc (s: Shader, src: string) {
	shader_data := cast(cstring) raw_data(src)
	shader_len := cast(i32) len(src)
	glShaderSource(cast(u32)s, 1, &shader_data, &shader_len)
}




CompileShader :: proc (s: Shader) {
	glCompileShader(cast(u32) s)
}




AttachShader :: proc (p: Program, s: Shader) {
	glAttachShader(cast(u32)p, cast(u32)s)
}




LinkProgram :: proc (p: Program) {
	glLinkProgram(cast(u32)p)
}




UniformBlockBinding :: proc (p: Program, index, binding: u32) {
	glUniformBlockBinding(cast(u32) p, index, binding)
}




GetUniformBlockIndex :: proc (p: Program, block_name: cstring) -> u32 {
	return glGetUniformBlockIndex(cast(u32)p, block_name)
}




// Not Web, need unified way of querying support.
MAJOR_VERSION :: 0x821B
MINOR_VERSION :: 0x821C
GetParameter :: proc {
	GetIntegerv,
	GetInteger64v,
}
GetIntegerv :: proc (pname: Integerv_Parameter) -> (value: i32) {
	glGetIntegerv(cast(u32)pname, &value)
	return
}

GetInteger64v :: proc (pname: Integer64v_Parameter) -> (value: i64) {
	glGetInteger64v(cast(u32)pname, &value)
	return
}


Viewport :: glViewport



