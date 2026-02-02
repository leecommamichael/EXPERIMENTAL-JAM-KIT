package angle

import "core:log"
import "core:fmt"
import "base:intrinsics"
import "base:runtime"

// IDEA: when generating a buffer, optional parameter to name it and use that for debug info.
// This way we can give you a debug view of the GL state and what is bound.
// In debug mode, the context will have fields for the bound state and you can look around.

// If enabled: the package will call glGetError after relevant gl procedures.
NGL_VALIDATE :: #config(NGL_VALIDATE, ODIN_DEBUG)

// If enabled: the package will emit a debug trap on errors.
NGL_DEBUG :: #config(NGL_DEBUG, ODIN_DEBUG)

when NGL_DEBUG {
	#assert(NGL_VALIDATE, "Can't debug_trap if we aren't checking errors.")
}

validate :: proc (src_loc: runtime.Source_Code_Location) -> Error {
	when NGL_VALIDATE {
		err := cast(Error) GetError()
		when NGL_DEBUG {
			if err != Error.NO_ERROR {
				log.errorf("%v\n%v %v", err, src_loc, err)
				intrinsics.debug_trap()
			}
		}
		return err
	} else {
		return .NO_ERROR
	}
}

_bad_input :: proc (str: string, loc: runtime.Source_Code_Location) {
	log.errorf("%v\n%v %v", str, loc, str)
}

////////////////////////////////////////////////////////////////////// 
// GLES Types
////////////////////////////////////////////////////////////////////// 
// TODO: when 64bit {f64} else f32 (GL has flexible float widths.)
GLboolean :: bool
GLbyte :: i8
GLubyte :: u8 
GLchar :: u8  // Spec: "Characters making up strings"
GLshort :: i16
GLushort :: u16
GLint :: int
GLuint :: u32
GLint64 :: i64
GLuint64 :: u64
GLsizei :: int // Spec: Non-negative binary integer size
GLenum :: GLuint // Spec: Enumerated binary integer value
GLbitfield :: GLuint
GLfloat :: f32
GLdouble :: f64
GLclampf :: f32 // float clamped to [0,1]
GLintptr :: uintptr
GLsizeiptr :: GLuint
// GLhalf :: f16 // Spec: Doesn't exist in WebGL
// GLfixed ::  // not in web
// GLsync :: GLuint // not in web

////////////////////////////////////////////////////////////////////// 
// WebGL Types
////////////////////////////////////////////////////////////////////// 
Buffer       :: distinct GLuint
Framebuffer  :: distinct GLuint
Program      :: distinct GLuint
Renderbuffer :: distinct GLuint
Shader       :: distinct GLuint
Texture      :: distinct GLuint
// WebGL2 Types
Query             :: distinct GLuint
Sampler           :: distinct GLuint
Sync              :: distinct GLuint
TransformFeedback :: distinct GLuint
VertexArrayObject :: distinct GLuint

////////////////////////////////////////////////////////////////////// 
Buffer_Binding_Target :: enum GLenum {
	ARRAY_BUFFER         = ARRAY_BUFFER,
	ELEMENT_ARRAY_BUFFER = ELEMENT_ARRAY_BUFFER,
	UNIFORM_BUFFER       = UNIFORM_BUFFER,
	COPY_READ_BUFFER     = COPY_READ_BUFFER,
	COPY_WRITE_BUFFER    = COPY_WRITE_BUFFER,
	PIXEL_PACK_BUFFER    = PIXEL_PACK_BUFFER,
	PIXEL_UNPACK_BUFFER  = PIXEL_UNPACK_BUFFER,
	TRANSFORM_FEEDBACK   = TRANSFORM_FEEDBACK_BUFFER,

	// @Beginners: These may be easier to type/remember.
	Attributes = ARRAY_BUFFER,
	Indices    = ELEMENT_ARRAY_BUFFER,
	Uniforms   = UNIFORM_BUFFER,
}

// @Beginners: You probably want _Draw usages.
Buffer_Usage_Hint :: enum GLenum {
	// _Draw usages are for data you write to the GPU from the CPU.
	STATIC_DRAW = STATIC_DRAW,   // Rarely updated.     e.g. Static mesh data.
	DYNAMIC_DRAW = DYNAMIC_DRAW, // Frequently updated. e.g. Animated data.
	STREAM_DRAW = STREAM_DRAW,   // Updated each frame. e.g. Uniforms.

	// _Read usages are for data you read from the GPU to the CPU.
	STATIC_READ = STATIC_READ,
	DYNAMIC_READ = DYNAMIC_READ,
	STREAM_READ = STREAM_READ,

	// _Copy usages are for transfers from GPU memory to GPU memory.
	STATIC_COPY = STATIC_COPY,
	DYNAMIC_COPY = DYNAMIC_COPY,
	STREAM_COPY = STREAM_COPY,
}

Primitive_Mode :: enum GLenum {
	TRIANGLES      = TRIANGLES,
	LINES          = LINES,
	POINTS         = POINTS,
	TRIANGLE_STRIP = TRIANGLE_STRIP,
	TRIANGLE_FAN   = TRIANGLE_FAN,
	LINE_STRIP     = LINE_STRIP,
	LINE_LOOP      = LINE_LOOP,
}

