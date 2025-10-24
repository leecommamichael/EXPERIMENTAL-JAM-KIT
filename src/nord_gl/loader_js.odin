package nord_gl

foreign import "webgl"
foreign import "webgl2"

import glm "core:math/linalg/glsl"
import "base:intrinsics"



ContextAttribute :: enum GLuint {
	disableAlpha                 = 0,
	disableAntialias             = 1,
	disableDepth                 = 2,
	failIfMajorPerformanceCaveat = 3,
	disablePremultipliedAlpha    = 4,
	preserveDrawingBuffer        = 5,
	stencil                      = 6,
	desynchronized               = 7,
}
ContextAttributes :: distinct bit_set[ContextAttribute; GLuint]

DEFAULT_CONTEXT_ATTRIBUTES :: ContextAttributes{}

@(default_calling_convention="contextless")
foreign webgl {
	// CreateCurrentContextById must be called before `GetCurrentContextAttributes` if the user wants to
	// set specific attributes, otherwise the default attributes will be set for the WebGL context
	CreateCurrentContextById :: proc(name: string, attributes: ContextAttributes) -> bool ---
	// Acquire the WebGL context from a canvas element by id
	SetCurrentContextById :: proc(name: string) -> bool ---
	GetCurrentContextAttributes :: proc() -> ContextAttributes ---

	DrawingBufferWidth  :: proc() -> int ---
	DrawingBufferHeight :: proc() -> int ---
	
	GetWebGLVersion :: proc(major, minor: ^int) ---
	GetESVersion :: proc(major, minor: ^int) ---
	
	GetError :: proc() -> Error ---
	
	// IsExtensionSupported :: proc(name: string) -> bool ---

	@(link_name="ActiveTexture")
	glActiveTexture         :: proc(x: GLuint) ---
	@(link_name="AttachShader")
	glAttachShader          :: proc(program: Program, shader: Shader) ---
	@(link_name="BindAttribLocation")
	glBindAttribLocation    :: proc(program: Program, index: int, name: string) ---
	@(link_name="BindBuffer")
	glBindBuffer            :: proc(target: GLuint, buffer: Buffer) ---
	@(link_name="BindFramebuffer")
	glBindFramebuffer       :: proc(target: GLuint, framebuffer: Framebuffer) ---
	@(link_name="BindTexture")
	glBindTexture           :: proc(target: GLuint, texture: Texture) ---
	@(link_name="BlendColor")
	glBlendColor            :: proc(red, green, blue, alpha: GLfloat) ---
	@(link_name="BlendEquation")
	glBlendEquation         :: proc(mode: GLuint) ---
	@(link_name="BlendEquationSeparate")
	glBlendEquationSeparate :: proc(modeRGB: GLuint, modeAlpha: GLuint) ---
	@(link_name="BlendFunc")
	glBlendFunc             :: proc(sfactor, dfactor: GLuint) ---
	@(link_name="BlendFuncSeparate")
	glBlendFuncSeparate     :: proc(srcRGB, dstRGB, srcAlpha, dstAlpha: GLuint) ---
	
	@(link_name="BufferData")
	glBufferData    :: proc(target: GLuint, size: int, data: rawptr, usage: GLuint) ---
	@(link_name="BufferSubData")
	glBufferSubData :: proc(target: GLuint, offset: GLuintptr, size: int, data: rawptr) ---

	@(link_name="Clear")
	glClear         :: proc(bits: GLuint) ---
	@(link_name="ClearColor")
	glClearColor    :: proc(r, g, b, a: GLfloat) ---
	@(link_name="ClearDepth")
	glClearDepth    :: proc(x: GLfloat) ---
	@(link_name="ClearStencil")
	glClearStencil  :: proc(x: int) ---
	@(link_name="ColorMask")
	glColorMask     :: proc(r, g, b, a: bool) ---
	@(link_name="CompileShader")
	glCompileShader :: proc(shader: Shader) ---
	
	@(link_name="CompressedTexImage2D")
	glCompressedTexImage2D    :: proc(target: GLuint, level: int, internalformat: GLuint, width, height: int, border: int, imageSize: int, data: rawptr) ---
	@(link_name="CompressedTexSubImage2D")
	glCompressedTexSubImage2D :: proc(target: GLuint, level: int, xoffset, yoffset, width, height: int, format: GLuint, imageSize: int, data: rawptr) ---
	@(link_name="CopyTexImage2D")
	glCopyTexImage2D          :: proc(target: GLuint, level: int, internalformat: GLuint, x, y, width, height: int, border: int) ---
	@(link_name="CopyTexSubImage2D")
	glCopyTexSubImage2D       :: proc(target: GLuint, level: int, xoffset, yoffset, x, y: int, width, height: int) ---
	

	@(link_name="CreateBuffer")
	glCreateBuffer       :: proc() -> Buffer ---
	@(link_name="CreateFramebuffer")
	glCreateFramebuffer  :: proc() -> Framebuffer ---
	@(link_name="CreateProgram")
	glCreateProgram      :: proc() -> Program ---
	@(link_name="CreateRenderbuffer")
	glCreateRenderbuffer :: proc() -> Renderbuffer ---
	@(link_name="CreateShader")
	glCreateShader       :: proc(shaderType: GLuint) -> Shader ---
	@(link_name="CreateTexture")
	glCreateTexture      :: proc() -> Texture ---
	
	@(link_name="CullFace")
	glCullFace :: proc(mode: GLuint) ---
	
	@(link_name="DeleteBuffer")
	glDeleteBuffer       :: proc(buffer: Buffer) ---
	@(link_name="DeleteFramebuffer")
	glDeleteFramebuffer  :: proc(framebuffer: Framebuffer) ---
	@(link_name="DeleteProgram")
	glDeleteProgram      :: proc(program: Program) ---
	@(link_name="DeleteRenderbuffer")
	glDeleteRenderbuffer :: proc(renderbuffer: Renderbuffer) ---
	@(link_name="DeleteShader")
	glDeleteShader       :: proc(shader: Shader) ---
	@(link_name="DeleteTexture")
	glDeleteTexture      :: proc(texture: Texture) ---
	
	@(link_name="DepthFunc")
	glDepthFunc                :: proc(func: GLuint) ---
	@(link_name="DepthMask")
	glDepthMask                :: proc(flag: bool) ---
	@(link_name="DepthRange")
	glDepthRange               :: proc(zNear, zFar: GLfloat) ---
	@(link_name="DetachShader")
	glDetachShader             :: proc(program: Program, shader: Shader) ---
	@(link_name="Disable")
	glDisable                  :: proc(cap: GLuint) ---
	@(link_name="DisableVertexAttribArray")
	glDisableVertexAttribArray :: proc(index: int) ---
	@(link_name="DrawArrays")
	glDrawArrays               :: proc(mode: GLuint, first, count: int) ---
	@(link_name="DrawElements")
	glDrawElements             :: proc(mode: GLuint, count: int, type: GLuint, indices: rawptr) ---
	
	@(link_name="Enable")
	glEnable                  :: proc(cap: GLuint) ---
	@(link_name="EnableVertexAttribArray")
	glEnableVertexAttribArray :: proc(index: GLuint) ---
	@(link_name="Finish")
	glFinish                  :: proc() ---
	@(link_name="Flush")
	glFlush                   :: proc() ---
	@(link_name="FramebufferRenderbuffer")
	glFramebufferRenderbuffer :: proc(target, attachment, renderbufertarget: GLuint, renderbuffer: Renderbuffer) ---
	@(link_name="FramebufferTexture2D")
	glFramebufferTexture2D    :: proc(target, attachment, textarget: GLuint, texture: Texture, level: int) ---
	@(link_name="FrontFace")
	glFrontFace               :: proc(mode: GLuint) ---
	
	@(link_name="GenerateMipmap")
	glGenerateMipmap :: proc(target: GLuint) ---
	
	@(link_name="GetAttribLocation")
	glGetAttribLocation     :: proc(program: Program, name: string) -> int ---
	@(link_name="GetUniformLocation")
	glGetUniformLocation    :: proc(program: Program, name: string) -> int ---
	@(link_name="GetVertexAttribOffset")
	glGetVertexAttribOffset :: proc(index: int, pname: GLuint) -> GLuintptr ---
	@(link_name="GetProgramParameter")
	glGetProgramParameter   :: proc(program: Program, pname: GLuint) -> int ---
	@(link_name="GetParameter")
	glGetParameter          :: proc(pname: GLuint) -> int ---
	@(link_name="GetParameter4i")
	glGetParameter4i        :: proc(pname: GLuint, v0, v1, v2, v4: ^int) ---

	@(link_name="Hint")
	glHint :: proc(target: GLuint, mode: GLuint) ---
	
	@(link_name="IsBuffer")
	glIsBuffer       :: proc(buffer: Buffer) -> bool ---
	@(link_name="IsEnabled")
	glIsEnabled      :: proc(cap: GLuint) -> bool ---
	@(link_name="IsFramebuffer")
	glIsFramebuffer  :: proc(framebuffer: Framebuffer) -> bool ---
	@(link_name="IsProgram")
	glIsProgram      :: proc(program: Program) -> bool ---
	@(link_name="IsRenderbuffer")
	glIsRenderbuffer :: proc(renderbuffer: Renderbuffer) -> bool ---
	@(link_name="IsShader")
	glIsShader       :: proc(shader: Shader) -> bool ---
	@(link_name="IsTexture")
	glIsTexture      :: proc(texture: Texture) -> bool ---
	
	@(link_name="LineWidth")
	glLineWidth     :: proc(width: GLfloat) ---
	@(link_name="LinkProgram")
	glLinkProgram   :: proc(program: Program) ---
	@(link_name="PixelStorei")
	glPixelStorei   :: proc(pname: GLuint, param: int) ---
	@(link_name="PolygonOffset")
	glPolygonOffset :: proc(factor: GLfloat, units: GLfloat) ---
	
	@(link_name="ReadnPixels")
	glReadnPixels         :: proc(x, y, width, height: int, format: GLuint, type: GLuint, bufSize: int, data: rawptr) ---
	@(link_name="RenderbufferStorage")
	glRenderbufferStorage :: proc(target: GLuint, internalformat: GLuint, width, height: int) ---
	@(link_name="SampleCoverage")
	glSampleCoverage      :: proc(value: GLfloat, invert: bool) ---
	@(link_name="Scissor")
	glScissor             :: proc(x, y, width, height: int) ---
	@(link_name="ShaderSource")
	glShaderSource        :: proc(shader: Shader, string: string) ---
	
	@(link_name="StencilFunc")
	glStencilFunc         :: proc(func: GLuint, ref: int, mask: GLuint) ---
	@(link_name="StencilFuncSeparate")
	glStencilFuncSeparate :: proc(face, func: GLuint, ref: int, mask: GLuint) ---
	@(link_name="StencilMask")
	glStencilMask         :: proc(mask: GLuint) ---
	@(link_name="StencilMaskSeparate")
	glStencilMaskSeparate :: proc(face: GLuint, mask: GLuint) ---
	@(link_name="StencilOp")
	glStencilOp           :: proc(fail, zfail, zpass: GLuint) ---
	@(link_name="StencilOpSeparate")
	glStencilOpSeparate   :: proc(face, fail, zfail, zpass: GLuint)	 ---
	
	@(link_name="TexImage2D")
	glTexImage2D    :: proc(target: GLuint, level: int, internalformat: int, width, height: int, border: int, format, type: GLuint, size: int, data: rawptr) ---
	@(link_name="TexSubImage2D")
	glTexSubImage2D :: proc(target: GLuint, level: int, xoffset, yoffset, width, height: int, format, type: GLuint, size: int, data: rawptr) ---
	
	@(link_name="TexParameterf")
	glTexParameterf :: proc(target, pname: GLuint, param: GLfloat) ---
	@(link_name="TexParameteri")
	glTexParameteri :: proc(target, pname: GLuint, param: int) ---
	
	@(link_name="Uniform1f")
	glUniform1f :: proc(location: int, v0: GLfloat) ---
	@(link_name="Uniform2f")
	glUniform2f :: proc(location: int, v0, v1: GLfloat) ---
	@(link_name="Uniform3f")
	glUniform3f :: proc(location: int, v0, v1, v2: GLfloat) ---
	@(link_name="Uniform4f")
	glUniform4f :: proc(location: int, v0, v1, v2, v3: GLfloat) ---
	
	@(link_name="Uniform1i")
	glUniform1i :: proc(location: int, v0: int) ---
	@(link_name="Uniform2i")
	glUniform2i :: proc(location: int, v0, v1: int) ---
	@(link_name="Uniform3i")
	glUniform3i :: proc(location: int, v0, v1, v2: int) ---
	@(link_name="Uniform4i")
	glUniform4i :: proc(location: int, v0, v1, v2, v3: int) ---
	
	@(link_name="UseProgram")
	glUseProgram      :: proc(program: Program) ---
	@(link_name="ValidateProgram")
	glValidateProgram :: proc(program: Program) ---
		
	@(link_name="VertexAttrib1f")
	glVertexAttrib1f      :: proc(index: int, x: GLfloat) ---
	@(link_name="VertexAttrib2f")
	glVertexAttrib2f      :: proc(index: int, x, y: GLfloat) ---
	@(link_name="VertexAttrib3f")
	glVertexAttrib3f      :: proc(index: int, x, y, z: GLfloat) ---
	@(link_name="VertexAttrib4f")
	glVertexAttrib4f      :: proc(index: int, x, y, z, w: GLfloat) ---
	@(link_name="VertexAttribPointer")
	glVertexAttribPointer :: proc(index: GLuint, size: int, type: GLuint, normalized: bool, stride: int, ptr: GLuintptr) ---
	
	@(link_name="Viewport")
	glViewport :: proc(x, y, w, h: int) ---
	@(link_name="UniformMatrix2fv")
	glUniformMatrix2fv :: proc "contextless" (location: int, value: [^]GLfloat) ---
	@(link_name="UniformMatrix3fv")
	glUniformMatrix3fv :: proc "contextless" (location: int, value: [^]GLfloat) ---
	@(link_name="UniformMatrix4fv")
	glUniformMatrix4fv :: proc "contextless" (location: int, value: [^]GLfloat) ---
	@(link_name="GetShaderiv")
	glGetShaderiv :: proc "contextless" (shader: Shader, pname: GLuint, p: ^int) ---
	@(link_name="GetProgramiv")
	glGetProgramiv :: proc "contextless" (shader: Program, pname: GLuint, p: ^int) --- // TODO: just here to get log length for now.
	@(link_name="GetProgramInfoLog")
	glGetProgramInfoLog :: proc "contextless" (program: Program, buf: []byte, length: ^int) ---
	@(link_name="GetShaderInfoLog")
	glGetShaderInfoLog :: proc "contextless" (shader: Shader, buf: []byte, length: ^int) ---
}

