////////////////////////////////////////////////////////////////////////////////
// SECTION: Differences Between WebGL and OpenGL ES 2.0 
// 
// WebGL 1.0 Specification
// Editor's Draft Fri Feb 7 11:45:36 2025 -0800
////////////////////////////////////////////////////////////////////////////////
This section describes changes made to the WebGL API relative to the OpenGL ES 2.0 API to improve portability across various operating systems and devices.

6.1 Buffer Object Binding
In the WebGL API, a given buffer object may only be bound to one of the ARRAY_BUFFER or ELEMENT_ARRAY_BUFFER binding points in its lifetime. This restriction implies that a given buffer object may contain either vertices or indices, but not both.
The type of a WebGLBuffer is initialized the first time it is passed as an argument to bindBuffer. A subsequent call to bindBuffer which attempts to bind the same WebGLBuffer to the other binding point will generate an INVALID_OPERATION error, and the state of the binding
point will remain untouched.

6.2 No Client Side Arrays
The WebGL API does not support client-side arrays.
If a vertex attribute is enabled as an array via enableVertexAttribArray but no buffer is bound to that attribute (generally via bindBuffer and vertexAttribPointer), then draw commands (drawArrays or drawElements) will generate an INVALID_OPERATION
error. If an indexed draw command (drawElements) is called and no WebGLBuffer is bound to the ELEMENT_ARRAY_BUFFER binding point, an INVALID_OPERATION error is generated. If vertexAttribPointer is called without a WebGLBuffer bound to the ARRAY_BUFFER binding point, and offset is non-zero, an INVALID_OPERATION error is generated.
	Rationale
	Allowing setting VERTEX_ATTRIB_ARRAY_BUFFER_BINDING to null even though client-side arrays are never supported allows for
	clearing the binding to its original state, which isn't strictly possible otherwise.
	This also matches the behavior in OpenGL ES 3.0.5 [GLES30] p25 for non-default VAO objects.

6.3 No Default Textures
The WebGL API does not support default textures. A non-null WebGLTexture object must be bound in order for texture-related operations
and queries to succeed.

6.4 No Shader Binaries
Accessing binary representations of compiled shaders is not supported in the WebGL API. This includes the OpenGL ES 2.0
ShaderBinary entry point. In addition, querying shader binary formats and the availability of a shader compiler via getParameter is not
supported in the WebGL API.
All WebGL implementations must implicitly support an on-line shader compiler.

6.5 Buffer Offset and Stride Requirements
The offset arguments to drawElements and vertexAttribPointer, and the stride argument to vertexAttribPointer, must be a
multiple of the size of the data type passed to the call, or an INVALID_OPERATION error is generated.
	Rationale
	This enforces the following requirement from OpenGL ES 2.0.25 [GLES20] p24:
	"Clients must align data elements consistent with the requirements of the client platform, with an additional base-level requirement that
	an offset within a buffer to a datum comprising N basic machine units be a multiple of N."
	In addition the offset argument to drawElements must be non-negative or an INVALID_VALUE error is generated.

6.6 Enabled Vertex Attributes and Range Checking
It is possible for draw commands to request data outside the bounds of a WebGLBuffer by calling a drawing command that requires
fetching data for an active vertex attribute, when it is enabled as an array, either directly (drawArrays), or indirectly from an indexed draw
(drawElements). If this occurs, then one of the following behaviors will result:
1. The WebGL implementation may generate an INVALID_OPERATION error and draw no geometry.
2. Out-of-range vertex fetches may return any of the following values:
Values from anywhere within the buffer object.
Zero values, or (0,0,0,x) vectors for vector reads where x is a valid value represented in the type of the vector components and
may be any of:
0, 1, or the maximum representable positive integer value, for signed or unsigned integer components
0.0 or 1.0, for floating-point components
Non-normative
This behavior replicates that defined in [KHRROBUSTACCESS].
If a vertex attribute is enabled as an array, a buffer is bound to that attribute, but the attribute is not consumed by the current program, then
regardless of the size of the bound buffer, it will not cause any error to be generated during a call to drawArrays or drawElements.

6.7 Out-of-bounds fetches from the index buffer
Calling an indexed drawing command (drawElements) that fetches index elements outside the bounds of ELEMENT_ARRAY_BUFFER
will result in an INVALID_OPERATION error.

6.8 Framebuffer Object Attachments
WebGL adds the DEPTH_STENCIL_ATTACHMENT framebuffer object attachment point and the DEPTH_STENCIL renderbuffer internal format.
To attach both depth and stencil buffers to a framebuffer object, call renderbufferStorage with the DEPTH_STENCIL internal format, and
then call framebufferRenderbuffer with the DEPTH_STENCIL_ATTACHMENT attachment point.
A renderbuffer attached to the DEPTH_ATTACHMENT attachment point must be allocated with the DEPTH_COMPONENT16 internal format. A
renderbuffer attached to the STENCIL_ATTACHMENT attachment point must be allocated with the STENCIL_INDEX8 internal format. A
renderbuffer attached to the DEPTH_STENCIL_ATTACHMENT attachment point must be allocated with the DEPTH_STENCIL internal format.
In the WebGL API, it is an error to concurrently attach renderbuffers to the following combinations of attachment points:
DEPTH_ATTACHMENT + DEPTH_STENCIL_ATTACHMENT
STENCIL_ATTACHMENT + DEPTH_STENCIL_ATTACHMENT
DEPTH_ATTACHMENT + STENCIL_ATTACHMENT
If any of the constraints above are violated, then:
checkFramebufferStatus must return FRAMEBUFFER_UNSUPPORTED.
[Draw Operations] and [Read Operations], which either draw to or read from the framebuffer, must generate an
INVALID_FRAMEBUFFER_OPERATION error and return early, leaving the contents of the framebuffer, destination texture or destination
memory untouched.
The following combinations of framebuffer object attachments, when all of the attachments are framebuffer attachment complete, non-
zero, and have the same width and height, must result in the framebuffer being framebuffer complete:
COLOR_ATTACHMENT0 = RGBA/UNSIGNED_BYTE texture
COLOR_ATTACHMENT0 = RGBA/UNSIGNED_BYTE texture + DEPTH_ATTACHMENT = DEPTH_COMPONENT16 renderbuffer
COLOR_ATTACHMENT0 = RGBA/UNSIGNED_BYTE texture + DEPTH_STENCIL_ATTACHMENT = DEPTH_STENCIL renderbuffer

6.9 Texture Upload Width and Height
Unless width and height parameters are explicitly specified, the width and height of the texture set by texImage2D and the width and
height of the sub-rectangle updated by texSubImage2D are determined based on the uploaded TexImageSource source object:
source of type ImageData
The width and height of the texture are set to the current values of the width and height properties of the ImageData object,
representing the actual pixel width and height of the ImageData object.
source of type HTMLImageElement
If a bitmap is uploaded, the width and height of the texture are set to the width and height of the uploaded bitmap in pixels. If an SVG
image is uploaded, the width and height of the texture are set to the current values of the width and height properties of the
HTMLImageElement object.
source of type HTMLCanvasElement or OffscreenCanvas
The width and height of the texture are set to the current values of the width and height properties of the HTMLCanvasElement or
OffscreenCanvas object.
source of type HTMLVideoElement or VideoFrame[WEBCODECS]
The width and height of the texture are set to the width and height of the uploaded frame of the video in pixels.