Index_Type :: enum GLenum {
	UNSIGNED_BYTE  = UNSIGNED_BYTE,
	UNSIGNED_SHORT = UNSIGNED_SHORT,
	UNSIGNED_INT   = UNSIGNED_INT,
}

// Swizzling not present in WebGL
Set_Texture_Base_Level   :: proc (target: Texture_Parameter_Target, param: GLuint) {
	glTexParameteri(auto_cast target, TEXTURE_BASE_LEVEL, cast(int) param)
}
Set_Texture_Max_Level    :: proc (target: Texture_Parameter_Target, param: GLuint) {
	glTexParameteri(auto_cast target, TEXTURE_MAX_LEVEL, cast(int) param)
}
Set_Texture_Min_LOD      :: proc (target: Texture_Parameter_Target, param: f32) {
	glTexParameterf(auto_cast target, TEXTURE_MIN_LOD, param)
}
Set_Texture_Max_LOD      :: proc (target: Texture_Parameter_Target, param: f32) {
	glTexParameterf(auto_cast target, TEXTURE_MAX_LOD, param)
}
Set_Texture_Mag_Filter   :: proc (target: Texture_Parameter_Target, param: Texture_Mag_Filter) {
	glTexParameteri(auto_cast target, TEXTURE_MAG_FILTER, cast(int) param)
}
Set_Texture_Min_Filter   :: proc (target: Texture_Parameter_Target, param: Texture_Min_Filter) {
	glTexParameteri(auto_cast target, TEXTURE_MIN_FILTER, cast(int) param)
}
Set_Texture_Compare_Func :: proc (target: Texture_Parameter_Target, param: Compare_Func) {
	glTexParameteri(auto_cast target, TEXTURE_COMPARE_FUNC, cast(int) param)
}
Set_Texture_Compare_Mode :: proc (target: Texture_Parameter_Target, param: Texture_Compare_Mode) {
	glTexParameteri(auto_cast target, TEXTURE_COMPARE_MODE, cast(int) param)
}
Set_Texture_Wrap_S       :: proc (target: Texture_Parameter_Target, param: Texture_Wrap_Mode) {
	glTexParameteri(auto_cast target, TEXTURE_WRAP_S, cast(int) param)
}
Set_Texture_Wrap_T       :: proc (target: Texture_Parameter_Target, param: Texture_Wrap_Mode) {
	glTexParameteri(auto_cast target, TEXTURE_WRAP_T, cast(int) param)
}
Set_Texture_Wrap_R       :: proc (target: Texture_Parameter_Target, param: Texture_Wrap_Mode) {
	glTexParameteri(auto_cast target, TEXTURE_WRAP_R, cast(int) param)
}

// Set_Sampler_Base_Level   :: proc (target: Sampler, param: GLuint) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_BASE_LEVEL, cast(int) param)
// }
// Set_Sampler_Max_Level    :: proc (target: Sampler, param: GLuint) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_MAX_LEVEL, cast(int) param)
// }
// Set_Sampler_Min_LOD      :: proc (target: Sampler, param: f32) {
// 	glSamplerParameterf(auto_cast target, TEXTURE_MIN_LOD, param)
// }
// Set_Sampler_Max_LOD      :: proc (target: Sampler, param: f32) {
// 	glSamplerParameterf(auto_cast target, TEXTURE_MAX_LOD, param)
// }
// Set_Sampler_Mag_Filter   :: proc (target: Sampler, param: Texture_Mag_Filter) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_MAG_FILTER, cast(int) param)
// }
// Set_Sampler_Min_Filter   :: proc (target: Sampler, param: Texture_Min_Filter) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_MIN_FILTER, cast(int) param)
// }
// Set_Sampler_Compare_Func :: proc (target: Sampler, param: Compare_Func) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_COMPARE_FUNC, cast(int) param)
// }
// Set_Sampler_Compare_Mode :: proc (target: Sampler, param: Texture_Compare_Mode) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_COMPARE_MODE, cast(int) param)
// }
// Set_Sampler_Wrap_S       :: proc (target: Sampler, param: Texture_Wrap_Mode) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_WRAP_S, cast(int) param)
// }
// Set_Sampler_Wrap_T       :: proc (target: Sampler, param: Texture_Wrap_Mode) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_WRAP_T, cast(int) param)
// }
// Set_Sampler_Wrap_R       :: proc (target: Sampler, param: Texture_Wrap_Mode) {
// 	glSamplerParameteri(auto_cast target, TEXTURE_WRAP_R, cast(int) param)
// }


TexImage2D :: proc {
	make_texture_2D,
	TexImage2D_verbatim
}

make_texture_2D :: proc (
	target: Texture_2D_Target,
	internalformat: Internal_Color_Format,
	width, height: int,
	data: []u8,
	lod: int = 0,
	_loc := #caller_location
) -> ( err: Error = .NO_ERROR ) {
	info := Internal_Format_Infos[internalformat]
	TexImage2D_verbatim(
		target = target,
		level  = lod,
		internalformat = cast(int) info.gl_name,
		width = width, 
		height = height,
		format = cast(GLenum) info.format,
		type = cast(GLenum) info.type,
		data = data
	)
	when NGL_VALIDATE { return validate(_loc) } else { return }
}
