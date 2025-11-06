package main

// Purpose: This file makes use of services afforded by the framework.
//          It tries not to work with implementation details of i.e. the renderer.
//          This file should strive not to import OpenGL

import "core:log"
import "sugar"
import "base:runtime"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

cursor: ^Entity

game_init :: proc () {
	globals.canvas_size_px = {384, 216}
	globals.canvas_scaling = .Fixed
	globals.canvas_stretching = .Integer_Aspect

	cursor = make_sprite(`berserker.aseprite`)
	cursor.basis.position = 0
	cursor.flags += {.Collider_Enabled,}
	cursor.collider.shape = .Circle
	cursor.collider.size = 16
}

game_step :: proc () {
	cursor.position.xy = globals.mouse_position
}