6.10 Pixel Storage Parameters
The WebGL API supports the following additional parameters to pixelStorei.
UNPACK_FLIP_Y_WEBGL of type boolean
If set, then during any subsequent calls to texImage2D or texSubImage2D, the source data is flipped along the vertical axis, so that
conceptually the last row is the first one transferred. The initial value is false. Any non-zero value is interpreted as true.
UNPACK_PREMULTIPLY_ALPHA_WEBGL of type boolean
If set, then during any subsequent calls to texImage2D or texSubImage2D, the alpha channel of the source data, if present, is
multiplied into the color channels during the data transfer. The initial value is false. Any non-zero value is interpreted as true.
UNPACK_COLORSPACE_CONVERSION_WEBGL of type unsigned long
If set to BROWSER_DEFAULT_WEBGL, then the browser's default colorspace conversion (e.g. converting a display-p3 image to srgb) is
applied during subsequent texture data upload calls (e.g. texImage2D and texSubImage2D) that take an argument of
TexImageSource. The precise conversions may be specific to both the browser and file type. If set to NONE, no colorspace conversion
is applied, other than conversion to RGBA. (For example, a rec709 YUV video is still converted to rec709 RGB data, but not then
converted to e.g. srgb RGB data) The initial value is BROWSER_DEFAULT_WEBGL.
If the TexImageSource is an ImageBitmap, then these three parameters will be ignored. Instead the equivalent ImageBitmapOptions
should be used to create an ImageBitmap with the desired format.

6.11 Reading Pixels Outside the Framebuffer
For [Read Operations], reads from out-of-bounds pixels sub-areas do not touch their corresponding destination sub-areas.
WebGL (behaves as if it) pre-initializes resources to zeros. Therefore for example copyTexImage2D will have zeros in sub-areas that
correspond to out-of-bounds framebuffer reads.

6.12 Stencil Separate Mask and Reference Value
In the WebGL API, if stencil testing is enabled and the currently bound framebuffer has a stencil buffer, then it is illegal to draw while any of
the following cases are true. Doing so will generate an INVALID_OPERATION error.
(STENCIL_WRITEMASK & maxStencilValue) != (STENCIL_BACK_WRITEMASK & maxStencilValue)
(as specified by stencilMaskSeparate for the mask parameter associated with the FRONT and BACK values of face, respectively)
(STENCIL_VALUE_MASK & maxStencilValue) != (STENCIL_BACK_VALUE_MASK & maxStencilValue)
(as specified by stencilFuncSeparate for the mask parameter associated with the FRONT and BACK values of face, respectively)
clamp(STENCIL_REF, 0, maxStencilValue) != clamp(STENCIL_BACK_REF, 0, maxStencilValue)
(as specified by stencilFuncSeparate for the ref parameter associated with the FRONT and BACK values of face, respectively)
where maxStencilValue is ((1 << s) - 1), where s is the number of stencil bits in the draw framebuffer. (When no stencil bits are
present, these checks always pass.)

6.13 Vertex Attribute Data Stride
The WebGL API supports vertex attribute data strides up to 255 bytes. A call to vertexAttribPointer will generate an INVALID_VALUE
error if the value for the stride parameter exceeds 255.

6.14 Viewport Depth Range
The WebGL API does not support depth ranges with where the near plane is mapped to a value greater than that of the far plane. A call to
depthRange will generate an INVALID_OPERATION error if zNear is greater than zFar.

6.15 Blending With Constant Color
In the WebGL API, constant color and constant alpha cannot be used together as source and destination factors in the blend function. A
call to blendFunc will generate an INVALID_OPERATION error if one of the two factors is set to CONSTANT_COLOR or
ONE_MINUS_CONSTANT_COLOR and the other to CONSTANT_ALPHA or ONE_MINUS_CONSTANT_ALPHA. A call to blendFuncSeparate will
generate an INVALID_OPERATION error if srcRGB is set to CONSTANT_COLOR or ONE_MINUS_CONSTANT_COLOR and dstRGB is set to
CONSTANT_ALPHA or ONE_MINUS_CONSTANT_ALPHA or vice versa.

6.16 Fixed point support
The WebGL API does not support the GL_FIXED data type.

6.17 GLSL Constructs
Per Supported GLSL Constructs, identifiers starting with "webgl_" and "_webgl_" are reserved for use by WebGL.

6.18 Extension Queries
In the OpenGL ES 2.0 API, the available extensions are determined by calling glGetString(GL_EXTENSIONS), which returns a space-
separated list of extension strings. In the WebGL API, the EXTENSIONS enumerant has been removed. Instead, getSupportedExtensions
must be called to determine the set of available extensions.

6.19 Compressed Texture Support
The core WebGL specification does not define any supported compressed texture formats. Therefore, in the absence of any other
extensions being enabled:
The compressedTexImage2D and compressedTexSubImage2D methods generate an INVALID_ENUM error.
Calling getParameter with the argument COMPRESSED_TEXTURE_FORMATS returns a zero-length array (of type Uint32Array).
WebGL implementations should only expose compressed texture formats that are more efficient than the uncompressed form.

6.20 Maximum GLSL Token Size
The GLSL ES spec [GLES20GLSL] does not define a limit to the length of tokens. WebGL requires support of tokens up to 256 characters
in length. Shaders containing tokens longer than 256 characters must fail to compile.

6.21 Characters Outside the GLSL Source Character Set
WebGL supports passing any HTML DOMString [DOMSTRING] to shaderSource without error. However during shader compilation, after
GLSL preprocessing and comment stripping, all remaining characters MUST be within the character set of [GLES20GLSL]. Otherwise, the
shader MUST fail to compile.
In particular, this allows for:
Non-ASCII unicode in comments
// 你好
Invalid characters in preprocessor-eliminated blocks
#ifdef __cplusplus
#line 42 "foo.glsl"
#endif
(The double-quote character is outside the GLSL character set, but since it is removed by preprocessing, this is allowed in shader
sources)
	Rationale
	The GLSL ES spec [GLES20GLSL] defines the source character set for the OpenGL ES shading language as a subset of ISO/IEC

646:1991, commonly called ASCII [ASCII]. Some GLSL implementations disallow any characters outside the ASCII range, even in
comments. While browsers MUST correctly handle preprocessing the full DOMString character set, WebGL implementations generally
must ensure that the shader source sent to a GLSL driver only contains ASCII for safety. Implementations SHOULD preserve line
numbers for debugging purposes, potentially by inserting blank lines as needed.
If a string containing a character not in this set is passed to any of the other shader-related entry points bindAttribLocation,
getAttribLocation, or getUniformLocation, an INVALID_VALUE error will be generated.

6.22 Maximum Nesting of Structures in GLSL Shaders
WebGL imposes a limit on the nesting of structures in GLSL shaders. Nesting occurs when a field in a struct refers to another struct type;
the GLSL ES spec [GLES20GLSL] forbids embedded structure definitions. The fields in a top-level struct definition have a nesting level of
1.
WebGL requires support of a structure nesting level of 4. Shaders containing structures nested more than 4 levels deep must fail to
compile.

