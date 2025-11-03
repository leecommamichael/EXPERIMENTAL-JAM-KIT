package main

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: matrix[4,4]f32
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec2 :: #force_inline proc "contextless" (x, y: f32) -> [2]f32 {
	return {x, y}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec3 :: proc {
	vec3make,
	vec3of2,
	vec3of1,
}

vec3make :: #force_inline proc "contextless" (x, y, z: f32) -> [3]f32 {
	return {x, y, z}
}

vec3of2 :: #force_inline proc "contextless" (xy: Vec2, z: f32 = 0) -> Vec3 {
	return {xy.x, xy.y, z}
}

vec3of1 :: #force_inline proc "contextless" (xyz: f32) -> Vec3 {
	return {xyz, xyz, xyz}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
vec4 :: proc {
	vec4make,
	vec4of3
}

vec4make :: #force_inline proc "contextless" (x, y, z, w: f32) -> Vec4 {
	return {x, y, z, w}
}

vec4of3 :: #force_inline proc "contextless" (vec3: Vec3, w: f32) -> Vec4 {
	return {vec3.x, vec3.y, vec3.z, w}
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
is_nearly :: proc {
	is_nearly_float,
	is_nearly_array,
}

@(require_results)
is_nearly_float :: #force_inline proc "contextless" (
	value,
	target: $F,
	margin := 0.00001
) -> bool where is_float(F) {
	assert_contextless(value == value) // NaN check.
	assert_contextless(is_real(target))

	margin := F(margin) // is this a copy? No idea. TODO: Check optimizer output.
	return value >= target - margin && value <= target + margin
}

@(require_results)
is_nearly_array :: proc "contextless" (
	values: $A/[$N]$T,
	target: [N]T,
	margin := 0.00001
) -> bool where is_float(T) {
	for i in 0..<N {
		if !is_nearly_float(values[i], target[i], margin) { return false }
	}
	return true
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// This proc doesn't consider NaN/Inf to be "real"
is_real :: proc {
	is_real_float,
	is_real_array
}

// Returns true if the float wouldn't propagate errors through it's bit-pattern.
@(require_results)
is_real_float :: proc "contextless" (f: $T) -> bool where is_float(T) 
{
	switch math.classify(f) {
	case .Normal, .Zero, .Neg_Zero: 
		return true
	case .Subnormal, .NaN, .Inf, .Neg_Inf:
		return false
	}
	return false
}

@(require_results)
is_real_array :: proc "contextless" (x: $A/[$N]$T) -> bool where is_float(T) {
	for i in 0..<N {
		is_real := #force_inline is_real_float(x[i])
		if !is_real {
			return false
		}
	}
	return true
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
distance :: linalg.distance
trunc :: glsl.trunc
ceil :: glsl.ceil
vec_min :: linalg.min
vec_max :: linalg.max
lerp :: math.lerp