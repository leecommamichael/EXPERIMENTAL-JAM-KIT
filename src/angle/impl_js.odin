package angle

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
	glBufferData(cast(GLuint) target, size_of(T) * len(src), raw_data(src), cast(GLuint) usage)
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
	glBufferData(cast(GLuint) target, size_of(T), src, cast(GLuint) usage)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BufferSubData :: proc {
	Buffer_SubData_Many,
	Buffer_SubData_One,
}

Buffer_SubData_Many :: #force_inline proc (
	target: Buffer_Binding_Target,
	offset: GLintptr,
	src: []$T, 
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if len(src) == 0 {
			_bad_input("BufferSubData called with no data.", _loc)
			return
		}
	}
	glBufferSubData(cast(GLuint) target, offset, size_of(T) * len(src), raw_data(src))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

Buffer_SubData_One :: #force_inline proc (
	target: Buffer_Binding_Target,
	offset: GLintptr,
	src: ^$T,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	when NGL_DEBUG {
		if src == nil {
			_bad_input("BufferSubData called with nil.", _loc)
			return
		}
	}
	glBufferSubData(cast(GLuint) target, offset, size_of(T), src)
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
	glDrawElementsInstanced(
		cast(GLuint) mode,
		count,
		cast(GLuint) type,
		offset,
		instance_count)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




DrawElements :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	indices: GLintptr = 0,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glDrawElements(
		cast(GLuint) mode,
		count,
		cast(GLuint) type,
		indices = cast(rawptr) indices)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




