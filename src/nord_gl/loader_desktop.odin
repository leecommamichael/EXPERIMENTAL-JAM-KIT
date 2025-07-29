#+build !js
package nord_gl

NGL_DEBUG :: #config(NGL_DEBUG, ODIN_DEBUG)

import "base:runtime"
import "core:fmt"

loaded_up_to: [2]int
loaded_up_to_major := 0
loaded_up_to_minor := 0

Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring)

load_up_to :: proc(major, minor: int, set_proc_address: Set_Proc_Address_Type) {
	loaded_up_to = {0, 0}
	loaded_up_to[0] = major
	loaded_up_to[1] = minor
	loaded_up_to_major = major
	loaded_up_to_minor = minor

	switch major*10+minor {
	case 33: load_3_3(set_proc_address); fallthrough
	case 32: load_3_2(set_proc_address); fallthrough
	case 31: load_3_1(set_proc_address); fallthrough
	case 30: load_3_0(set_proc_address); fallthrough
	case 21: load_2_1(set_proc_address); fallthrough
	case 20: load_2_0(set_proc_address); fallthrough
	case 15: load_1_5(set_proc_address); fallthrough
	case 14: load_1_4(set_proc_address); fallthrough
	case 13: load_1_3(set_proc_address); fallthrough
	case 12: load_1_2(set_proc_address); fallthrough
	case 11: load_1_1(set_proc_address); fallthrough
	case 10: load_1_0(set_proc_address)
	}
}

/*
Type conversion overview:
	typedef unsigned int GLenum;     -> u32
	typedef unsigned char GLboolean; -> bool
	typedef unsigned int GLbitfield; -> u32
	typedef signed char GLbyte;      -> i8
	typedef short GLshort;           -> i16
	typedef int GLint;               -> i32
	typedef unsigned char GLubyte;   -> u8
	typedef unsigned short GLushort; -> u16
	typedef unsigned int GLuint;     -> u32
	typedef int GLsizei;             -> i32
	typedef float GLfloat;           -> f32
	typedef double GLdouble;         -> f64
	typedef char GLchar;             -> u8
	typedef ptrdiff_t GLintptr;      -> int
	typedef ptrdiff_t GLsizeiptr;    -> int
	typedef int64_t GLint64;         -> i64
	typedef uint64_t GLuint64;       -> u64

	void*                            -> rawptr
*/

sync_t :: distinct rawptr
// debug_proc_t :: #type proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr)


// VERSION_1_0
impl_CullFace:               proc "c" (mode: u32)
impl_FrontFace:              proc "c" (mode: u32)
impl_Hint:                   proc "c" (target: u32, mode: u32)
impl_LineWidth:              proc "c" (width: f32)
impl_PointSize:              proc "c" (size: f32)
impl_PolygonMode:            proc "c" (face: u32, mode: u32)
impl_Scissor:                proc "c" (x: i32, y: i32, width: i32, height: i32)
impl_TexParameterf:          proc "c" (target: u32, pname: u32, param: f32)
impl_TexParameterfv:         proc "c" (target: u32, pname: u32, params: [^]f32)
impl_TexParameteri:          proc "c" (target: u32, pname: u32, param: i32)
impl_TexParameteriv:         proc "c" (target: u32, pname: u32, params: [^]i32)
impl_TexImage1D:             proc "c" (target: u32, level: i32, internalformat: i32, width: i32, border: i32, format: u32, type: u32, pixels: rawptr)
impl_TexImage2D:             proc "c" (target: u32, level: i32, internalformat: i32, width: i32, height: i32, border: i32, format: u32, type: u32, pixels: rawptr)
impl_DrawBuffer:             proc "c" (buf: u32)
impl_Clear:                  proc "c" (mask: u32)
impl_ClearColor:             proc "c" (red: f32, green: f32, blue: f32, alpha: f32)
impl_ClearStencil:           proc "c" (s: i32)
impl_ClearDepth:             proc "c" (depth: f64)
impl_StencilMask:            proc "c" (mask: u32)
impl_ColorMask:              proc "c" (red: bool, green: bool, blue: bool, alpha: bool)
impl_DepthMask:              proc "c" (flag: bool)
impl_Disable:                proc "c" (cap: u32)
impl_Enable:                 proc "c" (cap: u32)
impl_Finish:                 proc "c" ()
impl_Flush:                  proc "c" ()
impl_BlendFunc:              proc "c" (sfactor: u32, dfactor: u32)
impl_LogicOp:                proc "c" (opcode: u32)
impl_StencilFunc:            proc "c" (func: u32, ref: i32, mask: u32)
impl_StencilOp:              proc "c" (fail: u32, zfail: u32, zpass: u32)
impl_DepthFunc:              proc "c" (func: u32)
impl_PixelStoref:            proc "c" (pname: u32, param: f32)
impl_PixelStorei:            proc "c" (pname: u32, param: i32)
impl_ReadBuffer:             proc "c" (src: u32)
impl_ReadPixels:             proc "c" (x: i32, y: i32, width: i32, height: i32, format: u32, type: u32, pixels: rawptr)
impl_GetBooleanv:            proc "c" (pname: u32, data: ^bool)
impl_GetDoublev:             proc "c" (pname: u32, data: ^f64)
impl_GetError:               proc "c" () -> u32
impl_GetFloatv:              proc "c" (pname: u32, data: ^f32)
impl_GetIntegerv:            proc "c" (pname: u32, data: ^i32)
impl_GetString:              proc "c" (name: u32) -> cstring
impl_GetTexImage:            proc "c" (target: u32,  level: i32, format: u32, type: u32, pixels: rawptr)
impl_GetTexParameterfv:      proc "c" (target: u32, pname: u32, params: [^]f32)
impl_GetTexParameteriv:      proc "c" (target: u32, pname: u32, params: [^]i32)
impl_GetTexLevelParameterfv: proc "c" (target: u32, level: i32, pname: u32, params: [^]f32)
impl_GetTexLevelParameteriv: proc "c" (target: u32, level: i32, pname: u32, params: [^]i32)
impl_IsEnabled:              proc "c" (cap: u32) -> bool
impl_DepthRange:             proc "c" (near: f64, far: f64)
impl_Viewport:               proc "c" (x: i32, y: i32, width: i32, height: i32)

load_1_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_CullFace,               "glCullFace")
	set_proc_address(&impl_FrontFace,              "glFrontFace")
	set_proc_address(&impl_Hint,                   "glHint")
	set_proc_address(&impl_LineWidth,              "glLineWidth")
	set_proc_address(&impl_PointSize,              "glPointSize")
	set_proc_address(&impl_PolygonMode,            "glPolygonMode")
	set_proc_address(&impl_Scissor,                "glScissor")
	set_proc_address(&impl_TexParameterf,          "glTexParameterf")
	set_proc_address(&impl_TexParameterfv,         "glTexParameterfv")
	set_proc_address(&impl_TexParameteri,          "glTexParameteri")
	set_proc_address(&impl_TexParameteriv,         "glTexParameteriv")
	set_proc_address(&impl_TexImage1D,             "glTexImage1D")
	set_proc_address(&impl_TexImage2D,             "glTexImage2D")
	set_proc_address(&impl_DrawBuffer,             "glDrawBuffer")
	set_proc_address(&impl_Clear,                  "glClear")
	set_proc_address(&impl_ClearColor,             "glClearColor")
	set_proc_address(&impl_ClearStencil,           "glClearStencil")
	set_proc_address(&impl_ClearDepth,             "glClearDepth")
	set_proc_address(&impl_StencilMask,            "glStencilMask")
	set_proc_address(&impl_ColorMask,              "glColorMask")
	set_proc_address(&impl_DepthMask,              "glDepthMask")
	set_proc_address(&impl_Disable,                "glDisable")
	set_proc_address(&impl_Enable,                 "glEnable")
	set_proc_address(&impl_Finish,                 "glFinish")
	set_proc_address(&impl_Flush,                  "glFlush")
	set_proc_address(&impl_BlendFunc,              "glBlendFunc")
	set_proc_address(&impl_LogicOp,                "glLogicOp")
	set_proc_address(&impl_StencilFunc,            "glStencilFunc")
	set_proc_address(&impl_StencilOp,              "glStencilOp")
	set_proc_address(&impl_DepthFunc,              "glDepthFunc")
	set_proc_address(&impl_PixelStoref,            "glPixelStoref")
	set_proc_address(&impl_PixelStorei,            "glPixelStorei")
	set_proc_address(&impl_ReadBuffer,             "glReadBuffer")
	set_proc_address(&impl_ReadPixels,             "glReadPixels")
	set_proc_address(&impl_GetBooleanv,            "glGetBooleanv")
	set_proc_address(&impl_GetDoublev,             "glGetDoublev")
	set_proc_address(&impl_GetError,               "glGetError")
	set_proc_address(&impl_GetFloatv,              "glGetFloatv")
	set_proc_address(&impl_GetIntegerv,            "glGetIntegerv")
	set_proc_address(&impl_GetString,              "glGetString")
	set_proc_address(&impl_GetTexImage,            "glGetTexImage")
	set_proc_address(&impl_GetTexParameterfv,      "glGetTexParameterfv")
	set_proc_address(&impl_GetTexParameteriv,      "glGetTexParameteriv")
	set_proc_address(&impl_GetTexLevelParameterfv, "glGetTexLevelParameterfv")
	set_proc_address(&impl_GetTexLevelParameteriv, "glGetTexLevelParameteriv")
	set_proc_address(&impl_IsEnabled,              "glIsEnabled")
	set_proc_address(&impl_DepthRange,             "glDepthRange")
	set_proc_address(&impl_Viewport,               "glViewport")
}


// VERSION_1_1
impl_DrawArrays:        proc "c" (mode: u32, first: i32, count: i32)
impl_DrawElements:      proc "c" (mode: u32, count: i32, type: u32, indices: rawptr)
impl_PolygonOffset:     proc "c" (factor: f32, units: f32)
impl_CopyTexImage1D:    proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, border: i32)
impl_CopyTexImage2D:    proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, height: i32, border: i32)
impl_CopyTexSubImage1D: proc "c" (target: u32, level: i32, xoffset: i32, x: i32, y: i32, width: i32)
impl_CopyTexSubImage2D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, x: i32, y: i32, width: i32, height: i32)
impl_TexSubImage1D:     proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, type: u32, pixels: rawptr)
impl_TexSubImage2D:     proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type: u32, pixels: rawptr)
impl_BindTexture:       proc "c" (target: u32, texture: u32)
impl_DeleteTextures:    proc "c" (n: i32, textures: [^]u32)
impl_GenTextures:       proc "c" (n: i32, textures: [^]u32)
impl_IsTexture:         proc "c" (texture: u32) -> bool

load_1_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_DrawArrays,        "glDrawArrays")
	set_proc_address(&impl_DrawElements,      "glDrawElements")
	set_proc_address(&impl_PolygonOffset,     "glPolygonOffset")
	set_proc_address(&impl_CopyTexImage1D,    "glCopyTexImage1D")
	set_proc_address(&impl_CopyTexImage2D,    "glCopyTexImage2D")
	set_proc_address(&impl_CopyTexSubImage1D, "glCopyTexSubImage1D")
	set_proc_address(&impl_CopyTexSubImage2D, "glCopyTexSubImage2D")
	set_proc_address(&impl_TexSubImage1D,     "glTexSubImage1D")
	set_proc_address(&impl_TexSubImage2D,     "glTexSubImage2D")
	set_proc_address(&impl_BindTexture,       "glBindTexture")
	set_proc_address(&impl_DeleteTextures,    "glDeleteTextures")
	set_proc_address(&impl_GenTextures,       "glGenTextures")
	set_proc_address(&impl_IsTexture,         "glIsTexture")
}


// VERSION_1_2
impl_DrawRangeElements: proc "c" (mode: u32, start: u32, end: u32, count: i32, type: u32, indices: rawptr)
impl_TexImage3D:        proc "c" (target: u32, level: i32, internalformat: i32, width: i32, height: i32, depth: i32, border: i32, format: u32, type: u32, data: rawptr)
impl_TexSubImage3D:     proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, type: u32, pixels: rawptr)
impl_CopyTexSubImage3D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, x: i32, y: i32, width: i32, height: i32)

load_1_2 :: proc(set_proc_address: Set_Proc_Address_Type) {

	set_proc_address(&impl_DrawRangeElements, "glDrawRangeElements")
	set_proc_address(&impl_TexImage3D,        "glTexImage3D")
	set_proc_address(&impl_TexSubImage3D,     "glTexSubImage3D")
	set_proc_address(&impl_CopyTexSubImage3D, "glCopyTexSubImage3D")
}


// VERSION_1_3
impl_ActiveTexture:           proc "c" (texture: u32)
impl_SampleCoverage:          proc "c" (value: f32, invert: bool)
impl_CompressedTexImage3D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, depth: i32, border: i32, imageSize: i32, data: rawptr)
impl_CompressedTexImage2D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, border: i32, imageSize: i32, data: rawptr)
impl_CompressedTexImage1D:    proc "c" (target: u32, level: i32, internalformat: u32, width: i32, border: i32, imageSize: i32, data: rawptr)
impl_CompressedTexSubImage3D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, imageSize: i32, data: rawptr)
impl_CompressedTexSubImage2D: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, imageSize: i32, data: rawptr)
impl_CompressedTexSubImage1D: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, imageSize: i32, data: rawptr)
impl_GetCompressedTexImage:   proc "c" (target: u32, level: i32, img: rawptr)

load_1_3 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_ActiveTexture,           "glActiveTexture")
	set_proc_address(&impl_SampleCoverage,          "glSampleCoverage")
	set_proc_address(&impl_CompressedTexImage3D,    "glCompressedTexImage3D")
	set_proc_address(&impl_CompressedTexImage2D,    "glCompressedTexImage2D")
	set_proc_address(&impl_CompressedTexImage1D,    "glCompressedTexImage1D")
	set_proc_address(&impl_CompressedTexSubImage3D, "glCompressedTexSubImage3D")
	set_proc_address(&impl_CompressedTexSubImage2D, "glCompressedTexSubImage2D")
	set_proc_address(&impl_CompressedTexSubImage1D, "glCompressedTexSubImage1D")
	set_proc_address(&impl_GetCompressedTexImage,   "glGetCompressedTexImage")
}


// VERSION_1_4
impl_BlendFuncSeparate: proc "c" (sfactorRGB: u32, dfactorRGB: u32, sfactorAlpha: u32, dfactorAlpha: u32)
impl_MultiDrawArrays:   proc "c" (mode: u32, first: [^]i32, count: [^]i32, drawcount: i32)
impl_MultiDrawElements: proc "c" (mode: u32, count: [^]i32, type: u32, indices: [^]rawptr, drawcount: i32)
impl_PointParameterf:   proc "c" (pname: u32, param: f32)
impl_PointParameterfv:  proc "c" (pname: u32, params: [^]f32)
impl_PointParameteri:   proc "c" (pname: u32, param: i32)
impl_PointParameteriv:  proc "c" (pname: u32, params: [^]i32)
impl_BlendColor:        proc "c" (red: f32, green: f32, blue: f32, alpha: f32)
impl_BlendEquation:     proc "c" (mode: u32)


load_1_4 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_BlendFuncSeparate, "glBlendFuncSeparate")
	set_proc_address(&impl_MultiDrawArrays,   "glMultiDrawArrays")
	set_proc_address(&impl_MultiDrawElements, "glMultiDrawElements")
	set_proc_address(&impl_PointParameterf,   "glPointParameterf")
	set_proc_address(&impl_PointParameterfv,  "glPointParameterfv")
	set_proc_address(&impl_PointParameteri,   "glPointParameteri")
	set_proc_address(&impl_PointParameteriv,  "glPointParameteriv")
	set_proc_address(&impl_BlendColor,        "glBlendColor")
	set_proc_address(&impl_BlendEquation,     "glBlendEquation")
}


// VERSION_1_5
impl_GenQueries:           proc "c" (n: i32, ids: [^]u32)
impl_DeleteQueries:        proc "c" (n: i32, ids: [^]u32)
impl_IsQuery:              proc "c" (id: u32) -> bool
impl_BeginQuery:           proc "c" (target: u32, id: u32)
impl_EndQuery:             proc "c" (target: u32)
impl_GetQueryiv:           proc "c" (target: u32, pname: u32, params: [^]i32)
impl_GetQueryObjectiv:     proc "c" (id: u32, pname: u32, params: [^]i32)
impl_GetQueryObjectuiv:    proc "c" (id: u32, pname: u32, params: [^]u32)
impl_BindBuffer:           proc "c" (target: u32, buffer: u32)
impl_DeleteBuffers:        proc "c" (n: i32, buffers: [^]u32)
impl_GenBuffers:           proc "c" (n: i32, buffers: [^]u32)
impl_IsBuffer:             proc "c" (buffer: u32) -> bool
impl_BufferData:           proc "c" (target: u32, size: int, data: rawptr, usage: u32)
impl_BufferSubData:        proc "c" (target: u32, offset: int, size: int, data: rawptr)
impl_GetBufferSubData:     proc "c" (target: u32, offset: int, size: int, data: rawptr)
impl_MapBuffer:            proc "c" (target: u32, access: u32) -> rawptr
impl_UnmapBuffer:          proc "c" (target: u32) -> bool
impl_GetBufferParameteriv: proc "c" (target: u32, pname: u32, params: [^]i32)
impl_GetBufferPointerv:    proc "c" (target: u32, pname: u32, params: [^]rawptr)

load_1_5 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_GenQueries,           "glGenQueries")
	set_proc_address(&impl_DeleteQueries,        "glDeleteQueries")
	set_proc_address(&impl_IsQuery,              "glIsQuery")
	set_proc_address(&impl_BeginQuery,           "glBeginQuery")
	set_proc_address(&impl_EndQuery,             "glEndQuery")
	set_proc_address(&impl_GetQueryiv,           "glGetQueryiv")
	set_proc_address(&impl_GetQueryObjectiv,     "glGetQueryObjectiv")
	set_proc_address(&impl_GetQueryObjectuiv,    "glGetQueryObjectuiv")
	set_proc_address(&impl_BindBuffer,           "glBindBuffer")
	set_proc_address(&impl_DeleteBuffers,        "glDeleteBuffers")
	set_proc_address(&impl_GenBuffers,           "glGenBuffers")
	set_proc_address(&impl_IsBuffer,             "glIsBuffer")
	set_proc_address(&impl_BufferData,           "glBufferData")
	set_proc_address(&impl_BufferSubData,        "glBufferSubData")
	set_proc_address(&impl_GetBufferSubData,     "glGetBufferSubData")
	set_proc_address(&impl_MapBuffer,            "glMapBuffer")
	set_proc_address(&impl_UnmapBuffer,          "glUnmapBuffer")
	set_proc_address(&impl_GetBufferParameteriv, "glGetBufferParameteriv")
	set_proc_address(&impl_GetBufferPointerv,    "glGetBufferPointerv")
}


// VERSION_2_0
impl_BlendEquationSeparate:    proc "c" (modeRGB: u32, modeAlpha: u32)
impl_DrawBuffers:              proc "c" (n: i32, bufs: [^]u32)
impl_StencilOpSeparate:        proc "c" (face: u32, sfail: u32, dpfail: u32, dppass: u32)
impl_StencilFuncSeparate:      proc "c" (face: u32, func: u32, ref: i32, mask: u32)
impl_StencilMaskSeparate:      proc "c" (face: u32, mask: u32)
impl_AttachShader:             proc "c" (program: u32, shader: u32)
impl_BindAttribLocation:       proc "c" (program: u32, index: u32, name: cstring)
impl_CompileShader:            proc "c" (shader: u32)
impl_CreateProgram:            proc "c" () -> u32
impl_CreateShader:             proc "c" (type: u32) -> u32
impl_DeleteProgram:            proc "c" (program: u32)
impl_DeleteShader:             proc "c" (shader: u32)
impl_DetachShader:             proc "c" (program: u32, shader: u32)
impl_DisableVertexAttribArray: proc "c" (index: u32)
impl_EnableVertexAttribArray:  proc "c" (index: u32)
impl_GetActiveAttrib:          proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)
impl_GetActiveUniform:         proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)
impl_GetAttachedShaders:       proc "c" (program: u32, maxCount: i32, count: ^i32, shaders: ^u32)
impl_GetAttribLocation:        proc "c" (program: u32, name: cstring) -> i32
impl_GetProgramiv:             proc "c" (program: u32, pname: u32, params: [^]i32)
impl_GetProgramInfoLog:        proc "c" (program: u32, bufSize: i32, length: ^i32, infoLog: [^]u8)
impl_GetShaderiv:              proc "c" (shader: u32, pname: u32, params: [^]i32)
impl_GetShaderInfoLog:         proc "c" (shader: u32, bufSize: i32, length: ^i32, infoLog: [^]u8)
impl_GetShaderSource:          proc "c" (shader: u32, bufSize: i32, length: ^i32, source: [^]u8)
impl_GetUniformLocation:       proc "c" (program: u32, name: cstring) -> i32
impl_GetUniformfv:             proc "c" (program: u32, location: i32, params: [^]f32)
impl_GetUniformiv:             proc "c" (program: u32, location: i32, params: [^]i32)
impl_GetVertexAttribdv:        proc "c" (index: u32, pname: u32, params: [^]f64)
impl_GetVertexAttribfv:        proc "c" (index: u32, pname: u32, params: [^]f32)
impl_GetVertexAttribiv:        proc "c" (index: u32, pname: u32, params: [^]i32)
impl_GetVertexAttribPointerv:  proc "c" (index: u32, pname: u32, pointer: ^uintptr)
impl_IsProgram:                proc "c" (program: u32) -> bool
impl_IsShader:                 proc "c" (shader: u32) -> bool
impl_LinkProgram:              proc "c" (program: u32)
impl_ShaderSource:             proc "c" (shader: u32, count: i32, string: [^]cstring, length: [^]i32)
impl_UseProgram:               proc "c" (program: u32)
impl_Uniform1f:                proc "c" (location: i32, v0: f32)
impl_Uniform2f:                proc "c" (location: i32, v0: f32, v1: f32)
impl_Uniform3f:                proc "c" (location: i32, v0: f32, v1: f32, v2: f32)
impl_Uniform4f:                proc "c" (location: i32, v0: f32, v1: f32, v2: f32, v3: f32)
impl_Uniform1i:                proc "c" (location: i32, v0: i32)
impl_Uniform2i:                proc "c" (location: i32, v0: i32, v1: i32)
impl_Uniform3i:                proc "c" (location: i32, v0: i32, v1: i32, v2: i32)
impl_Uniform4i:                proc "c" (location: i32, v0: i32, v1: i32, v2: i32, v3: i32)
impl_Uniform1fv:               proc "c" (location: i32, count: i32, value: [^]f32)
impl_Uniform2fv:               proc "c" (location: i32, count: i32, value: [^]f32)
impl_Uniform3fv:               proc "c" (location: i32, count: i32, value: [^]f32)
impl_Uniform4fv:               proc "c" (location: i32, count: i32, value: [^]f32)
impl_Uniform1iv:               proc "c" (location: i32, count: i32, value: [^]i32)
impl_Uniform2iv:               proc "c" (location: i32, count: i32, value: [^]i32)
impl_Uniform3iv:               proc "c" (location: i32, count: i32, value: [^]i32)
impl_Uniform4iv:               proc "c" (location: i32, count: i32, value: [^]i32)
impl_UniformMatrix2fv:         proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix3fv:         proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix4fv:         proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_ValidateProgram:          proc "c" (program: u32)
impl_VertexAttrib1d:           proc "c" (index: u32, x: f64)
impl_VertexAttrib1dv:          proc "c" (index: u32, v: ^f64)
impl_VertexAttrib1f:           proc "c" (index: u32, x: f32)
impl_VertexAttrib1fv:          proc "c" (index: u32, v: ^f32)
impl_VertexAttrib1s:           proc "c" (index: u32, x: i16)
impl_VertexAttrib1sv:          proc "c" (index: u32, v: ^i16)
impl_VertexAttrib2d:           proc "c" (index: u32, x: f64, y: f64)
impl_VertexAttrib2dv:          proc "c" (index: u32, v: ^[2]f64)
impl_VertexAttrib2f:           proc "c" (index: u32, x: f32, y: f32)
impl_VertexAttrib2fv:          proc "c" (index: u32, v: ^[2]f32)
impl_VertexAttrib2s:           proc "c" (index: u32, x: i16, y: i16)
impl_VertexAttrib2sv:          proc "c" (index: u32, v: ^[2]i16)
impl_VertexAttrib3d:           proc "c" (index: u32, x: f64, y: f64, z: f64)
impl_VertexAttrib3dv:          proc "c" (index: u32, v: ^[3]f64)
impl_VertexAttrib3f:           proc "c" (index: u32, x: f32, y: f32, z: f32)
impl_VertexAttrib3fv:          proc "c" (index: u32, v: ^[3]f32)
impl_VertexAttrib3s:           proc "c" (index: u32, x: i16, y: i16, z: i16)
impl_VertexAttrib3sv:          proc "c" (index: u32, v: ^[3]i16)
impl_VertexAttrib4Nbv:         proc "c" (index: u32, v: ^[4]i8)
impl_VertexAttrib4Niv:         proc "c" (index: u32, v: ^[4]i32)
impl_VertexAttrib4Nsv:         proc "c" (index: u32, v: ^[4]i16)
impl_VertexAttrib4Nub:         proc "c" (index: u32, x: u8, y: u8, z: u8, w: u8)
impl_VertexAttrib4Nubv:        proc "c" (index: u32, v: ^[4]u8)
impl_VertexAttrib4Nuiv:        proc "c" (index: u32, v: ^[4]u32)
impl_VertexAttrib4Nusv:        proc "c" (index: u32, v: ^[4]u16)
impl_VertexAttrib4bv:          proc "c" (index: u32, v: ^[4]i8)
impl_VertexAttrib4d:           proc "c" (index: u32, x: f64, y: f64, z: f64, w: f64)
impl_VertexAttrib4dv:          proc "c" (index: u32, v: ^[4]f64)
impl_VertexAttrib4f:           proc "c" (index: u32, x: f32, y: f32, z: f32, w: f32)
impl_VertexAttrib4fv:          proc "c" (index: u32, v: ^[4]f32)
impl_VertexAttrib4iv:          proc "c" (index: u32, v: ^[4]i32)
impl_VertexAttrib4s:           proc "c" (index: u32, x: i16, y: i16, z: i16, w: i16)
impl_VertexAttrib4sv:          proc "c" (index: u32, v: ^[4]i16)
impl_VertexAttrib4ubv:         proc "c" (index: u32, v: ^[4]u8)
impl_VertexAttrib4uiv:         proc "c" (index: u32, v: ^[4]u32)
impl_VertexAttrib4usv:         proc "c" (index: u32, v: ^[4]u16)
impl_VertexAttribPointer:      proc "c" (index: u32, size: i32, type: u32, normalized: bool, stride: i32, pointer: uintptr)

