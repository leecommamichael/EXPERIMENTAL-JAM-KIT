Ethos. It's time I got my own.

These are the repetitions. I promise to repeat them.

1. What are you building?
2. For who?
3. Why are you choosing to do it that way?
4. Does that work for the machine?
5. Does that work for other people?
6. Does that work for you?
7. Could it use math to make it more sound / general?

---

GLES Package

I am building it so Odin projects can easily target web.
I am building it for myself, and others if possible.
I am replacing vendor:OpenGL and vendor:wasm/webgl for two reasons:
	1. Primarily, the compiler has a bug about wrapping packages.
	2. I don't want to use their JS interface.
	3. vendor:OpenGL goes up to 4.x, and I need one interface for 3.3 Core
		 in order to prevent incompatibility.
It works for the machine, as I'm matching the spec.
It works mostly works for other people. I'm trying to make one interface that
  is minimally different in order to support Odin's types.
I like the approach.
I'm not sure if math is the right tool just yet, this is API design (human language / meta math)

Follow-ups:

Why not use WebGPU?
	1. It's fantasy, but so is OpenGL
	2. It's too new.
	3. It's got a bespoke shading language, and this is for general learning
	4. It's mostly for use on the web, and native webgpu is even less reliable
	5. GLSL is what's used in industry, and WGSL may never be.

Is it a good idea to use it in Gordon?
	I could see an argument for not. It's bespoke, not really OpenGL nor WebGL.
	On the other hand, it follows the word of the ES 3.0.6 and WebGL 2.0 specs.
	Anyone with access to those specs can implement this, because it's the compatible
	union between the two.

The biggest hole in this is that it runs on desktops.
Technically a Core 3.3 context is used, and so I really need to port my example
  project to an ES 3.0.6 platform to ensure it is what I say it is. But WebGL
  should do. It's fuzzy.