GenBuffers :: proc (
	len: int,
	out: [^]Buffer, 
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	for i in 0..<len {
		out[i] = glCreateBuffer()
	}
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

CreateBuffer :: proc (
	_loc := #caller_location
) -> (err: Error = .NO_ERROR, buffer: Buffer) {
	buffer = glCreateBuffer()
	when NGL_VALIDATE { err = validate(_loc); return } else { return }
}




GenVertexArrays :: proc (
	len: int,
	out: [^]VertexArrayObject,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	for i in 0..<len {
		out[i] = glCreateVertexArray()
	}
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

CreateVertexArray :: proc (
	_loc := #caller_location
) -> (err: Error = .NO_ERROR, vao: VertexArrayObject) {
	vao = glCreateVertexArray()
	when NGL_VALIDATE { err = validate(_loc); return } else { return }
}




GenTextures :: proc (
	len: int,
	out: []Texture,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	for i in 0..<len {
		out[i] = glCreateTexture()
	}
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

CreateTexture :: proc (_loc := #caller_location) -> (err: Error = .NO_ERROR, tex: Texture) {
	tex = glCreateTexture()
	when NGL_VALIDATE { err = validate(_loc); return } else { return }
}




BindBuffer :: proc (
	target: Buffer_Type,
	buffer: Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBuffer(cast(GLuint) target, buffer)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BindBufferBase :: proc (
	target,
	index: GLuint,
	buffer: Buffer,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBufferBase(target, index, buffer)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}





BindBufferRange :: proc (
	target, index: GLuint,
	buffer: Buffer,
	offset, size: int,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindBufferRange(target, index, buffer, offset, size)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}





BindVertexArray :: proc (
	vao: VertexArrayObject,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glBindVertexArray(vao)
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
	index: GLuint,
	size: int,
	type: Data_Type,
	normalized: bool,
	stride: int,
	offset: GLintptr,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribPointer(index, size, cast(GLuint)type, normalized, stride, offset)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}

VertexAttribIPointer :: proc (
	index: GLuint,
	size: int,
	type: Data_Type,
	stride: int,
	offset: GLintptr,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribIPointer(index, size, cast(GLuint)type, stride, offset)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




// WebGL mimics KHR_robust_access (bounds checking)
EnableVertexAttribArray :: proc (
	index: GLuint,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glEnableVertexAttribArray(index)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}



// Generates INVALID_VALUE if index > MAX_VERTEX_ATTRIBS
VertexAttribDivisor :: proc (
	index,
	divisor: GLuint,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glVertexAttribDivisor(index, divisor)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




Clear :: proc (mask: Clear_Buffer_Mask) {
	glClear(transmute(GLuint)mask)
}




ClearColor :: glClearColor




Enable :: proc (cap: Capability) {
	glEnable(cast(GLuint) cap)
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
	glBlendFunc(cast(GLuint)src, cast(GLuint)dst)
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
	glCullFace(cast(GLuint)mode)
}




FrontFace :: proc (cw_or_ccw: Vertex_Winding_Order) {
	glFrontFace(cast(GLuint)cw_or_ccw)
}




UseProgram :: proc (
	program: Program,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glUseProgram(program)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




GetProgramInfoLog :: proc (program: Program) -> string {
	log_length: int
	GetProgramiv(program, cast(GLuint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetProgramInfoLog(program, log_bytes, &log_length)
	return string(log_bytes[:log_length])
}




GetShaderInfoLog :: proc (shader: Shader) -> string {
	log_length: int
	GetShaderiv(shader, cast(GLuint)Shader_Parameter_Name.INFO_LOG_LENGTH, &log_length)
	log_bytes := make([]u8, log_length)
	glGetShaderInfoLog(shader, log_bytes, &log_length)
	return string(log_bytes[:log_length])
}




CreateShader :: proc (type: Shader_Type) -> Shader {
	return cast(Shader) glCreateShader(cast(GLuint)type)
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




UniformBlockBinding :: proc (p: Program, index, binding: GLuint) {
	glUniformBlockBinding(p, index, binding)
}




GetUniformBlockIndex :: proc (p: Program, block_name: string) -> GLuint {
	return glGetUniformBlockIndex(p, block_name)
}




GetUniformLocation :: proc (p: Program, name: string) -> int {
	return glGetUniformLocation(p, name)
}




TexImage2D_verbatim :: proc (
	target: Texture_2D_Target,
	level: int,
	internalformat: int,
	width, height: int,
	format,
	type: GLuint,
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
		len(data) * size_of(T),
		raw_data(data))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




TexSubImage2D :: proc (
	target: Texture_2D_Target,
	level: int,
	xoffset, yoffset: int,
	width, height: int,
	format: GLuint, // TODO scoped enum
	type: GLuint,
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
		len(data) * size_of(T),
		raw_data(data))
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




BindTexture :: proc (binding: Texture_Target, tex: Texture) {
	glBindTexture(cast(GLuint) binding, tex)
}



CreateFramebuffer :: proc () -> (Framebuffer) {
	return glCreateFramebuffer()
}

GenFramebuffers :: proc (len: int, out: [^]Framebuffer) {
	for index in 0..<len {
		out[index] = glCreateFramebuffer()
	}
}

BindFramebuffer :: proc (target: Framebuffer_Target, fb: Framebuffer) {
	glBindFramebuffer(cast(GLuint)target, fb)
}

FramebufferTexture2D :: proc (
	target: Framebuffer_Target,
	attachment: Framebuffer_Attachment,
	textarget: Texture_2D_Target,
	texture: Texture,
	level: int,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	glFramebufferTexture2D(
		cast(GLuint) target,
		cast(GLuint) attachment,
		cast(GLuint) textarget,
		texture,
		level)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}




CreateSampler :: proc () -> (Sampler) {
	return glCreateSampler()
}

GenSamplers :: proc (
	len: int,
	out: [^]Sampler,
	_loc := #caller_location
) -> (err: Error = .NO_ERROR) {
	for index in 0..<len {
		out[index] = glCreateSampler()
		when NGL_VALIDATE { return validate(_loc) } else { return }
	}
	return
}




BindSampler :: proc (unit: GLuint, sampler: Sampler) {
	glBindSampler(unit, sampler)
}

CheckFramebufferStatus :: proc (target: Framebuffer_Target) -> GLenum {
	return glCheckFramebufferStatus(auto_cast target)
}




DeleteVertexArray :: proc (it: VertexArrayObject) {
	glDeleteVertexArray(it)
}

DeleteBuffer :: proc (it: Buffer) {
	glDeleteBuffer(it)
}

DeleteProgram :: proc (it: Program) {
	glDeleteProgram(it)
}

// Get_Texture_Base_Level   :: proc (target: Texture_Parameter_Target) -> GLuint {}
// Get_Texture_Max_Level    :: proc (target: Texture_Parameter_Target) -> GLuint {}
// Get_Texture_Min_LOD      :: proc (target: Texture_Parameter_Target) -> f32 {}
// Get_Texture_Max_LOD      :: proc (target: Texture_Parameter_Target) -> f32 {}
// Get_Texture_Mag_Filter   :: proc (target: Texture_Parameter_Target) -> Texture_Mag_Filter {}
// Get_Texture_Min_Filter   :: proc (target: Texture_Parameter_Target) -> Texture_Min_Filter {}
// Get_Texture_Compare_Func :: proc (target: Texture_Parameter_Target) -> Compare_Func {}
// Get_Texture_Compare_Mode :: proc (target: Texture_Parameter_Target) -> Compare_Mode {}
// Get_Texture_Wrap_S       :: proc (target: Texture_Parameter_Target) -> Texture_Wrap_Mode {}
// Get_Texture_wrap_T       :: proc (target: Texture_Parameter_Target) -> Texture_Wrap_Mode {}
// Get_Texture_Wrap_R       :: proc (target: Texture_Parameter_Target) -> Texture_Wrap_Mode {}

//////////////////////////////////////////////////////////////////////
// Platform-Specific Stuff Below
//////////////////////////////////////////////////////////////////////
// Not Web, need unified way of querying support.
GetParameter :: proc {
	GetIntegerv,
	GetInteger64v,
}

GetIntegerv :: proc (pname: Integerv_Parameter) -> (value: int) {
	value = glGetParameter(cast(GLuint)pname)
	return
}

GetInteger64v :: proc (pname: Integer64v_Parameter) -> (value: i64) {
	value = auto_cast glGetParameter(cast(GLuint)pname) // TODO: odin.js is wrong about this.
	return
}


Viewport :: glViewport