6.23 Maximum Uniform and Attribute Location Lengths
WebGL imposes a limit of 256 characters on the lengths of uniform and attribute locations.

6.24 String Length Queries
In the WebGL API, the enumerants INFO_LOG_LENGTH, SHADER_SOURCE_LENGTH, ACTIVE_UNIFORM_MAX_LENGTH, and
ACTIVE_ATTRIBUTE_MAX_LENGTH have been removed. In the OpenGL ES 2.0 API, these enumerants are needed to determine the size of
buffers passed to calls like glGetActiveAttrib. In the WebGL API, the analogous calls (getActiveAttrib, getActiveUniform,
getProgramInfoLog, getShaderInfoLog, and getShaderSource) all return DOMString.

6.25 Texture Type in TexSubImage2D Calls
In the WebGL API, the type argument passed to texSubImage2D must match the type used to originally define the texture object (i.e.,
using texImage2D).

6.26 Packing Restrictions for Uniforms and Varyings
The OpenGL ES Shading Language, Version 1.00 [GLES20GLSL], Appendix A, Section 7 "Counting of Varyings and Uniforms" defines a
conservative algorithm for computing the storage required for all of the uniform and varying variables in a shader. The GLSL ES
specification requires that if the packing algorithm defined in Appendix A succeeds, then the shader must succeed compilation on the
target platform. The WebGL API further requires that if the packing algorithm fails either for the uniform variables of a shader or for the
varying variables of a program, compilation or linking must fail.
Instead of using a fixed size grid of registers, the number of rows in the target architecture is determined in the following ways:
when counting uniform variables in a vertex shader: getParameter(MAX_VERTEX_UNIFORM_VECTORS)
when counting uniform variables in a fragment shader: getParameter(MAX_FRAGMENT_UNIFORM_VECTORS)
when counting varying variables: getParameter(MAX_VARYING_VECTORS)
Non-normative
The text above defines the circumstances under which compilation or linking of a shader or program must fail due to the constraints
enforced by the packing algorithm. It is not guaranteed that a shader which uses more variables than the minimum required amount
whose variables pack successfully according to this algorithm will compile successfully. Inefficiencies have been observed in
implementations, including expansion of scalar arrays to consume multiple columns. Developers should avoid relying heavily upon
automatic packing of multiple variables into columns. Instead, define larger variables (like vec4) and explicitly pack values into the
rightmost columns.

6.27 Feedback Loops Between Textures and the Framebuffer
In the OpenGL ES 2.0 API, it's possible to make calls that both write to and read from the same texture, creating a feedback loop. It
specifies that where these feedback loops exist, undefined behavior results.
In the WebGL API, such operations that would cause such feedback loops (by the definitions in the OpenGL ES 2.0 spec) will instead
generate an INVALID_OPERATION error.

6.28 Reading From a Missing Attachment
In the OpenGL ES 2.0 API, it is not specified what happens when a command tries to source data from a missing attachment, such as
ReadPixels of color data from a complete framebuffer that does not have a color attachment.
In the WebGL API, any [Read Operations] that require data from an attachment that is missing will generate an INVALID_OPERATION error.

6.29 Drawing To a Missing Attachment
In the OpenGL ES 2.0 API, it is not specified what happens when a command tries to draw to a missing attachment, such as clearing a
draw buffer from a complete framebuffer that does not have a color attachment.
In the WebGL API, any [Draw Operations] that draw to an attachment that is missing will draw nothing to that attachment. No error is
generated.

6.30 NaN Line Width
In the WebGL API, if the width parameter passed to lineWidth is set to NaN, an INVALID_VALUE error is generated and the line width is
not changed.

6.31 Attribute Aliasing
It is possible for an application to bind more than one attribute name to the same location. This is referred to as aliasing. When more than
one attributes that are aliased to the same location are active in the executable program, linkProgram should fail.

6.32 Initial value for gl_Position
The GLSL ES [GLES20GLSL] spec leaves the value of gl_Position as undefined unless it is written to in a vertex shader. WebGL
guarantees that gl_Position's initial value is (0,0,0,0).

6.33 GLSL ES Global Variable Initialization
The GLSL ES 1.00 [GLES20GLSL] spec restricts global variable initializers to be constant expressions. In the WebGL API, it is allowed to
use other global variables not qualified with the const qualifier and uniform values in global variable initializers in GLSL ES 1.00 shaders.
Global variable initializers must be global initializer expressions, which are defined as one of:
a constant expression
a user-defined global variable
a uniform
an expression formed by an operator on operands that are global initializer expressions, including getting an element of a global
initializer vector or global initializer matrix, or a field of a global initializer structure
a constructor whose arguments are all global initializer expressions
a built-in function call whose arguments are all global initializer expressions, with the exception of the texture lookup functions
The following may not be used in global initializer expressions:
User-defined functions
Attributes and varyings
Built-in variables with the exception of constant expressions
Global variables as l-values in an assignment or other operation
Compilers should generate a warning when a global variable initializer is in violation of the unmodified GLSL ES spec i.e. when a global
variable initializer is not a constant expression.
	Rationale
	This behavior has existed in WebGL implementations for several years. Fixing this behavior to be consistent with the GLSL ES
	specification would have a large compatibility impact with existing content.

6.34 GLSL ES Preprocessor "defined" Operator
The C++ standard, which the GLSL ES preprocessor specification refers to, has undefined behavior when the defined operator is
generated by macro replacement when parsing the controlling expression of an #if or #elif directive. When shader code processed by
the WebGL API generates the token defined during macro replacement inside a preprocessor expression, that must result in a compiler
error.
This has no effect on macro expansion outside preprocessor directives that handle the defined operator.
Using defined as a macro name also has undefined behavior in the C++ standard. In the WebGL API, using defined as a macro name
must result in a compiler error.
	Rationale
	Behavior of the WebGL API should be consistent in cases where the native API spec allows undefined behavior.

6.35 GLSL ES #extension directive location
The GLSL ES 1.00 [GLES20GLSL] specification mandates that #extension directives must occur before any non-preprocessor tokens
unless the extension specification says otherwise. In the WebGL API, #extension directives may always occur after non-preprocessor
tokens in GLSL ES 1.00 shaders. The scope of #extension directives in GLSL ES 1.00 shaders is always the whole shader, and
#extension directives that occur later override those seen earlier for the whole shader.
	Rationale
	Letting extensions determine where the #extension directives should be placed has resulted in a lot of room for interpretation in the
	spec. In practice GLES implementations have not enforced the rule that's written in the GLSL ES spec, and neither have WebGL
	implementations, so relaxing the rule is the only way to make the spec well-defined while being compatible with existing content.

6.36 Completeness of Cube Map Framebuffer Attachments
In the WebGL API, a face of a cube map that is not cube complete is not framebuffer attachment complete. Querying framebuffer status
when a face of an incomplete cube map is attached must return FRAMEBUFFER_INCOMPLETE_ATTACHMENT.
	Rationale
	APIs that WebGL is implemented on, including recent OpenGL core versions and OpenGL ES 3.0 and newer, have a requirement that
	cube map faces used as a framebuffer attachment must be part of a cube complete cube map. See for example OpenGL ES 3.0.4
	§4.4.4 "Framebuffer Completeness", subsection "Framebuffer Attachment Completeness".