load_2_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_BlendEquationSeparate,    "glBlendEquationSeparate")
	set_proc_address(&impl_DrawBuffers,              "glDrawBuffers")
	set_proc_address(&impl_StencilOpSeparate,        "glStencilOpSeparate")
	set_proc_address(&impl_StencilFuncSeparate,      "glStencilFuncSeparate")
	set_proc_address(&impl_StencilMaskSeparate,      "glStencilMaskSeparate")
	set_proc_address(&impl_AttachShader,             "glAttachShader")
	set_proc_address(&impl_BindAttribLocation,       "glBindAttribLocation")
	set_proc_address(&impl_CompileShader,            "glCompileShader")
	set_proc_address(&impl_CreateProgram,            "glCreateProgram")
	set_proc_address(&impl_CreateShader,             "glCreateShader")
	set_proc_address(&impl_DeleteProgram,            "glDeleteProgram")
	set_proc_address(&impl_DeleteShader,             "glDeleteShader")
	set_proc_address(&impl_DetachShader,             "glDetachShader")
	set_proc_address(&impl_DisableVertexAttribArray, "glDisableVertexAttribArray")
	set_proc_address(&impl_EnableVertexAttribArray,  "glEnableVertexAttribArray")
	set_proc_address(&impl_GetActiveAttrib,          "glGetActiveAttrib")
	set_proc_address(&impl_GetActiveUniform,         "glGetActiveUniform")
	set_proc_address(&impl_GetAttachedShaders,       "glGetAttachedShaders")
	set_proc_address(&impl_GetAttribLocation,        "glGetAttribLocation")
	set_proc_address(&impl_GetProgramiv,             "glGetProgramiv")
	set_proc_address(&impl_GetProgramInfoLog,        "glGetProgramInfoLog")
	set_proc_address(&impl_GetShaderiv,              "glGetShaderiv")
	set_proc_address(&impl_GetShaderInfoLog,         "glGetShaderInfoLog")
	set_proc_address(&impl_GetShaderSource,          "glGetShaderSource")
	set_proc_address(&impl_GetUniformLocation,       "glGetUniformLocation")
	set_proc_address(&impl_GetUniformfv,             "glGetUniformfv")
	set_proc_address(&impl_GetUniformiv,             "glGetUniformiv")
	set_proc_address(&impl_GetVertexAttribdv,        "glGetVertexAttribdv")
	set_proc_address(&impl_GetVertexAttribfv,        "glGetVertexAttribfv")
	set_proc_address(&impl_GetVertexAttribiv,        "glGetVertexAttribiv")
	set_proc_address(&impl_GetVertexAttribPointerv,  "glGetVertexAttribPointerv")
	set_proc_address(&impl_IsProgram,                "glIsProgram")
	set_proc_address(&impl_IsShader,                 "glIsShader")
	set_proc_address(&impl_LinkProgram,              "glLinkProgram")
	set_proc_address(&impl_ShaderSource,             "glShaderSource")
	set_proc_address(&impl_UseProgram,               "glUseProgram")
	set_proc_address(&impl_Uniform1f,                "glUniform1f")
	set_proc_address(&impl_Uniform2f,                "glUniform2f")
	set_proc_address(&impl_Uniform3f,                "glUniform3f")
	set_proc_address(&impl_Uniform4f,                "glUniform4f")
	set_proc_address(&impl_Uniform1i,                "glUniform1i")
	set_proc_address(&impl_Uniform2i,                "glUniform2i")
	set_proc_address(&impl_Uniform3i,                "glUniform3i")
	set_proc_address(&impl_Uniform4i,                "glUniform4i")
	set_proc_address(&impl_Uniform1fv,               "glUniform1fv")
	set_proc_address(&impl_Uniform2fv,               "glUniform2fv")
	set_proc_address(&impl_Uniform3fv,               "glUniform3fv")
	set_proc_address(&impl_Uniform4fv,               "glUniform4fv")
	set_proc_address(&impl_Uniform1iv,               "glUniform1iv")
	set_proc_address(&impl_Uniform2iv,               "glUniform2iv")
	set_proc_address(&impl_Uniform3iv,               "glUniform3iv")
	set_proc_address(&impl_Uniform4iv,               "glUniform4iv")
	set_proc_address(&impl_UniformMatrix2fv,         "glUniformMatrix2fv")
	set_proc_address(&impl_UniformMatrix3fv,         "glUniformMatrix3fv")
	set_proc_address(&impl_UniformMatrix4fv,         "glUniformMatrix4fv")
	set_proc_address(&impl_ValidateProgram,          "glValidateProgram")
	set_proc_address(&impl_VertexAttrib1d,           "glVertexAttrib1d")
	set_proc_address(&impl_VertexAttrib1dv,          "glVertexAttrib1dv")
	set_proc_address(&impl_VertexAttrib1f,           "glVertexAttrib1f")
	set_proc_address(&impl_VertexAttrib1fv,          "glVertexAttrib1fv")
	set_proc_address(&impl_VertexAttrib1s,           "glVertexAttrib1s")
	set_proc_address(&impl_VertexAttrib1sv,          "glVertexAttrib1sv")
	set_proc_address(&impl_VertexAttrib2d,           "glVertexAttrib2d")
	set_proc_address(&impl_VertexAttrib2dv,          "glVertexAttrib2dv")
	set_proc_address(&impl_VertexAttrib2f,           "glVertexAttrib2f")
	set_proc_address(&impl_VertexAttrib2fv,          "glVertexAttrib2fv")
	set_proc_address(&impl_VertexAttrib2s,           "glVertexAttrib2s")
	set_proc_address(&impl_VertexAttrib2sv,          "glVertexAttrib2sv")
	set_proc_address(&impl_VertexAttrib3d,           "glVertexAttrib3d")
	set_proc_address(&impl_VertexAttrib3dv,          "glVertexAttrib3dv")
	set_proc_address(&impl_VertexAttrib3f,           "glVertexAttrib3f")
	set_proc_address(&impl_VertexAttrib3fv,          "glVertexAttrib3fv")
	set_proc_address(&impl_VertexAttrib3s,           "glVertexAttrib3s")
	set_proc_address(&impl_VertexAttrib3sv,          "glVertexAttrib3sv")
	set_proc_address(&impl_VertexAttrib4Nbv,         "glVertexAttrib4Nbv")
	set_proc_address(&impl_VertexAttrib4Niv,         "glVertexAttrib4Niv")
	set_proc_address(&impl_VertexAttrib4Nsv,         "glVertexAttrib4Nsv")
	set_proc_address(&impl_VertexAttrib4Nub,         "glVertexAttrib4Nub")
	set_proc_address(&impl_VertexAttrib4Nubv,        "glVertexAttrib4Nubv")
	set_proc_address(&impl_VertexAttrib4Nuiv,        "glVertexAttrib4Nuiv")
	set_proc_address(&impl_VertexAttrib4Nusv,        "glVertexAttrib4Nusv")
	set_proc_address(&impl_VertexAttrib4bv,          "glVertexAttrib4bv")
	set_proc_address(&impl_VertexAttrib4d,           "glVertexAttrib4d")
	set_proc_address(&impl_VertexAttrib4dv,          "glVertexAttrib4dv")
	set_proc_address(&impl_VertexAttrib4f,           "glVertexAttrib4f")
	set_proc_address(&impl_VertexAttrib4fv,          "glVertexAttrib4fv")
	set_proc_address(&impl_VertexAttrib4iv,          "glVertexAttrib4iv")
	set_proc_address(&impl_VertexAttrib4s,           "glVertexAttrib4s")
	set_proc_address(&impl_VertexAttrib4sv,          "glVertexAttrib4sv")
	set_proc_address(&impl_VertexAttrib4ubv,         "glVertexAttrib4ubv")
	set_proc_address(&impl_VertexAttrib4uiv,         "glVertexAttrib4uiv")
	set_proc_address(&impl_VertexAttrib4usv,         "glVertexAttrib4usv")
	set_proc_address(&impl_VertexAttribPointer,      "glVertexAttribPointer")
}


// VERSION_2_1
impl_UniformMatrix2x3fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix3x2fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix2x4fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix4x2fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix3x4fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)
impl_UniformMatrix4x3fv: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)

load_2_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_UniformMatrix2x3fv, "glUniformMatrix2x3fv")
	set_proc_address(&impl_UniformMatrix3x2fv, "glUniformMatrix3x2fv")
	set_proc_address(&impl_UniformMatrix2x4fv, "glUniformMatrix2x4fv")
	set_proc_address(&impl_UniformMatrix4x2fv, "glUniformMatrix4x2fv")
	set_proc_address(&impl_UniformMatrix3x4fv, "glUniformMatrix3x4fv")
	set_proc_address(&impl_UniformMatrix4x3fv, "glUniformMatrix4x3fv")
}


// VERSION_3_0
impl_ColorMaski:                          proc "c" (index: u32, r: bool, g: bool, b: bool, a: bool)
impl_GetBooleani_v:                       proc "c" (target: u32, index: u32, data: ^bool)
impl_GetIntegeri_v:                       proc "c" (target: u32, index: u32, data: ^i32)
impl_Enablei:                             proc "c" (target: u32, index: u32)
impl_Disablei:                            proc "c" (target: u32, index: u32)
impl_IsEnabledi:                          proc "c" (target: u32, index: u32) -> bool
impl_BeginTransformFeedback:              proc "c" (primitiveMode: u32)
impl_EndTransformFeedback:                proc "c" ()
impl_BindBufferRange:                     proc "c" (target: u32, index: u32, buffer: u32, offset: int, size: int)
impl_BindBufferBase:                      proc "c" (target: u32, index: u32, buffer: u32)
impl_TransformFeedbackVaryings:           proc "c" (program: u32, count: i32, varyings: [^]cstring, bufferMode: u32)
impl_GetTransformFeedbackVarying:         proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)
impl_ClampColor:                          proc "c" (target: u32, clamp: u32)
impl_BeginConditionalRender:              proc "c" (id: u32, mode: u32)
impl_EndConditionalRender:                proc "c" ()
impl_VertexAttribIPointer:                proc "c" (index: u32, size: i32, type: u32, stride: i32, pointer: uintptr)
impl_GetVertexAttribIiv:                  proc "c" (index: u32, pname: u32, params: [^]i32)
impl_GetVertexAttribIuiv:                 proc "c" (index: u32, pname: u32, params: [^]u32)
impl_VertexAttribI1i:                     proc "c" (index: u32, x: i32)
impl_VertexAttribI2i:                     proc "c" (index: u32, x: i32, y: i32)
impl_VertexAttribI3i:                     proc "c" (index: u32, x: i32, y: i32, z: i32)
impl_VertexAttribI4i:                     proc "c" (index: u32, x: i32, y: i32, z: i32, w: i32)
impl_VertexAttribI1ui:                    proc "c" (index: u32, x: u32)
impl_VertexAttribI2ui:                    proc "c" (index: u32, x: u32, y: u32)
impl_VertexAttribI3ui:                    proc "c" (index: u32, x: u32, y: u32, z: u32)
impl_VertexAttribI4ui:                    proc "c" (index: u32, x: u32, y: u32, z: u32, w: u32)
impl_VertexAttribI1iv:                    proc "c" (index: u32, v: [^]i32)
impl_VertexAttribI2iv:                    proc "c" (index: u32, v: [^]i32)
impl_VertexAttribI3iv:                    proc "c" (index: u32, v: [^]i32)
impl_VertexAttribI4iv:                    proc "c" (index: u32, v: [^]i32)
impl_VertexAttribI1uiv:                   proc "c" (index: u32, v: [^]u32)
impl_VertexAttribI2uiv:                   proc "c" (index: u32, v: [^]u32)
impl_VertexAttribI3uiv:                   proc "c" (index: u32, v: [^]u32)
impl_VertexAttribI4uiv:                   proc "c" (index: u32, v: [^]u32)
impl_VertexAttribI4bv:                    proc "c" (index: u32, v: [^]i8)
impl_VertexAttribI4sv:                    proc "c" (index: u32, v: [^]i16)
impl_VertexAttribI4ubv:                   proc "c" (index: u32, v: [^]u8)
impl_VertexAttribI4usv:                   proc "c" (index: u32, v: [^]u16)
impl_GetUniformuiv:                       proc "c" (program: u32, location: i32, params: [^]u32)
impl_BindFragDataLocation:                proc "c" (program: u32, color: u32, name: cstring)
impl_GetFragDataLocation:                 proc "c" (program: u32, name: cstring) -> i32
impl_Uniform1ui:                          proc "c" (location: i32, v0: u32)
impl_Uniform2ui:                          proc "c" (location: i32, v0: u32, v1: u32)
impl_Uniform3ui:                          proc "c" (location: i32, v0: u32, v1: u32, v2: u32)
impl_Uniform4ui:                          proc "c" (location: i32, v0: u32, v1: u32, v2: u32, v3: u32)
impl_Uniform1uiv:                         proc "c" (location: i32, count: i32, value: [^]u32)
impl_Uniform2uiv:                         proc "c" (location: i32, count: i32, value: [^]u32)
impl_Uniform3uiv:                         proc "c" (location: i32, count: i32, value: [^]u32)
impl_Uniform4uiv:                         proc "c" (location: i32, count: i32, value: [^]u32)
impl_TexParameterIiv:                     proc "c" (target: u32, pname: u32, params: [^]i32)
impl_TexParameterIuiv:                    proc "c" (target: u32, pname: u32, params: [^]u32)
impl_GetTexParameterIiv:                  proc "c" (target: u32, pname: u32, params: [^]i32)
impl_GetTexParameterIuiv:                 proc "c" (target: u32, pname: u32, params: [^]u32)
impl_ClearBufferiv:                       proc "c" (buffer: u32, drawbuffer: i32, value: ^i32)
impl_ClearBufferuiv:                      proc "c" (buffer: u32, drawbuffer: i32, value: ^u32)
impl_ClearBufferfv:                       proc "c" (buffer: u32, drawbuffer: i32, value: ^f32)
impl_ClearBufferfi:                       proc "c" (buffer: u32, drawbuffer: i32, depth: f32, stencil: i32) -> rawptr
impl_GetStringi:                          proc "c" (name: u32, index: u32) -> cstring
impl_IsRenderbuffer:                      proc "c" (renderbuffer: u32) -> bool
impl_BindRenderbuffer:                    proc "c" (target: u32, renderbuffer: u32)
impl_DeleteRenderbuffers:                 proc "c" (n: i32, renderbuffers: [^]u32)
impl_GenRenderbuffers:                    proc "c" (n: i32, renderbuffers: [^]u32)
impl_RenderbufferStorage:                 proc "c" (target: u32, internalformat: u32, width: i32, height: i32)
impl_GetRenderbufferParameteriv:          proc "c" (target: u32, pname: u32, params: [^]i32)
impl_IsFramebuffer:                       proc "c" (framebuffer: u32) -> bool
impl_BindFramebuffer:                     proc "c" (target: u32, framebuffer: u32)
impl_DeleteFramebuffers:                  proc "c" (n: i32, framebuffers: [^]u32)
impl_GenFramebuffers:                     proc "c" (n: i32, framebuffers: [^]u32)
impl_CheckFramebufferStatus:              proc "c" (target: u32) -> u32
impl_FramebufferTexture1D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32)
impl_FramebufferTexture2D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32)
impl_FramebufferTexture3D:                proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, zoffset: i32)
impl_FramebufferRenderbuffer:             proc "c" (target: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32)
impl_GetFramebufferAttachmentParameteriv: proc "c" (target: u32, attachment: u32, pname: u32, params: [^]i32)
impl_GenerateMipmap:                      proc "c" (target: u32)
impl_BlitFramebuffer:                     proc "c" (srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32)
impl_RenderbufferStorageMultisample:      proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32)
impl_FramebufferTextureLayer:             proc "c" (target: u32, attachment: u32, texture: u32, level: i32, layer: i32)
impl_MapBufferRange:                      proc "c" (target: u32, offset: int, length: int, access: u32) -> rawptr
impl_FlushMappedBufferRange:              proc "c" (target: u32, offset: int, length: int)
impl_BindVertexArray:                     proc "c" (array: u32)
impl_DeleteVertexArrays:                  proc "c" (n: i32, arrays: [^]u32)
impl_GenVertexArrays:                     proc "c" (n: i32, arrays: [^]u32)
impl_IsVertexArray:                       proc "c" (array: u32) -> bool

load_3_0 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_ColorMaski,                          "glColorMaski")
	set_proc_address(&impl_GetBooleani_v,                       "glGetBooleani_v")
	set_proc_address(&impl_GetIntegeri_v,                       "glGetIntegeri_v")
	set_proc_address(&impl_Enablei,                             "glEnablei")
	set_proc_address(&impl_Disablei,                            "glDisablei")
	set_proc_address(&impl_IsEnabledi,                          "glIsEnabledi")
	set_proc_address(&impl_BeginTransformFeedback,              "glBeginTransformFeedback")
	set_proc_address(&impl_EndTransformFeedback,                "glEndTransformFeedback")
	set_proc_address(&impl_BindBufferRange,                     "glBindBufferRange")
	set_proc_address(&impl_BindBufferBase,                      "glBindBufferBase")
	set_proc_address(&impl_TransformFeedbackVaryings,           "glTransformFeedbackVaryings")
	set_proc_address(&impl_GetTransformFeedbackVarying,         "glGetTransformFeedbackVarying")
	set_proc_address(&impl_ClampColor,                          "glClampColor")
	set_proc_address(&impl_BeginConditionalRender,              "glBeginConditionalRender")
	set_proc_address(&impl_EndConditionalRender,                "glEndConditionalRender")
	set_proc_address(&impl_VertexAttribIPointer,                "glVertexAttribIPointer")
	set_proc_address(&impl_GetVertexAttribIiv,                  "glGetVertexAttribIiv")
	set_proc_address(&impl_GetVertexAttribIuiv,                 "glGetVertexAttribIuiv")
	set_proc_address(&impl_VertexAttribI1i,                     "glVertexAttribI1i")
	set_proc_address(&impl_VertexAttribI2i,                     "glVertexAttribI2i")
	set_proc_address(&impl_VertexAttribI3i,                     "glVertexAttribI3i")
	set_proc_address(&impl_VertexAttribI4i,                     "glVertexAttribI4i")
	set_proc_address(&impl_VertexAttribI1ui,                    "glVertexAttribI1ui")
	set_proc_address(&impl_VertexAttribI2ui,                    "glVertexAttribI2ui")
	set_proc_address(&impl_VertexAttribI3ui,                    "glVertexAttribI3ui")
	set_proc_address(&impl_VertexAttribI4ui,                    "glVertexAttribI4ui")
	set_proc_address(&impl_VertexAttribI1iv,                    "glVertexAttribI1iv")
	set_proc_address(&impl_VertexAttribI2iv,                    "glVertexAttribI2iv")
	set_proc_address(&impl_VertexAttribI3iv,                    "glVertexAttribI3iv")
	set_proc_address(&impl_VertexAttribI4iv,                    "glVertexAttribI4iv")
	set_proc_address(&impl_VertexAttribI1uiv,                   "glVertexAttribI1uiv")
	set_proc_address(&impl_VertexAttribI2uiv,                   "glVertexAttribI2uiv")
	set_proc_address(&impl_VertexAttribI3uiv,                   "glVertexAttribI3uiv")
	set_proc_address(&impl_VertexAttribI4uiv,                   "glVertexAttribI4uiv")
	set_proc_address(&impl_VertexAttribI4bv,                    "glVertexAttribI4bv")
	set_proc_address(&impl_VertexAttribI4sv,                    "glVertexAttribI4sv")
	set_proc_address(&impl_VertexAttribI4ubv,                   "glVertexAttribI4ubv")
	set_proc_address(&impl_VertexAttribI4usv,                   "glVertexAttribI4usv")
	set_proc_address(&impl_GetUniformuiv,                       "glGetUniformuiv")
	set_proc_address(&impl_BindFragDataLocation,                "glBindFragDataLocation")
	set_proc_address(&impl_GetFragDataLocation,                 "glGetFragDataLocation")
	set_proc_address(&impl_Uniform1ui,                          "glUniform1ui")
	set_proc_address(&impl_Uniform2ui,                          "glUniform2ui")
	set_proc_address(&impl_Uniform3ui,                          "glUniform3ui")
	set_proc_address(&impl_Uniform4ui,                          "glUniform4ui")
	set_proc_address(&impl_Uniform1uiv,                         "glUniform1uiv")
	set_proc_address(&impl_Uniform2uiv,                         "glUniform2uiv")
	set_proc_address(&impl_Uniform3uiv,                         "glUniform3uiv")
	set_proc_address(&impl_Uniform4uiv,                         "glUniform4uiv")
	set_proc_address(&impl_TexParameterIiv,                     "glTexParameterIiv")
	set_proc_address(&impl_TexParameterIuiv,                    "glTexParameterIuiv")
	set_proc_address(&impl_GetTexParameterIiv,                  "glGetTexParameterIiv")
	set_proc_address(&impl_GetTexParameterIuiv,                 "glGetTexParameterIuiv")
	set_proc_address(&impl_ClearBufferiv,                       "glClearBufferiv")
	set_proc_address(&impl_ClearBufferuiv,                      "glClearBufferuiv")
	set_proc_address(&impl_ClearBufferfv,                       "glClearBufferfv")
	set_proc_address(&impl_ClearBufferfi,                       "glClearBufferfi")
	set_proc_address(&impl_GetStringi,                          "glGetStringi")
	set_proc_address(&impl_IsRenderbuffer,                      "glIsRenderbuffer")
	set_proc_address(&impl_BindRenderbuffer,                    "glBindRenderbuffer")
	set_proc_address(&impl_DeleteRenderbuffers,                 "glDeleteRenderbuffers")
	set_proc_address(&impl_GenRenderbuffers,                    "glGenRenderbuffers")
	set_proc_address(&impl_RenderbufferStorage,                 "glRenderbufferStorage")
	set_proc_address(&impl_GetRenderbufferParameteriv,          "glGetRenderbufferParameteriv")
	set_proc_address(&impl_IsFramebuffer,                       "glIsFramebuffer")
	set_proc_address(&impl_BindFramebuffer,                     "glBindFramebuffer")
	set_proc_address(&impl_DeleteFramebuffers,                  "glDeleteFramebuffers")
	set_proc_address(&impl_GenFramebuffers,                     "glGenFramebuffers")
	set_proc_address(&impl_CheckFramebufferStatus,              "glCheckFramebufferStatus")
	set_proc_address(&impl_FramebufferTexture1D,                "glFramebufferTexture1D")
	set_proc_address(&impl_FramebufferTexture2D,                "glFramebufferTexture2D")
	set_proc_address(&impl_FramebufferTexture3D,                "glFramebufferTexture3D")
	set_proc_address(&impl_FramebufferRenderbuffer,             "glFramebufferRenderbuffer")
	set_proc_address(&impl_GetFramebufferAttachmentParameteriv, "glGetFramebufferAttachmentParameteriv")
	set_proc_address(&impl_GenerateMipmap,                      "glGenerateMipmap")
	set_proc_address(&impl_BlitFramebuffer,                     "glBlitFramebuffer")
	set_proc_address(&impl_RenderbufferStorageMultisample,      "glRenderbufferStorageMultisample")
	set_proc_address(&impl_FramebufferTextureLayer,             "glFramebufferTextureLayer")
	set_proc_address(&impl_MapBufferRange,                      "glMapBufferRange")
	set_proc_address(&impl_FlushMappedBufferRange,              "glFlushMappedBufferRange")
	set_proc_address(&impl_BindVertexArray,                     "glBindVertexArray")
	set_proc_address(&impl_DeleteVertexArrays,                  "glDeleteVertexArrays")
	set_proc_address(&impl_GenVertexArrays,                     "glGenVertexArrays")
	set_proc_address(&impl_IsVertexArray,                       "glIsVertexArray")
}


// VERSION_3_1
impl_DrawArraysInstanced:       proc "c" (mode: u32, first: i32, count: i32, instancecount: i32)
impl_DrawElementsInstanced:     proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32)
impl_TexBuffer:                 proc "c" (target: u32, internalformat: u32, buffer: u32)
impl_PrimitiveRestartIndex:     proc "c" (index: u32)
impl_CopyBufferSubData:         proc "c" (readTarget: u32, writeTarget: u32, readOffset: int, writeOffset: int, size: int)
impl_GetUniformIndices:         proc "c" (program: u32, uniformCount: i32, uniformNames: [^]cstring, uniformIndices: [^]u32)
impl_GetActiveUniformsiv:       proc "c" (program: u32, uniformCount: i32, uniformIndices: [^]u32, pname: u32, params: [^]i32)
impl_GetActiveUniformName:      proc "c" (program: u32, uniformIndex: u32, bufSize: i32, length: ^i32, uniformName: [^]u8)
impl_GetUniformBlockIndex:      proc "c" (program: u32, uniformBlockName: cstring) -> u32
impl_GetActiveUniformBlockiv:   proc "c" (program: u32, uniformBlockIndex: u32, pname: u32, params: [^]i32)
impl_GetActiveUniformBlockName: proc "c" (program: u32, uniformBlockIndex: u32, bufSize: i32, length: ^i32, uniformBlockName: [^]u8)
impl_UniformBlockBinding:       proc "c" (program: u32, uniformBlockIndex: u32, uniformBlockBinding: u32)

load_3_1 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_DrawArraysInstanced,       "glDrawArraysInstanced")
	set_proc_address(&impl_DrawElementsInstanced,     "glDrawElementsInstanced")
	set_proc_address(&impl_TexBuffer,                 "glTexBuffer")
	set_proc_address(&impl_PrimitiveRestartIndex,     "glPrimitiveRestartIndex")
	set_proc_address(&impl_CopyBufferSubData,         "glCopyBufferSubData")
	set_proc_address(&impl_GetUniformIndices,         "glGetUniformIndices")
	set_proc_address(&impl_GetActiveUniformsiv,       "glGetActiveUniformsiv")
	set_proc_address(&impl_GetActiveUniformName,      "glGetActiveUniformName")
	set_proc_address(&impl_GetUniformBlockIndex,      "glGetUniformBlockIndex")
	set_proc_address(&impl_GetActiveUniformBlockiv,   "glGetActiveUniformBlockiv")
	set_proc_address(&impl_GetActiveUniformBlockName, "glGetActiveUniformBlockName")
	set_proc_address(&impl_UniformBlockBinding,       "glUniformBlockBinding")
}


