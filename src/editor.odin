package main

import gl "vendor:OpenGL"
import ngl "nord_gl"
import "core:math/linalg"
import "core:math"
import "sugar" // reports mouse in pixels. top left is 0
import "core:log"

// Returns the position of the cursor, and its direction thru the camera frustum.
// e.g. cursor_in_world, cursor_direction := cursor_direction_in_world()
cursor_direction_in_world :: proc () -> (Vec3, Vec3) {
	ndc := pixel_to_ndc(sugar.mouse_position)
	return camera_clip_coord_direction(&globals.game_camera, &globals.game_view, ndc)
}

// Pixel origin is top-left and y is flipped.
// LIMIT: 32 bit floats have no gaps up to 16384 2^14, so screen resolution.
pixel_to_ndc :: proc (offset: [2]f32) -> [2]f32 {
	res: Vec2 = {
		cast(f32)sugar.viewport_size.x,
		cast(f32)sugar.viewport_size.y,
	}
	ndc: Vec2 = {
		 (2*offset.x / res.x) - 1,
		(-2*offset.y / res.y) + 1
	}
	return ndc
}

// Returns a unit vector representing the direction of an XY NDC coordinate
// pointing from the near to the far planes of the camera.
//
// NOTE: OpenGL specific as all other Z ranges are [0,1] not [-1, 1]
camera_clip_coord_direction :: proc (
	projection: ^Mat4,
	view:       ^Mat4,
	ndc:        [2]f32
) -> (Vec3, Vec3) {
	// inverse(p*v) takes NDC -> camera -> world
	ndc_to_world := linalg.inverse(projection^ * view^)
	cursor_near := ndc_to_world * vec4(vec3(ndc, 1), 1) // <- OpenGL Z-
	cursor_far  := ndc_to_world * vec4(vec3(ndc,-1), 1) // <- OpenGL Z+ (flipped because depth-range flipped)
	origin      := cursor_near.xyz / cursor_near.w
	destination := cursor_far.xyz / cursor_far.w
	return origin, linalg.normalize(destination - origin)
}
