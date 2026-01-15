package main

import "base:runtime"

////////////////////////////////////////////////////////////////////////////////
// Timed_Effect
////////////////////////////////////////////////////////////////////////////////
// this is an entity variant, so putting T here could inflate entities.
// So some things are pointers that otherwise would not be.
Timed_Effect_State :: struct ($T: typeid) {
	data: ^T,
	step: proc(data: ^T, percent: f32),
	seconds_total: f32,
	seconds_left: f32,
	timeout: proc(^T),
	allocator: runtime.Allocator,
}

step_timed_effect :: proc (entity: ^Entity, tick: f32 = globals.tick) {
	it := &entity.variant.(Timed_Effect_State(Empty_Struct))

	it.seconds_left -= tick
	percent := clamp(1 - cast(f32) (it.seconds_left/it.seconds_total), 0, 1)
	it.step(it.data, percent)

	if it.seconds_left <= 0 {
		if it.timeout != nil {
			it.timeout(it.data)
		}
		free(it.data, it.allocator)
		free_entity(entity)
	}
}

timed_effect :: proc (
	data: $T,
	seconds_left: f32,
	step: proc(data: ^T, percent: f32),
	allocator := context.allocator
) -> ^Timed_Effect_State(T) {
	ent := make_entity()
	data_copy := new(T, allocator)
	data_copy^ = data
	effect := Timed_Effect_State(T) {
		data_copy,
		step,
		seconds_left,
		seconds_left,
		nil,
		allocator,
	}
	ent.variant = transmute(Timed_Effect_State(Empty_Struct))effect
	ent.flags += {.Hidden}
	return transmute(^Timed_Effect_State(T)) &ent.variant.(Timed_Effect_State(Empty_Struct))
}

////////////////////////////////////////////////////////////////////////////////
// Timed_Lerp
////////////////////////////////////////////////////////////////////////////////
Lerp :: struct {
	sink: ^f32,
	start: f32,
	target: f32,
}

Timed_Lerp :: Timed_Effect_State(Lerp)
timed_lerp :: proc (
	data: ^f32,
	target: f32,
	seconds_left: f32,
	allocator := context.allocator
) -> ^Timed_Lerp {
	ent := make_entity()
	managed_data := new(Lerp, allocator)
	managed_data^ = Lerp { sink=data, start=data^, target=target }
	effect := Timed_Effect_State(Lerp) {
		managed_data,
		proc (it: ^Lerp, percent: f32) {
			it.sink^ = cast(f32) lerp(it.start, it.target, percent)
		},
		seconds_left,
		seconds_left,
		nil,
		allocator,
	}
	ent.variant = transmute(Timed_Effect_State(Empty_Struct))effect
	ent.flags += {.Hidden}
	return transmute(^Timed_Effect_State(Lerp)) &ent.variant.(Timed_Effect_State(Empty_Struct))
}