6.37 Transferring vertices when current program is null
Any command that transfers vertices to the GL generates INVALID_OPERATION if the CURRENT_PROGRAM is null. This includes
drawElements and drawArrays.

6.38 Fragment shader output
If a fragment shader writes to neither gl_FragColor nor gl_FragData, the values of the fragment colors following shader execution are
untouched.

6.39 Initial values for GLSL local and global variables
The GLSL ES [GLES20GLSL] spec leaves the value of local and global variables as undefined unless they are initialized by the shader.
WebGL guarantees that such variables are initialized to zero: 0.0, vec4(0.0), 0, false, etc.

6.40 Vertex attribute conversions from normalized signed integers to floating point
The OpenGL ES 2.0 spec [GLES20] section 2.1.2 "Data Conversions", subsection "Conversion from Integer to Floating-Point" defines
conversion from a normalized signed integer c, where the bit width of the type is b, to floating-point value f as:
f = (2*c + 1) / (2^b - 1)
During conversions of signed normalized vertex attributes to floating point, WebGL 1.0 implementations may optionally use this conversion
rule, which preserves zeros:
f = max(c / (2^(b - 1) - 1), -1.0)
	Rationale
	Some APIs on which WebGL 1.0 is built on use the second rule, and since this conversion is done in fixed-function hardware, it is not
	possible to emulate one behavior or the other. This difference in behavior does not affect most applications, so a query to determine
	which behavior is being used has not been added to the WebGL rendering context.

6.41 Uniform and attribute name collisions
If any of the shaders attached to a WebGL program declare a uniform that has the same name as a statically used vertex attribute,
program linking should fail.
Non-normative
This behavior differs from one specified in GLSL ES 3.00.6 section 12.47.
	Rationale
	WebGL implementations have enforced this behavior for several years now, due to that some OpenGL drivers don't accept uniforms
	and vertex attributes with the same name.

6.42 Wide point primitive clipping
POINTS primitives may or may not be discarded if the vertex lies outside the clip volume, but within the near and far clip planes.
	Rationale
	Clipping of wide points works differently in GLES and GL, and this difference in behavior is prohibitive to work around in
	implementations.
	OpenGL ES 2.0.25 p46:
	If the primitive under consideration is a point, then clipping discards it if it lies outside the near or far clip plane; otherwise it
	is passed unchanged.
	OpenGL 3.2 Core p97:
	If the primitive under consideration is a point, then clipping passes it unchanged if it lies within the clip volume; otherwise,
	it is discarded.

6.43 Current program invalidated upon unsuccessful link
In the WebGL API, if the program passed to linkProgram is also the current program object in use as defined by useProgram, and the link
is unsuccessful, then the executable code referenced by the current rendering state is immediately invalidated. Further draw calls that
utilize the current program generate an INVALID_OPERATION error.
	Rationale
	Rejecting draw calls eagerly against programs whose relink has failed makes WebGL implementations more robust. The OpenGL ES
	API's behavior is that the current executable is preserved until the current program is changed. Correctly implementing this behavior in
	all scenarios is challenging, and has led to security bugs.

////////////////////////////////////////////////////////////////////////////////
// SECTION: Differences Between WebGL and OpenGL ES 3.0
//
// WebGL 2.0 Specification
// Editor's Draft Fri Feb 7 11:45:36 2025 -0800        
////////////////////////////////////////////////////////////////////////////////
This section describes changes made to the WebGL API relative to the OpenGL ES 3.0 API to improve portability across various operating
systems and devices.

5.1 Buffer Object Binding
WebGL buffer type Binding points that set this type
undefined
 none
element array
 ELEMENT_ARRAY_BUFFER
other data
 all binding points except ELEMENT_ARRAY_BUFFER, COPY_READ_BUFFER and COPY_WRITE_BUFFER
In the WebGL 2.0 API, buffers have their WebGL buffer type initially set to undefined. Calling bindBuffer, bindBufferRange or
bindBufferBase with the target argument set to any buffer binding point except COPY_READ_BUFFER or COPY_WRITE_BUFFER will then set the
WebGL buffer type of the buffer being bound according to the table above. Binding a buffer with type undefined to the COPY_READ_BUFFER or
COPY_WRITE_BUFFER binding points will set its type to other data.
Any call to one of these functions which attempts to bind a deleted buffer will generate a INVALID_OPERATION error, and the binding will remain
untouched.
Any call to one of these functions which attempts to bind a WebGLBuffer that has the element array WebGL buffer type to a binding point that
falls under other data, or bind a WebGLBuffer which has the other data WebGL buffer type to ELEMENT_ARRAY_BUFFER will generate an
INVALID_OPERATION error, and the state of the binding point will remain untouched.
This restriction implies that a given buffer object may contain either indices or other data, but not both.
These restrictions are similar to buffer object binding restrictions in the WebGL 1.0 specification.
	Rationale
	This restriction has been added to prevent writing to index buffers on the GPU, which would make doing any CPU-side checks on index data
	prohibitively expensive. Handling index buffers as different from other buffer data also maps better to the Direct3D API.

5.2 Copying Buffers
Attempting to use copyBufferSubData to copy between buffers that have element array and other data WebGL buffer types as specified in
section Buffer Object Binding generates an INVALID_OPERATION error and no copying is performed.
Rationale
Same as with Buffer Object Binding restrictions above.

5.3 Preventing undefined behavior with Transform Feedback
A buffer which is simultaneously bound to an indexed TRANSFORM_FEEDBACK_BUFFER binding point in the currently bound transform
feedback object and any other binding point in the WebGL API, except generic TRANSFORM_FEEDBACK_BUFFER binding point, cannot be
used. Any attempted use of such a double bound buffer fails with an INVALID_OPERATION error, regardless of whether transform feedback is
enabled. For example, readPixels to a PIXEL_PACK_BUFFER will fail if the buffer is also bound to the current transform feedback object.
	Rationale
	If an error were not generated, the values read or written would be undefined. ( OpenGL ES 3.0.6 §2.15.2)
	In case the same buffer is bound to more than one indexed binding point in the active transform feedback, beginTransformFeedback
	generates an INVALID_OPERATION error.
	Non-normative
	This can happen only in SEPARATE_ATTRIBS mode.
		Rationale
		This is a restriction from D3D11, where writing two different streams to the same buffer is not allowed.