// Uniform1fv :: proc "contextless" (location: int, v: GLfloat)       { glUniform1f(location, v) }
// Uniform2fv :: proc "contextless" (location: int, v: glm.vec2)  { glUniform2f(location, v.x, v.y) }
// Uniform3fv :: proc "contextless" (location: int, v: glm.vec3)  { glUniform3f(location, v.x, v.y, v.z) }
// Uniform4fv :: proc "contextless" (location: int, v: glm.vec4)  { glUniform4f(location, v.x, v.y, v.z, v.w) }
// Uniform1iv :: proc "contextless" (location: int, v: int)       { glUniform1i(location, v) }
// Uniform2iv :: proc "contextless" (location: int, v: glm.ivec2) { glUniform2i(location, v.x, v.y) }
// Uniform3iv :: proc "contextless" (location: int, v: glm.ivec3) { glUniform3i(location, v.x, v.y, v.z) }
// Uniform4iv :: proc "contextless" (location: int, v: glm.ivec4) { glUniform4i(location, v.x, v.y, v.z, v.w) }

// VertexAttrib1fv :: proc "contextless" (index: int, v: GLfloat)     { glVertexAttrib1f(index, v) }
// VertexAttrib2fv :: proc "contextless" (index: int, v: glm.vec2){ glVertexAttrib2f(index, v.x, v.y) }
// VertexAttrib3fv :: proc "contextless" (index: int, v: glm.vec3){ glVertexAttrib3f(index, v.x, v.y, v.z) }
// VertexAttrib4fv :: proc "contextless" (index: int, v: glm.vec4){ glVertexAttrib4f(index, v.x, v.y, v.z, v.w) }

