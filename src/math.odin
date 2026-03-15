package main

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/linalg/hlsl"
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Types and their idioms.
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
// Operations.
reflect :: linalg.reflect // (incident, normal) -> reflection
length :: linalg.length
distance :: linalg.distance
normalize :: linalg.normalize
dot :: linalg.dot
cross :: linalg.cross
abs :: linalg.abs
round :: linalg.round
fmod :: hlsl.fmod
trunc :: glsl.trunc
ceil :: glsl.ceil
vec_len :: linalg.length
vec_min :: linalg.min
vec_max :: linalg.max
lerp :: proc {
	math.lerp,
	lerp_vec,
	lerp_transform,
}
atan2 :: math.atan2
sin :: math.sin
cos :: math.cos
exp :: math.exp
pow :: math.pow
sign :: math.sign
sqrt :: math.sqrt
PI :: math.PI
inf_f32 :: math.inf_f32
inf_f64 :: math.inf_f64

// Selects the quantity with the smaller absolute value,
// but returns the quantity with sign included.
@(require_results)
min_by_abs :: proc "contextless" (a: ..f32) -> (out: f32) {
	out = max(f32)
	for elem in a {
		if abs(elem) < abs(out) {
			out = elem
		}
	}
	return
}

// Snaps input to nearest of: Left, Right, Up, Down
nearest_direction_xy :: proc(vec: Vec3) -> Vec3 {
	rad := atan2(vec.y, vec.x) // -PI to PI
	switch {
	case between(rad,    PI/4,  3*PI/4): return UP;
	case between(rad, -3*PI/4,   -PI/4): return DOWN;

	case rad <= -3*PI/4 || rad >= 3*PI/4: return LEFT;
	case rad >=   -PI/4 || rad <=   PI/4: return RIGHT;
	}
	panic("unhandled range")
}

// inclusive
between :: #force_inline proc "contextless" (val, min, max: f32) -> bool {
	assert_contextless(is_real(val))
	return val >= min && val <= max;
}

lerp_vec :: proc "contextless" (l,r: Vec3, alpha: f32) -> Vec3 {
	return {
		lerp(l.x, r.x, alpha),
		lerp(l.y, r.y, alpha),
		lerp(l.z, r.z, alpha),
	}
}

lerp_transform :: proc "contextless" (l,r: Transform, alpha: f32) -> Transform {
	return {
		lerp_vec(l.position, r.position, alpha),
		lerp_vec(l.rotation, r.rotation, alpha),
		lerp_vec(l.scale, r.scale, alpha),
	}
}

clamp_length :: proc "contextless" (direction: Vec3, max_length: f32) -> Vec3 {
	length := length(direction)
	if length > max_length {
		normalized := direction / length
		return normalized * max_length
	}
	return direction
}

precision :: proc (f: f32, digits: int) -> f32 {
	k := pow(10, f32(digits))
	kept_digits := (k * f)
	kept_digits = trunc(kept_digits)
	return kept_digits / k
}

////////////////////////////////////////////////////////////////////////////////
// Curves
////////////////////////////////////////////////////////////////////////////////
// k : -1 to 10000
// -1 to 0: k will bow the curve to the bottom-right
// 0 to 10000: k will bow the curve to the top-left
// at 10000 and -1 the curve is a right-angle.
midtone :: proc (x, k: f32) -> f32 {
	return (k+1)*x/(1+k*x)
}

when ODIN_OS == .Windows {
	foreign import libc "system:libucrt.lib"
} else when ODIN_OS == .Darwin {
	foreign import libc "system:System"
} else {
	foreign import libc "system:c"
}

@(default_calling_convention="c")
foreign libc {
	// Bessel function
	@(link_name="_j0") bessel :: proc(x: f64) -> f64 ---
}