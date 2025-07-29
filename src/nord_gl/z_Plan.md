ngl: OpenGL with some help from Odin.

Step to realizing ubiquity:
	0. Design minimal changes to the API to enable portable usage.
	1. Comments provide full context on what is non-standard, why, and alternatives.
	2. Provide platform-native bindings if it is necessary to avoid caveats.
	3. Provide something of a "OpenGL Validation Layer"

Steps to realizing this library:
  1. This replaces vendor:OpenGL and vendor:wasm/WebGL2
  2. Copy WebGL 1 and 2 constants here.
	3. Add procs as-needed, ecah proc has its own enum of valid possible arguments.
		a. This means the values of those enum cases are GL enum cases.
		b. GL enum cases are still available with _underscore prefix.
	4. Use `when DEBUG` to add robustness and debug info since there is no debug messenger in 3_3
		a. Bounds-check args and panic early.
		b. Allow a flag to use a more modern context solely for the debug messenger (GL 4.x context)
		c. On ES,  if possible, load GL_KHR_debug and load "glDebugMessageCallbackKHR"
		d. On Web, https://developer.mozilla.org/en-US/docs/Web/API/WEBGL_debug_renderer_info.

0. Ubiquity.
1. GLenum safety makes it easier to learn, and avoid/detect crashes.
2. Odin flavor.

//////////////////////////////////////////////////////////////////////

How to synchronize the interface between Web and Native?

Function signatures must be the same
	foreign import works with static 
	foreign web {}
	foreign gl  {} // symbols aren't public for opengl3, can't use foreign

There need to be 2 implementations of the same interface.

			fnproc :: T // load point

			call_fn :: #force_inline proc () {
				when debug {dealwithargs}

				map args to impls.
				fnproc()
				do sutff

				when debug { check crash }
			}

We don't want the user just calling the loaded proc in debug anyway.
We want to inline everything over the loaded procs though.

Can I #static_assert that a proc matches the interface?

Then users can just see the proc types with comments and go from there.
The impls can be sure they match because #assert says so.

| nord_gl                 | thinnest compatibility layer on GLES 3.0 and WebGL 2
| nord_gl/wrapper         | For those who want to build the renderer. Me.
| nord_gl/wrapper/jam_gfx | For those who just wanna jam and maybe learn a shader.