// UniformMatrix2fv :: proc "contextless" (location: int, m: glm.mat2) {
// 	value := transmute([2*2]GLfloat)m
// 	glUniformMatrix2fv(location, &value[0])
// }

// UniformMatrix3fv :: proc "contextless" (location: int, m: glm.mat3) {
// 	value := transmute([3*3]GLfloat)m
// 	glUniformMatrix3fv(location, &value[0])
// }

// UniformMatrix4fv :: proc "contextless" (location: int, m: glm.mat4) {
// 	value := transmute([4*4]GLfloat)m
// 	glUniformMatrix4fv(location, &value[0])
// }

// GetShaderiv :: proc "contextless" (shader: Shader, pname: GLuint) -> (p: int) {
// 	glGetShaderiv(shader, pname, &p)
// 	return
// }





// WebGL2 Start //////////////////////////////////////////////////////////////////////////////////////////////

// BufferDataSlice :: proc "contextless" (target: GLuint, slice: $S/[]$E, usage: GLuint) {
// 	BufferData(target, len(slice)*size_of(E), raw_data(slice), usage)
// }
// BufferSubDataSlice :: proc "contextless" (target: GLuint, offset: GLuintptr, slice: $S/[]$E) {
// 	glBufferSubData(target, offset, len(slice)*size_of(E), raw_data(slice))
// }