5.4 Draw Buffers
The value of the MAX_COLOR_ATTACHMENTS parameter must be equal to that of the MAX_DRAW_BUFFERS parameter.
	Rationale
	There is no use case for these parameters being different.
	If an ESSL1 fragment shader writes to neither gl_FragColor nor gl_FragData, the values of the fragment colors following shader execution
	are untouched. If corresponding output variables are not defined in an ESSL3 fragment shader, the values of the fragment colors following
	shader execution are untouched.
	All user-defined output variables default to zero if they are not written during a shader execution.
	Non-normative
	For optimal performance, an output array should not include any elements that are not accessed.
	A draw buffer is "shader-output-incompatible" with a fragment shader if:
	the values written to it by the shader do not match the format of the corresponding color buffer (For example, the output variable is an
	integer, but the corresponding color buffer has a floating-point format, or vice versa)
	OR there is no defined fragment shader output for its location.
	If any draw buffers are "shader-output-incompatible", draws generate INVALID_OPERATION if:
	Any channel of colorMask is set to true
	AND, for each DRAW_BUFFERi of DRAW_FRAMEBUFFER that is "shader-output-incompatible":
	DRAW_BUFFERi is not NONE
	AND, any channel colorMaski (from e.g. OES_draw_buffers_indexed) is set to true.

5.5 No Program Binaries
Accessing binary representations of compiled shader programs is not supported in the WebGL 2.0 API. This includes OpenGL ES 3.0
GetProgramBinary, ProgramBinary, and ProgramParameteri entry points. In addition, querying the program binary length with
getProgramParameter, and querying program binary formats with getParameter are not supported in the WebGL 2.0 API.

5.6 Range Checking
In addition to the range checking specified in the WebGL 1.0 specification section Enabled Vertex Attributes and Range Checking, indices
referenced by drawElements, drawRangeElements or drawElementsInstanced that are greater than the MAX_ELEMENT_INDEX parameter
cause the draw call to generate an INVALID_OPERATION error even if they lie within the storage of the bound buffer. Range checking is not
performed for indices that trigger primitive restart if primitive restart is enabled. The range checking specified for drawArrays in the WebGL 1.0
API is also applied to drawArraysInstanced in the WebGL 2.0 API.
	Rationale
	The OpenGL robustness extensions do not specify what happens if indices above MAX_ELEMENT_INDEX are used, so passing them to the
	driver is risky. On platforms where MAX_ELEMENT_INDEX is the same as the maximum unsigned integer value this section will have no
	effect.

5.7 Active Uniform Block Backing
In the WebGL 2.0 API, attempting to draw with drawArrays, drawElements, drawRangeElements or their instanced variants generates an
INVALID_OPERATION error if any active uniform block in the program used for the draw command is not backed by a sufficiently large buffer
object.
	Rationale
	In OpenGL, insufficient uniform block backing is allowed to cause GL interruption or termination. See OpenGL ES 3.0 specification section
	2.12.6 ( OpenGL ES 3.0.6 §2.12.6), under "Uniform Buffer Object Bindings."

5.8 Default Framebuffer
WebGL always has a default framebuffer. The FRAMEBUFFER_UNDEFINED enumerant is removed from the WebGL 2.0 API.

5.9 String Length Queries
In the WebGL 2.0 API, the enumerants ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH, TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH,
UNIFORM_BLOCK_NAME_LENGTH, and UNIFORM_NAME_LENGTH are removed in addition to similar enumerants removed in the WebGL 1.0 API.

5.10 Invalid Clears
In the WebGL 2.0 API, trying to perform a clear when there is a mismatch between the type of the specified clear value and the type of a buffer
that is being cleared generates an INVALID_OPERATION error instead of producing undefined results.

5.11 Invalid Texture Offsets
A GLSL shader which attempts to use a texture offset value outside the range specified by implementation-defined parameters
MIN_PROGRAM_TEXEL_OFFSET and MAX_PROGRAM_TEXEL_OFFSET in texture lookup function arguments must fail compilation in the WebGL 2.0
API.
	Rationale
	Using an offset outside the valid range returns undefined results, so it can not be allowed. The offset must be a constant expression
	according to the GLSL ES spec, so checking the value against the correct range can be done at compile time.

5.12 Texel Fetches
Texel fetches that have undefined results in the OpenGL ES 3.0 API must return zero, or a texture source color of (0, 0, 0, 1) in the case of a
texel fetch from an incomplete texture in the WebGL 2.0 API.
	Rationale
	Behavior of out-of-range texel fetches needs to be testable in order to guarantee security.

5.13 GLSL ES 1.00 Fragment Shader Output
A fragment shader written in The OpenGL ES Shading Language, Version 1.00, that statically assigns a value to gl_FragData[n] where n
does not equal constant value 0 must fail to compile in the WebGL 2.0 API. This is to achieve consistency with The OpenGL ES 3.0
specification section 4.2.1 (OpenGL ES 3.0.6 §4.2.1) and The OpenGL ES Shading Language 3.00.6 specification section 1.5 (GLSL ES 3.00.6 §1.5). As in the
OpenGL ES 3.0 API, multiple fragment shader outputs are only supported for GLSL ES 3.00 shaders in the WebGL 2.0 API.

5.14 No MapBufferRange
The MapBufferRange, FlushMappedBufferRange, and UnmapBuffer entry points are removed from the WebGL 2.0 API. The following enum
values are also removed: BUFFER_ACCESS_FLAGS, BUFFER_MAP_LENGTH, BUFFER_MAP_OFFSET, MAP_READ_BIT, MAP_WRITE_BIT,
MAP_INVALIDATE_RANGE_BIT, MAP_INVALIDATE_BUFFER_BIT, MAP_FLUSH_EXPLICIT_BIT, and MAP_UNSYNCHRONIZED_BIT.
Non-normative
Instead of using MapBufferRange, buffer data may be read by using the getBufferSubData entry point.

5.15 TIMEOUT_IGNORED
In the WebGL 2.0 API TIMEOUT_IGNORED is defined as a GLint64 with the value -1 instead of a GLuint64 with the value 0xFFFFFFFFFFFFFFFF.
This is because Javascript cannot accurately represent an integer that large. For the same reason waitSync takes GLint64 values instead of
GLuint64 for timeout.

5.16 clientWaitSync
In the WebGL 2.0 API, WebGL implementations must enforce a short maximum timeout on calls to clientWaitSync in order to avoid blocking
execution of the main thread for excessive periods of time. This timeout may be queried by calling getParameter with the argument
MAX_CLIENT_WAIT_TIMEOUT_WEBGL.
Non-normative
The implementation-defined maximum timeout is not specified. It is acceptable for an implementation to enforce a zero maximum timeout.

5.17 Vertex Attribute Aliasing
WebGL 2.0 API implementations must strictly follow GLSL ES 3.00.6 section 12.46, which specifies that any vertex attribute aliasing is
disallowed. As stated in [GLES30] p57, GLSL ES 1.00 shaders may still alias, as allowed by the WebGL 1.0 spec section Attribute aliasing.

5.18 PRIMITIVE_RESTART_FIXED_INDEX is always enabled
The PRIMITIVE_RESTART_FIXED_INDEX context state, controlled with Enable/Disable in OpenGL ES 3.0, is not supported in WebGL 2.0.
Instead, WebGL 2.0 behaves as though this state were always enabled. This is a compatibility difference compared to WebGL 1.0.
When drawElements, drawElementsInstanced, or drawRangeElements processes an index, if the index's value is the maximum for the data
type (255 for UNSIGNED_BYTE indices, 65535 for UNSIGNED_SHORT, or 4294967295 for UNSIGNED_INT), then the vertex is not processed
normally. Instead, it is as if the drawing command ended with the immediately preceding vertex, and another drawing command is immediately
started with the same parameters, but only transferring the immediately following index through the end of the originally specified indices.
	Rationale
	This compatibility difference was introduced in order to avoid performance pitfalls in Direct3D based WebGL implementations. Applications
	and content creation tools can be adjusted to avoid using the maximum vertex index if the primitive restart behavior is not desired.

