ES 3.0.6

3.8.3.1 Required Texture Formats

Texture & RenderBuffer:
	RGBA32I, RGBA32UI, RGBA16I, RGBA16UI, RGBA8, RGBA8I,
	RGBA8UI, SRGB8_ALPHA8, RGB10_A2, RGB10_A2UI, RGBA4, and
	RGB5_A1

Texture-only Formats:
– RGBA32F, RGBA16F, RGBA8_SNORM.
– RGB32F, RGB32I, RGB32UI.
– RGB16F, RGB16I, RGB16UI.
– RGB8_SNORM, RGB8I, RGB8UI, SRGB8.
– R11F_G11F_B10F RGB9_E5.
– RG32F, RG16F, RG8_SNORM.
– R32F, R16F, R8_SNORM.

Depth:
	DEPTH_COMPONENT32F,
	DEPTH_COMPONENT24,
	DEPTH_COMPONENT16.
Depth+Stencil:
	DEPTH32F_STENCIL8
	DEPTH24_STENCIL8.

----

Two parameters combine to decide effective internal format.
If internalformat is a sized internal format, then it's set.
If it's a "base internal format", then consult the format & type arguments.
  format | type         | internalformat
  -------|--------------|--------------------
	RGBA   |UNSIGNED_BYTE | RGBA8
	RGB    |UNSIGNED_BYTE | RGB8
	A      |UNSIGNED_BYTE | Alpha8
	... there are plenty of these permutations.

Unless specified elsewhere, the effective internal format values in table 3.12
	are not legal to pass directly to GL.


So it appears there are:
	types
	formats
	internalformats
	effectiveinternalformats (usually don't pass)

	