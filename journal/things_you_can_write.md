Here are the things you should be able to write,
but can't because the GPU is a bastard.
> do_ prefix means it's immediate mode, and should be done each frame.

procs:
	collided(entity, entity)
	kv5_get(key)
	kv5_set(key, value)

Util
	shader(vertex, fragment)
	sound("caw.ogg")

ND
	path()
	polygon()
	shadertoy(anyshape, shader)

2D
	text("Hellope!")
	image("crow.png")
	sprite("character.aseprite")
	circle()
	rectangle()
	circle_fan()

3D
	sphere()
	box()
	cylinder()

UI
	button(icon, label, style)
	ui_box(corner_radius)
	row()
	column()
	flexible()
	centered()

entity:
	parent: Entity,
	position
	scale
	rotation
	...
	skip_hit_test: bool
	skip_render:   bool
	is_3D:         bool

image:
	filters: Nearest | Linear

sound:
	playing: bool
	progress: float
	
animation:
	playing: bool
	animation: string
	frame:     int

collision:
  entities: [2]Entity
  point:    [3]f32
----------------------------------------------------------------------	

Half-baked ideas:
	instance_entity(entity, count, user_data, builder)
