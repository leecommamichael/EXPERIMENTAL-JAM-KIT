package nord_gl

import "core:log"
import "core:fmt"
import "base:intrinsics"

// If enabled: the package will call glGetError after relevant gl procedures.
NGL_VALIDATE :: #config(NGL_VALIDATE, ODIN_DEBUG)

// If enabled: the package will emit a debug trap on errors.
NGL_DEBUG :: #config(NGL_DEBUG, ODIN_DEBUG)

when NGL_DEBUG {
	#assert(NGL_VALIDATE, "Can't debug_trap if we aren't checking errors.")
}

validate :: proc () -> Error {
	when NGL_VALIDATE {
		err := cast(Error) GetError()
		when NGL_DEBUG {
			if err != Error.NO_ERROR {
				intrinsics.debug_trap()
				fmt.printfln("debug_trap emitted.")
			}
		}
		return err
	} else {
		return .NO_ERROR
	}
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
GLuint :: uint
GLint64 :: i64
GLuint64 :: u64
GLsizei :: int // Spec: Non-negative binary integer size
GLenum :: uint // Spec: Enumerated binary integer value
GLbitfield :: uint
GLfloat :: f32
GLclampf :: f32 // float clamped to [0,1]
GLintptr :: i64
GLsizeiptr :: uint
// GLhalf :: f16 // Spec: Doesn't exist in WebGL
// GLfixed ::  // not in web
// GLsync :: uint // not in web

////////////////////////////////////////////////////////////////////// 
// WebGL Types
////////////////////////////////////////////////////////////////////// 
Buffer       :: distinct uint
Framebuffer  :: distinct uint
Program      :: distinct uint
Renderbuffer :: distinct uint
Shader       :: distinct uint
Texture      :: distinct uint
// WebGL2 Types
Query             :: distinct uint
Sampler           :: distinct uint
Sync              :: distinct uint
TransformFeedback :: distinct uint
VertexArrayObject :: distinct uint

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

// IDEA: when generating a buffer, optional parameter to name it and use that for debug info.
// This way we can give you a debug view of the GL state and what is bound.
// In debug mode, the context will have fields for the bound state and you can look around.

import "core:path/slashpath"
import "base:runtime"

_bad_input :: #force_inline proc (message: string, src_loc: runtime.Source_Code_Location) {
	// TODO: Before sharing this code, introduce a when config here.
	_, file := slashpath.split(src_loc.file_path)
	log.debugf("nord_gl\n" +
		"  Text│ %s\n" +
		"  File│ %s\n" +
		"  Line│ %v",
		 message, file, src_loc.line)
}