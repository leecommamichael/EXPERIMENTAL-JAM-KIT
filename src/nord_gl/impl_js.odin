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
	glBufferData(cast(uint) target, size_of(T) * len(src), raw_data(src), cast(uint) usage)
	when NGL_VALIDATE { return validate() } else { return }
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
	when NGL_VALIDATE { return validate() } else { return }
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
	glBufferSubData(cast(uint) target, offset, size_of(T) * len(src), raw_data(src))
	when NGL_VALIDATE { return validate() } else { return }
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
	glBufferSubData(cast(uint) target, offset, size_of(T), src)
	when NGL_VALIDATE { return validate() } else { return }
}




// @Experts: As you can see, offset is not a rawptr to CPU memory. For WebGL2 compatibility.
DrawElementsInstanced :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	offset: int,
	instance_count: int
) -> (err: Error = .NO_ERROR) {
	glDrawElementsInstanced(
		cast(uint) mode,
		count,
		cast(uint) type,
		offset,
		instance_count)
	when NGL_VALIDATE { return validate() } else { return }
}




DrawElements :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	indices: uintptr = 0,
) -> (err: Error = .NO_ERROR) {
	glDrawElements(
		cast(uint) mode,
		count,
		cast(uint) type,
		indices = cast(rawptr) indices)
	when NGL_VALIDATE { return validate() } else { return }
}




GenBuffers :: proc {
	GenBuffersMany,
	GenBuffersOne
}

GenBuffersMany :: proc (out: []Buffer) -> (err: Error = .NO_ERROR) {
	for &buffer in out {
		buffer = glCreateBuffer()
	}
	when NGL_VALIDATE { return validate() } else { return }
}

GenBuffersOne :: proc (out: ^Buffer) -> (err: Error = .NO_ERROR) {
	out := out
	out^ = glCreateBuffer()
	when NGL_VALIDATE { return validate() } else { return }
}




GenVertexArrays :: proc {
	GenVertexArraysMany,
	GenVertexArraysOne, 
}

GenVertexArraysMany :: proc (out: []VertexArrayObject) -> (err: Error = .NO_ERROR) {
	for &buffer in out {
		buffer = glCreateVertexArray()
	}
	when NGL_VALIDATE { return validate() } else { return }
}

GenVertexArraysOne :: proc (out: ^VertexArrayObject) -> (err: Error = .NO_ERROR) {
	out := out
	out^ = glCreateVertexArray()
	when NGL_VALIDATE { return validate() } else { return }
}




// :: proc () -> (err: Error = .NO_ERROR)
// when NGL_VALIDATE { return validate() } else { return }
BindBuffer :: proc (target: Buffer_Type, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBuffer(cast(uint) target, buffer)
	when NGL_VALIDATE { return validate() } else { return }
}




BindBufferBase :: proc (target, index: uint, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBufferBase(target, index, buffer)
	when NGL_VALIDATE { return validate() } else { return }
}





BindBufferRange :: proc (
	target, index: uint,
	buffer: Buffer,
	offset, size: int) -> (err: Error = .NO_ERROR) {
	glBindBufferRange(target, index, buffer, offset, size)
	when NGL_VALIDATE { return validate() } else { return }
}





BindVertexArray :: proc (vao: VertexArrayObject) -> (err: Error = .NO_ERROR) {
	glBindVertexArray(vao)
	when NGL_VALIDATE { return validate() } else { return }
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
	offset: uintptr
) -> (err: Error = .NO_ERROR) {
	glVertexAttribPointer(index, size, cast(uint)type, normalized, stride, offset)
	when NGL_VALIDATE { return validate() } else { return }
}

VertexAttribIPointer :: proc (
	index: uint,
	size: int,
	type: Data_Type,
	stride: int,
	offset: uintptr
) -> (err: Error = .NO_ERROR) {
	glVertexAttribIPointer(index, size, cast(uint)type, stride, offset)
	when NGL_VALIDATE { return validate() } else { return }
}




// WebGL mimics KHR_robust_access (bounds checking)
EnableVertexAttribArray :: proc (index: uint) -> (err: Error = .NO_ERROR) {
	glEnableVertexAttribArray(index)
	when NGL_VALIDATE { return validate() } else { return }
}



