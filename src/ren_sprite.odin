package main

import gl "nord_gl"
import log "core:log"

//////////////////////////////////////////////////////////////////////
// Entity Variant
//////////////////////////////////////////////////////////////////////
// for play/pause/speed use entity.time_scale
Sprite_Entity :: struct {
	using base:      Entity,
	sprite:          ^Sprite,
	repetitions:     int,
	animation:       ^Sprite_Animation,
	frame_index:     int,
	frame_seconds_remaining: f64,
	_play_in_reverse: bool,
}

Sprite :: struct {
	filename:   string,
	size_px:    [2]int,
	frames:     []Sprite_Animation_Frame,
	animations: map[string]Sprite_Animation,
}

/**/	Sprite_Animation_Frame :: struct {
/**/		uv_rect: Vec4, // .xy = top_left, .w = width, .z = height
/**/		seconds: f64,
/**/	}
/**/
/**/	Sprite_Animation :: struct {
/**/		name:                 string,
/**/		first_frame_index:    int,
/**/		final_frame_index:    int, // consider removing. have offset + len
/**/		frame_count:          int,
/**/		playback_mode:        Animation_Playback_Mode,
/**/	}
/**/
/**/	Animation_Playback_Mode :: enum {
/**/		Forward,
/**/		Reverse,
/**/		Ping_Pong,
/**/		Ping_Pong_Reverse,
/**/	}


//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////

sprite :: proc (filename: string) -> ^Sprite_Entity {
	sprite: ^Sprite = &globals.assets.sprites[filename]
	entity: ^Sprite_Entity = make_entity(Sprite_Entity)
	entity.sprite = sprite
	return entity
}

do_sprite :: proc (filename: string, position: Vec3) -> (events: bit_set[Sprite_Event]) {
	entity := sprite(filename)
	events = step_sprite(0.16, entity, immediate=true)
	ren_draw_entity(globals.ren, transmute(^Entity) entity)
	free_entity(entity)
	return
}

/**/	Sprite_Event :: enum {
/**/		None,
/**/		Repetition_Completed,
/**/		Animation_Completed,
/**/		Frame_Advanced,
/**/	}

set_animation :: proc (it: ^Sprite_Entity, name: string) {
	if !(name in it.sprite.animations) {
		log.errorf("animation not found in sprite.")
		return
	}
	it.animation = &it.sprite.animations[name]
	reset_animation(it)
}

reset_animation :: proc (it: ^Sprite_Entity) {
	switch it.animation.playback_mode {
		case .Forward: 
			it.frame_index = it.animation.first_frame_index
		case .Ping_Pong:
			it.frame_index = it.animation.first_frame_index
			it._play_in_reverse = false
		case .Reverse:
			it.frame_index = it.animation.final_frame_index
		case .Ping_Pong_Reverse:
			it.frame_index = it.animation.final_frame_index
			it._play_in_reverse = true
	}
	it.frame_seconds_remaining = 0
}

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////

sprite_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
	out vec4 io_color;
	out vec2 uv;

	void main() {
		uv = v_texcoord;
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

sprite_fragment_shader_source :: fragment_preamble + `
	uniform sampler2D font_atlas;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 tex_color = texture(font_atlas, uv);
		tex_color = mix(tex_color, io_color, tex_color.r);
		tex_color = mix(tex_color, vec4(0,0,0,0), 1.-tex_color.r);
		outColor = tex_color;
	}
`

ren_make_sprite_draw_cmd :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd = ren_make_basic_draw_cmd(instance_buffer, instance_index, vertices, indices)
	cmd.program = globals.ren.programs[Game_Shader.Sprite]
	return cmd
}

// If instance data needs to be mutated from properites mutated during `step`, do it here.
step_sprite :: proc (_dt: f64, it: ^Sprite_Entity, immediate: bool) -> (events: bit_set[Sprite_Event]) {
	dt := _dt* it.time_scale
	assert(is_real(dt))
	seconds_left := it.frame_seconds_remaining - dt
	if it.animation.frame_count < 2 { return } // Single frame, no work.
	if it.repetitions < 1 { return } // All repetitions finished, no work.
	if seconds_left <= 0 {
// We used up all of this frame's time. Let's see how many we need to advance.
		seconds_to_spend := dt - it.frame_seconds_remaining
		for seconds_to_spend > 0 {
			offset := -1 if it._play_in_reverse else 1
			it.frame_index = (it.frame_index + offset) % len(it.sprite.frames)
// Decide on the next frame_index.
			if it.frame_index > it.animation.final_frame_index {
				switch it.animation.playback_mode {
				case .Forward:
					count_repetition(it, &events) or_break
					it.frame_index = it.animation.first_frame_index
				case .Reverse: assert(false)
				case .Ping_Pong:
					count_repetition(it, &events) or_break
					it.frame_index = it.animation.final_frame_index - 1
					it._play_in_reverse = !it._play_in_reverse
				case .Ping_Pong_Reverse:
					it.frame_index = it.animation.final_frame_index - 1
					it._play_in_reverse = !it._play_in_reverse
				}
			} else if it.frame_index < 0 {
				switch it.animation.playback_mode {
				case .Forward: assert(false)
				case .Reverse:
					count_repetition(it, &events) or_break
					it.frame_index = it.animation.final_frame_index
				case .Ping_Pong:
					it.frame_index = it.animation.first_frame_index + 1
					it._play_in_reverse = !it._play_in_reverse
				case .Ping_Pong_Reverse:
					count_repetition(it, &events) or_break
					it.frame_index = it.animation.first_frame_index + 1
					it._play_in_reverse = !it._play_in_reverse
				}
			}
			events += { .Frame_Advanced }
			it.frame_seconds_remaining = it.sprite.frames[it.frame_index].seconds
			seconds_to_spend -= it.frame_seconds_remaining
		}
	} else {
		it.frame_seconds_remaining = seconds_left
	}
	uv_xform := it.sprite.frames[it.frame_index].uv_rect
// Can just use a single static draw call and shared instance data.
// just assign the instance's uv_xform and you're done.
	return events
}

// TODO: rename to loop, cycle, loop_cycle?
count_repetition :: proc (
	it: ^Sprite_Entity,
	events: ^bit_set[Sprite_Event]
) -> (animation_complete: bool) {
	it.repetitions -= 1
	if it.repetitions < 1 {
		events^ += { .Animation_Completed }
		return true
	} else {
		events^ += { .Repetition_Completed }
		return false
	}
}