5.19 No texture swizzles
OpenGL ES 3.0 introduces new state on texture objects allowing a four-channel swizzle operation to be specified against the texture. The
swizzle is applied to every texture lookup performed within any shader referencing that texture. These texture swizzles are not supported in
WebGL 2.0. TEXTURE_SWIZZLE_* enum values are removed from the WebGL 2.0 API.
	Rationale
	Texture swizzles can not be implemented in a performant manner on Direct3D based WebGL implementations. Applications relying on this
	functionality would run significantly more slowly on those implementations. Applications are still able to swizzle results of texture fetches in
	shaders and swizzle texture data before uploading without this interface.

5.20 Queries should fail on a program that failed to link
OpenGL ES 3.0 allows applications to enumerate and query properties of active variables and interface blocks of a specified program even if
that program failed to link (OpenGL ES 3.0.6 §2.12.3). In WebGL, these commands will always generate an INVALID_OPERATION error on a program
that failed to link, and no information is returned.
	Rationale
	The returned information in OpenGL ES 3.0 is implementation dependent and may be incomplete. The error condition is added to ensure
	consistent behavior across all platforms.

5.21 Color values from a fragment shader must match the color buffer format
Color values written by a fragment shader may be floating-point, signed integer, or unsigned integer. If the values written by the fragment
shader do not match the format(s) of the corresponding color buffer(s), the result is undefined in OpenGL ES 3.0 (OpenGL ES 3.0.6 §3.9.2.3). In WebGL,
generates an INVALID_OPERATION error in the corresponding draw call, including drawArrays, drawElements, drawArraysInstanced ,
drawElementsInstanced , and drawRangeElements.
If the color buffer has a normalized fixed-point format, floating-point color values are converted to match the format; generates no error in such
situation.

5.22 A sampler type must match the internal texture format
Texture lookup functions return values as floating point, unsigned integer or signed integer, depending on the sampler type passed to the
lookup function. If the wrong sampler type is used for texture access, i.e., the sampler type does not match the texture internal format, the
returned values are undefined in OpenGL ES Shading Language 3.00.6 (OpenGL ES Shading Language 3.00.6 §8.8). In WebGL, generates an
INVALID_OPERATION error in the corresponding draw call, including drawArrays, drawElements, drawArraysInstanced,
drawElementsInstanced , and drawRangeElements.
If the sampler type is floating point and the internal texture format is normalized integer, it is considered as a match and the returned values are
converted to floating point in the range [0, 1].

5.23 Queries' results must not be made available in the current frame
In OpenGL ES 3.0, if the appropriate primitives (e.g. glFinish() or another synchronous API) are called, a query's result may be made
available in the same frame it was issued. In WebGL, in order to improve application portability, a query's result must never be made available
to the application in the same frame the query was issued. See the specification of getQueryParameter for discussion and rationale.

5.24 GLSL ES 3.00 #extension directive location
The WebGL 1.0 specification section GLSL ES #extension directive location only applies to OpenGL ES Shading Language 1.00 shaders. It
does not apply to shaders that are written in OpenGL ES Shading Language 3.00. In shaders written in OpenGL ES Shading Language 3.00,
#extension directives must occur before non-preprocessor tokens regardless of what is written in the extension specification.
	Rationale
	This is done to make WebGL 2.0 to follow the written GLSL ES 3.00 specification more closely. Enforcing the restriction more strictly than
	native GLES drivers makes the behavior well-defined.

5.25 Only std140 layout supported in uniform blocks
The GLSL ES 3.00 specification supports the shared, packed, and std140 layout qualifiers for uniform blocks, defining how variables are laid
out in uniform buffers' storage. Of these, the WebGL 2.0 specification supports only the std140 layout, which is defined in OpenGL ES 3.0.6
§2.12 "Vertex Shaders", subsection "Standard Uniform Block Layout". Shaders attempting to use the shared or packed layout qualifiers will fail
either the compilation or linking stages.
The initial state of compilation is as if the following were declared:
layout(std140) uniform;
	Rationale
	This restriction is enforced to improve portability by avoiding exposing uniform block layouts that are specific to one vendor's GPUs.

5.26 Disallowed variants of GLSL ES 3.00 operators
In the WebGL 2.0 API, the following shading language constructs are not allowed and attempting to use them must result in a compile error:
Ternary operator applied to void, arrays, or structs containing arrays
Sequence operator applied to void, arrays, or structs containing arrays
	Rationale
	This restriction ensures easy portability across OpenGL ES 3.0 supporting devices.

5.27 checkFramebufferStatus may return FRAMEBUFFER_INCOMPLETE_DIMENSIONS
All attached images much have the same width and height; otherwise, checkFramebufferStatus returns
FRAMEBUFFER_INCOMPLETE_DIMENSIONS.
	Rationale
	In OpenGL ES 3, attached images for a framebuffer need not to have the same width and height to be framebuffer complete, and
	FRAMEBUFFER_INCOMPLETE_DIMENSIONS is not one of the valid return values for checkFramebufferStatus. However, in Direct3D 11, on top
	of which OpenGL ES 3 behavior is emulated in Windows, all render targets must have the same size in all dimensions (see msdn manual
	page). Emulation of the ES3 semantic on top of DirectX 11 will be inefficient. In order to have consistent WebGL 2.0 behaviors across
	platforms, it is reasonable to keep the OpenGL ES 2 / WebGL 1.0 restriction for WebGL 2.0 that all attached images must have the same
	width and height.

5.28 Uniform block matching
In the WebGL 2.0 API, layout qualifiers row_major and column_major are required to match in matched uniform blocks even when they are
applied exclusively on non-matrix variables.
	Rationale
	This uniform block matching rule is known to be inconsistent across OpenGL ES 3.0 implementations.

5.29 Framebuffer contents after invalidation
In OpenGL ES 3.0, after calling invalidateFramebuffer or invalidateSubFramebuffer, the affected region's contents become effectively
undefined. In WebGL 2.0, it is required for the contents to either stay unchanged or become cleared to their default values. (e.g. 0 for colors
and stencil, and 1.0 for depth)
Non-normative
It is acceptable for WebGL 2.0 implementations to make invalidateFramebuffer or invalidateSubFramebuffer a no-op.

5.30 No ArrayBufferView matching texture type FLOAT_32_UNSIGNED_INT_24_8_REV
In texImage2D and texImage3D with ArrayBufferView, if type is FLOAT_32_UNSIGNED_INT_24_8_REV and srcData is not null, generates an
INVALID_OPERATION.
In texSubImage2D and texSubImage3D with ArrayBufferView, if type is FLOAT_32_UNSIGNED_INT_24_8_REV, generates an INVALID_ENUM.

