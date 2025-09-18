Questions {
	1. Sprites: To loop, or not, by default?
	            How to let user config which ones loop?
	            Define as finite in aseprite?
	2. Sprites: Should there be a more obvious play() pause()?
	            Maybe define them on all nodes?
}

################################################################################
# API ##########################################################################
################################################################################

root repo {
	entity()
		.parent = Entity
		.time_scale = 2
		.position =
		.scale    =
		.rotation =
		.skip_hit_test =
		.skip_render   =
		.is_3D         =

	text("Hellope!")
		.text    = "Hello"
		.usage   = .body_large
		.variant = .italic

	image("crow.png")
		.image = "other.aseprite"

	sprite("character.aseprite")
		.sprite = "other.aseprite"
		.repetitions = 1
		set_animation(entity, "run")

	geo {
		circle()    rename
		rectangle() rename
	}
}

package kv5 {
	load
	store
	delete
}


################################################################################
# TODO #########################################################################
################################################################################

platform {  GL  | INPUT      | AUDIO
  macOS   ANGLE | IOKit      | CoreAudio
  windows WGL   | GameInput  | XAudio2
  linux   WAYLND| evdev      | PulseAudio or ALSA
  web     WebGL2| GamepadAPI | WebAudio
}

non-rendering {
	pressed()
	released()
	play()
	pause()
	tween()
	sound("ogg/wav")
	button(data, proc)
}

root repo {
	shader(vertex, fragment)
	sound("caw.ogg")
	shadertoy(anyshape, shader)

	geo {
		circle_fan() TODO
		collided(entity, entity)
		path()
		polygon()

		sphere()
		box()
		cylinder()
	}

	collision:
	  entities: [2]Entity
	  point:    [3]f32

	ui {
		button(icon, label, style)
		ui_box(corner_radius)
		row()
		column()
		flexible()
		centered()
	}
}

assorted issues: {
	when no resource found for asset-path, debug draw and log once.
	cant set image() filter without affecting whole atlas.
}

################################################################################
# Idea #########################################################################
################################################################################

instance_entity(entity, count, user_data, builder)

sound:
	playing: bool
	progress: float