// Generates INVALID_VALUE if index > MAX_VERTEX_ATTRIBS
VertexAttribDivisor :: proc (index, divisor: uint) -> (err: Error = .NO_ERROR) {
	glVertexAttribDivisor(index, divisor)
	when NGL_VALIDATE { return validate() } else { return }
}




Clear :: proc (mask: Clear_Buffer_Mask) {
	glClear(transmute(uint)mask)
}




ClearColor :: glClearColor




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
The WebGL API does not support depth ranges where the near plane is greater the far plane.
DepthRange will generate an INVALID_OPERATION error if zNear is greater than zFar.
*/
DepthRange :: proc {
	_DepthRange,  // Desktop 2.0+, WebGL
	DepthRangef, // ES 2.0, Desktop 4.1+, 
}

_DepthRange :: proc (near, far: f64) -> Error {
	glDepthRange(cast(f32)near, cast(f32)far)
	return .NO_ERROR
}

// Emulated. DepthRangef is not available on web.
DepthRangef :: proc (near, far: f32) -> Error {
	glDepthRange(near, far)
	return .NO_ERROR
}




CullFace :: proc (mode: Cull_Face_Mode) {
	glCullFace(cast(uint)mode)
}




FrontFace :: proc (cw_or_ccw: Vertex_Winding_Order) {
	glFrontFace(cast(uint)cw_or_ccw)
}




UseProgram :: proc (program: Program) -> (err: Error = .NO_ERROR) {
	glUseProgram(program)
	when NGL_VALIDATE { return validate() } else { return }
}




GetProgramInfoLog :: proc (program: Program) -> string {
	log_length: int
	GetProgramiv(program, cast(uint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetProgramInfoLog(program, log_bytes, &log_length)
	return string(log_bytes[:log_length])
}




GetShaderInfoLog :: proc (shader: Shader) -> string {
	log_length: int
	GetShaderiv(shader, cast(uint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetShaderInfoLog(shader, log_bytes, &log_length)
	return string(log_bytes[:log_length])
}




CreateShader :: proc (type: Shader_Type) -> Shader {
	return cast(Shader) glCreateShader(cast(uint)type)
}




CreateProgram :: proc () -> Program {
	return cast(Program)glCreateProgram()
}



// TODO: GetParameter functions that are enum-safe and portable.
//       This is a polyfill approach to that, and not what I'm after.
//       I want a better GLES3.
// iv I guess means instance-variable???????
GetProgramiv :: glGetProgramiv

GetShaderiv :: glGetShaderiv // Emulated in JS. 




DeleteShader :: proc (s: Shader) {
	glDeleteShader(s)
}



// This temporary array is actually due to a bug in odin.js (their spec is wrong)
ShaderSource :: proc (s: Shader, src: string) {
	glShaderSource(s, src)
}




CompileShader :: proc (s: Shader) {
	glCompileShader(s)
}




AttachShader :: proc (p: Program, s: Shader) {
	glAttachShader(p, s)
}




LinkProgram :: proc (p: Program) {
	glLinkProgram(p)
}




UniformBlockBinding :: proc (p: Program, index, binding: uint) {
	glUniformBlockBinding(p, index, binding)
}




GetUniformBlockIndex :: proc (p: Program, block_name: string) -> uint {
	return glGetUniformBlockIndex(p, block_name)
}




TexImage2D :: proc (
	target: Texture_2D_Target,
	level: int,
	internalformat: int,
	width, height: int,
	format,
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
		len(size) * size_of(T),
		raw_data(data)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

//////////////////////////////////////////////////////////////////////
// Platform-Specific Stuff Below
//////////////////////////////////////////////////////////////////////
// Not Web, need unified way of querying support.
GetParameter :: proc {
	GetIntegerv,
	GetInteger64v,
}

GetIntegerv :: proc (pname: Integerv_Parameter) -> (value: int) {
	value = glGetParameter(cast(uint)pname)
	return
}

GetInteger64v :: proc (pname: Integer64v_Parameter) -> (value: i64) {
	value = auto_cast glGetParameter(cast(uint)pname) // TODO: odin.js is wrong about this.
	return
}


Viewport :: glViewport