// VERSION_3_2
impl_DrawElementsBaseVertex:          proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, basevertex: i32)
impl_DrawRangeElementsBaseVertex:     proc "c" (mode: u32, start: u32, end: u32, count: i32, type: u32, indices: rawptr, basevertex: i32)
impl_DrawElementsInstancedBaseVertex: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32, basevertex: i32)
impl_MultiDrawElementsBaseVertex:     proc "c" (mode: u32, count: ^i32, type: u32, indices: [^]rawptr, drawcount: i32, basevertex: ^i32)
impl_ProvokingVertex:                 proc "c" (mode: u32)
impl_FenceSync:                       proc "c" (condition: u32, flags: u32) -> sync_t
impl_IsSync:                          proc "c" (sync: sync_t) -> bool
impl_DeleteSync:                      proc "c" (sync: sync_t)
impl_ClientWaitSync:                  proc "c" (sync: sync_t, flags: u32, timeout: u64) -> u32
impl_WaitSync:                        proc "c" (sync: sync_t, flags: u32, timeout: u64)
impl_GetInteger64v:                   proc "c" (pname: u32, data: ^i64)
impl_GetSynciv:                       proc "c" (sync: sync_t, pname: u32, bufSize: i32, length: ^i32, values: [^]i32)
impl_GetInteger64i_v:                 proc "c" (target: u32, index: u32, data: ^i64)
impl_GetBufferParameteri64v:          proc "c" (target: u32, pname: u32, params: [^]i64)
impl_FramebufferTexture:              proc "c" (target: u32, attachment: u32, texture: u32, level: i32)
impl_TexImage2DMultisample:           proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: bool)
impl_TexImage3DMultisample:           proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: bool)
impl_GetMultisamplefv:                proc "c" (pname: u32, index: u32, val: ^f32)
impl_SampleMaski:                     proc "c" (maskNumber: u32, mask: u32)

load_3_2 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_DrawElementsBaseVertex,          "glDrawElementsBaseVertex")
	set_proc_address(&impl_DrawRangeElementsBaseVertex,     "glDrawRangeElementsBaseVertex")
	set_proc_address(&impl_DrawElementsInstancedBaseVertex, "glDrawElementsInstancedBaseVertex")
	set_proc_address(&impl_MultiDrawElementsBaseVertex,     "glMultiDrawElementsBaseVertex")
	set_proc_address(&impl_ProvokingVertex,                 "glProvokingVertex")
	set_proc_address(&impl_FenceSync,                       "glFenceSync")
	set_proc_address(&impl_IsSync,                          "glIsSync")
	set_proc_address(&impl_DeleteSync,                      "glDeleteSync")
	set_proc_address(&impl_ClientWaitSync,                  "glClientWaitSync")
	set_proc_address(&impl_WaitSync,                        "glWaitSync")
	set_proc_address(&impl_GetInteger64v,                   "glGetInteger64v")
	set_proc_address(&impl_GetSynciv,                       "glGetSynciv")
	set_proc_address(&impl_GetInteger64i_v,                 "glGetInteger64i_v")
	set_proc_address(&impl_GetBufferParameteri64v,          "glGetBufferParameteri64v")
	set_proc_address(&impl_FramebufferTexture,              "glFramebufferTexture")
	set_proc_address(&impl_TexImage2DMultisample,           "glTexImage2DMultisample")
	set_proc_address(&impl_TexImage3DMultisample,           "glTexImage3DMultisample")
	set_proc_address(&impl_GetMultisamplefv,                "glGetMultisamplefv")
	set_proc_address(&impl_SampleMaski,                     "glSampleMaski")
}


// VERSION_3_3
impl_BindFragDataLocationIndexed: proc "c" (program: u32, colorNumber: u32, index: u32, name: cstring)
impl_GetFragDataIndex:            proc "c" (program: u32, name: cstring) -> i32
impl_GenSamplers:                 proc "c" (count: i32, samplers: [^]u32)
impl_DeleteSamplers:              proc "c" (count: i32, samplers: [^]u32)
impl_IsSampler:                   proc "c" (sampler: u32) -> bool
impl_BindSampler:                 proc "c" (unit: u32, sampler: u32)
impl_SamplerParameteri:           proc "c" (sampler: u32, pname: u32, param: i32)
impl_SamplerParameteriv:          proc "c" (sampler: u32, pname: u32, param: ^i32)
impl_SamplerParameterf:           proc "c" (sampler: u32, pname: u32, param: f32)
impl_SamplerParameterfv:          proc "c" (sampler: u32, pname: u32, param: ^f32)
impl_SamplerParameterIiv:         proc "c" (sampler: u32, pname: u32, param: ^i32)
impl_SamplerParameterIuiv:        proc "c" (sampler: u32, pname: u32, param: ^u32)
impl_GetSamplerParameteriv:       proc "c" (sampler: u32, pname: u32, params: [^]i32)
impl_GetSamplerParameterIiv:      proc "c" (sampler: u32, pname: u32, params: [^]i32)
impl_GetSamplerParameterfv:       proc "c" (sampler: u32, pname: u32, params: [^]f32)
impl_GetSamplerParameterIuiv:     proc "c" (sampler: u32, pname: u32, params: [^]u32)
impl_QueryCounter:                proc "c" (id: u32, target: u32)
impl_GetQueryObjecti64v:          proc "c" (id: u32, pname: u32, params: [^]i64)
impl_GetQueryObjectui64v:         proc "c" (id: u32, pname: u32, params: [^]u64)
impl_VertexAttribDivisor:         proc "c" (index: u32, divisor: u32)
impl_VertexAttribP1ui:            proc "c" (index: u32, type: u32, normalized: bool, value: u32)
impl_VertexAttribP1uiv:           proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)
impl_VertexAttribP2ui:            proc "c" (index: u32, type: u32, normalized: bool, value: u32)
impl_VertexAttribP2uiv:           proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)
impl_VertexAttribP3ui:            proc "c" (index: u32, type: u32, normalized: bool, value: u32)
impl_VertexAttribP3uiv:           proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)
impl_VertexAttribP4ui:            proc "c" (index: u32, type: u32, normalized: bool, value: u32)
impl_VertexAttribP4uiv:           proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)
impl_VertexP2ui:                  proc "c" (type: u32, value: u32)
impl_VertexP2uiv:                 proc "c" (type: u32, value: ^u32)
impl_VertexP3ui:                  proc "c" (type: u32, value: u32)
impl_VertexP3uiv:                 proc "c" (type: u32, value: ^u32)
impl_VertexP4ui:                  proc "c" (type: u32, value: u32)
impl_VertexP4uiv:                 proc "c" (type: u32, value: ^u32)
impl_TexCoordP1ui:                proc "c" (type: u32, coords: u32)
impl_TexCoordP1uiv:               proc "c" (type: u32, coords: [^]u32)
impl_TexCoordP2ui:                proc "c" (type: u32, coords: u32)
impl_TexCoordP2uiv:               proc "c" (type: u32, coords: [^]u32)
impl_TexCoordP3ui:                proc "c" (type: u32, coords: u32)
impl_TexCoordP3uiv:               proc "c" (type: u32, coords: [^]u32)
impl_TexCoordP4ui:                proc "c" (type: u32, coords: u32)
impl_TexCoordP4uiv:               proc "c" (type: u32, coords: [^]u32)
impl_MultiTexCoordP1ui:           proc "c" (texture: u32, type: u32, coords: u32)
impl_MultiTexCoordP1uiv:          proc "c" (texture: u32, type: u32, coords: [^]u32)
impl_MultiTexCoordP2ui:           proc "c" (texture: u32, type: u32, coords: u32)
impl_MultiTexCoordP2uiv:          proc "c" (texture: u32, type: u32, coords: [^]u32)
impl_MultiTexCoordP3ui:           proc "c" (texture: u32, type: u32, coords: u32)
impl_MultiTexCoordP3uiv:          proc "c" (texture: u32, type: u32, coords: [^]u32)
impl_MultiTexCoordP4ui:           proc "c" (texture: u32, type: u32, coords: u32)
impl_MultiTexCoordP4uiv:          proc "c" (texture: u32, type: u32, coords: [^]u32)
impl_NormalP3ui:                  proc "c" (type: u32, coords: u32)
impl_NormalP3uiv:                 proc "c" (type: u32, coords: [^]u32)
impl_ColorP3ui:                   proc "c" (type: u32, color: u32)
impl_ColorP3uiv:                  proc "c" (type: u32, color: ^u32)
impl_ColorP4ui:                   proc "c" (type: u32, color: u32)
impl_ColorP4uiv:                  proc "c" (type: u32, color: ^u32)
impl_SecondaryColorP3ui:          proc "c" (type: u32, color: u32)
impl_SecondaryColorP3uiv:         proc "c" (type: u32, color: ^u32)

load_3_3 :: proc(set_proc_address: Set_Proc_Address_Type) {
	set_proc_address(&impl_BindFragDataLocationIndexed, "glBindFragDataLocationIndexed")
	set_proc_address(&impl_GetFragDataIndex,            "glGetFragDataIndex")
	set_proc_address(&impl_GenSamplers,                 "glGenSamplers")
	set_proc_address(&impl_DeleteSamplers,              "glDeleteSamplers")
	set_proc_address(&impl_IsSampler,                   "glIsSampler")
	set_proc_address(&impl_BindSampler,                 "glBindSampler")
	set_proc_address(&impl_SamplerParameteri,           "glSamplerParameteri")
	set_proc_address(&impl_SamplerParameteriv,          "glSamplerParameteriv")
	set_proc_address(&impl_SamplerParameterf,           "glSamplerParameterf")
	set_proc_address(&impl_SamplerParameterfv,          "glSamplerParameterfv")
	set_proc_address(&impl_SamplerParameterIiv,         "glSamplerParameterIiv")
	set_proc_address(&impl_SamplerParameterIuiv,        "glSamplerParameterIuiv")
	set_proc_address(&impl_GetSamplerParameteriv,       "glGetSamplerParameteriv")
	set_proc_address(&impl_GetSamplerParameterIiv,      "glGetSamplerParameterIiv")
	set_proc_address(&impl_GetSamplerParameterfv,       "glGetSamplerParameterfv")
	set_proc_address(&impl_GetSamplerParameterIuiv,     "glGetSamplerParameterIuiv")
	set_proc_address(&impl_QueryCounter,                "glQueryCounter")
	set_proc_address(&impl_GetQueryObjecti64v,          "glGetQueryObjecti64v")
	set_proc_address(&impl_GetQueryObjectui64v,         "glGetQueryObjectui64v")
	set_proc_address(&impl_VertexAttribDivisor,         "glVertexAttribDivisor")
	set_proc_address(&impl_VertexAttribP1ui,            "glVertexAttribP1ui")
	set_proc_address(&impl_VertexAttribP1uiv,           "glVertexAttribP1uiv")
	set_proc_address(&impl_VertexAttribP2ui,            "glVertexAttribP2ui")
	set_proc_address(&impl_VertexAttribP2uiv,           "glVertexAttribP2uiv")
	set_proc_address(&impl_VertexAttribP3ui,            "glVertexAttribP3ui")
	set_proc_address(&impl_VertexAttribP3uiv,           "glVertexAttribP3uiv")
	set_proc_address(&impl_VertexAttribP4ui,            "glVertexAttribP4ui")
	set_proc_address(&impl_VertexAttribP4uiv,           "glVertexAttribP4uiv")
	set_proc_address(&impl_VertexP2ui,                  "glVertexP2ui")
	set_proc_address(&impl_VertexP2uiv,                 "glVertexP2uiv")
	set_proc_address(&impl_VertexP3ui,                  "glVertexP3ui")
	set_proc_address(&impl_VertexP3uiv,                 "glVertexP3uiv")
	set_proc_address(&impl_VertexP4ui,                  "glVertexP4ui")
	set_proc_address(&impl_VertexP4uiv,                 "glVertexP4uiv")
	set_proc_address(&impl_TexCoordP1ui,                "glTexCoordP1ui")
	set_proc_address(&impl_TexCoordP1uiv,               "glTexCoordP1uiv")
	set_proc_address(&impl_TexCoordP2ui,                "glTexCoordP2ui")
	set_proc_address(&impl_TexCoordP2uiv,               "glTexCoordP2uiv")
	set_proc_address(&impl_TexCoordP3ui,                "glTexCoordP3ui")
	set_proc_address(&impl_TexCoordP3uiv,               "glTexCoordP3uiv")
	set_proc_address(&impl_TexCoordP4ui,                "glTexCoordP4ui")
	set_proc_address(&impl_TexCoordP4uiv,               "glTexCoordP4uiv")
	set_proc_address(&impl_MultiTexCoordP1ui,           "glMultiTexCoordP1ui")
	set_proc_address(&impl_MultiTexCoordP1uiv,          "glMultiTexCoordP1uiv")
	set_proc_address(&impl_MultiTexCoordP2ui,           "glMultiTexCoordP2ui")
	set_proc_address(&impl_MultiTexCoordP2uiv,          "glMultiTexCoordP2uiv")
	set_proc_address(&impl_MultiTexCoordP3ui,           "glMultiTexCoordP3ui")
	set_proc_address(&impl_MultiTexCoordP3uiv,          "glMultiTexCoordP3uiv")
	set_proc_address(&impl_MultiTexCoordP4ui,           "glMultiTexCoordP4ui")
	set_proc_address(&impl_MultiTexCoordP4uiv,          "glMultiTexCoordP4uiv")
	set_proc_address(&impl_NormalP3ui,                  "glNormalP3ui")
	set_proc_address(&impl_NormalP3uiv,                 "glNormalP3uiv")
	set_proc_address(&impl_ColorP3ui,                   "glColorP3ui")
	set_proc_address(&impl_ColorP3uiv,                  "glColorP3uiv")
	set_proc_address(&impl_ColorP4ui,                   "glColorP4ui")
	set_proc_address(&impl_ColorP4uiv,                  "glColorP4uiv")
	set_proc_address(&impl_SecondaryColorP3ui,          "glSecondaryColorP3ui")
	set_proc_address(&impl_SecondaryColorP3uiv,         "glSecondaryColorP3uiv")
}