// CompressedTexImage2DSlice :: proc "contextless" (target: GLuint, level: int, internalformat: GLuint, width, height: int, border: int, slice: $S/[]$E) {
// 	glCompressedTexImage2DSlice(target, level, internalformat, width, height, border, len(slice)*size_of(E), raw_data(slice))
// }
// CompressedTexSubImage2DSlice :: proc "contextless" (target: GLuint, level: int, xoffset, yoffset, width, height: int, format: GLuint, slice: $S/[]$E) {
// 	glCompressedTexSubImage2DSlice(target, level, level, xoffset, yoffset, width, height, format, len(slice)*size_of(E), raw_data(slice))
// }

// ReadPixelsSlice :: proc "contextless" (x, y, width, height: int, format: GLuint, type: GLuint, slice: $S/[]$E) {
// 	glReadnPixels(x, y, width, height, format, type, len(slice)*size_of(E), raw_data(slice))
// }

// TexImage2DSlice :: proc "contextless" (target: GLuint, level: int, internalformat: GLuint, width, height: int, border: int, format, type: GLuint, slice: $S/[]$E) {
// 	glTexImage2D(target, level, internalformat, width, height, border, format, type, len(slice)*size_of(E), raw_data(slice))
// }
// TexSubImage2DSlice :: proc "contextless" (target: GLuint, level: int, xoffset, yoffset, width, height: int, format, type: GLuint, slice: $S/[]$E) {
// 	glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, len(slice)*size_of(E), raw_data(slice))
// }

