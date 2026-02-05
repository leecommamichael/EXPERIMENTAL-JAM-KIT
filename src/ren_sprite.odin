package main

import gl "angle"
import log "core:log"

//////////////////////////////////////////////////////////////////////
// Entity Variant
//////////////////////////////////////////////////////////////////////

Sprite_State :: struct {
	asset:          ^Sprite_Asset,
	repetitions:     int,
	animation:       ^Sprite_Animation,
	frame_index:     int,
	frame_seconds_remaining: f32,
	_play_in_reverse: bool,
}

Sprite_Asset :: struct {
	filename:   string,
	frames:     []Sprite_Animation_Frame,
	animations: map[string]Sprite_Animation,
	size_px:    [2]int,
	texture:    ^GPU_Texture `cbor:"-"`
}

/**/	Sprite_Animation_Frame :: struct {
/**/		uv_rect: Vec4, // .xy = top_left, .w = width, .z = height
/**/		seconds: f32,
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

sprite :: proc (
	filename: string,
	hash: Hash = #caller_location
) -> (^Entity, bool) #optional_ok {
	entity, is_new := get_entity(hash)
	if is_new {
		init_sprite(entity)
		set_sprite(entity, filename)
	} else if filename != entity.variant.(Sprite_State).asset.filename {
		set_sprite(entity, filename)
	}
	step_sprite(entity)
	entity.position.z = next_z()
	return entity, is_new
}

//////////////////////////////////////////////////////////////////////
// Retained Interface
//////////////////////////////////////////////////////////////////////

make_sprite :: proc (filename: string) -> ^Entity {
	entity := make_entity()
	init_sprite(entity)
	set_sprite(entity, filename)
	return entity
}

init_sprite :: proc (entity: ^Entity) {
	mesh: Geom_Mesh2 = globals.unit_rect_mesh
	entity.draw_command = sprite_make_draw_command(globals.instance_buffer, cast(int) entity.id, mesh.vertices[:], mesh.indices[:])
	entity.color = {0,0,0,0} // don't mix a color overtop the sprite.
}

set_sprite :: proc (entity: ^Entity, filename: string) {
	asset := &globals.assets.sprites[filename]
	sprite_state := Sprite_State {
		asset = asset
	}
	entity.basis.scale.xy = array_cast(sprite_state.asset.size_px, f32)
	entity.basis.position.xy = array_cast(sprite_state.asset.size_px/2, f32)
	assert(len(sprite_state.asset.frames) > 0)
	assert(len(sprite_state.asset.animations) > 0)
	if "default" in sprite_state.asset.animations {
		set_animation(&sprite_state, "default")
	} else {
		// Fallback "first" animation. (maps are unordered, so it's unpredictable.)
		for _, &v in asset.animations {
			set_animation(&sprite_state, &v)
			sprite_state.animation = &v;
			break 
		}
	}
	entity.variant = sprite_state
}

/**/	Sprite_Event :: enum {
/**/		None,
/**/		Repetition_Completed,
/**/		Animation_Completed,
/**/		Frame_Advanced,
/**/	}

set_animation :: proc {
	set_animation_by_name,
	set_animation_by_value,
}

set_animation_by_name :: proc (it: ^Sprite_State, name: string) {
	if !(name in it.asset.animations) {
		log.errorf("animation not found in sprite.")
		return
	}
	it.animation = &it.asset.animations[name]
	reset_animation(it)
}

set_animation_by_value :: proc (it: ^Sprite_State, value: ^Sprite_Animation) {
	it.animation = value
	reset_animation(it)
}

reset_animation :: proc (it: ^Sprite_State) {
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

// If instance data needs to be mutated from properites mutated during `step`, do it here.
step_sprite :: proc (entity: ^Entity) -> (events: bit_set[Sprite_Event]) {
	it: ^Sprite_State = &entity.variant.(Sprite_State)
	defer entity.instance.uv_transform = it.asset.frames[it.frame_index].uv_rect
	dt := globals.tick * entity.time_scale
	assert(is_real(dt))
	seconds_left := it.frame_seconds_remaining - dt
	if it.animation.frame_count < 2 { return } // Single frame, no work.
	if it.repetitions < 1 { return } // All repetitions finished, no work.
	if seconds_left <= 0 {
// We used up all of this frame's time. Let's see how many we need to advance.
		seconds_to_spend := dt - it.frame_seconds_remaining
		for seconds_to_spend > 0 {
			offset := -1 if it._play_in_reverse else 1
			it.frame_index = it.frame_index + offset
// Decide on the next frame_index.
			if it.frame_index > it.animation.final_frame_index {
				switch it.animation.playback_mode {
				case .Forward:
					count_completed_loop(it, &events) or_break
					it.frame_index = it.animation.first_frame_index
				case .Reverse: assert(false)
				case .Ping_Pong:
					count_completed_loop(it, &events) or_break
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
					count_completed_loop(it, &events) or_break
					it.frame_index = it.animation.final_frame_index
				case .Ping_Pong:
					it.frame_index = it.animation.first_frame_index + 1
					it._play_in_reverse = !it._play_in_reverse
				case .Ping_Pong_Reverse:
					count_completed_loop(it, &events) or_break
					it.frame_index = it.animation.first_frame_index + 1
					it._play_in_reverse = !it._play_in_reverse
				}
			}
			it.frame_index %= len(it.asset.frames)
			events += { .Frame_Advanced }
			it.frame_seconds_remaining = it.asset.frames[it.frame_index].seconds
			seconds_to_spend -= it.frame_seconds_remaining
		}
	} else {
		it.frame_seconds_remaining = seconds_left
	}
// Can just use a single static draw call and shared instance data.
// just assign the instance's uv_xform and you're done.
	return events
}

// TODO: rename to loop, cycle, loop_cycle?
count_completed_loop :: proc (
	it: ^Sprite_State,
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

//////////////////////////////////////////////////////////////////////
// Shader
//////////////////////////////////////////////////////////////////////

sprite_make_draw_command :: proc (
	instance_buffer: gl.Buffer,
	instance_index: int,
	vertices: []Ren_Vertex_Base,
	indices:  []u32,
) -> (cmd: Draw_Command) {
	cmd = ren_make_basic_draw_cmd(instance_buffer, instance_index, vertices, indices)
	cmd.program = globals.ren.programs[Game_Shader.Sprite]
	return cmd
}

sprite_vertex_shader_source :: vertex_preamble + basic_vertex_inputs +
`
	out vec4 io_color;
	out vec2 uv;

	void main() {
		uv = i_uv_xform.xy + (v_texcoord * i_uv_xform.zw);
		io_color = i_color;
		mat4 mvp = frame.projection * frame.view * i_model_mat;
		gl_Position = mvp * vec4(v_position, 1);
	}
`

sprite_fragment_shader_source :: fragment_preamble +
`
	uniform sampler2D font_atlas;
	uniform sampler2D texture_atlas;

	in vec4 io_color;
	in vec2 uv;

	out vec4 outColor;

	void main() {
		vec4 tex_color = texture(texture_atlas, uv);
		// vec3 modulated = mix(tex_color.rgb, io_color.rgb, io_color.a);
		// outColor.rgb = mix(tex_color.rgb, modulated, tex_color.a);
		// outColor.a = float(tex_color.a);
		outColor = tex_color;
	}
`