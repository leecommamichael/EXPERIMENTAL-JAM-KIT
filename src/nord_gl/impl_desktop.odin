#+build !js
package nord_gl

import "base:intrinsics"
import "core:strings"
import "core:fmt"

validate :: proc () -> Error {
	when NGL_VALIDATE {
		err := cast(Error) glGetError()
		when NGL_DEBUG {
			if err != .NO_ERROR {
				intrinsics.debug_trap()
				fmt.printfln("debug_trap emitted.")
			}
		}
		return err
	} else {
		return .NO_ERROR
	}
}

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




// @Experts: As you can see, offset is not a rawptr to CPU memory. For WebGL2 compatibility.
DrawElementsInstanced :: #force_inline proc (
	mode:   Primitive_Mode,
	count:  int,
	type:   Index_Type,
	offset: int,
	instance_count: int
) -> (err: Error = .NO_ERROR) {
	offset := cast(rawptr) cast(uintptr) offset
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
	glGenBuffers(cast(int)len(out), cast(^uint)&out[0])
	when NGL_VALIDATE { return validate() } else { return }
}

GenBuffersOne :: proc (out: ^Buffer) -> (err: Error = .NO_ERROR) {
	glGenBuffers(1, cast(^uint)out)
	when NGL_VALIDATE { return validate() } else { return }
}




GenVertexArrays :: proc {
	GenVertexArraysMany,
	GenVertexArraysOne, 
}

GenVertexArraysMany :: proc (out: []Buffer) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(cast(int)len(out), cast([^]uint)raw_data(out))
	when NGL_VALIDATE { return validate() } else { return }
}

GenVertexArraysOne :: proc (out: ^Buffer) -> (err: Error = .NO_ERROR) {
	glGenVertexArrays(1, cast(^uint)out)
	when NGL_VALIDATE { return validate() } else { return }
}




// :: proc () -> (err: Error = .NO_ERROR)
// when NGL_VALIDATE { return validate() } else { return }
BindBuffer :: proc (target: Buffer_Type, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBuffer(cast(uint) target, cast(uint) buffer)
	when NGL_VALIDATE { return validate() } else { return }
}




BindBufferBase :: proc (target, index: uint, buffer: Buffer) -> (err: Error = .NO_ERROR) {
	glBindBufferBase(target, index, cast(uint)buffer)
	when NGL_VALIDATE { return validate() } else { return }
}





BindBufferRange :: proc (
	target, index: uint,
	buffer: Buffer,
	offset, size: int) -> (err: Error = .NO_ERROR) {
	glBindBufferRange(target, index, cast(uint)buffer, offset, size)
	when NGL_VALIDATE { return validate() } else { return }
}





BindVertexArray :: proc (vao: Buffer) -> (err: Error = .NO_ERROR) {
	glBindVertexArray(cast(uint) vao)
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




UseProgram :: proc (program: Program) -> (err: Error = .NO_ERROR) {
	glUseProgram(cast(uint) program)
	when NGL_VALIDATE { return validate() } else { return }
}



// These aren't on Web
GetProgramInfoLog :: proc (program: uint, bufSize: int, length: ^int, infoLog: [^]u8) {
	glGetProgramInfoLog(program, bufSize, length, infoLog)
}

GetShaderInfoLog :: proc (shader: uint, bufSize: int, length: ^int, infoLog: [^]u8) {
	glGetShaderInfoLog(shader, bufSize, length, infoLog)
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