// IsWebGL2Supported :: proc "contextless" () -> bool {
// 	major, minor: int
// 	GetWebGLVersion(&major, &minor)
// 	return major >= 2
// }

@(default_calling_convention="contextless")
foreign webgl2 {
	/* Buffer objects */
	@(link_name="CopyBufferSubData")
	glCopyBufferSubData :: proc(readTarget, writeTarget: GLuint, readOffset, writeOffset: int, size: int) ---	
	@(link_name="GetBufferSubData")
	glGetBufferSubData  :: proc(target: GLuint, srcByteOffset: int, dst_buffer: []byte, dstOffset: int = 0, length: int = 0) ---
	
	/* Framebuffer objects */
	@(link_name="BlitFramebuffer")
	glBlitFramebuffer          :: proc(srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1: int, mask: GLuint, filter: GLuint) ---
	@(link_name="FramebufferTextureLayer")
	glFramebufferTextureLayer  :: proc(target: GLuint, attachment: GLuint, texture: Texture, level: int, layer: int) ---
	@(link_name="InvalidateFramebuffer")
	glInvalidateFramebuffer    :: proc(target: GLuint, attachments: []GLuint) ---
	@(link_name="InvalidateSubFramebuffer")
	glInvalidateSubFramebuffer :: proc(target: GLuint, attachments: []GLuint, x, y, width, height: int) ---
	@(link_name="ReadBuffer")
	glReadBuffer               :: proc(src: GLuint) ---
	
	/* Renderbuffer objects */
	@(link_name="RenderbufferStorageMultisample")
	glRenderbufferStorageMultisample :: proc(target: GLuint, samples: int, internalformat: GLuint, width, height: int) ---
	
	/* Texture objects */
	@(link_name="TexStorage3D")
	glTexStorage3D            :: proc(target: GLuint, levels: int, internalformat: GLuint, width, height, depth: int) ---
	@(link_name="TexImage3D")
	glTexImage3D              :: proc(target: GLuint, level: int, internalformat: GLuint, width, height, depth: int, border: int, format, type: GLuint, size: int, data: rawptr) ---
	@(link_name="TexSubImage3D")
	glTexSubImage3D           :: proc(target: GLuint, level: int, xoffset, yoffset, width, height, depth: int, format, type: GLuint, size: int, data: rawptr) ---
	@(link_name="CompressedTexImage3D")
	glCompressedTexImage3D    :: proc(target: GLuint, level: int, internalformat: GLuint, width, height, depth: int, border: int, imageSize: int, data: rawptr) ---
	@(link_name="CompressedTexSubImage3D")
	glCompressedTexSubImage3D :: proc(target: GLuint, level: int, xoffset, yoffset: int, width, height, depth: int, format: GLuint, imageSize: int, data: rawptr) ---
	@(link_name="CopyTexSubImage3D")
	glCopyTexSubImage3D       :: proc(target: GLuint, level: int, xoffset, yoffset, zoffset: int, x, y, width, height: int) ---
	
	/* Programs and shaders */
	@(link_name="GetFragDataLocation")
	glGetFragDataLocation :: proc(program: Program, name: string) -> int ---
	
	/* Uniforms */
	@(link_name="Uniform1ui")
	glUniform1ui :: proc(location: int, v0: GLuint) ---
	@(link_name="Uniform2ui")
	glUniform2ui :: proc(location: int, v0: GLuint, v1: GLuint) ---
	@(link_name="Uniform3ui")
	glUniform3ui :: proc(location: int, v0: GLuint, v1: GLuint, v2: GLuint) ---
	@(link_name="Uniform4ui")
	glUniform4ui :: proc(location: int, v0: GLuint, v1: GLuint, v2: GLuint, v3: GLuint) ---

	/* Vertex attribs */
	@(link_name="VertexAttribI4i")
	glVertexAttribI4i      :: proc(index: int, x, y, z, w: int) ---
	@(link_name="VertexAttribI4ui")
	glVertexAttribI4ui     :: proc(index: int, x, y, z, w: GLuint) ---
	@(link_name="VertexAttribIPointer")
	glVertexAttribIPointer :: proc(index: GLuint, size: int, type: GLuint, stride: int, offset: GLuintptr) ---
	
	/* Writing to the drawing buffer */
	@(link_name="VertexAttribDivisor")
	glVertexAttribDivisor   :: proc(index: GLuint, divisor: GLuint) ---
	@(link_name="DrawArraysInstanced")
	glDrawArraysInstanced   :: proc(mode: GLuint, first, count: int, instanceCount: int) ---
	@(link_name="DrawElementsInstanced")
	glDrawElementsInstanced :: proc(mode: GLuint, count: int, type: GLuint, offset: int, instanceCount: int) ---
	@(link_name="DrawRangeElements")
	glDrawRangeElements     :: proc(mode: GLuint, start, end, count: int, type: GLuint, offset: int) ---
	
	/* Multiple Render Targets */
	@(link_name="DrawBuffers")
	glDrawBuffers    :: proc(buffers: []GLuint) ---
	@(link_name="ClearBufferfv")
	glClearBufferfv  :: proc(buffer: GLuint, drawbuffer: int, values: []GLfloat) ---
	@(link_name="ClearBufferiv")
	glClearBufferiv  :: proc(buffer: GLuint, drawbuffer: int, values: []int) ---
	@(link_name="ClearBufferuiv")
	glClearBufferuiv :: proc(buffer: GLuint, drawbuffer: int, values: []GLuint) ---
	@(link_name="ClearBufferfi")
	glClearBufferfi  :: proc(buffer: GLuint, drawbuffer: int, depth: GLfloat, stencil: int) ---
	
	@(link_name="CreateQuery")
	glCreateQuery :: proc() -> Query ---
	@(link_name="DeleteQuery")
	glDeleteQuery :: proc(query: Query) ---
	@(link_name="IsQuery")
	glIsQuery     :: proc(query: Query) -> bool ---
	@(link_name="BeginQuery")
	glBeginQuery  :: proc(target: GLuint, query: Query) ---
	@(link_name="EndQuery")
	glEndQuery    :: proc(target: GLuint) ---
	@(link_name="GetQuery")
	glGetQuery    :: proc(target, pname: GLuint) ---
	
	@(link_name="CreateSampler")
	glCreateSampler     :: proc() -> Sampler ---
	@(link_name="DeleteSampler")
	glDeleteSampler     :: proc(sampler: Sampler) ---
	@(link_name="IsSampler")
	glIsSampler         :: proc(sampler: Sampler) -> bool ---
	@(link_name="BindSampler")
	glBindSampler       :: proc(unit: GLuint, sampler: Sampler) ---
	@(link_name="SamplerParameteri")
	glSamplerParameteri :: proc(sampler: Sampler, pname: GLuint, param: int) ---
	@(link_name="SamplerParameterf")
	glSamplerParameterf :: proc(sampler: Sampler, pname: GLuint, param: GLfloat) ---
	
	@(link_name="FenceSync")
	glFenceSync      :: proc(condition: GLuint, flags: GLuint) -> Sync ---
	@(link_name="IsSync")
	glIsSync         :: proc(sync: Sync) -> bool ---
	@(link_name="DeleteSync")
	glDeleteSync     :: proc(sync: Sync) ---
	@(link_name="ClientWaitSync")
	glClientWaitSync :: proc(sync: Sync, flags: GLuint, timeout: u64) ---
	@(link_name="WaitSync")
	glWaitSync       :: proc(sync: Sync, flags: GLuint, timeout: i64) ---
	
	@(link_name="CreateTransformFeedback")
	glCreateTransformFeedback   :: proc() -> TransformFeedback ---
	@(link_name="DeleteTransformFeedback")
	glDeleteTransformFeedback   :: proc(tf: TransformFeedback) ---
	@(link_name="IsTransformFeedback")
	glIsTransformFeedback       :: proc(tf: TransformFeedback) -> bool ---
	@(link_name="BindTransformFeedback")
	glBindTransformFeedback     :: proc(target: GLuint, tf: TransformFeedback) ---
	@(link_name="BeginTransformFeedback")
	glBeginTransformFeedback    :: proc(primitiveMode: GLuint) ---
	@(link_name="EndTransformFeedback")
	glEndTransformFeedback      :: proc() ---
	@(link_name="TransformFeedbackVaryings")
	glTransformFeedbackVaryings :: proc(program: Program, varyings: []string, bufferMode: GLuint) ---
	@(link_name="PauseTransformFeedback")
	glPauseTransformFeedback    :: proc() ---
	@(link_name="ResumeTransformFeedback")
	glResumeTransformFeedback   :: proc() ---
	
	@(link_name="BindBufferBase")
	glBindBufferBase            :: proc(target: GLuint, index: GLuint, buffer: Buffer) ---
	@(link_name="BindBufferRange")
	glBindBufferRange           :: proc(target: GLuint, index: GLuint, buffer: Buffer, offset: int, size: int) ---
	@(link_name="GetUniformBlockIndex")
	glGetUniformBlockIndex      :: proc(program: Program, uniformBlockName: string) -> GLuint ---
	@(link_name="UniformBlockBinding")
	glUniformBlockBinding       :: proc(program: Program, uniformBlockIndex: GLuint, uniformBlockBinding: GLuint) ---
	
	@(link_name="CreateVertexArray")
	glCreateVertexArray :: proc() -> VertexArrayObject ---
	@(link_name="DeleteVertexArray")
	glDeleteVertexArray :: proc(vertexArray: VertexArrayObject) ---
	@(link_name="IsVertexArray")
	glIsVertexArray     :: proc(vertexArray: VertexArrayObject) -> bool ---
	@(link_name="BindVertexArray")
	glBindVertexArray   :: proc(vertexArray: VertexArrayObject) ---	

	@(link_name="UniformMatrix2x3fv")
	glUniformMatrix2x3fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="UniformMatrix2x4fv")
	glUniformMatrix2x4fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="UniformMatrix3x2fv")
	glUniformMatrix3x2fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="UniformMatrix3x4fv")
	glUniformMatrix3x4fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="UniformMatrix4x2fv")
	glUniformMatrix4x2fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="UniformMatrix4x3fv")
	glUniformMatrix4x3fv :: proc "contextless" (location: int, addr: [^]GLfloat) ---
	@(link_name="GetActiveUniformBlockName")
	glGetActiveUniformBlockName :: proc "contextless" (program: Program, uniformBlockIndex: int, buf: []byte, length: ^int) ---
}