when !NGL_DEBUG {
	// VERSION_1_0
	glCullFace               :: proc "c" (mode: u32)                                                                                         {        impl_CullFace(mode)                                                                         }
	glFrontFace              :: proc "c" (mode: u32)                                                                                         {        impl_FrontFace(mode)                                                                        }
	glHint                   :: proc "c" (target, mode: u32)                                                                                 {        impl_Hint(target, mode)                                                                     }
	glLineWidth              :: proc "c" (width: f32)                                                                                        {        impl_LineWidth(width)                                                                       }
	glPointSize              :: proc "c" (size: f32)                                                                                         {        impl_PointSize(size)                                                                        }
	glPolygonMode            :: proc "c" (face, mode: u32)                                                                                   {        impl_PolygonMode(face, mode)                                                                }
	glScissor                :: proc "c" (x, y, width, height: i32)                                                                          {        impl_Scissor(x, y, width, height)                                                           }
	glTexParameterf          :: proc "c" (target, pname: u32, param: f32)                                                                    {        impl_TexParameterf(target, pname, param)                                                    }
	glTexParameterfv         :: proc "c" (target, pname: u32, params: [^]f32)                                                                {        impl_TexParameterfv(target, pname, params)                                                  }
	glTexParameteri          :: proc "c" (target, pname: u32, param: i32)                                                                    {        impl_TexParameteri(target, pname, param)                                                    }
	glTexParameteriv         :: proc "c" (target, pname: u32, params: [^]i32)                                                                {        impl_TexParameteriv(target, pname, params)                                                  }
	glTexImage1D             :: proc "c" (target: u32, level, internalformat, width, border: i32, format, type: u32, pixels: rawptr)         {        impl_TexImage1D(target, level, internalformat, width, border, format, type, pixels)         }
	glTexImage2D             :: proc "c" (target: u32, level, internalformat, width, height, border: i32, format, type: u32, pixels: rawptr) {        impl_TexImage2D(target, level, internalformat, width, height, border, format, type, pixels) }
	glDrawBuffer             :: proc "c" (buf: u32)                                                                                          {        impl_DrawBuffer(buf)                                                                        }
	glClear                  :: proc "c" (mask: u32)                                                                                         {        impl_Clear(mask)                                                                            }
	glClearColor             :: proc "c" (red, green, blue, alpha: f32)                                                                      {        impl_ClearColor(red, green, blue, alpha)                                                    }
	glClearStencil           :: proc "c" (s: i32)                                                                                            {        impl_ClearStencil(s)                                                                        }
	glClearDepth             :: proc "c" (depth: f64)                                                                                        {        impl_ClearDepth(depth)                                                                      }
	glStencilMask            :: proc "c" (mask: u32)                                                                                         {        impl_StencilMask(mask)                                                                      }
	glColorMask              :: proc "c" (red, green, blue, alpha: bool)                                                                     {        impl_ColorMask(red, green, blue, alpha)                                                     }
	glDepthMask              :: proc "c" (flag: bool)                                                                                        {        impl_DepthMask(flag)                                                                        }
	glDisable                :: proc "c" (cap: u32)                                                                                          {        impl_Disable(cap)                                                                           }
	glEnable                 :: proc "c" (cap: u32)                                                                                          {        impl_Enable(cap)                                                                            }
	glFinish                 :: proc "c" ()                                                                                                  {        impl_Finish()                                                                               }
	glFlush                  :: proc "c" ()                                                                                                  {        impl_Flush()                                                                                }
	glBlendFunc              :: proc "c" (sfactor, dfactor: u32)                                                                             {        impl_BlendFunc(sfactor, dfactor)                                                            }
	glLogicOp                :: proc "c" (opcode: u32)                                                                                       {        impl_LogicOp(opcode)                                                                        }
	glStencilFunc            :: proc "c" (func: u32, ref: i32, mask: u32)                                                                    {        impl_StencilFunc(func, ref, mask)                                                           }
	glStencilOp              :: proc "c" (fail, zfail, zpass: u32)                                                                           {        impl_StencilOp(fail, zfail, zpass)                                                          }
	glDepthFunc              :: proc "c" (func: u32)                                                                                         {        impl_DepthFunc(func)                                                                        }
	glPixelStoref            :: proc "c" (pname: u32, param: f32)                                                                            {        impl_PixelStoref(pname, param)                                                              }
	glPixelStorei            :: proc "c" (pname: u32, param: i32)                                                                            {        impl_PixelStorei(pname, param)                                                              }
	glReadBuffer             :: proc "c" (src: u32)                                                                                          {        impl_ReadBuffer(src)                                                                        }
	glReadPixels             :: proc "c" (x, y, width, height: i32, format, type: u32, pixels: rawptr)                                       {        impl_ReadPixels(x, y, width, height, format, type, pixels)                                  }
	glGetBooleanv            :: proc "c" (pname: u32, data: ^bool)                                                                           {        impl_GetBooleanv(pname, data)                                                               }
	glGetDoublev             :: proc "c" (pname: u32, data: ^f64)                                                                            {        impl_GetDoublev(pname, data)                                                                }
	glGetError               :: proc "c" () -> u32                                                                                           { return impl_GetError()                                                                             }
	glGetFloatv              :: proc "c" (pname: u32, data: ^f32)                                                                            {        impl_GetFloatv(pname, data)                                                                 }
	glGetIntegerv            :: proc "c" (pname: u32, data: ^i32)                                                                            {        impl_GetIntegerv(pname, data)                                                               }
	glGetString              :: proc "c" (name: u32) -> cstring                                                                              { return impl_GetString(name)                                                                        }
	glGetTexImage            :: proc "c" (target: u32,  level: i32, format, type: u32, pixels: rawptr)                                       {        impl_GetTexImage(target,  level, format, type, pixels)                                      }
	glGetTexParameterfv      :: proc "c" (target, pname: u32, params: [^]f32)                                                                {        impl_GetTexParameterfv(target, pname, params)                                               }
	glGetTexParameteriv      :: proc "c" (target, pname: u32, params: [^]i32)                                                                {        impl_GetTexParameteriv(target, pname, params)                                               }
	glGetTexLevelParameterfv :: proc "c" (target: u32, level: i32, pname: u32, params: [^]f32)                                               {        impl_GetTexLevelParameterfv(target, level, pname, params)                                   }
	glGetTexLevelParameteriv :: proc "c" (target: u32, level: i32, pname: u32, params: [^]i32)                                               {        impl_GetTexLevelParameteriv(target, level, pname, params)                                   }
	glIsEnabled              :: proc "c" (cap: u32) -> bool                                                                                  { return impl_IsEnabled(cap)                                                                         }
	glDepthRange             :: proc "c" (near, far: f64)                                                                                    {        impl_DepthRange(near, far)                                                                  }
	glViewport               :: proc "c" (x, y, width, height: i32)                                                                          {        impl_Viewport(x, y, width, height)                                                          }

	// VERSION_1_1
	glDrawArrays        :: proc "c" (mode: u32, first: i32, count: i32)                                                                                    {        impl_DrawArrays(mode, first, count)                                                      }
	glDrawElements      :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr)                                                                    {        impl_DrawElements(mode, count, type, indices)                                            }
	glPolygonOffset     :: proc "c" (factor: f32, units: f32)                                                                                              {        impl_PolygonOffset(factor, units)                                                        }
	glCopyTexImage1D    :: proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, border: i32)                                {        impl_CopyTexImage1D(target, level, internalformat, x, y, width, border)                  }
	glCopyTexImage2D    :: proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, height: i32, border: i32)                   {        impl_CopyTexImage2D(target, level, internalformat, x, y, width, height, border)          }
	glCopyTexSubImage1D :: proc "c" (target: u32, level: i32, xoffset: i32, x: i32, y: i32, width: i32)                                                    {        impl_CopyTexSubImage1D(target, level, xoffset, x, y, width)                              }
	glCopyTexSubImage2D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, x: i32, y: i32, width: i32, height: i32)                         {        impl_CopyTexSubImage2D(target, level, xoffset, yoffset, x, y, width, height)             }
	glTexSubImage1D     :: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, type: u32, pixels: rawptr)                            {        impl_TexSubImage1D(target, level, xoffset, width, format, type, pixels)                  }
	glTexSubImage2D     :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type: u32, pixels: rawptr) {        impl_TexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels) }
	glBindTexture       :: proc "c" (target: u32, texture: u32)                                                                                            {        impl_BindTexture(target, texture)                                                        }
	glDeleteTextures    :: proc "c" (n: i32, textures: [^]u32)                                                                                             {        impl_DeleteTextures(n, textures)                                                         }
	glGenTextures       :: proc "c" (n: i32, textures: [^]u32)                                                                                             {        impl_GenTextures(n, textures)                                                            }
	glIsTexture         :: proc "c" (texture: u32) -> bool                                                                                                 { return impl_IsTexture(texture)                                                                  }

	// VERSION_1_2
	glDrawRangeElements :: proc "c" (mode, start, end: u32, count: i32, type: u32, indices: rawptr)                                               { impl_DrawRangeElements(mode, start, end, count, type, indices)                                           }
	glTexImage3D        :: proc "c" (target: u32, level, internalformat, width, height, depth, border: i32, format, type: u32, data: rawptr)    { impl_TexImage3D(target, level, internalformat, width, height, depth, border, format, type, data)       }
	glTexSubImage3D     :: proc "c" (target: u32, level, xoffset, yoffset, zoffset, width, height, depth: i32, format, type: u32, pixels: rawptr) { impl_TexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pixels) }
	glCopyTexSubImage3D :: proc "c" (target: u32, level, xoffset, yoffset, zoffset, x, y, width, height: i32)                                     { impl_CopyTexSubImage3D(target, level, xoffset, yoffset, zoffset, x, y, width, height)                    }

	// VERSION_1_3
	glActiveTexture           :: proc "c" (texture: u32)                                                                                                                                      { impl_ActiveTexture(texture)                                                                                           }
	glSampleCoverage          :: proc "c" (value: f32, invert: bool)                                                                                                                          { impl_SampleCoverage(value, invert)                                                                                    }
	glCompressedTexImage3D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, depth: i32, border: i32, imageSize: i32, data: rawptr)                      { impl_CompressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, data)               }
	glCompressedTexImage2D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, border: i32, imageSize: i32, data: rawptr)                                  { impl_CompressedTexImage2D(target, level, internalformat, width, height, border, imageSize, data)                      }
	glCompressedTexImage1D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, border: i32, imageSize: i32, data: rawptr)                                               { impl_CompressedTexImage1D(target, level, internalformat, width, border, imageSize, data)                              }
	glCompressedTexSubImage3D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, imageSize: i32, data: rawptr) { impl_CompressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, data) }
	glCompressedTexSubImage2D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, imageSize: i32, data: rawptr)                           { impl_CompressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, data)                 }
	glCompressedTexSubImage1D :: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, imageSize: i32, data: rawptr)                                                      { impl_CompressedTexSubImage1D(target, level, xoffset, width, format, imageSize, data)                                  }
	glGetCompressedTexImage   :: proc "c" (target: u32, level: i32, img: rawptr)                                                                                                              { impl_GetCompressedTexImage(target, level, img)                                                                        }

	// VERSION_1_4
	glBlendFuncSeparate :: proc "c" (sfactorRGB: u32, dfactorRGB: u32, sfactorAlpha: u32, dfactorAlpha: u32)  { impl_BlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha) }
	glMultiDrawArrays   :: proc "c" (mode: u32, first: [^]i32, count: [^]i32, drawcount: i32)                 { impl_MultiDrawArrays(mode, first, count, drawcount)                    }
	glMultiDrawElements :: proc "c" (mode: u32, count: [^]i32, type: u32, indices: [^]rawptr, drawcount: i32) { impl_MultiDrawElements(mode, count, type, indices, drawcount)           }
	glPointParameterf   :: proc "c" (pname: u32, param: f32)                                                  { impl_PointParameterf(pname, param)                                         }
	glPointParameterfv  :: proc "c" (pname: u32, params: [^]f32)                                              { impl_PointParameterfv(pname, params)                                     }
	glPointParameteri   :: proc "c" (pname: u32, param: i32)                                                  { impl_PointParameteri(pname, param)                                         }
	glPointParameteriv  :: proc "c" (pname: u32, params: [^]i32)                                              { impl_PointParameteriv(pname, params)                                     }
	glBlendColor        :: proc "c" (red: f32, green: f32, blue: f32, alpha: f32)                             { impl_BlendColor(red, green, blue, alpha)                                   }
	glBlendEquation     :: proc "c" (mode: u32)                                                               { impl_BlendEquation(mode)                                                   }

	// VERSION_1_5
	glGenQueries           :: proc "c" (n: i32, ids: [^]u32)                               {        impl_GenQueries(n, ids)                                       }
	glDeleteQueries        :: proc "c" (n: i32, ids: [^]u32)                               {        impl_DeleteQueries(n, ids)                                    }
	glIsQuery              :: proc "c" (id: u32) -> bool                                   { ret := impl_IsQuery(id);                                  return ret }
	glBeginQuery           :: proc "c" (target: u32, id: u32)                              {        impl_BeginQuery(target, id)                                   }
	glEndQuery             :: proc "c" (target: u32)                                       {        impl_EndQuery(target)                                         }
	glGetQueryiv           :: proc "c" (target: u32, pname: u32, params: [^]i32)           {        impl_GetQueryiv(target, pname, params)                        }
	glGetQueryObjectiv     :: proc "c" (id: u32, pname: u32, params: [^]i32)               {        impl_GetQueryObjectiv(id, pname, params)                      }
	glGetQueryObjectuiv    :: proc "c" (id: u32, pname: u32, params: [^]u32)               {        impl_GetQueryObjectuiv(id, pname, params)                     }
	glBindBuffer           :: proc "c" (target: u32, buffer: u32)                          {        impl_BindBuffer(target, buffer)                               }
	glDeleteBuffers        :: proc "c" (n: i32, buffers: [^]u32)                           {        impl_DeleteBuffers(n, buffers)                                }
	glGenBuffers           :: proc "c" (n: i32, buffers: [^]u32)                           {        impl_GenBuffers(n, buffers)                                   }
	glIsBuffer             :: proc "c" (buffer: u32) -> bool                               { ret := impl_IsBuffer(buffer);                             return ret }
	glBufferData           :: proc "c" (target: u32, size: int, data: rawptr, usage: u32)  {        impl_BufferData(target, size, data, usage)                    }
	glBufferSubData        :: proc "c" (target: u32, offset: int, size: int, data: rawptr) {        impl_BufferSubData(target, offset, size, data)                }
	glGetBufferSubData     :: proc "c" (target: u32, offset: int, size: int, data: rawptr) {        impl_GetBufferSubData(target, offset, size, data)             }
	glMapBuffer            :: proc "c" (target: u32, access: u32) -> rawptr                { ret := impl_MapBuffer(target, access);                    return ret }
	glUnmapBuffer          :: proc "c" (target: u32) -> bool                               { ret := impl_UnmapBuffer(target);                          return ret }
	glGetBufferParameteriv :: proc "c" (target: u32, pname: u32, params: [^]i32)           {        impl_GetBufferParameteriv(target, pname, params)              }
	glGetBufferPointerv    :: proc "c" (target: u32, pname: u32, params: [^]rawptr)        {        impl_GetBufferPointerv(target, pname, params)                 }

	// VERSION_2_0
	glBlendEquationSeparate    :: proc "c" (modeRGB: u32, modeAlpha: u32)                                                               {        impl_BlendEquationSeparate(modeRGB, modeAlpha)                                        }
	glDrawBuffers              :: proc "c" (n: i32, bufs: [^]u32)                                                                       {        impl_DrawBuffers(n, bufs)                                                             }
	glStencilOpSeparate        :: proc "c" (face: u32, sfail: u32, dpfail: u32, dppass: u32)                                            {        impl_StencilOpSeparate(face, sfail, dpfail, dppass)                                   }
	glStencilFuncSeparate      :: proc "c" (face: u32, func: u32, ref: i32, mask: u32)                                                  {        impl_StencilFuncSeparate(face, func, ref, mask)                                       }
	glStencilMaskSeparate      :: proc "c" (face: u32, mask: u32)                                                                       {        impl_StencilMaskSeparate(face, mask)                                                  }
	glAttachShader             :: proc "c" (program: u32, shader: u32)                                                                  {        impl_AttachShader(program, shader)                                                    }
	glBindAttribLocation       :: proc "c" (program: u32, index: u32, name: cstring)                                                    {        impl_BindAttribLocation(program, index, name)                                         }
	glCompileShader            :: proc "c" (shader: u32)                                                                                {        impl_CompileShader(shader)                                                            }
	glCreateProgram            :: proc "c" () -> u32                                                                                    { ret := impl_CreateProgram();                                                      return ret }
	glCreateShader             :: proc "c" (type: u32) -> u32                                                                           { ret := impl_CreateShader(type);                                                  return ret }
	glDeleteProgram            :: proc "c" (program: u32)                                                                               {        impl_DeleteProgram(program)                                                           }
	glDeleteShader             :: proc "c" (shader: u32)                                                                                {        impl_DeleteShader(shader)                                                             }
	glDetachShader             :: proc "c" (program: u32, shader: u32)                                                                  {        impl_DetachShader(program, shader)                                                    }
	glDisableVertexAttribArray :: proc "c" (index: u32)                                                                                 {        impl_DisableVertexAttribArray(index)                                                  }
	glEnableVertexAttribArray  :: proc "c" (index: u32)                                                                                 {        impl_EnableVertexAttribArray(index)                                                   }
	glGetActiveAttrib          :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)  {        impl_GetActiveAttrib(program, index, bufSize, length, size, type, name)              }
	glGetActiveUniform         :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)  {        impl_GetActiveUniform(program, index, bufSize, length, size, type, name)             }
	glGetAttachedShaders       :: proc "c" (program: u32, maxCount: i32, count: [^]i32, shaders: [^]u32)                                {        impl_GetAttachedShaders(program, maxCount, count, shaders)                            }
	glGetAttribLocation        :: proc "c" (program: u32, name: cstring) -> i32                                                         { ret := impl_GetAttribLocation(program, name);                                     return ret }
	glGetProgramiv             :: proc "c" (program: u32, pname: u32, params: [^]i32)                                                   {        impl_GetProgramiv(program, pname, params)                                             }
	glGetProgramInfoLog        :: proc "c" (program: u32, bufSize: i32, length: ^i32, infoLog: [^]u8)                                   {        impl_GetProgramInfoLog(program, bufSize, length, infoLog)                             }
	glGetShaderiv              :: proc "c" (shader: u32, pname: u32, params: [^]i32)                                                    {        impl_GetShaderiv(shader, pname, params)                                               }
	glGetShaderInfoLog         :: proc "c" (shader: u32, bufSize: i32, length: ^i32, infoLog: [^]u8)                                    {        impl_GetShaderInfoLog(shader, bufSize, length, infoLog)                               }
	glGetShaderSource          :: proc "c" (shader: u32, bufSize: i32, length: ^i32, source: [^]u8)                                     {        impl_GetShaderSource(shader, bufSize, length, source)                                 }
	glGetUniformLocation       :: proc "c" (program: u32, name: cstring) -> i32                                                         { ret := impl_GetUniformLocation(program, name);                                    return ret }
	glGetUniformfv             :: proc "c" (program: u32, location: i32, params: [^]f32)                                                {        impl_GetUniformfv(program, location, params)                                          }
	glGetUniformiv             :: proc "c" (program: u32, location: i32, params: [^]i32)                                                {        impl_GetUniformiv(program, location, params)                                          }
	glGetVertexAttribdv        :: proc "c" (index: u32, pname: u32, params: [^]f64)                                                     {        impl_GetVertexAttribdv(index, pname, params)                                          }
	glGetVertexAttribfv        :: proc "c" (index: u32, pname: u32, params: [^]f32)                                                     {        impl_GetVertexAttribfv(index, pname, params)                                          }
	glGetVertexAttribiv        :: proc "c" (index: u32, pname: u32, params: [^]i32)                                                     {        impl_GetVertexAttribiv(index, pname, params)                                          }
	glGetVertexAttribPointerv  :: proc "c" (index: u32, pname: u32, pointer: ^uintptr)                                                   {        impl_GetVertexAttribPointerv(index, pname, pointer)                                   }
	glIsProgram                :: proc "c" (program: u32) -> bool                                                                       { ret := impl_IsProgram(program);                                                   return ret }
	glIsShader                 :: proc "c" (shader: u32) -> bool                                                                        { ret := impl_IsShader(shader);                                                     return ret }
	glLinkProgram              :: proc "c" (program: u32)                                                                               {        impl_LinkProgram(program)                                                             }
	glShaderSource             :: proc "c" (shader: u32, count: i32, string: [^]cstring, length: [^]i32)                                {        impl_ShaderSource(shader, count, string, length)                                      }
	glUseProgram               :: proc "c" (program: u32)                                                                               {        impl_UseProgram(program)                                                              }
	glUniform1f                :: proc "c" (location: i32, v0: f32)                                                                     {        impl_Uniform1f(location, v0)                                                          }
	glUniform2f                :: proc "c" (location: i32, v0: f32, v1: f32)                                                            {        impl_Uniform2f(location, v0, v1)                                                      }
	glUniform3f                :: proc "c" (location: i32, v0: f32, v1: f32, v2: f32)                                                   {        impl_Uniform3f(location, v0, v1, v2)                                                  }
	glUniform4f                :: proc "c" (location: i32, v0: f32, v1: f32, v2: f32, v3: f32)                                          {        impl_Uniform4f(location, v0, v1, v2, v3)                                              }
	glUniform1i                :: proc "c" (location: i32, v0: i32)                                                                     {        impl_Uniform1i(location, v0)                                                          }
	glUniform2i                :: proc "c" (location: i32, v0: i32, v1: i32)                                                            {        impl_Uniform2i(location, v0, v1)                                                      }
	glUniform3i                :: proc "c" (location: i32, v0: i32, v1: i32, v2: i32)                                                   {        impl_Uniform3i(location, v0, v1, v2)                                                  }
	glUniform4i                :: proc "c" (location: i32, v0: i32, v1: i32, v2: i32, v3: i32)                                          {        impl_Uniform4i(location, v0, v1, v2, v3)                                              }
	glUniform1fv               :: proc "c" (location: i32, count: i32, value: [^]f32)                                                {        impl_Uniform1fv(location, count, value)                                               }
	glUniform2fv               :: proc "c" (location: i32, count: i32, value: [^]f32)                                                {        impl_Uniform2fv(location, count, value)                                               }
	glUniform3fv               :: proc "c" (location: i32, count: i32, value: [^]f32)                                                {        impl_Uniform3fv(location, count, value)                                               }
	glUniform4fv               :: proc "c" (location: i32, count: i32, value: [^]f32)                                                {        impl_Uniform4fv(location, count, value)                                               }
	glUniform1iv               :: proc "c" (location: i32, count: i32, value: [^]i32)                                                {        impl_Uniform1iv(location, count, value)                                               }
	glUniform2iv               :: proc "c" (location: i32, count: i32, value: [^]i32)                                                {        impl_Uniform2iv(location, count, value)                                               }
	glUniform3iv               :: proc "c" (location: i32, count: i32, value: [^]i32)                                                {        impl_Uniform3iv(location, count, value)                                               }
	glUniform4iv               :: proc "c" (location: i32, count: i32, value: [^]i32)                                                {        impl_Uniform4iv(location, count, value)                                               }
	glUniformMatrix2fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)                               {        impl_UniformMatrix2fv(location, count, transpose, value)                              }
	glUniformMatrix3fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)                               {        impl_UniformMatrix3fv(location, count, transpose, value)                              }
	glUniformMatrix4fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32)                               {        impl_UniformMatrix4fv(location, count, transpose, value)                              }
	glValidateProgram          :: proc "c" (program: u32)                                                                               {        impl_ValidateProgram(program)                                                         }
	glVertexAttrib1d           :: proc "c" (index: u32, x: f64)                                                                         {        impl_VertexAttrib1d(index, x)                                                         }
	glVertexAttrib1dv          :: proc "c" (index: u32, v: ^f64)                                                                        {        impl_VertexAttrib1dv(index, v)                                                        }
	glVertexAttrib1f           :: proc "c" (index: u32, x: f32)                                                                         {        impl_VertexAttrib1f(index, x)                                                         }
	glVertexAttrib1fv          :: proc "c" (index: u32, v: ^f32)                                                                        {        impl_VertexAttrib1fv(index, v)                                                        }
	glVertexAttrib1s           :: proc "c" (index: u32, x: i16)                                                                         {        impl_VertexAttrib1s(index, x)                                                         }
	glVertexAttrib1sv          :: proc "c" (index: u32, v: ^i16)                                                                      {        impl_VertexAttrib1sv(index, v)                                                        }
	glVertexAttrib2d           :: proc "c" (index: u32, x: f64, y: f64)                                                                 {        impl_VertexAttrib2d(index, x, y)                                                      }
	glVertexAttrib2dv          :: proc "c" (index: u32, v: ^[2]f64)                                                                      {        impl_VertexAttrib2dv(index, v)                                                        }
	glVertexAttrib2f           :: proc "c" (index: u32, x: f32, y: f32)                                                                 {        impl_VertexAttrib2f(index, x, y)                                                      }
	glVertexAttrib2fv          :: proc "c" (index: u32, v: ^[2]f32)                                                                      {        impl_VertexAttrib2fv(index, v)                                                        }
	glVertexAttrib2s           :: proc "c" (index: u32, x: i16, y: i16)                                                                 {        impl_VertexAttrib2s(index, x, y)                                                      }
	glVertexAttrib2sv          :: proc "c" (index: u32, v: ^[2]i16)                                                                      {        impl_VertexAttrib2sv(index, v)                                                        }
	glVertexAttrib3d           :: proc "c" (index: u32, x: f64, y: f64, z: f64)                                                         {        impl_VertexAttrib3d(index, x, y, z)                                                   }
	glVertexAttrib3dv          :: proc "c" (index: u32, v: ^[3]f64)                                                                      {        impl_VertexAttrib3dv(index, v)                                                        }
	glVertexAttrib3f           :: proc "c" (index: u32, x: f32, y: f32, z: f32)                                                         {        impl_VertexAttrib3f(index, x, y, z)                                                   }
	glVertexAttrib3fv          :: proc "c" (index: u32, v: ^[3]f32)                                                                      {        impl_VertexAttrib3fv(index, v)                                                        }
	glVertexAttrib3s           :: proc "c" (index: u32, x: i16, y: i16, z: i16)                                                         {        impl_VertexAttrib3s(index, x, y, z)                                                   }
	glVertexAttrib3sv          :: proc "c" (index: u32, v: ^[3]i16)                                                                      {        impl_VertexAttrib3sv(index, v)                                                        }
	glVertexAttrib4Nbv         :: proc "c" (index: u32, v: ^[4]i8)                                                                       {        impl_VertexAttrib4Nbv(index, v)                                                       }
	glVertexAttrib4Niv         :: proc "c" (index: u32, v: ^[4]i32)                                                                      {        impl_VertexAttrib4Niv(index, v)                                                       }
	glVertexAttrib4Nsv         :: proc "c" (index: u32, v: ^[4]i16)                                                                      {        impl_VertexAttrib4Nsv(index, v)                                                       }
	glVertexAttrib4Nub         :: proc "c" (index: u32, x: u8, y: u8, z: u8, w: u8)                                                     {        impl_VertexAttrib4Nub(index, x, y, z, w)                                              }
	glVertexAttrib4Nubv        :: proc "c" (index: u32, v: ^[4]u8)                                                                       {        impl_VertexAttrib4Nubv(index, v)                                                      }
	glVertexAttrib4Nuiv        :: proc "c" (index: u32, v: ^[4]u32)                                                                      {        impl_VertexAttrib4Nuiv(index, v)                                                      }
	glVertexAttrib4Nusv        :: proc "c" (index: u32, v: ^[4]u16)                                                                      {        impl_VertexAttrib4Nusv(index, v)                                                      }
	glVertexAttrib4bv          :: proc "c" (index: u32, v: ^[4]i8)                                                                       {        impl_VertexAttrib4bv(index, v)                                                        }
	glVertexAttrib4d           :: proc "c" (index: u32, x: f64, y: f64, z: f64, w: f64)                                                 {        impl_VertexAttrib4d(index, x, y, z, w)                                                }
	glVertexAttrib4dv          :: proc "c" (index: u32, v: ^[4]f64)                                                                      {        impl_VertexAttrib4dv(index, v)                                                        }
	glVertexAttrib4f           :: proc "c" (index: u32, x: f32, y: f32, z: f32, w: f32)                                                 {        impl_VertexAttrib4f(index, x, y, z, w)                                                }
	glVertexAttrib4fv          :: proc "c" (index: u32, v: ^[4]f32)                                                                      {        impl_VertexAttrib4fv(index, v)                                                        }
	glVertexAttrib4iv          :: proc "c" (index: u32, v: ^[4]i32)                                                                      {        impl_VertexAttrib4iv(index, v)                                                        }
	glVertexAttrib4s           :: proc "c" (index: u32, x: i16, y: i16, z: i16, w: i16)                                                 {        impl_VertexAttrib4s(index, x, y, z, w)                                                }
	glVertexAttrib4sv          :: proc "c" (index: u32, v: ^[4]i16)                                                                      {        impl_VertexAttrib4sv(index, v)                                                        }
	glVertexAttrib4ubv         :: proc "c" (index: u32, v: ^[4]u8)                                                                       {        impl_VertexAttrib4ubv(index, v)                                                       }
	glVertexAttrib4uiv         :: proc "c" (index: u32, v: ^[4]u32)                                                                      {        impl_VertexAttrib4uiv(index, v)                                                       }
	glVertexAttrib4usv         :: proc "c" (index: u32, v: ^[4]u16)                                                                      {        impl_VertexAttrib4usv(index, v)                                                       }
	glVertexAttribPointer      :: proc "c" (index: u32, size: i32, type: u32, normalized: bool, stride: i32, pointer: uintptr)           {        impl_VertexAttribPointer(index, size, type, normalized, stride, pointer)             }

	// VERSION_2_1
	glUniformMatrix2x3fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix2x3fv(location, count, transpose, value) }
	glUniformMatrix3x2fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix3x2fv(location, count, transpose, value) }
	glUniformMatrix2x4fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix2x4fv(location, count, transpose, value) }
	glUniformMatrix4x2fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix4x2fv(location, count, transpose, value) }
	glUniformMatrix3x4fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix3x4fv(location, count, transpose, value) }
	glUniformMatrix4x3fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32) { impl_UniformMatrix4x3fv(location, count, transpose, value) }


	// VERSION_3_0
	glColorMaski                          :: proc "c" (index: u32, r: bool, g: bool, b: bool, a: bool)                                                                         {        impl_ColorMaski(index, r, g, b, a)                                                                     }
	glGetBooleani_v                       :: proc "c" (target: u32, index: u32, data: ^bool)                                                                                   {        impl_GetBooleani_v(target, index, data)                                                                }
	glGetIntegeri_v                       :: proc "c" (target: u32, index: u32, data: ^i32)                                                                                    {        impl_GetIntegeri_v(target, index, data)                                                                }
	glEnablei                             :: proc "c" (target: u32, index: u32)                                                                                                {        impl_Enablei(target, index)                                                                            }
	glDisablei                            :: proc "c" (target: u32, index: u32)                                                                                                {        impl_Disablei(target, index)                                                                           }
	glIsEnabledi                          :: proc "c" (target: u32, index: u32) -> bool                                                                                        { ret := impl_IsEnabledi(target, index);                                                             return ret }
	glBeginTransformFeedback              :: proc "c" (primitiveMode: u32)                                                                                                     {        impl_BeginTransformFeedback(primitiveMode)                                                             }
	glEndTransformFeedback                :: proc "c" ()                                                                                                                       {        impl_EndTransformFeedback()                                                                            }
	glBindBufferRange                     :: proc "c" (target: u32, index: u32, buffer: u32, offset: int, size: int)                                                           {        impl_BindBufferRange(target, index, buffer, offset, size)                                              }
	glBindBufferBase                      :: proc "c" (target: u32, index: u32, buffer: u32)                                                                                   {        impl_BindBufferBase(target, index, buffer)                                                             }
	glTransformFeedbackVaryings           :: proc "c" (program: u32, count: i32, varyings: [^]cstring, bufferMode: u32)                                                        {        impl_TransformFeedbackVaryings(program, count, varyings, bufferMode)                                   }
	glGetTransformFeedbackVarying         :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8)                              {        impl_GetTransformFeedbackVarying(program, index, bufSize, length, size, type, name)                   }
	glClampColor                          :: proc "c" (target: u32, clamp: u32)                                                                                                {        impl_ClampColor(target, clamp)                                                                         }
	glBeginConditionalRender              :: proc "c" (id: u32, mode: u32)                                                                                                     {        impl_BeginConditionalRender(id, mode)                                                                  }
	glEndConditionalRender                :: proc "c" ()                                                                                                                       {        impl_EndConditionalRender()                                                                            }
	glVertexAttribIPointer                :: proc "c" (index: u32, size: i32, type: u32, stride: i32, pointer: uintptr)                                                         {        impl_VertexAttribIPointer(index, size, type, stride, pointer)                                         }
	glGetVertexAttribIiv                  :: proc "c" (index: u32, pname: u32, params: [^]i32)                                                                                 {        impl_GetVertexAttribIiv(index, pname, params)                                                          }
	glGetVertexAttribIuiv                 :: proc "c" (index: u32, pname: u32, params: [^]u32)                                                                                 {        impl_GetVertexAttribIuiv(index, pname, params)                                                         }
	glVertexAttribI1i                     :: proc "c" (index: u32, x: i32)                                                                                                     {        impl_VertexAttribI1i(index, x)                                                                         }
	glVertexAttribI2i                     :: proc "c" (index: u32, x: i32, y: i32)                                                                                             {        impl_VertexAttribI2i(index, x, y)                                                                      }
	glVertexAttribI3i                     :: proc "c" (index: u32, x: i32, y: i32, z: i32)                                                                                     {        impl_VertexAttribI3i(index, x, y, z)                                                                   }
	glVertexAttribI4i                     :: proc "c" (index: u32, x: i32, y: i32, z: i32, w: i32)                                                                             {        impl_VertexAttribI4i(index, x, y, z, w)                                                                }
	glVertexAttribI1ui                    :: proc "c" (index: u32, x: u32)                                                                                                     {        impl_VertexAttribI1ui(index, x)                                                                        }
	glVertexAttribI2ui                    :: proc "c" (index: u32, x: u32, y: u32)                                                                                             {        impl_VertexAttribI2ui(index, x, y)                                                                     }
	glVertexAttribI3ui                    :: proc "c" (index: u32, x: u32, y: u32, z: u32)                                                                                     {        impl_VertexAttribI3ui(index, x, y, z)                                                                  }
	glVertexAttribI4ui                    :: proc "c" (index: u32, x: u32, y: u32, z: u32, w: u32)                                                                             {        impl_VertexAttribI4ui(index, x, y, z, w)                                                               }
	glVertexAttribI1iv                    :: proc "c" (index: u32, v: [^]i32)                                                                                                    {        impl_VertexAttribI1iv(index, v)                                                                        }
	glVertexAttribI2iv                    :: proc "c" (index: u32, v: [^]i32)                                                                                                    {        impl_VertexAttribI2iv(index, v)                                                                        }
	glVertexAttribI3iv                    :: proc "c" (index: u32, v: [^]i32)                                                                                                    {        impl_VertexAttribI3iv(index, v)                                                                        }
	glVertexAttribI4iv                    :: proc "c" (index: u32, v: [^]i32)                                                                                                    {        impl_VertexAttribI4iv(index, v)                                                                        }
	glVertexAttribI1uiv                   :: proc "c" (index: u32, v: [^]u32)                                                                                                    {        impl_VertexAttribI1uiv(index, v)                                                                       }
	glVertexAttribI2uiv                   :: proc "c" (index: u32, v: [^]u32)                                                                                                    {        impl_VertexAttribI2uiv(index, v)                                                                       }
	glVertexAttribI3uiv                   :: proc "c" (index: u32, v: [^]u32)                                                                                                    {        impl_VertexAttribI3uiv(index, v)                                                                       }
	glVertexAttribI4uiv                   :: proc "c" (index: u32, v: [^]u32)                                                                                                    {        impl_VertexAttribI4uiv(index, v)                                                                       }
	glVertexAttribI4bv                    :: proc "c" (index: u32, v: [^]i8)                                                                                                     {        impl_VertexAttribI4bv(index, v)                                                                        }
	glVertexAttribI4sv                    :: proc "c" (index: u32, v: [^]i16)                                                                                                    {        impl_VertexAttribI4sv(index, v)                                                                        }
	glVertexAttribI4ubv                   :: proc "c" (index: u32, v: [^]u8)                                                                                                     {        impl_VertexAttribI4ubv(index, v)                                                                       }
	glVertexAttribI4usv                   :: proc "c" (index: u32, v: [^]u16)                                                                                                    {        impl_VertexAttribI4usv(index, v)                                                                       }
	glGetUniformuiv                       :: proc "c" (program: u32, location: i32, params: [^]u32)                                                                            {        impl_GetUniformuiv(program, location, params)                                                          }
	glBindFragDataLocation                :: proc "c" (program: u32, color: u32, name: cstring)                                                                                {        impl_BindFragDataLocation(program, color, name)                                                        }
	glGetFragDataLocation                 :: proc "c" (program: u32, name: cstring) -> i32                                                                                     { ret := impl_GetFragDataLocation(program, name);                                                    return ret }
	glUniform1ui                          :: proc "c" (location: i32, v0: u32)                                                                                                 {        impl_Uniform1ui(location, v0)                                                                          }
	glUniform2ui                          :: proc "c" (location: i32, v0: u32, v1: u32)                                                                                        {        impl_Uniform2ui(location, v0, v1)                                                                      }
	glUniform3ui                          :: proc "c" (location: i32, v0: u32, v1: u32, v2: u32)                                                                               {        impl_Uniform3ui(location, v0, v1, v2)                                                                  }
	glUniform4ui                          :: proc "c" (location: i32, v0: u32, v1: u32, v2: u32, v3: u32)                                                                      {        impl_Uniform4ui(location, v0, v1, v2, v3)                                                              }
	glUniform1uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32)                                                                               {        impl_Uniform1uiv(location, count, value)                                                               }
	glUniform2uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32)                                                                               {        impl_Uniform2uiv(location, count, value)                                                               }
	glUniform3uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32)                                                                               {        impl_Uniform3uiv(location, count, value)                                                               }
	glUniform4uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32)                                                                               {        impl_Uniform4uiv(location, count, value)                                                               }
	glTexParameterIiv                     :: proc "c" (target: u32, pname: u32, params: [^]i32)                                                                                {        impl_TexParameterIiv(target, pname, params)                                                            }
	glTexParameterIuiv                    :: proc "c" (target: u32, pname: u32, params: [^]u32)                                                                                {        impl_TexParameterIuiv(target, pname, params)                                                           }
	glGetTexParameterIiv                  :: proc "c" (target: u32, pname: u32, params: [^]i32)                                                                                {        impl_GetTexParameterIiv(target, pname, params)                                                         }
	glGetTexParameterIuiv                 :: proc "c" (target: u32, pname: u32, params: [^]u32)                                                                                {        impl_GetTexParameterIuiv(target, pname, params)                                                        }
	glClearBufferiv                       :: proc "c" (buffer: u32, drawbuffer: i32, value: ^i32)                                                                              {        impl_ClearBufferiv(buffer, drawbuffer, value)                                                          }
	glClearBufferuiv                      :: proc "c" (buffer: u32, drawbuffer: i32, value: ^u32)                                                                              {        impl_ClearBufferuiv(buffer, drawbuffer, value)                                                         }
	glClearBufferfv                       :: proc "c" (buffer: u32, drawbuffer: i32, value: ^f32)                                                                              {        impl_ClearBufferfv(buffer, drawbuffer, value)                                                          }
	glClearBufferfi                       :: proc "c" (buffer: u32, drawbuffer: i32, depth: f32, stencil: i32) -> rawptr                                                       { ret := impl_ClearBufferfi(buffer, drawbuffer, depth, stencil);                                     return ret }
	glGetStringi                          :: proc "c" (name: u32, index: u32) -> cstring                                                                                       { ret := impl_GetStringi(name, index);                                                               return ret }
	glIsRenderbuffer                      :: proc "c" (renderbuffer: u32) -> bool                                                                                              { ret := impl_IsRenderbuffer(renderbuffer);                                                          return ret }
	glBindRenderbuffer                    :: proc "c" (target: u32, renderbuffer: u32)                                                                                         {        impl_BindRenderbuffer(target, renderbuffer)                                                            }
	glDeleteRenderbuffers                 :: proc "c" (n: i32, renderbuffers: [^]u32)                                                                                          {        impl_DeleteRenderbuffers(n, renderbuffers)                                                             }
	glGenRenderbuffers                    :: proc "c" (n: i32, renderbuffers: [^]u32)                                                                                          {        impl_GenRenderbuffers(n, renderbuffers)                                                                }
	glRenderbufferStorage                 :: proc "c" (target: u32, internalformat: u32, width: i32, height: i32)                                                              {        impl_RenderbufferStorage(target, internalformat, width, height)                                        }
	glGetRenderbufferParameteriv          :: proc "c" (target: u32, pname: u32, params: [^]i32)                                                                                {        impl_GetRenderbufferParameteriv(target, pname, params)                                                 }
	glIsFramebuffer                       :: proc "c" (framebuffer: u32) -> bool                                                                                               { ret := impl_IsFramebuffer(framebuffer);                                                            return ret }
	glBindFramebuffer                     :: proc "c" (target: u32, framebuffer: u32)                                                                                          {        impl_BindFramebuffer(target, framebuffer)                                                              }
	glDeleteFramebuffers                  :: proc "c" (n: i32, framebuffers: [^]u32)                                                                                           {        impl_DeleteFramebuffers(n, framebuffers)                                                               }
	glGenFramebuffers                     :: proc "c" (n: i32, framebuffers: [^]u32)                                                                                           {        impl_GenFramebuffers(n, framebuffers)                                                                  }
	glCheckFramebufferStatus              :: proc "c" (target: u32) -> u32                                                                                                     { ret := impl_CheckFramebufferStatus(target);                                                        return ret }
	glFramebufferTexture1D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32)                                                 {        impl_FramebufferTexture1D(target, attachment, textarget, texture, level)                               }
	glFramebufferTexture2D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32)                                                 {        impl_FramebufferTexture2D(target, attachment, textarget, texture, level)                               }
	glFramebufferTexture3D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, zoffset: i32)                                   {        impl_FramebufferTexture3D(target, attachment, textarget, texture, level, zoffset)                      }
	glFramebufferRenderbuffer             :: proc "c" (target: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32)                                               {        impl_FramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer)                     }
	glGetFramebufferAttachmentParameteriv :: proc "c" (target: u32, attachment: u32, pname: u32, params: [^]i32)                                                               {        impl_GetFramebufferAttachmentParameteriv(target, attachment, pname, params)                            }
	glGenerateMipmap                      :: proc "c" (target: u32)                                                                                                            {        impl_GenerateMipmap(target)                                                                            }
	glBlitFramebuffer                     :: proc "c" (srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32) {        impl_BlitFramebuffer(srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter)             }
	glRenderbufferStorageMultisample      :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32)                                                {        impl_RenderbufferStorageMultisample(target, samples, internalformat, width, height)                    }
	glFramebufferTextureLayer             :: proc "c" (target: u32, attachment: u32, texture: u32, level: i32, layer: i32)                                                     {        impl_FramebufferTextureLayer(target, attachment, texture, level, layer)                                }
	glMapBufferRange                      :: proc "c" (target: u32, offset: int, length: int, access: u32) -> rawptr                                                           { ret := impl_MapBufferRange(target, offset, length, access);                                        return ret }
	glFlushMappedBufferRange              :: proc "c" (target: u32, offset: int, length: int)                                                                                  {        impl_FlushMappedBufferRange(target, offset, length)                                                    }
	glBindVertexArray                     :: proc "c" (array: u32)                                                                                                             {        impl_BindVertexArray(array)                                                                            }
	glDeleteVertexArrays                  :: proc "c" (n: i32, arrays: [^]u32)                                                                                                 {        impl_DeleteVertexArrays(n, arrays)                                                                     }
	glGenVertexArrays                     :: proc "c" (n: i32, arrays: [^]u32)                                                                                                 {        impl_GenVertexArrays(n, arrays)                                                                        }
	glIsVertexArray                       :: proc "c" (array: u32) -> bool                                                                                                     { ret := impl_IsVertexArray(array);                                                                  return ret }

	// VERSION_3_1
	glDrawArraysInstanced       :: proc "c" (mode: u32, first: i32, count: i32, instancecount: i32)                                     {        impl_DrawArraysInstanced(mode, first, count, instancecount)                                               }
	glDrawElementsInstanced     :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32)                     {        impl_DrawElementsInstanced(mode, count, type, indices, instancecount)                                    }
	glTexBuffer                 :: proc "c" (target: u32, internalformat: u32, buffer: u32)                                             {        impl_TexBuffer(target, internalformat, buffer)                                                            }
	glPrimitiveRestartIndex     :: proc "c" (index: u32)                                                                                {        impl_PrimitiveRestartIndex(index)                                                                         }
	glCopyBufferSubData         :: proc "c" (readTarget: u32, writeTarget: u32, readOffset: int, writeOffset: int, size: int)           {        impl_CopyBufferSubData(readTarget, writeTarget, readOffset, writeOffset, size)                            }
	glGetUniformIndices         :: proc "c" (program: u32, uniformCount: i32, uniformNames: [^]cstring, uniformIndices: [^]u32)         {        impl_GetUniformIndices(program, uniformCount, uniformNames, uniformIndices)                               }
	glGetActiveUniformsiv       :: proc "c" (program: u32, uniformCount: i32, uniformIndices: [^]u32, pname: u32, params: [^]i32)       {        impl_GetActiveUniformsiv(program, uniformCount, uniformIndices, pname, params)                            }
	glGetActiveUniformName      :: proc "c" (program: u32, uniformIndex: u32, bufSize: i32, length: ^i32, uniformName: [^]u8)           {        impl_GetActiveUniformName(program, uniformIndex, bufSize, length, uniformName)                            }
	glGetUniformBlockIndex      :: proc "c" (program: u32, uniformBlockName: cstring) -> u32                                            { ret := impl_GetUniformBlockIndex(program, uniformBlockName);                                          return ret }
	glGetActiveUniformBlockiv   :: proc "c" (program: u32, uniformBlockIndex: u32, pname: u32, params: [^]i32)                          {        impl_GetActiveUniformBlockiv(program, uniformBlockIndex, pname, params)                                   }
	glGetActiveUniformBlockName :: proc "c" (program: u32, uniformBlockIndex: u32, bufSize: i32, length: ^i32, uniformBlockName: [^]u8) {        impl_GetActiveUniformBlockName(program, uniformBlockIndex, bufSize, length, uniformBlockName)             }
	glUniformBlockBinding       :: proc "c" (program: u32, uniformBlockIndex: u32, uniformBlockBinding: u32)                            {        impl_UniformBlockBinding(program, uniformBlockIndex, uniformBlockBinding)                                 }

	// VERSION_3_2
	glDrawElementsBaseVertex          :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, basevertex: i32)                                            {        impl_DrawElementsBaseVertex(mode, count, type, indices, basevertex)                                                }
	glDrawRangeElementsBaseVertex     :: proc "c" (mode: u32, start: u32, end: u32, count: i32, type: u32, indices: rawptr, basevertex: i32)                      {        impl_DrawRangeElementsBaseVertex(mode, start, end, count, type, indices, basevertex)                               }
	glDrawElementsInstancedBaseVertex :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32, basevertex: i32)                        {        impl_DrawElementsInstancedBaseVertex(mode, count, type, indices, instancecount, basevertex)                        }
	glMultiDrawElementsBaseVertex     :: proc "c" (mode: u32, count: [^]i32, type: u32, indices: [^]rawptr, drawcount: i32, basevertex: [^]i32)                   {        impl_MultiDrawElementsBaseVertex(mode, count, type, indices, drawcount, basevertex)                                }
	glProvokingVertex                 :: proc "c" (mode: u32)                                                                                                     {        impl_ProvokingVertex(mode)                                                                                          }
	glFenceSync                       :: proc "c" (condition: u32, flags: u32) -> sync_t                                                                          { ret := impl_FenceSync(condition, flags);                                                                        return ret }
	glIsSync                          :: proc "c" (sync: sync_t) -> bool                                                                                          { ret := impl_IsSync(sync);                                                                                       return ret }
	glDeleteSync                      :: proc "c" (sync: sync_t)                                                                                                  {        impl_DeleteSync(sync)                                                                                               }
	glClientWaitSync                  :: proc "c" (sync: sync_t, flags: u32, timeout: u64) -> u32                                                                 { ret := impl_ClientWaitSync(sync, flags, timeout);                                                               return ret }
	glWaitSync                        :: proc "c" (sync: sync_t, flags: u32, timeout: u64)                                                                        {        impl_WaitSync(sync, flags, timeout)                                                                                 }
	glGetInteger64v                   :: proc "c" (pname: u32, data: ^i64)                                                                                        {        impl_GetInteger64v(pname, data)                                                                                     }
	glGetSynciv                       :: proc "c" (sync: sync_t, pname: u32, bufSize: i32, length: ^i32, values: [^]i32)                                          {        impl_GetSynciv(sync, pname, bufSize, length, values)                                                                }
	glGetInteger64i_v                 :: proc "c" (target: u32, index: u32, data: ^i64)                                                                           {        impl_GetInteger64i_v(target, index, data)                                                                           }
	glGetBufferParameteri64v          :: proc "c" (target: u32, pname: u32, params: [^]i64)                                                                       {        impl_GetBufferParameteri64v(target, pname, params)                                                                  }
	glFramebufferTexture              :: proc "c" (target: u32, attachment: u32, texture: u32, level: i32)                                                        {        impl_FramebufferTexture(target, attachment, texture, level)                                                         }
	glTexImage2DMultisample           :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: bool)             {        impl_TexImage2DMultisample(target, samples, internalformat, width, height, fixedsamplelocations)                    }
	glTexImage3DMultisample           :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: bool) {        impl_TexImage3DMultisample(target, samples, internalformat, width, height, depth, fixedsamplelocations)             }
	glGetMultisamplefv                :: proc "c" (pname: u32, index: u32, val: ^f32)                                                                             {        impl_GetMultisamplefv(pname, index, val)                                                                            }
	glSampleMaski                     :: proc "c" (maskNumber: u32, mask: u32)                                                                                    {        impl_SampleMaski(maskNumber, mask)                                                                                  }

	// VERSION_3_3
	glBindFragDataLocationIndexed :: proc "c" (program: u32, colorNumber: u32, index: u32, name: cstring) {        impl_BindFragDataLocationIndexed(program, colorNumber, index, name)             }
	glGetFragDataIndex            :: proc "c" (program: u32, name: cstring) -> i32                        { ret := impl_GetFragDataIndex(program, name);                                return ret }
	glGenSamplers                 :: proc "c" (count: i32, samplers: [^]u32)                              {        impl_GenSamplers(count, samplers)                                               }
	glDeleteSamplers              :: proc "c" (count: i32, samplers: [^]u32)                              {        impl_DeleteSamplers(count, samplers)                                            }
	glIsSampler                   :: proc "c" (sampler: u32) -> bool                                      { ret := impl_IsSampler(sampler);                                             return ret }
	glBindSampler                 :: proc "c" (unit: u32, sampler: u32)                                   {        impl_BindSampler(unit, sampler)                                                 }
	glSamplerParameteri           :: proc "c" (sampler: u32, pname: u32, param: i32)                      {        impl_SamplerParameteri(sampler, pname, param)                                   }
	glSamplerParameteriv          :: proc "c" (sampler: u32, pname: u32, param: ^i32)                     {        impl_SamplerParameteriv(sampler, pname, param)                                  }
	glSamplerParameterf           :: proc "c" (sampler: u32, pname: u32, param: f32)                      {        impl_SamplerParameterf(sampler, pname, param)                                   }
	glSamplerParameterfv          :: proc "c" (sampler: u32, pname: u32, param: ^f32)                     {        impl_SamplerParameterfv(sampler, pname, param)                                  }
	glSamplerParameterIiv         :: proc "c" (sampler: u32, pname: u32, param: ^i32)                     {        impl_SamplerParameterIiv(sampler, pname, param)                                 }
	glSamplerParameterIuiv        :: proc "c" (sampler: u32, pname: u32, param: ^u32)                     {        impl_SamplerParameterIuiv(sampler, pname, param)                                }
	glGetSamplerParameteriv       :: proc "c" (sampler: u32, pname: u32, params: [^]i32)                  {        impl_GetSamplerParameteriv(sampler, pname, params)                              }
	glGetSamplerParameterIiv      :: proc "c" (sampler: u32, pname: u32, params: [^]i32)                  {        impl_GetSamplerParameterIiv(sampler, pname, params)                             }
	glGetSamplerParameterfv       :: proc "c" (sampler: u32, pname: u32, params: [^]f32)                  {        impl_GetSamplerParameterfv(sampler, pname, params)                              }
	glGetSamplerParameterIuiv     :: proc "c" (sampler: u32, pname: u32, params: [^]u32)                  {        impl_GetSamplerParameterIuiv(sampler, pname, params)                            }
	glQueryCounter                :: proc "c" (id: u32, target: u32)                                      {        impl_QueryCounter(id, target)                                                   }
	glGetQueryObjecti64v          :: proc "c" (id: u32, pname: u32, params: [^]i64)                       {        impl_GetQueryObjecti64v(id, pname, params)                                      }
	glGetQueryObjectui64v         :: proc "c" (id: u32, pname: u32, params: [^]u64)                       {        impl_GetQueryObjectui64v(id, pname, params)                                     }
	glVertexAttribDivisor         :: proc "c" (index: u32, divisor: u32)                                  {        impl_VertexAttribDivisor(index, divisor)                                        }
	glVertexAttribP1ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32)       {        impl_VertexAttribP1ui(index, type, normalized, value)                          }
	glVertexAttribP1uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)      {        impl_VertexAttribP1uiv(index, type, normalized, value)                         }
	glVertexAttribP2ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32)       {        impl_VertexAttribP2ui(index, type, normalized, value)                          }
	glVertexAttribP2uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)      {        impl_VertexAttribP2uiv(index, type, normalized, value)                         }
	glVertexAttribP3ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32)       {        impl_VertexAttribP3ui(index, type, normalized, value)                          }
	glVertexAttribP3uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)      {        impl_VertexAttribP3uiv(index, type, normalized, value)                         }
	glVertexAttribP4ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32)       {        impl_VertexAttribP4ui(index, type, normalized, value)                          }
	glVertexAttribP4uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32)      {        impl_VertexAttribP4uiv(index, type, normalized, value)                         }
	glVertexP2ui                  :: proc "c" (type: u32, value: u32)                                     {        impl_VertexP2ui(type, value)                                                   }
	glVertexP2uiv                 :: proc "c" (type: u32, value: ^u32)                                    {        impl_VertexP2uiv(type, value)                                                  }
	glVertexP3ui                  :: proc "c" (type: u32, value: u32)                                     {        impl_VertexP3ui(type, value)                                                   }
	glVertexP3uiv                 :: proc "c" (type: u32, value: ^u32)                                    {        impl_VertexP3uiv(type, value)                                                  }
	glVertexP4ui                  :: proc "c" (type: u32, value: u32)                                     {        impl_VertexP4ui(type, value)                                                   }
	glVertexP4uiv                 :: proc "c" (type: u32, value: ^u32)                                    {        impl_VertexP4uiv(type, value)                                                  }
	glTexCoordP1ui                :: proc "c" (type: u32, coords: u32)                                    {        impl_TexCoordP1ui(type, coords)                                                }
	glTexCoordP1uiv               :: proc "c" (type: u32, coords: [^]u32)                                 {        impl_TexCoordP1uiv(type, coords)                                               }
	glTexCoordP2ui                :: proc "c" (type: u32, coords: u32)                                    {        impl_TexCoordP2ui(type, coords)                                                }
	glTexCoordP2uiv               :: proc "c" (type: u32, coords: [^]u32)                                 {        impl_TexCoordP2uiv(type, coords)                                               }
	glTexCoordP3ui                :: proc "c" (type: u32, coords: u32)                                    {        impl_TexCoordP3ui(type, coords)                                                }
	glTexCoordP3uiv               :: proc "c" (type: u32, coords: [^]u32)                                 {        impl_TexCoordP3uiv(type, coords)                                               }
	glTexCoordP4ui                :: proc "c" (type: u32, coords: u32)                                    {        impl_TexCoordP4ui(type, coords)                                                }
	glTexCoordP4uiv               :: proc "c" (type: u32, coords: [^]u32)                                 {        impl_TexCoordP4uiv(type, coords)                                               }
	glMultiTexCoordP1ui           :: proc "c" (texture: u32, type: u32, coords: u32)                      {        impl_MultiTexCoordP1ui(texture, type, coords)                                  }
	glMultiTexCoordP1uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32)                   {        impl_MultiTexCoordP1uiv(texture, type, coords)                                 }
	glMultiTexCoordP2ui           :: proc "c" (texture: u32, type: u32, coords: u32)                      {        impl_MultiTexCoordP2ui(texture, type, coords)                                  }
	glMultiTexCoordP2uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32)                   {        impl_MultiTexCoordP2uiv(texture, type, coords)                                 }
	glMultiTexCoordP3ui           :: proc "c" (texture: u32, type: u32, coords: u32)                      {        impl_MultiTexCoordP3ui(texture, type, coords)                                  }
	glMultiTexCoordP3uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32)                   {        impl_MultiTexCoordP3uiv(texture, type, coords)                                 }
	glMultiTexCoordP4ui           :: proc "c" (texture: u32, type: u32, coords: u32)                      {        impl_MultiTexCoordP4ui(texture, type, coords)                                  }
	glMultiTexCoordP4uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32)                   {        impl_MultiTexCoordP4uiv(texture, type, coords)                                 }
	glNormalP3ui                  :: proc "c" (type: u32, coords: u32)                                    {        impl_NormalP3ui(type, coords)                                                  }
	glNormalP3uiv                 :: proc "c" (type: u32, coords: [^]u32)                                 {        impl_NormalP3uiv(type, coords)                                                 }
	glColorP3ui                   :: proc "c" (type: u32, color: u32)                                     {        impl_ColorP3ui(type, color)                                                    }
	glColorP3uiv                  :: proc "c" (type: u32, color: ^u32)                                    {        impl_ColorP3uiv(type, color)                                                   }
	glColorP4ui                   :: proc "c" (type: u32, color: u32)                                     {        impl_ColorP4ui(type, color)                                                    }
	glColorP4uiv                  :: proc "c" (type: u32, color: ^u32)                                    {        impl_ColorP4uiv(type, color)                                                   }
	glSecondaryColorP3ui          :: proc "c" (type: u32, color: u32)                                     {        impl_SecondaryColorP3ui(type, color)                                           }
	glSecondaryColorP3uiv         :: proc "c" (type: u32, color: ^u32)                                    {        impl_SecondaryColorP3uiv(type, color)                                          }

} else {
	debug_helper :: proc"c"(from_loc: runtime.Source_Code_Location, num_ret: int, args: ..any, loc := #caller_location) {
		context = runtime.default_context()

		Error_Enum :: enum GLenum {
			NO_ERROR = NO_ERROR,
			INVALID_VALUE = INVALID_VALUE,
			INVALID_ENUM = INVALID_ENUM,
			INVALID_OPERATION = INVALID_OPERATION,
			INVALID_FRAMEBUFFER_OPERATION = INVALID_FRAMEBUFFER_OPERATION,
			OUT_OF_MEMORY = OUT_OF_MEMORY,
			// STACK_UNDERFLOW = STACK_UNDERFLOW,
			// STACK_OVERFLOW = STACK_OVERFLOW,
			// TODO: What if the return enum is invalid?
		}

		// There can be multiple errors, so we're required to continuously call glGetError until there are no more errors
		for i := 0; /**/; i += 1 {
			err := cast(Error_Enum)impl_GetError()
			if err == .NO_ERROR { break }

			fmt.printf("%d: glGetError() returned GL_%v\n", i, err)

			// add function call
			fmt.printf("   call: gl%s(", loc.procedure)
			{
				// add input arguments
				for arg, arg_index in args[num_ret:] {
					if arg_index > 0 { fmt.printf(", ") }

					if v, ok := arg.(u32); ok { // TODO: Assumes all u32 are GLenum (they're not, GLbitfield and GLuint are also mapped to u32), fix later by better typing
						if err == .INVALID_ENUM {
							fmt.printf("INVALID_ENUM=%d", v)
						} else {
							fmt.printf("GL_%v=%d", GLenum(v), v)
						}
					} else {
						fmt.printf("%v", arg)
					}
				}

				// add return arguments
				if num_ret == 1 {
					fmt.printf(") -> %v \n", args[0])
				} else if num_ret > 1 {
					fmt.printf(") -> (")
					for arg, arg_index in args[1:num_ret] {
						if arg_index > 0 { fmt.printf(", ") }
						fmt.printf("%v", arg)
					}
					fmt.printf(")\n")
				} else {
					fmt.printf(")\n")
				}
			}

			// add location
			fmt.printf("   in:   %s(%d:%d)\n", from_loc.file_path, from_loc.line, from_loc.column)
		}
	}

	glCullFace               :: proc "c" (mode: u32, loc := #caller_location)                                                                                         {        impl_CullFace(mode);                                                                         debug_helper(loc, 0, mode)                                                                                   }
	glFrontFace              :: proc "c" (mode: u32, loc := #caller_location)                                                                                         {        impl_FrontFace(mode);                                                                        debug_helper(loc, 0, mode)                                                                                   }
	glHint                   :: proc "c" (target, mode: u32, loc := #caller_location)                                                                                 {        impl_Hint(target, mode);                                                                     debug_helper(loc, 0, target, mode)                                                                           }
	glLineWidth              :: proc "c" (width: f32, loc := #caller_location)                                                                                        {        impl_LineWidth(width);                                                                       debug_helper(loc, 0, width)                                                                                  }
	glPointSize              :: proc "c" (size: f32, loc := #caller_location)                                                                                         {        impl_PointSize(size);                                                                        debug_helper(loc, 0, size)                                                                                   }
	glPolygonMode            :: proc "c" (face, mode: u32, loc := #caller_location)                                                                                   {        impl_PolygonMode(face, mode);                                                                debug_helper(loc, 0, face, mode)                                                                             }
	glScissor                :: proc "c" (x, y, width, height: i32, loc := #caller_location)                                                                          {        impl_Scissor(x, y, width, height);                                                           debug_helper(loc, 0, x, y, width, height)                                                                    }
	glTexParameterf          :: proc "c" (target, pname: u32, param: f32, loc := #caller_location)                                                                    {        impl_TexParameterf(target, pname, param);                                                    debug_helper(loc, 0, target, pname, param)                                                                   }
	glTexParameterfv         :: proc "c" (target, pname: u32, params: [^]f32, loc := #caller_location)                                                                {        impl_TexParameterfv(target, pname, params);                                                  debug_helper(loc, 0, target, pname, params)                                                                  }
	glTexParameteri          :: proc "c" (target, pname: u32, param: i32, loc := #caller_location)                                                                    {        impl_TexParameteri(target, pname, param);                                                    debug_helper(loc, 0, target, pname, param)                                                                   }
	glTexParameteriv         :: proc "c" (target, pname: u32, params: [^]i32, loc := #caller_location)                                                                {        impl_TexParameteriv(target, pname, params);                                                  debug_helper(loc, 0, target, pname, params)                                                                  }
	glTexImage1D             :: proc "c" (target: u32, level, internalformat, width, border: i32, format, type: u32, pixels: rawptr, loc := #caller_location)         {        impl_TexImage1D(target, level, internalformat, width, border, format, type, pixels);         debug_helper(loc, 0, target, level, internalformat, width, border, format, type, pixels)                     }
	glTexImage2D             :: proc "c" (target: u32, level, internalformat, width, height, border: i32, format, type: u32, pixels: rawptr, loc := #caller_location) {        impl_TexImage2D(target, level, internalformat, width, height, border, format, type, pixels); debug_helper(loc, 0, target, level, internalformat, width, height, border, format, type, pixels)             }
	glDrawBuffer             :: proc "c" (buf: u32, loc := #caller_location)                                                                                          {        impl_DrawBuffer(buf);                                                                        debug_helper(loc, 0, buf)                                                                                    }
	glClear                  :: proc "c" (mask: u32, loc := #caller_location)                                                                                         {        impl_Clear(mask);                                                                            debug_helper(loc, 0, mask)                                                                                   }
	glClearColor             :: proc "c" (red, green, blue, alpha: f32, loc := #caller_location)                                                                      {        impl_ClearColor(red, green, blue, alpha);                                                    debug_helper(loc, 0, red, green, blue, alpha)                                                                }
	glClearStencil           :: proc "c" (s: i32, loc := #caller_location)                                                                                            {        impl_ClearStencil(s);                                                                        debug_helper(loc, 0, s)                                                                                      }
	glClearDepth             :: proc "c" (depth: f64, loc := #caller_location)                                                                                        {        impl_ClearDepth(depth);                                                                      debug_helper(loc, 0, depth)                                                                                  }
	glStencilMask            :: proc "c" (mask: u32, loc := #caller_location)                                                                                         {        impl_StencilMask(mask);                                                                      debug_helper(loc, 0, mask)                                                                                   }
	glColorMask              :: proc "c" (red, green, blue, alpha: bool, loc := #caller_location)                                                                     {        impl_ColorMask(red, green, blue, alpha);                                                     debug_helper(loc, 0, red, green, blue, alpha)                                                                }
	glDepthMask              :: proc "c" (flag: bool, loc := #caller_location)                                                                                        {        impl_DepthMask(flag);                                                                        debug_helper(loc, 0, flag)                                                                                   }
	glDisable                :: proc "c" (cap: u32, loc := #caller_location)                                                                                          {        impl_Disable(cap);                                                                           debug_helper(loc, 0, cap)                                                                                    }
	glEnable                 :: proc "c" (cap: u32, loc := #caller_location)                                                                                          {        impl_Enable(cap);                                                                            debug_helper(loc, 0, cap)                                                                                    }
	glFinish                 :: proc "c" (loc := #caller_location)                                                                                                    {        impl_Finish();                                                                               debug_helper(loc, 0)                                                                                         }
	glFlush                  :: proc "c" (loc := #caller_location)                                                                                                    {        impl_Flush();                                                                                debug_helper(loc, 0)                                                                                         }
	glBlendFunc              :: proc "c" (sfactor, dfactor: u32, loc := #caller_location)                                                                             {        impl_BlendFunc(sfactor, dfactor);                                                            debug_helper(loc, 0, sfactor, dfactor)                                                                       }
	glLogicOp                :: proc "c" (opcode: u32, loc := #caller_location)                                                                                       {        impl_LogicOp(opcode);                                                                        debug_helper(loc, 0, opcode)                                                                                 }
	glStencilFunc            :: proc "c" (func: u32, ref: i32, mask: u32, loc := #caller_location)                                                                    {        impl_StencilFunc(func, ref, mask);                                                           debug_helper(loc, 0, func, ref, mask)                                                                        }
	glStencilOp              :: proc "c" (fail, zfail, zpass: u32, loc := #caller_location)                                                                           {        impl_StencilOp(fail, zfail, zpass);                                                          debug_helper(loc, 0, fail, zfail, zpass)                                                                     }
	glDepthFunc              :: proc "c" (func: u32, loc := #caller_location)                                                                                         {        impl_DepthFunc(func);                                                                        debug_helper(loc, 0, func)                                                                                   }
	glPixelStoref            :: proc "c" (pname: u32, param: f32, loc := #caller_location)                                                                            {        impl_PixelStoref(pname, param);                                                              debug_helper(loc, 0, pname, param)                                                                           }
	glPixelStorei            :: proc "c" (pname: u32, param: i32, loc := #caller_location)                                                                            {        impl_PixelStorei(pname, param);                                                              debug_helper(loc, 0, pname, param)                                                                           }
	glReadBuffer             :: proc "c" (src: u32, loc := #caller_location)                                                                                          {        impl_ReadBuffer(src);                                                                        debug_helper(loc, 0, src)                                                                                    }
	glReadPixels             :: proc "c" (x, y, width, height: i32, format, type: u32, pixels: rawptr, loc := #caller_location)                                       {        impl_ReadPixels(x, y, width, height, format, type, pixels);                                  debug_helper(loc, 0, x, y, width, height, format, type, pixels)                                              }
	glGetBooleanv            :: proc "c" (pname: u32, data: ^bool, loc := #caller_location)                                                                           {        impl_GetBooleanv(pname, data);                                                               debug_helper(loc, 0, pname, data)                                                                            }
	glGetDoublev             :: proc "c" (pname: u32, data: ^f64, loc := #caller_location)                                                                            {        impl_GetDoublev(pname, data);                                                                debug_helper(loc, 0, pname, data)                                                                            }
	glGetError               :: proc "c" (loc := #caller_location) -> u32                                                                                             { ret := impl_GetError();                                                                             debug_helper(loc, 1, ret);                                                                        return ret }
	glGetFloatv              :: proc "c" (pname: u32, data: ^f32, loc := #caller_location)                                                                            {        impl_GetFloatv(pname, data);                                                                 debug_helper(loc, 0, pname, data)                                                                            }
	glGetIntegerv            :: proc "c" (pname: u32, data: ^i32, loc := #caller_location)                                                                            {        impl_GetIntegerv(pname, data);                                                               debug_helper(loc, 0, pname, data)                                                                            }
	glGetString              :: proc "c" (name: u32, loc := #caller_location) -> cstring                                                                              { ret := impl_GetString(name);                                                                        debug_helper(loc, 1, ret, name);                                                                  return ret }
	glGetTexImage            :: proc "c" (target: u32,  level: i32, format, type: u32, pixels: rawptr, loc := #caller_location)                                       {        impl_GetTexImage(target,  level, format, type, pixels);                                      debug_helper(loc, 0, target,  level, format, type, pixels)                                                   }
	glGetTexParameterfv      :: proc "c" (target, pname: u32, params: [^]f32, loc := #caller_location)                                                                {        impl_GetTexParameterfv(target, pname, params);                                               debug_helper(loc, 0, target, pname, params)                                                                  }
	glGetTexParameteriv      :: proc "c" (target, pname: u32, params: [^]i32, loc := #caller_location)                                                                {        impl_GetTexParameteriv(target, pname, params);                                               debug_helper(loc, 0, target, pname, params)                                                                  }
	glGetTexLevelParameterfv :: proc "c" (target: u32, level: i32, pname: u32, params: [^]f32, loc := #caller_location)                                               {        impl_GetTexLevelParameterfv(target, level, pname, params);                                   debug_helper(loc, 0, target, level, pname, params)                                                           }
	glGetTexLevelParameteriv :: proc "c" (target: u32, level: i32, pname: u32, params: [^]i32, loc := #caller_location)                                               {        impl_GetTexLevelParameteriv(target, level, pname, params);                                   debug_helper(loc, 0, target, level, pname, params)                                                           }
	glIsEnabled              :: proc "c" (cap: u32, loc := #caller_location) -> bool                                                                                  { ret := impl_IsEnabled(cap);                                                                         debug_helper(loc, 1, ret, cap);                                                                   return ret }
	glDepthRange             :: proc "c" (near, far: f64, loc := #caller_location)                                                                                    {        impl_DepthRange(near, far);                                                                  debug_helper(loc, 0, near, far)                                                                              }
	glViewport               :: proc "c" (x, y, width, height: i32, loc := #caller_location)                                                                          {        impl_Viewport(x, y, width, height);                                                          debug_helper(loc, 0, x, y, width, height)                                                                    }

	// VERSION_1_1
	glDrawArrays        :: proc "c" (mode: u32, first: i32, count: i32, loc := #caller_location)                                                                                    {        impl_DrawArrays(mode, first, count);                                                      debug_helper(loc, 0, mode, first, count)                                                               }
	glDrawElements      :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, loc := #caller_location)                                                                    {        impl_DrawElements(mode, count, type, indices);                                            debug_helper(loc, 0, mode, count, type, indices)                                                       }
	glPolygonOffset     :: proc "c" (factor: f32, units: f32, loc := #caller_location)                                                                                              {        impl_PolygonOffset(factor, units);                                                        debug_helper(loc, 0, factor, units)                                                                    }
	glCopyTexImage1D    :: proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, border: i32, loc := #caller_location)                                {        impl_CopyTexImage1D(target, level, internalformat, x, y, width, border);                  debug_helper(loc, 0, target, level, internalformat, x, y, width, border)                               }
	glCopyTexImage2D    :: proc "c" (target: u32, level: i32, internalformat: u32, x: i32, y: i32, width: i32, height: i32, border: i32, loc := #caller_location)                   {        impl_CopyTexImage2D(target, level, internalformat, x, y, width, height, border);          debug_helper(loc, 0, target, level, internalformat, x, y, width, height, border)                       }
	glCopyTexSubImage1D :: proc "c" (target: u32, level: i32, xoffset: i32, x: i32, y: i32, width: i32, loc := #caller_location)                                                    {        impl_CopyTexSubImage1D(target, level, xoffset, x, y, width);                              debug_helper(loc, 0, target, level, xoffset, x, y, width)                                              }
	glCopyTexSubImage2D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, x: i32, y: i32, width: i32, height: i32, loc := #caller_location)                         {        impl_CopyTexSubImage2D(target, level, xoffset, yoffset, x, y, width, height);             debug_helper(loc, 0, target, level, xoffset, yoffset, x, y, width, height)                             }
	glTexSubImage1D     :: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, type: u32, pixels: rawptr, loc := #caller_location)                            {        impl_TexSubImage1D(target, level, xoffset, width, format, type, pixels);                  debug_helper(loc, 0, target, level, xoffset, width, format, type, pixels)                              }
	glTexSubImage2D     :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, type: u32, pixels: rawptr, loc := #caller_location) {        impl_TexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels); debug_helper(loc, 0, target, level, xoffset, yoffset, width, height, format, type, pixels)             }
	glBindTexture       :: proc "c" (target: u32, texture: u32, loc := #caller_location)                                                                                            {        impl_BindTexture(target, texture);                                                        debug_helper(loc, 0, target, texture)                                                                  }
	glDeleteTextures    :: proc "c" (n: i32, textures: [^]u32, loc := #caller_location)                                                                                             {        impl_DeleteTextures(n, textures);                                                         debug_helper(loc, 0, n, textures)                                                                      }
	glGenTextures       :: proc "c" (n: i32, textures: [^]u32, loc := #caller_location)                                                                                             {        impl_GenTextures(n, textures);                                                            debug_helper(loc, 0, n, textures)                                                                      }
	glIsTexture         :: proc "c" (texture: u32, loc := #caller_location) -> bool                                                                                                 { ret := impl_IsTexture(texture);                                                                  debug_helper(loc, 1, ret, texture);                                                         return ret }

	// VERSION_1_2
	glDrawRangeElements :: proc "c" (mode, start, end: u32, count: i32, type: u32, indices: rawptr, loc := #caller_location)                                               { impl_DrawRangeElements(mode, start, end, count, type, indices);                                           debug_helper(loc, 0, mode, start, end, count, type, indices)                                               }
	glTexImage3D        :: proc "c" (target: u32, level, internalformat, width, height, depth, border: i32, format, type: u32, pixels: rawptr, loc := #caller_location)    { impl_TexImage3D(target, level, internalformat, width, height, depth, border, format, type, pixels);       debug_helper(loc, 0, target, level, internalformat, width, height, depth, border, format, type, pixels)    }
	glTexSubImage3D     :: proc "c" (target: u32, level, xoffset, yoffset, zoffset, width, height, depth: i32, format, type: u32, pixels: rawptr, loc := #caller_location) { impl_TexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pixels); debug_helper(loc, 0, target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pixels) }
	glCopyTexSubImage3D :: proc "c" (target: u32, level, xoffset, yoffset, zoffset, x, y, width, height: i32, loc := #caller_location)                                     { impl_CopyTexSubImage3D(target, level, xoffset, yoffset, zoffset, x, y, width, height);                    debug_helper(loc, 0, target, level, xoffset, yoffset, zoffset, x, y, width, height)                        }

	// VERSION_1_3
	glActiveTexture           :: proc "c" (texture: u32, loc := #caller_location)                                                                                                                                      { impl_ActiveTexture(texture);                                                                                           debug_helper(loc, 0, texture)                                                                                 }
	glSampleCoverage          :: proc "c" (value: f32, invert: bool, loc := #caller_location)                                                                                                                          { impl_SampleCoverage(value, invert);                                                                                    debug_helper(loc, 0, value, invert)                                                                           }
	glCompressedTexImage3D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, depth: i32, border: i32, imageSize: i32, data: rawptr, loc := #caller_location)                      { impl_CompressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, data);               debug_helper(loc, 0, target, level, internalformat, width, height, depth, border, imageSize, data)            }
	glCompressedTexImage2D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, height: i32, border: i32, imageSize: i32, data: rawptr, loc := #caller_location)                                  { impl_CompressedTexImage2D(target, level, internalformat, width, height, border, imageSize, data);                      debug_helper(loc, 0, target, level, internalformat, width, height, border, imageSize, data)                   }
	glCompressedTexImage1D    :: proc "c" (target: u32, level: i32, internalformat: u32, width: i32, border: i32, imageSize: i32, data: rawptr, loc := #caller_location)                                               { impl_CompressedTexImage1D(target, level, internalformat, width, border, imageSize, data);                              debug_helper(loc, 0, target, level, internalformat, width, border, imageSize, data)                           }
	glCompressedTexSubImage3D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, zoffset: i32, width: i32, height: i32, depth: i32, format: u32, imageSize: i32, data: rawptr, loc := #caller_location) { impl_CompressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, data); debug_helper(loc, 0, target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, data) }
	glCompressedTexSubImage2D :: proc "c" (target: u32, level: i32, xoffset: i32, yoffset: i32, width: i32, height: i32, format: u32, imageSize: i32, data: rawptr, loc := #caller_location)                           { impl_CompressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, data);                 debug_helper(loc, 0, target, level, xoffset, yoffset, width, height, format, imageSize, data)                 }
	glCompressedTexSubImage1D :: proc "c" (target: u32, level: i32, xoffset: i32, width: i32, format: u32, imageSize: i32, data: rawptr, loc := #caller_location)                                                      { impl_CompressedTexSubImage1D(target, level, xoffset, width, format, imageSize, data);                                  debug_helper(loc, 0, target, level, xoffset, width, format, imageSize, data)                                  }
	glGetCompressedTexImage   :: proc "c" (target: u32, level: i32, img: rawptr, loc := #caller_location)                                                                                                              { impl_GetCompressedTexImage(target, level, img);                                                                        debug_helper(loc, 0, target, level, img)                                                                      }

	// VERSION_1_4
	glBlendFuncSeparate :: proc "c" (sfactorRGB: u32, dfactorRGB: u32, sfactorAlpha: u32, dfactorAlpha: u32, loc := #caller_location)  { impl_BlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha); debug_helper(loc, 0, sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha) }
	glMultiDrawArrays   :: proc "c" (mode: u32, first: [^]i32, count: [^]i32, drawcount: i32, loc := #caller_location)                 { impl_MultiDrawArrays(mode, first, count, drawcount);                        debug_helper(loc, 0, mode, first, count, drawcount)                      }
	glMultiDrawElements :: proc "c" (mode: u32, count: [^]i32, type: u32, indices: [^]rawptr, drawcount: i32, loc := #caller_location) { impl_MultiDrawElements(mode, count, type, indices, drawcount);             debug_helper(loc, 0, mode, count, type, indices, drawcount)             }
	glPointParameterf   :: proc "c" (pname: u32, param: f32, loc := #caller_location)                                                  { impl_PointParameterf(pname, param);                                         debug_helper(loc, 0, pname, param)                                       }
	glPointParameterfv  :: proc "c" (pname: u32, params: [^]f32, loc := #caller_location)                                              { impl_PointParameterfv(pname, params);                                       debug_helper(loc, 0, pname, params)                                      }
	glPointParameteri   :: proc "c" (pname: u32, param: i32, loc := #caller_location)                                                  { impl_PointParameteri(pname, param);                                         debug_helper(loc, 0, pname, param)                                       }
	glPointParameteriv  :: proc "c" (pname: u32, params: [^]i32, loc := #caller_location)                                              { impl_PointParameteriv(pname, params);                                       debug_helper(loc, 0, pname, params)                                      }
	glBlendColor        :: proc "c" (red: f32, green: f32, blue: f32, alpha: f32, loc := #caller_location)                             { impl_BlendColor(red, green, blue, alpha);                                   debug_helper(loc, 0, red, green, blue, alpha)                            }
	glBlendEquation     :: proc "c" (mode: u32, loc := #caller_location)                                                               { impl_BlendEquation(mode);                                                   debug_helper(loc, 0, mode)                                               }

	// VERSION_1_5
	glGenQueries           :: proc "c" (n: i32, ids: [^]u32, loc := #caller_location)                               {        impl_GenQueries(n, ids);                           debug_helper(loc, 0, n, ids)                                 }
	glDeleteQueries        :: proc "c" (n: i32, ids: [^]u32, loc := #caller_location)                               {        impl_DeleteQueries(n, ids);                        debug_helper(loc, 0, n, ids)                                 }
	glIsQuery              :: proc "c" (id: u32, loc := #caller_location) -> bool                                   { ret := impl_IsQuery(id);                                  debug_helper(loc, 1, ret, id);                    return ret }
	glBeginQuery           :: proc "c" (target: u32, id: u32, loc := #caller_location)                              {        impl_BeginQuery(target, id);                       debug_helper(loc, 0, target, id)                             }
	glEndQuery             :: proc "c" (target: u32, loc := #caller_location)                                       {        impl_EndQuery(target);                             debug_helper(loc, 0, target)                                 }
	glGetQueryiv           :: proc "c" (target: u32, pname: u32, params: [^]i32, loc := #caller_location)           {        impl_GetQueryiv(target, pname, params);            debug_helper(loc, 0, target, pname, params)                  }
	glGetQueryObjectiv     :: proc "c" (id: u32, pname: u32, params: [^]i32, loc := #caller_location)               {        impl_GetQueryObjectiv(id, pname, params);          debug_helper(loc, 0, id, pname, params)                      }
	glGetQueryObjectuiv    :: proc "c" (id: u32, pname: u32, params: [^]u32, loc := #caller_location)               {        impl_GetQueryObjectuiv(id, pname, params);         debug_helper(loc, 0, id, pname, params)                      }
	glBindBuffer           :: proc "c" (target: u32, buffer: u32, loc := #caller_location)                          {        impl_BindBuffer(target, buffer);                   debug_helper(loc, 0, target, buffer)                         }
	glDeleteBuffers        :: proc "c" (n: i32, buffers: [^]u32, loc := #caller_location)                           {        impl_DeleteBuffers(n, buffers);                    debug_helper(loc, 0, n, buffers)                             }
	glGenBuffers           :: proc "c" (n: i32, buffers: [^]u32, loc := #caller_location)                           {        impl_GenBuffers(n, buffers);                       debug_helper(loc, 0, n, buffers)                             }
	glIsBuffer             :: proc "c" (buffer: u32, loc := #caller_location) -> bool                               { ret := impl_IsBuffer(buffer);                             debug_helper(loc, 1, ret, buffer);                return ret }
	glBufferData           :: proc "c" (target: u32, size: int, data: rawptr, usage: u32, loc := #caller_location)  {        impl_BufferData(target, size, data, usage);        debug_helper(loc, 0, target, size, data, usage)              }
	glBufferSubData        :: proc "c" (target: u32, offset: int, size: int, data: rawptr, loc := #caller_location) {        impl_BufferSubData(target, offset, size, data);    debug_helper(loc, 0, target, offset, size, data)             }
	glGetBufferSubData     :: proc "c" (target: u32, offset: int, size: int, data: rawptr, loc := #caller_location) {        impl_GetBufferSubData(target, offset, size, data); debug_helper(loc, 0, target, offset, size, data)             }
	glMapBuffer            :: proc "c" (target: u32, access: u32, loc := #caller_location) -> rawptr                { ret := impl_MapBuffer(target, access);                    debug_helper(loc, 1, ret, target, access);        return ret }
	glUnmapBuffer          :: proc "c" (target: u32, loc := #caller_location) -> bool                               { ret := impl_UnmapBuffer(target);                          debug_helper(loc, 1, ret, target);                return ret }
	glGetBufferParameteriv :: proc "c" (target: u32, pname: u32, params: [^]i32, loc := #caller_location)           {        impl_GetBufferParameteriv(target, pname, params);  debug_helper(loc, 0, target, pname, params)                  }
	glGetBufferPointerv    :: proc "c" (target: u32, pname: u32, params: [^]rawptr, loc := #caller_location)        {        impl_GetBufferPointerv(target, pname, params);     debug_helper(loc, 0, target, pname, params)                  }

	// VERSION_2_0
	glBlendEquationSeparate    :: proc "c" (modeRGB: u32, modeAlpha: u32, loc := #caller_location)                                                              {        impl_BlendEquationSeparate(modeRGB, modeAlpha);                            debug_helper(loc, 0, modeRGB, modeAlpha)                                             }
	glDrawBuffers              :: proc "c" (n: i32, bufs: [^]u32, loc := #caller_location)                                                                      {        impl_DrawBuffers(n, bufs);                                                 debug_helper(loc, 0, n, bufs)                                                        }
	glStencilOpSeparate        :: proc "c" (face: u32, sfail: u32, dpfail: u32, dppass: u32, loc := #caller_location)                                           {        impl_StencilOpSeparate(face, sfail, dpfail, dppass);                       debug_helper(loc, 0, face, sfail, dpfail, dppass)                                    }
	glStencilFuncSeparate      :: proc "c" (face: u32, func: u32, ref: i32, mask: u32, loc := #caller_location)                                                 {        impl_StencilFuncSeparate(face, func, ref, mask);                           debug_helper(loc, 0, face, func, ref, mask)                                          }
	glStencilMaskSeparate      :: proc "c" (face: u32, mask: u32, loc := #caller_location)                                                                      {        impl_StencilMaskSeparate(face, mask);                                      debug_helper(loc, 0, face, mask)                                                     }
	glAttachShader             :: proc "c" (program: u32, shader: u32, loc := #caller_location)                                                                 {        impl_AttachShader(program, shader);                                        debug_helper(loc, 0, program, shader)                                                }
	glBindAttribLocation       :: proc "c" (program: u32, index: u32, name: cstring, loc := #caller_location)                                                   {        impl_BindAttribLocation(program, index, name);                             debug_helper(loc, 0, program, index, name)                                           }
	glCompileShader            :: proc "c" (shader: u32, loc := #caller_location)                                                                               {        impl_CompileShader(shader);                                                debug_helper(loc, 0, shader)                                                         }
	glCreateProgram            :: proc "c" (loc := #caller_location) -> u32                                                                                     { ret := impl_CreateProgram();                                                      debug_helper(loc, 1, ret);                                                return ret }
	glCreateShader             :: proc "c" (type: u32, loc := #caller_location) -> u32                                                                          { ret := impl_CreateShader(type);                                                  debug_helper(loc, 1, ret, type);                                         return ret }
	glDeleteProgram            :: proc "c" (program: u32, loc := #caller_location)                                                                              {        impl_DeleteProgram(program);                                               debug_helper(loc, 0, program)                                                        }
	glDeleteShader             :: proc "c" (shader: u32, loc := #caller_location)                                                                               {        impl_DeleteShader(shader);                                                 debug_helper(loc, 0, shader)                                                         }
	glDetachShader             :: proc "c" (program: u32, shader: u32, loc := #caller_location)                                                                 {        impl_DetachShader(program, shader);                                        debug_helper(loc, 0, program, shader)                                                }
	glDisableVertexAttribArray :: proc "c" (index: u32, loc := #caller_location)                                                                                {        impl_DisableVertexAttribArray(index);                                      debug_helper(loc, 0, index)                                                          }
	glEnableVertexAttribArray  :: proc "c" (index: u32, loc := #caller_location)                                                                                {        impl_EnableVertexAttribArray(index);                                       debug_helper(loc, 0, index)                                                          }
	glGetActiveAttrib          :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8, loc := #caller_location) {        impl_GetActiveAttrib(program, index, bufSize, length, size, type, name);  debug_helper(loc, 0, program, index, bufSize, length, size, type, name)             }
	glGetActiveUniform         :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8, loc := #caller_location) {        impl_GetActiveUniform(program, index, bufSize, length, size, type, name); debug_helper(loc, 0, program, index, bufSize, length, size, type, name)             }
	glGetAttachedShaders       :: proc "c" (program: u32, maxCount: i32, count: [^]i32, shaders: [^]u32, loc := #caller_location)                               {        impl_GetAttachedShaders(program, maxCount, count, shaders);                debug_helper(loc, 0, program, maxCount, count, shaders)                              }
	glGetAttribLocation        :: proc "c" (program: u32, name: cstring, loc := #caller_location) -> i32                                                        { ret := impl_GetAttribLocation(program, name);                                     debug_helper(loc, 1, ret, program, name);                                 return ret }
	glGetProgramiv             :: proc "c" (program: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                  {        impl_GetProgramiv(program, pname, params);                                 debug_helper(loc, 0, program, pname, params)                                         }
	glGetProgramInfoLog        :: proc "c" (program: u32, bufSize: i32, length: ^i32, infoLog: [^]u8, loc := #caller_location)                                  {        impl_GetProgramInfoLog(program, bufSize, length, infoLog);                 debug_helper(loc, 0, program, bufSize, length, infoLog)                              }
	glGetShaderiv              :: proc "c" (shader: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                   {        impl_GetShaderiv(shader, pname, params);                                   debug_helper(loc, 0, shader, pname, params)                                          }
	glGetShaderInfoLog         :: proc "c" (shader: u32, bufSize: i32, length: ^i32, infoLog: [^]u8, loc := #caller_location)                                   {        impl_GetShaderInfoLog(shader, bufSize, length, infoLog);                   debug_helper(loc, 0, shader, bufSize, length, infoLog)                               }
	glGetShaderSource          :: proc "c" (shader: u32, bufSize: i32, length: ^i32, source: [^]u8, loc := #caller_location)                                    {        impl_GetShaderSource(shader, bufSize, length, source);                     debug_helper(loc, 0, shader, bufSize, length, source)                                }
	glGetUniformLocation       :: proc "c" (program: u32, name: cstring, loc := #caller_location) -> i32                                                        { ret := impl_GetUniformLocation(program, name);                                    debug_helper(loc, 1, ret, program, name);                                 return ret }
	glGetUniformfv             :: proc "c" (program: u32, location: i32, params: [^]f32, loc := #caller_location)                                               {        impl_GetUniformfv(program, location, params);                              debug_helper(loc, 0, program, location, params)                                      }
	glGetUniformiv             :: proc "c" (program: u32, location: i32, params: [^]i32, loc := #caller_location)                                               {        impl_GetUniformiv(program, location, params);                              debug_helper(loc, 0, program, location, params)                                      }
	glGetVertexAttribdv        :: proc "c" (index: u32, pname: u32, params: [^]f64, loc := #caller_location)                                                    {        impl_GetVertexAttribdv(index, pname, params);                              debug_helper(loc, 0, index, pname, params)                                           }
	glGetVertexAttribfv        :: proc "c" (index: u32, pname: u32, params: [^]f32, loc := #caller_location)                                                    {        impl_GetVertexAttribfv(index, pname, params);                              debug_helper(loc, 0, index, pname, params)                                           }
	glGetVertexAttribiv        :: proc "c" (index: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                    {        impl_GetVertexAttribiv(index, pname, params);                              debug_helper(loc, 0, index, pname, params)                                           }
	glGetVertexAttribPointerv  :: proc "c" (index: u32, pname: u32, pointer: ^uintptr, loc := #caller_location)                                                  {        impl_GetVertexAttribPointerv(index, pname, pointer);                       debug_helper(loc, 0, index, pname, pointer)                                          }
	glIsProgram                :: proc "c" (program: u32, loc := #caller_location) -> bool                                                                      { ret := impl_IsProgram(program);                                                   debug_helper(loc, 1, ret, program);                                       return ret }
	glIsShader                 :: proc "c" (shader: u32, loc := #caller_location) -> bool                                                                       { ret := impl_IsShader(shader);                                                     debug_helper(loc, 1, ret, shader);                                        return ret }
	glLinkProgram              :: proc "c" (program: u32, loc := #caller_location)                                                                              {        impl_LinkProgram(program);                                                 debug_helper(loc, 0, program)                                                        }
	glShaderSource             :: proc "c" (shader: u32, count: i32, string: [^]cstring, length: [^]i32, loc := #caller_location)                               {        impl_ShaderSource(shader, count, string, length);                          debug_helper(loc, 0, shader, count, string, length)                                  }
	glUseProgram               :: proc "c" (program: u32, loc := #caller_location)                                                                              {        impl_UseProgram(program);                                                  debug_helper(loc, 0, program)                                                        }
	glUniform1f                :: proc "c" (location: i32, v0: f32, loc := #caller_location)                                                                    {        impl_Uniform1f(location, v0);                                              debug_helper(loc, 0, location, v0)                                                   }
	glUniform2f                :: proc "c" (location: i32, v0: f32, v1: f32, loc := #caller_location)                                                           {        impl_Uniform2f(location, v0, v1);                                          debug_helper(loc, 0, location, v0, v1)                                               }
	glUniform3f                :: proc "c" (location: i32, v0: f32, v1: f32, v2: f32, loc := #caller_location)                                                  {        impl_Uniform3f(location, v0, v1, v2);                                      debug_helper(loc, 0, location, v0, v1, v2)                                           }
	glUniform4f                :: proc "c" (location: i32, v0: f32, v1: f32, v2: f32, v3: f32, loc := #caller_location)                                         {        impl_Uniform4f(location, v0, v1, v2, v3);                                  debug_helper(loc, 0, location, v0, v1, v2, v3)                                       }
	glUniform1i                :: proc "c" (location: i32, v0: i32, loc := #caller_location)                                                                    {        impl_Uniform1i(location, v0);                                              debug_helper(loc, 0, location, v0)                                                   }
	glUniform2i                :: proc "c" (location: i32, v0: i32, v1: i32, loc := #caller_location)                                                           {        impl_Uniform2i(location, v0, v1);                                          debug_helper(loc, 0, location, v0, v1)                                               }
	glUniform3i                :: proc "c" (location: i32, v0: i32, v1: i32, v2: i32, loc := #caller_location)                                                  {        impl_Uniform3i(location, v0, v1, v2);                                      debug_helper(loc, 0, location, v0, v1, v2)                                           }
	glUniform4i                :: proc "c" (location: i32, v0: i32, v1: i32, v2: i32, v3: i32, loc := #caller_location)                                         {        impl_Uniform4i(location, v0, v1, v2, v3);                                  debug_helper(loc, 0, location, v0, v1, v2, v3)                                       }
	glUniform1fv               :: proc "c" (location: i32, count: i32, value: [^]f32, loc := #caller_location)                                                  {        impl_Uniform1fv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform2fv               :: proc "c" (location: i32, count: i32, value: [^]f32, loc := #caller_location)                                                  {        impl_Uniform2fv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform3fv               :: proc "c" (location: i32, count: i32, value: [^]f32, loc := #caller_location)                                                  {        impl_Uniform3fv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform4fv               :: proc "c" (location: i32, count: i32, value: [^]f32, loc := #caller_location)                                                  {        impl_Uniform4fv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform1iv               :: proc "c" (location: i32, count: i32, value: [^]i32, loc := #caller_location)                                                  {        impl_Uniform1iv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform2iv               :: proc "c" (location: i32, count: i32, value: [^]i32, loc := #caller_location)                                                  {        impl_Uniform2iv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform3iv               :: proc "c" (location: i32, count: i32, value: [^]i32, loc := #caller_location)                                                  {        impl_Uniform3iv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniform4iv               :: proc "c" (location: i32, count: i32, value: [^]i32, loc := #caller_location)                                                  {        impl_Uniform4iv(location, count, value);                                   debug_helper(loc, 0, location, count, value)                                         }
	glUniformMatrix2fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location)                              {        impl_UniformMatrix2fv(location, count, transpose, value);                  debug_helper(loc, 0, location, count, transpose, value)                              }
	glUniformMatrix3fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location)                              {        impl_UniformMatrix3fv(location, count, transpose, value);                  debug_helper(loc, 0, location, count, transpose, value)                              }
	glUniformMatrix4fv         :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location)                              {        impl_UniformMatrix4fv(location, count, transpose, value);                  debug_helper(loc, 0, location, count, transpose, value)                              }
	glValidateProgram          :: proc "c" (program: u32, loc := #caller_location)                                                                              {        impl_ValidateProgram(program);                                             debug_helper(loc, 0, program)                                                        }
	glVertexAttrib1d           :: proc "c" (index: u32, x: f64, loc := #caller_location)                                                                        {        impl_VertexAttrib1d(index, x);                                             debug_helper(loc, 0, index, x)                                                       }
	glVertexAttrib1dv          :: proc "c" (index: u32, v: ^f64, loc := #caller_location)                                                                       {        impl_VertexAttrib1dv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib1f           :: proc "c" (index: u32, x: f32, loc := #caller_location)                                                                        {        impl_VertexAttrib1f(index, x);                                             debug_helper(loc, 0, index, x)                                                       }
	glVertexAttrib1fv          :: proc "c" (index: u32, v: ^f32, loc := #caller_location)                                                                       {        impl_VertexAttrib1fv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib1s           :: proc "c" (index: u32, x: i16, loc := #caller_location)                                                                        {        impl_VertexAttrib1s(index, x);                                             debug_helper(loc, 0, index, x)                                                       }
	glVertexAttrib1sv          :: proc "c" (index: u32, v: ^i16, loc := #caller_location)                                                                       {        impl_VertexAttrib1sv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib2d           :: proc "c" (index: u32, x: f64, y: f64, loc := #caller_location)                                                                {        impl_VertexAttrib2d(index, x, y);                                          debug_helper(loc, 0, index, x, y)                                                    }
	glVertexAttrib2dv          :: proc "c" (index: u32, v: ^[2]f64, loc := #caller_location)                                                                       {        impl_VertexAttrib2dv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib2f           :: proc "c" (index: u32, x: f32, y: f32, loc := #caller_location)                                                                {        impl_VertexAttrib2f(index, x, y);                                          debug_helper(loc, 0, index, x, y)                                                    }
	glVertexAttrib2fv          :: proc "c" (index: u32, v: ^[2]f32, loc := #caller_location)                                                                       {        impl_VertexAttrib2fv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib2s           :: proc "c" (index: u32, x: i16, y: i16, loc := #caller_location)                                                                {        impl_VertexAttrib2s(index, x, y);                                          debug_helper(loc, 0, index, x, y)                                                    }
	glVertexAttrib2sv          :: proc "c" (index: u32, v: ^[2]i16, loc := #caller_location)                                                                       {        impl_VertexAttrib2sv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib3d           :: proc "c" (index: u32, x: f64, y: f64, z: f64, loc := #caller_location)                                                        {        impl_VertexAttrib3d(index, x, y, z);                                       debug_helper(loc, 0, index, x, y, z)                                                 }
	glVertexAttrib3dv          :: proc "c" (index: u32, v: ^[3]f64, loc := #caller_location)                                                                       {        impl_VertexAttrib3dv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib3f           :: proc "c" (index: u32, x: f32, y: f32, z: f32, loc := #caller_location)                                                        {        impl_VertexAttrib3f(index, x, y, z);                                       debug_helper(loc, 0, index, x, y, z)                                                 }
	glVertexAttrib3fv          :: proc "c" (index: u32, v: ^[3]f32, loc := #caller_location)                                                                       {        impl_VertexAttrib3fv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib3s           :: proc "c" (index: u32, x: i16, y: i16, z: i16, loc := #caller_location)                                                        {        impl_VertexAttrib3s(index, x, y, z);                                       debug_helper(loc, 0, index, x, y, z)                                                 }
	glVertexAttrib3sv          :: proc "c" (index: u32, v: ^[3]i16, loc := #caller_location)                                                                       {        impl_VertexAttrib3sv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Nbv         :: proc "c" (index: u32, v: ^[4]i8, loc := #caller_location)                                                                        {        impl_VertexAttrib4Nbv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Niv         :: proc "c" (index: u32, v: ^[4]i32, loc := #caller_location)                                                                       {        impl_VertexAttrib4Niv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Nsv         :: proc "c" (index: u32, v: ^[4]i16, loc := #caller_location)                                                                       {        impl_VertexAttrib4Nsv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Nub         :: proc "c" (index: u32, x: u8, y: u8, z: u8, w: u8, loc := #caller_location)                                                    {        impl_VertexAttrib4Nub(index, x, y, z, w);                                  debug_helper(loc, 0, index, x, y, z, w)                                              }
	glVertexAttrib4Nubv        :: proc "c" (index: u32, v: ^[4]u8, loc := #caller_location)                                                                        {        impl_VertexAttrib4Nubv(index, v);                                          debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Nuiv        :: proc "c" (index: u32, v: ^[4]u32, loc := #caller_location)                                                                       {        impl_VertexAttrib4Nuiv(index, v);                                          debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4Nusv        :: proc "c" (index: u32, v: ^[4]u16, loc := #caller_location)                                                                       {        impl_VertexAttrib4Nusv(index, v);                                          debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4bv          :: proc "c" (index: u32, v: ^[4]i8, loc := #caller_location)                                                                        {        impl_VertexAttrib4bv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4d           :: proc "c" (index: u32, x: f64, y: f64, z: f64, w: f64, loc := #caller_location)                                                {        impl_VertexAttrib4d(index, x, y, z, w);                                    debug_helper(loc, 0, index, x, y, z, w)                                              }
	glVertexAttrib4dv          :: proc "c" (index: u32, v: ^[4]f64, loc := #caller_location)                                                                       {        impl_VertexAttrib4dv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4f           :: proc "c" (index: u32, x: f32, y: f32, z: f32, w: f32, loc := #caller_location)                                                {        impl_VertexAttrib4f(index, x, y, z, w);                                    debug_helper(loc, 0, index, x, y, z, w)                                              }
	glVertexAttrib4fv          :: proc "c" (index: u32, v: ^[4]f32, loc := #caller_location)                                                                       {        impl_VertexAttrib4fv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4iv          :: proc "c" (index: u32, v: ^[4]i32, loc := #caller_location)                                                                       {        impl_VertexAttrib4iv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4s           :: proc "c" (index: u32, x: i16, y: i16, z: i16, w: i16, loc := #caller_location)                                                {        impl_VertexAttrib4s(index, x, y, z, w);                                    debug_helper(loc, 0, index, x, y, z, w)                                              }
	glVertexAttrib4sv          :: proc "c" (index: u32, v: ^[4]i16, loc := #caller_location)                                                                       {        impl_VertexAttrib4sv(index, v);                                            debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4ubv         :: proc "c" (index: u32, v: ^[4]u8, loc := #caller_location)                                                                        {        impl_VertexAttrib4ubv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4uiv         :: proc "c" (index: u32, v: ^[4]u32, loc := #caller_location)                                                                       {        impl_VertexAttrib4uiv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttrib4usv         :: proc "c" (index: u32, v: ^[4]u16, loc := #caller_location)                                                                       {        impl_VertexAttrib4usv(index, v);                                           debug_helper(loc, 0, index, v)                                                       }
	glVertexAttribPointer      :: proc "c" (index: u32, size: i32, type: u32, normalized: bool, stride: i32, pointer: uintptr, loc := #caller_location)          {        impl_VertexAttribPointer(index, size, type, normalized, stride, pointer); debug_helper(loc, 0, index, size, type, normalized, stride, pointer)                }

	// VERSION_2_1
	glUniformMatrix2x3fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix2x3fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }
	glUniformMatrix3x2fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix3x2fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }
	glUniformMatrix2x4fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix2x4fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }
	glUniformMatrix4x2fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix4x2fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }
	glUniformMatrix3x4fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix3x4fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }
	glUniformMatrix4x3fv :: proc "c" (location: i32, count: i32, transpose: bool, value: [^]f32, loc := #caller_location) { impl_UniformMatrix4x3fv(location, count, transpose, value); debug_helper(loc, 0, location, count, transpose, value) }

	// VERSION_3_0
	glColorMaski                          :: proc "c" (index: u32, r: bool, g: bool, b: bool, a: bool, loc := #caller_location)                                                                         {        impl_ColorMaski(index, r, g, b, a);                                                         debug_helper(loc, 0, index, r, g, b, a)                                                                }
	glGetBooleani_v                       :: proc "c" (target: u32, index: u32, data: ^bool, loc := #caller_location)                                                                                   {        impl_GetBooleani_v(target, index, data);                                                    debug_helper(loc, 0, target, index, data)                                                              }
	glGetIntegeri_v                       :: proc "c" (target: u32, index: u32, data: ^i32, loc := #caller_location)                                                                                    {        impl_GetIntegeri_v(target, index, data);                                                    debug_helper(loc, 0, target, index, data)                                                              }
	glEnablei                             :: proc "c" (target: u32, index: u32, loc := #caller_location)                                                                                                {        impl_Enablei(target, index);                                                                debug_helper(loc, 0, target, index)                                                                    }
	glDisablei                            :: proc "c" (target: u32, index: u32, loc := #caller_location)                                                                                                {        impl_Disablei(target, index);                                                               debug_helper(loc, 0, target, index)                                                                    }
	glIsEnabledi                          :: proc "c" (target: u32, index: u32, loc := #caller_location) -> bool                                                                                        { ret := impl_IsEnabledi(target, index);                                                             debug_helper(loc, 1, ret, target, index);                                                   return ret }
	glBeginTransformFeedback              :: proc "c" (primitiveMode: u32, loc := #caller_location)                                                                                                     {        impl_BeginTransformFeedback(primitiveMode);                                                 debug_helper(loc, 0, primitiveMode)                                                                    }
	glEndTransformFeedback                :: proc "c" (loc := #caller_location)                                                                                                                         {        impl_EndTransformFeedback();                                                                debug_helper(loc, 0)                                                                                   }
	glBindBufferRange                     :: proc "c" (target: u32, index: u32, buffer: u32, offset: int, size: int, loc := #caller_location)                                                           {        impl_BindBufferRange(target, index, buffer, offset, size);                                  debug_helper(loc, 0, target, index, buffer, offset, size)                                              }
	glBindBufferBase                      :: proc "c" (target: u32, index: u32, buffer: u32, loc := #caller_location)                                                                                   {        impl_BindBufferBase(target, index, buffer);                                                 debug_helper(loc, 0, target, index, buffer)                                                            }
	glTransformFeedbackVaryings           :: proc "c" (program: u32, count: i32, varyings: [^]cstring, bufferMode: u32, loc := #caller_location)                                                        {        impl_TransformFeedbackVaryings(program, count, varyings, bufferMode);                       debug_helper(loc, 0, program, count, varyings, bufferMode)                                             }
	glGetTransformFeedbackVarying         :: proc "c" (program: u32, index: u32, bufSize: i32, length: ^i32, size: ^i32, type: ^u32, name: [^]u8, loc := #caller_location)                              {        impl_GetTransformFeedbackVarying(program, index, bufSize, length, size, type, name);       debug_helper(loc, 0, program, index, bufSize, length, size, type, name)                               }
	glClampColor                          :: proc "c" (target: u32, clamp: u32, loc := #caller_location)                                                                                                {        impl_ClampColor(target, clamp);                                                             debug_helper(loc, 0, target, clamp)                                                                    }
	glBeginConditionalRender              :: proc "c" (id: u32, mode: u32, loc := #caller_location)                                                                                                     {        impl_BeginConditionalRender(id, mode);                                                      debug_helper(loc, 0, id, mode)                                                                         }
	glEndConditionalRender                :: proc "c" (loc := #caller_location)                                                                                                                         {        impl_EndConditionalRender();                                                                debug_helper(loc, 0)                                                                                   }
	glVertexAttribIPointer                :: proc "c" (index: u32, size: i32, type: u32, stride: i32, pointer: uintptr, loc := #caller_location)                                                         {        impl_VertexAttribIPointer(index, size, type, stride, pointer);                             debug_helper(loc, 0, index, size, type, stride, pointer)                                              }
	glGetVertexAttribIiv                  :: proc "c" (index: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                                                 {        impl_GetVertexAttribIiv(index, pname, params);                                              debug_helper(loc, 0, index, pname, params)                                                             }
	glGetVertexAttribIuiv                 :: proc "c" (index: u32, pname: u32, params: [^]u32, loc := #caller_location)                                                                                 {        impl_GetVertexAttribIuiv(index, pname, params);                                             debug_helper(loc, 0, index, pname, params)                                                             }
	glVertexAttribI1i                     :: proc "c" (index: u32, x: i32, loc := #caller_location)                                                                                                     {        impl_VertexAttribI1i(index, x);                                                             debug_helper(loc, 0, index, x)                                                                         }
	glVertexAttribI2i                     :: proc "c" (index: u32, x: i32, y: i32, loc := #caller_location)                                                                                             {        impl_VertexAttribI2i(index, x, y);                                                          debug_helper(loc, 0, index, x, y)                                                                      }
	glVertexAttribI3i                     :: proc "c" (index: u32, x: i32, y: i32, z: i32, loc := #caller_location)                                                                                     {        impl_VertexAttribI3i(index, x, y, z);                                                       debug_helper(loc, 0, index, x, y, z)                                                                   }
	glVertexAttribI4i                     :: proc "c" (index: u32, x: i32, y: i32, z: i32, w: i32, loc := #caller_location)                                                                             {        impl_VertexAttribI4i(index, x, y, z, w);                                                    debug_helper(loc, 0, index, x, y, z, w)                                                                }
	glVertexAttribI1ui                    :: proc "c" (index: u32, x: u32, loc := #caller_location)                                                                                                     {        impl_VertexAttribI1ui(index, x);                                                            debug_helper(loc, 0, index, x)                                                                         }
	glVertexAttribI2ui                    :: proc "c" (index: u32, x: u32, y: u32, loc := #caller_location)                                                                                             {        impl_VertexAttribI2ui(index, x, y);                                                         debug_helper(loc, 0, index, x, y)                                                                      }
	glVertexAttribI3ui                    :: proc "c" (index: u32, x: u32, y: u32, z: u32, loc := #caller_location)                                                                                     {        impl_VertexAttribI3ui(index, x, y, z);                                                      debug_helper(loc, 0, index, x, y, z)                                                                   }
	glVertexAttribI4ui                    :: proc "c" (index: u32, x: u32, y: u32, z: u32, w: u32, loc := #caller_location)                                                                             {        impl_VertexAttribI4ui(index, x, y, z, w);                                                   debug_helper(loc, 0, index, x, y, z, w)                                                                }
	glVertexAttribI1iv                    :: proc "c" (index: u32, v: [^]i32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI1iv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI2iv                    :: proc "c" (index: u32, v: [^]i32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI2iv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI3iv                    :: proc "c" (index: u32, v: [^]i32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI3iv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4iv                    :: proc "c" (index: u32, v: [^]i32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI4iv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI1uiv                   :: proc "c" (index: u32, v: [^]u32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI1uiv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI2uiv                   :: proc "c" (index: u32, v: [^]u32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI2uiv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI3uiv                   :: proc "c" (index: u32, v: [^]u32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI3uiv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4uiv                   :: proc "c" (index: u32, v: [^]u32, loc := #caller_location)                                                                                                    {        impl_VertexAttribI4uiv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4bv                    :: proc "c" (index: u32, v: [^]i8, loc := #caller_location)                                                                                                     {        impl_VertexAttribI4bv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4sv                    :: proc "c" (index: u32, v: [^]i16, loc := #caller_location)                                                                                                    {        impl_VertexAttribI4sv(index, v);                                                            debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4ubv                   :: proc "c" (index: u32, v: [^]u8, loc := #caller_location)                                                                                                     {        impl_VertexAttribI4ubv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glVertexAttribI4usv                   :: proc "c" (index: u32, v: [^]u16, loc := #caller_location)                                                                                                    {        impl_VertexAttribI4usv(index, v);                                                           debug_helper(loc, 0, index, v)                                                                         }
	glGetUniformuiv                       :: proc "c" (program: u32, location: i32, params: [^]u32, loc := #caller_location)                                                                            {        impl_GetUniformuiv(program, location, params);                                              debug_helper(loc, 0, program, location, params)                                                        }
	glBindFragDataLocation                :: proc "c" (program: u32, color: u32, name: cstring, loc := #caller_location)                                                                                {        impl_BindFragDataLocation(program, color, name);                                            debug_helper(loc, 0, program, color, name)                                                             }
	glGetFragDataLocation                 :: proc "c" (program: u32, name: cstring, loc := #caller_location) -> i32                                                                                     { ret := impl_GetFragDataLocation(program, name);                                                    debug_helper(loc, 1, ret, program, name);                                                   return ret }
	glUniform1ui                          :: proc "c" (location: i32, v0: u32, loc := #caller_location)                                                                                                 {        impl_Uniform1ui(location, v0);                                                              debug_helper(loc, 0, location, v0)                                                                     }
	glUniform2ui                          :: proc "c" (location: i32, v0: u32, v1: u32, loc := #caller_location)                                                                                        {        impl_Uniform2ui(location, v0, v1);                                                          debug_helper(loc, 0, location, v0, v1)                                                                 }
	glUniform3ui                          :: proc "c" (location: i32, v0: u32, v1: u32, v2: u32, loc := #caller_location)                                                                               {        impl_Uniform3ui(location, v0, v1, v2);                                                      debug_helper(loc, 0, location, v0, v1, v2)                                                             }
	glUniform4ui                          :: proc "c" (location: i32, v0: u32, v1: u32, v2: u32, v3: u32, loc := #caller_location)                                                                      {        impl_Uniform4ui(location, v0, v1, v2, v3);                                                  debug_helper(loc, 0, location, v0, v1, v2, v3)                                                         }
	glUniform1uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32, loc := #caller_location)                                                                               {        impl_Uniform1uiv(location, count, value);                                                   debug_helper(loc, 0, location, count, value)                                                           }
	glUniform2uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32, loc := #caller_location)                                                                               {        impl_Uniform2uiv(location, count, value);                                                   debug_helper(loc, 0, location, count, value)                                                           }
	glUniform3uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32, loc := #caller_location)                                                                               {        impl_Uniform3uiv(location, count, value);                                                   debug_helper(loc, 0, location, count, value)                                                           }
	glUniform4uiv                         :: proc "c" (location: i32, count: i32, value: [^]u32, loc := #caller_location)                                                                               {        impl_Uniform4uiv(location, count, value);                                                   debug_helper(loc, 0, location, count, value)                                                           }
	glTexParameterIiv                     :: proc "c" (target: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                                                {        impl_TexParameterIiv(target, pname, params);                                                debug_helper(loc, 0, target, pname, params)                                                            }
	glTexParameterIuiv                    :: proc "c" (target: u32, pname: u32, params: [^]u32, loc := #caller_location)                                                                                {        impl_TexParameterIuiv(target, pname, params);                                               debug_helper(loc, 0, target, pname, params)                                                            }
	glGetTexParameterIiv                  :: proc "c" (target: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                                                {        impl_GetTexParameterIiv(target, pname, params);                                             debug_helper(loc, 0, target, pname, params)                                                            }
	glGetTexParameterIuiv                 :: proc "c" (target: u32, pname: u32, params: [^]u32, loc := #caller_location)                                                                                {        impl_GetTexParameterIuiv(target, pname, params);                                            debug_helper(loc, 0, target, pname, params)                                                            }
	glClearBufferiv                       :: proc "c" (buffer: u32, drawbuffer: i32, value: ^i32, loc := #caller_location)                                                                              {        impl_ClearBufferiv(buffer, drawbuffer, value);                                              debug_helper(loc, 0, buffer, drawbuffer, value)                                                        }
	glClearBufferuiv                      :: proc "c" (buffer: u32, drawbuffer: i32, value: ^u32, loc := #caller_location)                                                                              {        impl_ClearBufferuiv(buffer, drawbuffer, value);                                             debug_helper(loc, 0, buffer, drawbuffer, value)                                                        }
	glClearBufferfv                       :: proc "c" (buffer: u32, drawbuffer: i32, value: ^f32, loc := #caller_location)                                                                              {        impl_ClearBufferfv(buffer, drawbuffer, value);                                              debug_helper(loc, 0, buffer, drawbuffer, value)                                                        }
	glClearBufferfi                       :: proc "c" (buffer: u32, drawbuffer: i32, depth: f32, stencil: i32, loc := #caller_location) -> rawptr                                                       { ret := impl_ClearBufferfi(buffer, drawbuffer, depth, stencil);                                     debug_helper(loc, 1, ret, buffer, drawbuffer, depth, stencil);                              return ret }
	glGetStringi                          :: proc "c" (name: u32, index: u32, loc := #caller_location) -> cstring                                                                                       { ret := impl_GetStringi(name, index);                                                               debug_helper(loc, 1, ret, name, index);                                                     return ret }
	glIsRenderbuffer                      :: proc "c" (renderbuffer: u32, loc := #caller_location) -> bool                                                                                              { ret := impl_IsRenderbuffer(renderbuffer);                                                          debug_helper(loc, 1, ret, renderbuffer);                                                    return ret }
	glBindRenderbuffer                    :: proc "c" (target: u32, renderbuffer: u32, loc := #caller_location)                                                                                         {        impl_BindRenderbuffer(target, renderbuffer);                                                debug_helper(loc, 0, target, renderbuffer)                                                             }
	glDeleteRenderbuffers                 :: proc "c" (n: i32, renderbuffers: [^]u32, loc := #caller_location)                                                                                          {        impl_DeleteRenderbuffers(n, renderbuffers);                                                 debug_helper(loc, 0, n, renderbuffers)                                                                 }
	glGenRenderbuffers                    :: proc "c" (n: i32, renderbuffers: [^]u32, loc := #caller_location)                                                                                          {        impl_GenRenderbuffers(n, renderbuffers);                                                    debug_helper(loc, 0, n, renderbuffers)                                                                 }
	glRenderbufferStorage                 :: proc "c" (target: u32, internalformat: u32, width: i32, height: i32, loc := #caller_location)                                                              {        impl_RenderbufferStorage(target, internalformat, width, height);                            debug_helper(loc, 0, target, internalformat, width, height)                                            }
	glGetRenderbufferParameteriv          :: proc "c" (target: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                                                {        impl_GetRenderbufferParameteriv(target, pname, params);                                     debug_helper(loc, 0, target, pname, params)                                                            }
	glIsFramebuffer                       :: proc "c" (framebuffer: u32, loc := #caller_location) -> bool                                                                                               { ret := impl_IsFramebuffer(framebuffer);                                                            debug_helper(loc, 1, ret, framebuffer);                                                     return ret }
	glBindFramebuffer                     :: proc "c" (target: u32, framebuffer: u32, loc := #caller_location)                                                                                          {        impl_BindFramebuffer(target, framebuffer);                                                  debug_helper(loc, 0, target, framebuffer)                                                              }
	glDeleteFramebuffers                  :: proc "c" (n: i32, framebuffers: [^]u32, loc := #caller_location)                                                                                           {        impl_DeleteFramebuffers(n, framebuffers);                                                   debug_helper(loc, 0, n, framebuffers)                                                                  }
	glGenFramebuffers                     :: proc "c" (n: i32, framebuffers: [^]u32, loc := #caller_location)                                                                                           {        impl_GenFramebuffers(n, framebuffers);                                                      debug_helper(loc, 0, n, framebuffers)                                                                  }
	glCheckFramebufferStatus              :: proc "c" (target: u32, loc := #caller_location) -> u32                                                                                                     { ret := impl_CheckFramebufferStatus(target);                                                        debug_helper(loc, 1, ret, target);                                                          return ret }
	glFramebufferTexture1D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, loc := #caller_location)                                                 {        impl_FramebufferTexture1D(target, attachment, textarget, texture, level);                   debug_helper(loc, 0, target, attachment, textarget, texture, level)                                    }
	glFramebufferTexture2D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, loc := #caller_location)                                                 {        impl_FramebufferTexture2D(target, attachment, textarget, texture, level);                   debug_helper(loc, 0, target, attachment, textarget, texture, level)                                    }
	glFramebufferTexture3D                :: proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32, zoffset: i32, loc := #caller_location)                                   {        impl_FramebufferTexture3D(target, attachment, textarget, texture, level, zoffset);          debug_helper(loc, 0, target, attachment, textarget, texture, level, zoffset)                           }
	glFramebufferRenderbuffer             :: proc "c" (target: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32, loc := #caller_location)                                               {        impl_FramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer);         debug_helper(loc, 0, target, attachment, renderbuffertarget, renderbuffer)                             }
	glGetFramebufferAttachmentParameteriv :: proc "c" (target: u32, attachment: u32, pname: u32, params: [^]i32, loc := #caller_location)                                                               {        impl_GetFramebufferAttachmentParameteriv(target, attachment, pname, params);                debug_helper(loc, 0, target, attachment, pname, params)                                                }
	glGenerateMipmap                      :: proc "c" (target: u32, loc := #caller_location)                                                                                                            {        impl_GenerateMipmap(target);                                                                debug_helper(loc, 0, target)                                                                           }
	glBlitFramebuffer                     :: proc "c" (srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32, loc := #caller_location) {        impl_BlitFramebuffer(srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter); debug_helper(loc, 0, srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter)             }
	glRenderbufferStorageMultisample      :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, loc := #caller_location)                                                {        impl_RenderbufferStorageMultisample(target, samples, internalformat, width, height);        debug_helper(loc, 0, target, samples, internalformat, width, height)                                   }
	glFramebufferTextureLayer             :: proc "c" (target: u32, attachment: u32, texture: u32, level: i32, layer: i32, loc := #caller_location)                                                     {        impl_FramebufferTextureLayer(target, attachment, texture, level, layer);                    debug_helper(loc, 0, target, attachment, texture, level, layer)                                        }
	glMapBufferRange                      :: proc "c" (target: u32, offset: int, length: int, access: u32, loc := #caller_location) -> rawptr                                                           { ret := impl_MapBufferRange(target, offset, length, access);                                        debug_helper(loc, 1, ret, target, offset, length, access);                                  return ret }
	glFlushMappedBufferRange              :: proc "c" (target: u32, offset: int, length: int, loc := #caller_location)                                                                                  {        impl_FlushMappedBufferRange(target, offset, length);                                        debug_helper(loc, 0, target, offset, length)                                                           }
	glBindVertexArray                     :: proc "c" (array: u32, loc := #caller_location)                                                                                                             {        impl_BindVertexArray(array);                                                                debug_helper(loc, 0, array)                                                                            }
	glDeleteVertexArrays                  :: proc "c" (n: i32, arrays: [^]u32, loc := #caller_location)                                                                                                 {        impl_DeleteVertexArrays(n, arrays);                                                         debug_helper(loc, 0, n, arrays)                                                                        }
	glGenVertexArrays                     :: proc "c" (n: i32, arrays: [^]u32, loc := #caller_location)                                                                                                 {        impl_GenVertexArrays(n, arrays);                                                            debug_helper(loc, 0, n, arrays)                                                                        }
	glIsVertexArray                       :: proc "c" (array: u32, loc := #caller_location) -> bool                                                                                                     { ret := impl_IsVertexArray(array);                                                                  debug_helper(loc, 1, ret, array);                                                           return ret }

	// VERSION_3_1
	glDrawArraysInstanced       :: proc "c" (mode: u32, first: i32, count: i32, instancecount: i32, loc := #caller_location)                                     {        impl_DrawArraysInstanced(mode, first, count, instancecount);                                   debug_helper(loc, 0, mode, first, count, instancecount)            }
	glDrawElementsInstanced     :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32, loc := #caller_location)                     {        impl_DrawElementsInstanced(mode, count, type, indices, instancecount);                        debug_helper(loc, 0, mode, count, type, indices, instancecount)            }
	glTexBuffer                 :: proc "c" (target: u32, internalformat: u32, buffer: u32, loc := #caller_location)                                             {        impl_TexBuffer(target, internalformat, buffer);                                                debug_helper(loc, 0, target, internalformat, buffer)            }
	glPrimitiveRestartIndex     :: proc "c" (index: u32, loc := #caller_location)                                                                                {        impl_PrimitiveRestartIndex(index);                                                             debug_helper(loc, 0, index)            }
	glCopyBufferSubData         :: proc "c" (readTarget: u32, writeTarget: u32, readOffset: int, writeOffset: int, size: int, loc := #caller_location)           {        impl_CopyBufferSubData(readTarget, writeTarget, readOffset, writeOffset, size);                debug_helper(loc, 0, readTarget, writeTarget, readOffset, writeOffset, size)            }
	glGetUniformIndices         :: proc "c" (program: u32, uniformCount: i32, uniformNames: [^]cstring, uniformIndices: [^]u32, loc := #caller_location)         {        impl_GetUniformIndices(program, uniformCount, uniformNames, uniformIndices);                   debug_helper(loc, 0, program, uniformCount, uniformNames, uniformIndices)            }
	glGetActiveUniformsiv       :: proc "c" (program: u32, uniformCount: i32, uniformIndices: [^]u32, pname: u32, params: [^]i32, loc := #caller_location)       {        impl_GetActiveUniformsiv(program, uniformCount, uniformIndices, pname, params);                debug_helper(loc, 0, program, uniformCount, uniformIndices, pname, params)            }
	glGetActiveUniformName      :: proc "c" (program: u32, uniformIndex: u32, bufSize: i32, length: ^i32, uniformName: [^]u8, loc := #caller_location)           {        impl_GetActiveUniformName(program, uniformIndex, bufSize, length, uniformName);                debug_helper(loc, 0, program, uniformIndex, bufSize, length, uniformName)            }
	glGetUniformBlockIndex      :: proc "c" (program: u32, uniformBlockName: cstring, loc := #caller_location) -> u32                                            { ret := impl_GetUniformBlockIndex(program, uniformBlockName);                                          debug_helper(loc, 1, ret, program, uniformBlockName); return ret }
	glGetActiveUniformBlockiv   :: proc "c" (program: u32, uniformBlockIndex: u32, pname: u32, params: [^]i32, loc := #caller_location)                          {        impl_GetActiveUniformBlockiv(program, uniformBlockIndex, pname, params);                       debug_helper(loc, 0, program, uniformBlockIndex, pname, params)            }
	glGetActiveUniformBlockName :: proc "c" (program: u32, uniformBlockIndex: u32, bufSize: i32, length: ^i32, uniformBlockName: [^]u8, loc := #caller_location) {        impl_GetActiveUniformBlockName(program, uniformBlockIndex, bufSize, length, uniformBlockName); debug_helper(loc, 0, program, uniformBlockIndex, bufSize, length, uniformBlockName)            }
	glUniformBlockBinding       :: proc "c" (program: u32, uniformBlockIndex: u32, uniformBlockBinding: u32, loc := #caller_location)                            {        impl_UniformBlockBinding(program, uniformBlockIndex, uniformBlockBinding);                     debug_helper(loc, 0, program, uniformBlockIndex, uniformBlockBinding)            }

	// VERSION_3_2
	glDrawElementsBaseVertex          :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, basevertex: i32, loc := #caller_location)                                            {        impl_DrawElementsBaseVertex(mode, count, type, indices, basevertex);                                    debug_helper(loc, 0, mode, count, type, indices, basevertex)                                                 }
	glDrawRangeElementsBaseVertex     :: proc "c" (mode: u32, start: u32, end: u32, count: i32, type: u32, indices: rawptr, basevertex: i32, loc := #caller_location)                      {        impl_DrawRangeElementsBaseVertex(mode, start, end, count, type, indices, basevertex);                   debug_helper(loc, 0, mode, start, end, count, type, indices, basevertex)                                     }
	glDrawElementsInstancedBaseVertex :: proc "c" (mode: u32, count: i32, type: u32, indices: rawptr, instancecount: i32, basevertex: i32, loc := #caller_location)                        {        impl_DrawElementsInstancedBaseVertex(mode, count, type, indices, instancecount, basevertex);            debug_helper(loc, 0, mode, count, type, indices, instancecount, basevertex)                                  }
	glMultiDrawElementsBaseVertex     :: proc "c" (mode: u32, count: [^]i32, type: u32, indices: [^]rawptr, drawcount: i32, basevertex: [^]i32, loc := #caller_location)                   {        impl_MultiDrawElementsBaseVertex(mode, count, type, indices, drawcount, basevertex);                    debug_helper(loc, 0, mode, count, type, indices, drawcount, basevertex)                                      }
	glProvokingVertex                 :: proc "c" (mode: u32, loc := #caller_location)                                                                                                     {        impl_ProvokingVertex(mode);                                                                              debug_helper(loc, 0, mode)                                                                                    }
	glFenceSync                       :: proc "c" (condition: u32, flags: u32, loc := #caller_location) -> sync_t                                                                          { ret := impl_FenceSync(condition, flags);                                                                        debug_helper(loc, 1, ret, condition, flags);                                                       return ret }
	glIsSync                          :: proc "c" (sync: sync_t, loc := #caller_location) -> bool                                                                                          { ret := impl_IsSync(sync);                                                                                       debug_helper(loc, 1, ret, sync);                                                                   return ret }
	glDeleteSync                      :: proc "c" (sync: sync_t, loc := #caller_location)                                                                                                  {        impl_DeleteSync(sync);                                                                                   debug_helper(loc, 0, sync)                                                                                    }
	glClientWaitSync                  :: proc "c" (sync: sync_t, flags: u32, timeout: u64, loc := #caller_location) -> u32                                                                 { ret := impl_ClientWaitSync(sync, flags, timeout);                                                               debug_helper(loc, 1, ret, sync, flags, timeout);                                                   return ret }
	glWaitSync                        :: proc "c" (sync: sync_t, flags: u32, timeout: u64, loc := #caller_location)                                                                        {        impl_WaitSync(sync, flags, timeout);                                                                     debug_helper(loc, 0, sync, flags, timeout)                                                                    }
	glGetInteger64v                   :: proc "c" (pname: u32, data: ^i64, loc := #caller_location)                                                                                        {        impl_GetInteger64v(pname, data);                                                                         debug_helper(loc, 0, pname, data)                                                                             }
	glGetSynciv                       :: proc "c" (sync: sync_t, pname: u32, bufSize: i32, length: ^i32, values: [^]i32, loc := #caller_location)                                          {        impl_GetSynciv(sync, pname, bufSize, length, values);                                                    debug_helper(loc, 0, sync, pname, bufSize, length, values)                                                    }
	glGetInteger64i_v                 :: proc "c" (target: u32, index: u32, data: ^i64, loc := #caller_location)                                                                           {        impl_GetInteger64i_v(target, index, data);                                                               debug_helper(loc, 0, target, index, data)                                                                     }
	glGetBufferParameteri64v          :: proc "c" (target: u32, pname: u32, params: [^]i64, loc := #caller_location)                                                                       {        impl_GetBufferParameteri64v(target, pname, params);                                                      debug_helper(loc, 0, target, pname, params)                                                                   }
	glFramebufferTexture              :: proc "c" (target: u32, attachment: u32, texture: u32, level: i32, loc := #caller_location)                                                        {        impl_FramebufferTexture(target, attachment, texture, level);                                             debug_helper(loc, 0, target, attachment, texture, level)                                                      }
	glTexImage2DMultisample           :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, fixedsamplelocations: bool, loc := #caller_location)             {        impl_TexImage2DMultisample(target, samples, internalformat, width, height, fixedsamplelocations);        debug_helper(loc, 0, target, samples, internalformat, width, height, fixedsamplelocations)                    }
	glTexImage3DMultisample           :: proc "c" (target: u32, samples: i32, internalformat: u32, width: i32, height: i32, depth: i32, fixedsamplelocations: bool, loc := #caller_location) {        impl_TexImage3DMultisample(target, samples, internalformat, width, height, depth, fixedsamplelocations); debug_helper(loc, 0, target, samples, internalformat, width, height, depth, fixedsamplelocations)             }
	glGetMultisamplefv                :: proc "c" (pname: u32, index: u32, val: ^f32, loc := #caller_location)                                                                             {        impl_GetMultisamplefv(pname, index, val);                                                                debug_helper(loc, 0, pname, index, val)                                                                       }
	glSampleMaski                     :: proc "c" (maskNumber: u32, mask: u32, loc := #caller_location)                                                                                    {        impl_SampleMaski(maskNumber, mask);                                                                      debug_helper(loc, 0, maskNumber, mask)                                                                        }

	// VERSION_3_3
	glBindFragDataLocationIndexed :: proc "c" (program: u32, colorNumber: u32, index: u32, name: cstring, loc := #caller_location) {        impl_BindFragDataLocationIndexed(program, colorNumber, index, name); debug_helper(loc, 0, program, colorNumber, index, name)             }
	glGetFragDataIndex            :: proc "c" (program: u32, name: cstring, loc := #caller_location) -> i32                        { ret := impl_GetFragDataIndex(program, name);                                debug_helper(loc, 1, ret, program, name);                return ret }
	glGenSamplers                 :: proc "c" (count: i32, samplers: [^]u32, loc := #caller_location)                              {        impl_GenSamplers(count, samplers);                                   debug_helper(loc, 0, count, samplers)                               }
	glDeleteSamplers              :: proc "c" (count: i32, samplers: [^]u32, loc := #caller_location)                              {        impl_DeleteSamplers(count, samplers);                                debug_helper(loc, 0, count, samplers)                               }
	glIsSampler                   :: proc "c" (sampler: u32, loc := #caller_location) -> bool                                      { ret := impl_IsSampler(sampler);                                             debug_helper(loc, 1, ret, sampler);                      return ret }
	glBindSampler                 :: proc "c" (unit: u32, sampler: u32, loc := #caller_location)                                   {        impl_BindSampler(unit, sampler);                                     debug_helper(loc, 0, unit, sampler)                                 }
	glSamplerParameteri           :: proc "c" (sampler: u32, pname: u32, param: i32, loc := #caller_location)                      {        impl_SamplerParameteri(sampler, pname, param);                       debug_helper(loc, 0, sampler, pname, param)                         }
	glSamplerParameteriv          :: proc "c" (sampler: u32, pname: u32, param: ^i32, loc := #caller_location)                     {        impl_SamplerParameteriv(sampler, pname, param);                      debug_helper(loc, 0, sampler, pname, param)                         }
	glSamplerParameterf           :: proc "c" (sampler: u32, pname: u32, param: f32, loc := #caller_location)                      {        impl_SamplerParameterf(sampler, pname, param);                       debug_helper(loc, 0, sampler, pname, param)                         }
	glSamplerParameterfv          :: proc "c" (sampler: u32, pname: u32, param: ^f32, loc := #caller_location)                     {        impl_SamplerParameterfv(sampler, pname, param);                      debug_helper(loc, 0, sampler, pname, param)                         }
	glSamplerParameterIiv         :: proc "c" (sampler: u32, pname: u32, param: ^i32, loc := #caller_location)                     {        impl_SamplerParameterIiv(sampler, pname, param);                     debug_helper(loc, 0, sampler, pname, param)                         }
	glSamplerParameterIuiv        :: proc "c" (sampler: u32, pname: u32, param: ^u32, loc := #caller_location)                     {        impl_SamplerParameterIuiv(sampler, pname, param);                    debug_helper(loc, 0, sampler, pname, param)                         }
	glGetSamplerParameteriv       :: proc "c" (sampler: u32, pname: u32, params: [^]i32, loc := #caller_location)                  {        impl_GetSamplerParameteriv(sampler, pname, params);                  debug_helper(loc, 0, sampler, pname, params)                        }
	glGetSamplerParameterIiv      :: proc "c" (sampler: u32, pname: u32, params: [^]i32, loc := #caller_location)                  {        impl_GetSamplerParameterIiv(sampler, pname, params);                 debug_helper(loc, 0, sampler, pname, params)                        }
	glGetSamplerParameterfv       :: proc "c" (sampler: u32, pname: u32, params: [^]f32, loc := #caller_location)                  {        impl_GetSamplerParameterfv(sampler, pname, params);                  debug_helper(loc, 0, sampler, pname, params)                        }
	glGetSamplerParameterIuiv     :: proc "c" (sampler: u32, pname: u32, params: [^]u32, loc := #caller_location)                  {        impl_GetSamplerParameterIuiv(sampler, pname, params);                debug_helper(loc, 0, sampler, pname, params)                        }
	glQueryCounter                :: proc "c" (id: u32, target: u32, loc := #caller_location)                                      {        impl_QueryCounter(id, target);                                       debug_helper(loc, 0, id, target)                                    }
	glGetQueryObjecti64v          :: proc "c" (id: u32, pname: u32, params: [^]i64, loc := #caller_location)                       {        impl_GetQueryObjecti64v(id, pname, params);                          debug_helper(loc, 0, id, pname, params)                             }
	glGetQueryObjectui64v         :: proc "c" (id: u32, pname: u32, params: [^]u64, loc := #caller_location)                       {        impl_GetQueryObjectui64v(id, pname, params);                         debug_helper(loc, 0, id, pname, params)                             }
	glVertexAttribDivisor         :: proc "c" (index: u32, divisor: u32, loc := #caller_location)                                  {        impl_VertexAttribDivisor(index, divisor);                            debug_helper(loc, 0, index, divisor)                                }
	glVertexAttribP1ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32, loc := #caller_location)       {        impl_VertexAttribP1ui(index, type, normalized, value);              debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP1uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32, loc := #caller_location)      {        impl_VertexAttribP1uiv(index, type, normalized, value);             debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP2ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32, loc := #caller_location)       {        impl_VertexAttribP2ui(index, type, normalized, value);              debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP2uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32, loc := #caller_location)      {        impl_VertexAttribP2uiv(index, type, normalized, value);             debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP3ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32, loc := #caller_location)       {        impl_VertexAttribP3ui(index, type, normalized, value);              debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP3uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32, loc := #caller_location)      {        impl_VertexAttribP3uiv(index, type, normalized, value);             debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP4ui            :: proc "c" (index: u32, type: u32, normalized: bool, value: u32, loc := #caller_location)       {        impl_VertexAttribP4ui(index, type, normalized, value);              debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexAttribP4uiv           :: proc "c" (index: u32, type: u32, normalized: bool, value: ^u32, loc := #caller_location)      {        impl_VertexAttribP4uiv(index, type, normalized, value);             debug_helper(loc, 0, index, type, normalized, value)               }
	glVertexP2ui                  :: proc "c" (type: u32, value: u32, loc := #caller_location)                                     {        impl_VertexP2ui(type, value);                                       debug_helper(loc, 0, type, value)                                  }
	glVertexP2uiv                 :: proc "c" (type: u32, value: ^u32, loc := #caller_location)                                    {        impl_VertexP2uiv(type, value);                                      debug_helper(loc, 0, type, value)                                  }
	glVertexP3ui                  :: proc "c" (type: u32, value: u32, loc := #caller_location)                                     {        impl_VertexP3ui(type, value);                                       debug_helper(loc, 0, type, value)                                  }
	glVertexP3uiv                 :: proc "c" (type: u32, value: ^u32, loc := #caller_location)                                    {        impl_VertexP3uiv(type, value);                                      debug_helper(loc, 0, type, value)                                  }
	glVertexP4ui                  :: proc "c" (type: u32, value: u32, loc := #caller_location)                                     {        impl_VertexP4ui(type, value);                                       debug_helper(loc, 0, type, value)                                  }
	glVertexP4uiv                 :: proc "c" (type: u32, value: ^u32, loc := #caller_location)                                    {        impl_VertexP4uiv(type, value);                                      debug_helper(loc, 0, type, value)                                  }
	glTexCoordP1ui                :: proc "c" (type: u32, coords: u32, loc := #caller_location)                                    {        impl_TexCoordP1ui(type, coords);                                    debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP1uiv               :: proc "c" (type: u32, coords: [^]u32, loc := #caller_location)                                 {        impl_TexCoordP1uiv(type, coords);                                   debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP2ui                :: proc "c" (type: u32, coords: u32, loc := #caller_location)                                    {        impl_TexCoordP2ui(type, coords);                                    debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP2uiv               :: proc "c" (type: u32, coords: [^]u32, loc := #caller_location)                                 {        impl_TexCoordP2uiv(type, coords);                                   debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP3ui                :: proc "c" (type: u32, coords: u32, loc := #caller_location)                                    {        impl_TexCoordP3ui(type, coords);                                    debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP3uiv               :: proc "c" (type: u32, coords: [^]u32, loc := #caller_location)                                 {        impl_TexCoordP3uiv(type, coords);                                   debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP4ui                :: proc "c" (type: u32, coords: u32, loc := #caller_location)                                    {        impl_TexCoordP4ui(type, coords);                                    debug_helper(loc, 0, type, coords)                                 }
	glTexCoordP4uiv               :: proc "c" (type: u32, coords: [^]u32, loc := #caller_location)                                 {        impl_TexCoordP4uiv(type, coords);                                   debug_helper(loc, 0, type, coords)                                 }
	glMultiTexCoordP1ui           :: proc "c" (texture: u32, type: u32, coords: u32, loc := #caller_location)                      {        impl_MultiTexCoordP1ui(texture, type, coords);                      debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP1uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32, loc := #caller_location)                   {        impl_MultiTexCoordP1uiv(texture, type, coords);                     debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP2ui           :: proc "c" (texture: u32, type: u32, coords: u32, loc := #caller_location)                      {        impl_MultiTexCoordP2ui(texture, type, coords);                      debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP2uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32, loc := #caller_location)                   {        impl_MultiTexCoordP2uiv(texture, type, coords);                     debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP3ui           :: proc "c" (texture: u32, type: u32, coords: u32, loc := #caller_location)                      {        impl_MultiTexCoordP3ui(texture, type, coords);                      debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP3uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32, loc := #caller_location)                   {        impl_MultiTexCoordP3uiv(texture, type, coords);                     debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP4ui           :: proc "c" (texture: u32, type: u32, coords: u32, loc := #caller_location)                      {        impl_MultiTexCoordP4ui(texture, type, coords);                      debug_helper(loc, 0, texture, type, coords)                        }
	glMultiTexCoordP4uiv          :: proc "c" (texture: u32, type: u32, coords: [^]u32, loc := #caller_location)                   {        impl_MultiTexCoordP4uiv(texture, type, coords);                     debug_helper(loc, 0, texture, type, coords)                        }
	glNormalP3ui                  :: proc "c" (type: u32, coords: u32, loc := #caller_location)                                    {        impl_NormalP3ui(type, coords);                                      debug_helper(loc, 0, type, coords)                                 }
	glNormalP3uiv                 :: proc "c" (type: u32, coords: [^]u32, loc := #caller_location)                                 {        impl_NormalP3uiv(type, coords);                                     debug_helper(loc, 0, type, coords)                                 }
	glColorP3ui                   :: proc "c" (type: u32, color: u32, loc := #caller_location)                                     {        impl_ColorP3ui(type, color);                                        debug_helper(loc, 0, type, color)                                  }
	glColorP3uiv                  :: proc "c" (type: u32, color: ^u32, loc := #caller_location)                                    {        impl_ColorP3uiv(type, color);                                       debug_helper(loc, 0, type, color)                                  }
	glColorP4ui                   :: proc "c" (type: u32, color: u32, loc := #caller_location)                                     {        impl_ColorP4ui(type, color);                                        debug_helper(loc, 0, type, color)                                  }
	glColorP4uiv                  :: proc "c" (type: u32, color: ^u32, loc := #caller_location)                                    {        impl_ColorP4uiv(type, color);                                       debug_helper(loc, 0, type, color)                                  }
	glSecondaryColorP3ui          :: proc "c" (type: u32, color: u32, loc := #caller_location)                                     {        impl_SecondaryColorP3ui(type, color);                               debug_helper(loc, 0, type, color)                                  }
	glSecondaryColorP3uiv         :: proc "c" (type: u32, color: ^u32, loc := #caller_location)                                    {        impl_SecondaryColorP3uiv(type, color);                              debug_helper(loc, 0, type, color)                                  }

}