5.31 VertexAttrib function must match shader attribute type
If any of the following situations are true, attempting to draw with drawArrays, drawElements, drawRangeElements or their instanced variants
generates an INVALID_OPERATION error:
vertexAttribPointer, vertexAttrib{1234}f, or vertexAttrib{1234}fv is used and the base type of the shader attribute at slot index
is not floating-point (e.g. is signed or unsigned integer);
vertexAttribIPointer is used with type UNSIGNED_BYTE, UNSIGNED_SHORT or UNSIGNED_INT, or vertexAttribI4ui or
vertexAttribI4uiv is used, and the base type of the shader attribute at slot index is not unsigned integer (e.g. is floating-point or signed
integer);
vertexAttribIPointer is used with type BYTE, SHORT or INT, or vertexAttribI4i or vertexAttribI4iv is used, and the base type of
the shader attribute at slot index is not signed integer (e.g. is floating-point or unsigned integer).
Non-normative
This undefined behavior is in the OpenGL ES 3.0 specification section 2.8 ( OpenGL ES 3.0.6 §2.8).

5.32 Transform feedback primitive capture
If any output variable is specified to be streamed to a buffer object but not actually written by a vertex shader, the value is set to 0.
Non-normative
This undefined behavior is in the OpenGL ES 3.0 specification section 2.15.2 ( OpenGL ES 3.0.6 §2.15.2).

5.33 gl_FragDepth
If a fragment shader statically assigns a value to gl_FragDepth, for any fragment where statements assigning a value to gl_FragDepth are not
executed, the value 0 is used.
Non-normative
This undefined behavior is in the OpenGL ES 3.0 specification section 3.9.2 ( OpenGL ES 3.0.6 §3.9.2).

5.34 Framebuffer color attachments
If an image is attached to more than one color attachment point in a framebuffer, checkFramebufferStatus returns
FRAMEBUFFER_UNSUPPORTED. An image can be an individual mip level, an array slice (from either 2D array or cube map textures), or a 3D
texture slice.
	Rationale
	This is a limitation of Direct3D 11, on top of which OpenGL ES 3 behavior is emulated on Windows. (see msdn manual page). In order to
	have consistent WebGL 2.0 behavior across platforms, it is reasonable to add this limitation in WebGL 2.0 for all platforms.

5.35 Pixel store parameters for uploads from TexImageSource
UNPACK_ALIGNMENT and UNPACK_ROW_LENGTH are ignored. UNPACK_ALIGNMENT is specified in bytes, and is implicit and implementation-
dependent for TexImageSource objects. UNPACK_ROW_LENGTH is currently unused.
Subrect selection is possible using UNPACK_ params. UNPACK_SKIP_PIXELS and UNPACK_SKIP_ROWS determine the origin of the subrect, with
the width and height arguments determining the size of the subrect.
For 3D textures, the width, height, and depth arguments specify a rectangular region of a texel array to unpack to. UNPACK_SKIP_IMAGES and
UNPACK_IMAGE_HEIGHT allow selection of multiple slices from the 2D source. UNPACK_IMAGE_HEIGHT determines the stride, in rows, between
two slices. For example, a TexImageSource 30 pixels tall may have the top 10 and bottom 10 rows uploaded into two slices of a 3D texture by
uploading with height equal to 10, UNPACK_IMAGE_HEIGHT set to 20, and depth equal to 2. If UNPACK_IMAGE_HEIGHT is 0, the stride, in rows,
between two slices defaults to height.
For an HTMLImageElement 20 pixels wide, passing width = 10 for texture upload will cause only the left half of the image to be selected, thus
uploaded. The resulting texture will have a width of 10. If, additionally in this example, UNPACK_SKIP_PIXELS is set to 10, only the right half of
the image is selected for unpack.
Also, UNPACK_SKIP_IMAGES applies only to 3D entrypoints, not to 2D entrypoints.
Looking at another example, the above 32x48 image of six colors, each of size 16x16, is uploaded to a 3D texture of width = 2, height = 1,
and depth = 3.
If UNPACK_SKIP_PIXELS is 0, UNPACK_SKIP_ROWS is 0, and UNPACK_IMAGE_HEIGHT is 0, the entire texel array is set to red.
If UNPACK_SKIP_PIXELS is 16, UNPACK_SKIP_ROWS is 16, and UNPACK_IMAGE_HEIGHT is 0, the entire texel array is set to yellow.
If UNPACK_SKIP_PIXELS is 0, UNPACK_SKIP_ROWS is 0, and UNPACK_IMAGE_HEIGHT is 16, the first slice of the texel array is red, the second
slice is blue, and the third slice is purple.
If UNPACK_SKIP_PIXELS is 16, UNPACK_SKIP_ROWS is 0, and UNPACK_IMAGE_HEIGHT is 16, the first slice of the texel array is green, the
second slice is yellow, and the third slice is pink.

5.36 Pixel store parameter constraints
Define:
DataStoreWidth := ROW_LENGTH ? ROW_LENGTH : width
DataStoreHeight := IMAGE_HEIGHT ? IMAGE_HEIGHT : height
If PACK_SKIP_PIXELS + width > DataStoreWidth, readPixels generates an INVALID_OPERATION error.
If UNPACK_SKIP_PIXELS + width > DataStoreWidth, texImage2D and texSubImage2D generate an INVALID_OPERATION error. This does not
apply to texImage2D if no PIXEL_UNPACK_BUFFER is bound and srcData is null.
If UNPACK_SKIP_PIXELS + width > DataStoreWidth or UNPACK_SKIP_ROWS + height > DataStoreHeight, texImage3D and texSubImage3D
generate an INVALID_OPERATION error. This does not apply to texImage3D if no PIXEL_UNPACK_BUFFER is bound and srcData is null.
	Rationale
	These constraints normalize the use of these parameters to specify a sub region where pixels are stored. For example, in readPixels
	cases, if we want to store pixels to a sub area of the entire data store, we can use PACK_ROW_LENGTH to specify the data store width, and
	PACK_SKIP_PIXELS, PACK_SKIP_ROWS, width and height to specify the subarea's xoffset, yoffset, width, and height.
	These contraints also forbid row and image overlap, where the situations are not tested in the OpenGL ES 3.0 DEQP test suites, and many
	drivers behave incorrectly. They also forbid skipping random pixels or rows, but that can be achieved by adjusting the data store offset
	accordingly.
	Further, for uploads from TexImageSource, implied UNPACK_ROW_LENGTH and UNPACK_ALIGNMENT are not strictly defined. These restrictions
	ensure consistent and efficient behavior regardless of implied UNPACK_ params.
	If UNPACK_FLIP_Y_WEBGL or UNPACK_PREMULTIPLY_ALPHA_WEBGL is set to true, texImage2D and texSubImage2D generate an
	INVALID_OPERATION error if they upload data from a PIXEL_UNPACK_BUFFER.
	If UNPACK_FLIP_Y_WEBGL or UNPACK_PREMULTIPLY_ALPHA_WEBGL is set to true, texImage3D and texSubImage3D generate an
	INVALID_OPERATION error if they upload data from a PIXEL_UNPACK_BUFFER or a non-null client side ArrayBufferView.