// GetActiveUniformBlockName :: proc(program: Program, uniformBlockIndex: int, buf: []byte) -> string {
// 	n: int
// 	glGetActiveUniformBlockName(program, uniformBlockIndex, buf, &n)
// 	return string(buf[:n])	
// }


// Uniform1uiv :: proc "contextless" (location: int, v: GLuint) {
// 	glUniform1ui(location, v)
// }
// Uniform2uiv :: proc "contextless" (location: int, v: glm.uvec2) {
// 	glUniform2ui(location, v.x, v.y)
// }
// Uniform3uiv :: proc "contextless" (location: int, v: glm.uvec3) {
// 	glUniform3ui(location, v.x, v.y, v.z)
// }
// Uniform4uiv :: proc "contextless" (location: int, v: glm.uvec4) {
// 	glUniform4ui(location, v.x, v.y, v.z, v.w)
// }

// UniformMatrix3x2fv :: proc "contextless" (location: int, m: glm.mat3x2) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix3x2fv(location, &array[0])
// }
// UniformMatrix4x2fv :: proc "contextless" (location: int, m: glm.mat4x2) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix4x2fv(location, &array[0])
// }
// UniformMatrix2x3fv :: proc "contextless" (location: int, m: glm.mat2x3) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix2x3fv(location, &array[0])
// }
// UniformMatrix4x3fv :: proc "contextless" (location: int, m: glm.mat4x3) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix4x3fv(location, &array[0])
// }
// UniformMatrix2x4fv :: proc "contextless" (location: int, m: glm.mat2x4) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix2x4fv(location, &array[0])
// }
// UniformMatrix3x4fv :: proc "contextless" (location: int, m: glm.mat3x4) {
// 	array := intrinsics.matrix_flatten(m)
// 	glUniformMatrix3x4fv(location, &array[0])
// }

// VertexAttribI4iv :: proc "contextless" (index: int, v: glm.ivec4) {
// 	glVertexAttribI4i(index, v.x, v.y, v.z, v.w)
// }
// VertexAttribI4uiv :: proc "contextless" (index: int, v: glm.uvec4) {
// 	glVertexAttribI4ui(index, v.x, v.y, v.z, v.w)
// }