5.37 No ETC2 and EAC compressed texture formats
OpenGL ES 3.0 requires support for the following ETC2 and EAC compressed texture formats: COMPRESSED_R11_EAC,
COMPRESSED_SIGNED_R11_EAC, COMPRESSED_RG11_EAC, COMPRESSED_SIGNED_RG11_EAC, COMPRESSED_RGB8_ETC2,
COMPRESSED_SRGB8_ETC2, COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2,
COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2, COMPRESSED_RGBA8_ETC2_EAC, and
COMPRESSED_SRGB8_ALPHA8_ETC2_EAC.
These texture formats are not supported by default in WebGL 2.0.
	Rationale
	These formats are not natively supported by most desktop GPU hardware. As such, supporting these formats requires software
	decompression in either the WebGL implementation or the underlying driver. This results in a drastic increase in video memory usage,
	causing performance losses which are invisible to the WebGL application.
	On hardware which supports the ETC2 and EAC compressed texture formats natively (e.g. mobile OpenGL ES 3.0+ hardware), they may be
	exposed via the extension WEBGL_compressed_texture_etc.

5.38 The value of UNIFORM_BUFFER_OFFSET_ALIGNMENT must be divisible by 4
The value of UNIFORM_BUFFER_OFFSET_ALIGNMENT, as given in basic machine units, must be divisible by 4.
	Rationale
	If the value of UNIFORM_BUFFER_OFFSET_ALIGNMENT was not divisible by 4, it would make it impractical to upload ArrayBuffers to
	uniform buffers which are bound with BindBufferRange.

5.39 Sync objects' results must not be made available in the current frame
In OpenGL ES 3.0, if the appropriate primitives (e.g. glFinish() or another synchronous API) are called, a sync object may be signaled in the
same frame it was issued. In WebGL, in order to improve application portability, a sync object must never transition to the signaled state in the
same frame the sync was issued. See the specification of getSyncParameter and clientWaitSync for discussion and rationale.

5.40 blitFramebuffer rectangle width/height limitations
blitFramebuffer() src* and dst* parameters must be set so that the resulting width and height of the source and destination rectangles are
less than or equal to the maximum value that can be stored in a GLint. In case computing any of the width or height values as a GLint results in
integer overflow, blitFramebuffer() generates an INVALID_VALUE error.
	Rationale
	Using larger than max 32-bit int sized rectangles for blitFramebuffer triggers issues on most desktop OpenGL drivers, and there is no
	general workaround for cases where blitFramebuffer is used to scale the framebuffer.

5.41 GenerateMipmap requires positive image dimensions
generateMipmap requires that TEXTURE_BASE_LEVEL's dimensions are all positive.
Non-normative
GLES 3.0.6 technically allows calling GenerateMipmap on 0x0 images, though cubemaps must be cube-complete, thus having positive
dimensions.
	Rationale
	This change simplifies implementations by allowing a concept of base-level-completeness for textures, as otherwise required for non-
	mipmap-sampled validation. Since GenerateMipmap has no effect on a 0x0 texture, and is illegal in WebGL 1 (0 is not a power of two), this
	is an easy restriction to add. Further, GenerateMipmap would otherwise be the only entrypoint that has to operate on undefined texture
	images, skipping an otherwise-common validation.

5.42 deleteQuery implicitly calls endQuery if the query is active
In GLES, DeleteQueries does not implicitly end queries, even if they are active.
	Rationale
	This deviation was not originally specified, but was implicitly standardized across browsers by conformance tests. Some implementations
	found this behavior simpler to implement. Reverting this behavior to match the GLES specs could break content, and at this point it's better
	to spec what we implemented.

5.43 Required compressed texture formats
Implementations must support at least one suite of compressed texture formats.
Implementations must support:
WEBGL_compressed_texture_etc AND/OR
(
WEBGL_compressed_texture_s3tc AND
WEBGL_compressed_texture_s3tc_srgb AND
EXT_texture_compression_rgtc
)
	Rationale
	To best support our ecosystem, we require implementations to support either ETC2/EAC formats (universal on GLES3 or similar drivers, like
	many phones) or S3TC formats (universal all other drivers). This guarantees to authors that they can always use compressed textures
	(including srgb variants) on all devices while maintaining support for as few as two different formats.
	Non-normative
	There are roughly equivalent formats in each suite for the following uses:
	Usage
	 S3TC/RGTC option (desktop)
	 ETC2/EAC option (mobile)
	R11 unsigned
	 COMPRESSED_RED_RGTC1_EXT
	 COMPRESSED_R11_EAC
	R11 signed
	 COMPRESSED_SIGNED_RED_RGTC1_EXT
	 COMPRESSED_SIGNED_R11_EAC
	RG11 unsigned
	 COMPRESSED_RED_GREEN_RGTC2_EXT
	 COMPRESSED_RG11_EAC
	RG11 signed
	 COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT COMPRESSED_SIGNED_RG11_EAC
	RGB8 unsigned
	 COMPRESSED_RGB_S3TC_DXT1_EXT
	 COMPRESSED_RGB8_ETC2
	RGB8 sRGB
	 COMPRESSED_SRGB_S3TC_DXT1_EXT
	 COMPRESSED_SRGB8_ETC2
	RGB8 punchthrough unsigned COMPRESSED_RGBA_S3TC_DXT1_EXT
	 COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2
	RGB8 punchthrough sRGB
	 COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT
	 COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2
	RGBA8 unsigned
	 COMPRESSED_RGBA_S3TC_DXT5_EXT
	 COMPRESSED_RGBA8_ETC2_EAC
	RGBA8 sRGB
	 COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT
	 COMPRESSED_SRGB8_ALPHA8_ETC2_EAC

5.44 E.g. sampler2DShadow does not guarantee e.g. LINEAR filtering
When TEXTURE_COMPARE_MODE is set to COMPARE_REF_TO_TEXTURE, a texture is always complete even if it uses a LINEAR filtering
without the required extensions. However, it is implementation-defined whether the LINEAR filtering occurs. (Implementations may do
NEAREST sampling instead)
	Rationale
	This functionality is underspecified in GLES. It is common but not universal. We choose to be liberal here, though implementations may warn
	on requests for this functionality.

5.45 Clamped Constant Blend Color
Implementations may clamp constant blend color on store when the underlying platform does the same. Applications may query BLEND_COLOR
parameter to check the effective behavior.

5.46 Generic TRANSFORM_FEEDBACK_BUFFER state location
The TRANSFORM_FEEDBACK_BUFFER generic buffer binding point has been moved to context state, rather than per-object state.
	Rationale
	A similar change was made in OpenGL ES 3.2.

5.47 Uninitialized Compressed Textures
In OpenGL ES 2.0 the specification omitted declaring whether it should be possible to create a compressed 2D texture with uninitialized data.
In WebGL 1.0, this is explicitly disallowed.
In OpenGL ES 3.0 it is explicitly allowed to create a compressed 2D texture with uninitialized data by passing null to
glCompressedTexImage2D. In WebGL 2.0, however, this is still explicitly disallowed. Users can use texStorage2D with a compressed internal
format to allocate zero-initialized compressed textures; these textures are however immutable, and not completely compatible with textures
allocated via compressedTexImage2D.
