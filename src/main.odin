package main

import "base:intrinsics"
import "core:time"
import "core:log"
import "core:slice"
import gl "nord_gl"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"
import sugar "sugar"

Entity_ID :: u16

// I've _prefixed anything that isn't for gameplay.
Entity :: struct {
	_id: Entity_ID, // index in storage.
	_used: bool,
	_ui:   bool, // 2D object anchored at origin in top-left (0,0)
	_asset: Ren_Asset,
	_distance_from_camera: f32,
	//
	position: Vec3,
	rotation: Vec3,
	scale:    f32, // PUNT nonuniform scale
	hidden:   bool,
	using instance: ^Ren_Instance,
}

X_Entity :: struct {
	using entity: Entity,
	using pillar: X
}
X :: struct {}

// ASSUME: All variants are subtypes of Entity.
Entity_Memory :: struct #packed {
	using entity: Entity,
	using variant: struct #raw_union {
		x: X,
	},
	// Can Transmute to Variants if I keep this below.
	tag: enum {
		Entity,
		X
	},
}

init_entity_memory :: proc (entity: ^Entity_Memory, id: Entity_ID) {
	entity^ = {} // zero
	entity._id = id
	entity._used = true
	entity.scale = 1
	entity.instance = subscript_aligned_array(&globals.instances, cast(int) entity._id)
	entity.instance^ = {} // zero
	entity.instance.color.a = 1
	entity.instance.uv_transform = {0,0,1,1}
}

make_entity :: proc {
	make_entity_basic,
	make_entity_variant
}

make_entity_basic :: proc () -> ^Entity {
	return make_entity_variant(Entity)
}

make_entity_variant :: proc ($T: typeid) -> ^T
where intrinsics.type_is_subtype_of(T, Entity) {
	for &mem, i in globals._entity_storage {
		if !mem._used {
			init_entity_memory(&mem, cast(Entity_ID) i)
			if T == X {
				mem.x = {}
				mem.tag = .X
			} else if T == Entity {
				mem.tag = .Entity
			} else {
				panic("Unimplemented Entity")
			}
			return transmute(^T) &mem
		}
	}
	panic("Out of entities.")
}

game_initialized := false

globals: Globals

Globals :: struct {
	// Engine Facilities
	gl_standard:        GL_Standard,
	ren:                ^Ren,
	instances:          Aligned_Array(Ren_Instance),
	_entity_storage:    [max(Entity_ID)]Entity_Memory,
	entities:           [dynamic]^Entity_Memory,
	game_entities:      [dynamic]^Entity_Memory,
	ui_entities:        [dynamic]^Entity_Memory,
	// Game State
	// Controls
	quit:               sugar.Button_Action,
	left_click:         sugar.Button_Action,
	right_click:        sugar.Button_Action,
	space:              sugar.Button_Action,
	// Coupled State
	uniforms:           Uniforms,
	// Window/Framebuffer
	resolution:         [2]int,
	aspect_ratio:       f32,
	// Camera
	game_camera:        Mat4,
	ui_orthographic:    Mat4,
	game_view:          Mat4,
	ui_view:            Mat4,
	camera:             Camera3D,
}

resolution_changed :: proc (res: [2]int) {
	globals.aspect_ratio = cast(f32)res.x / cast(f32)res.y
	globals.resolution = res

	globals.game_camera = glsl.mat4Ortho3d(
		left   = 0,
		right  = cast(f32) res.x,
		top    = 0,
		bottom = cast(f32) res.y,
		near   = -10,
		far    = 1000
	)
	globals.ui_orthographic = glsl.mat4Ortho3d(
		left   = 0,
		right  = cast(f32) res.x,
		top    = 0,
		bottom = cast(f32) res.y,
		near   = -10,
		far    = 1000
	)
}

main :: proc() {
	context.logger = log.create_console_logger(
		lowest = log.Level.Debug,
		opt = { .Level, } 
	)
	x := 1920 + 400 when ODIN_OS == .Windows else 0
	y := 400 when ODIN_OS == .Windows else 0
	x = 400
	y = 100
	window_rect := [4]int{x,y, 900, 900}
	ok := sugar.create_window(window_rect, "TCM", use_gl = true)
	ensure(ok)
	sugar.capture_cursor()
	sugar.set_cursor_visible(false)
	
	if sugar.platform_calls_step do return // Probably just Web.

	tick := time.tick_now()
	dt: f64
	frame_loop: for {
		feedback := sugar.poll_events() // empties message queue.
		if feedback == .Should_Exit {
			break frame_loop
		}
		if feedback == .Resized {
			resolution_changed(sugar.g_state.resolution)
		}

		dt = time.duration_seconds(time.tick_lap_time(&tick))
		if !step(dt) {
			break frame_loop
		}
		sugar.swap_buffers()
	}
}


GL_Standard :: struct {
	UNIFORM_BUFFER_OFFSET_ALIGNMENT: int,
	MAX_UNIFORM_BLOCK_SIZE: i64
}

// This is an entry-point, and so all game data must be globally visible for Web support.
@export
step :: proc(dt: f64) -> bool {
	if !game_initialized {
		game_initialized = true
		init_gl_constants :: proc () {
			assert(gl.glGetIntegerv != nil, "GL not loaded.")
			globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT = gl.GetIntegerv(.UNIFORM_BUFFER_OFFSET_ALIGNMENT)
			globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE          = gl.GetInteger64v(.MAX_UNIFORM_BLOCK_SIZE)
			log.infof("OpenGL Platform Constants ---\n" +
				"  MAX_UNIFORM_BLOCK_SIZE:          %v Bytes\n" +
				"  UNIFORM_BUFFER_OFFSET_ALIGNMENT: %v Bytes",
				globals.gl_standard.MAX_UNIFORM_BLOCK_SIZE,
				globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT
			)
		}
		init_gl_constants()
		#assert(size_of(Ren_Instance) < (1 << 14), "Instances may not fit in one Uniform Block")
		globals.instances = make_aligned_array(
			Ren_Instance,
			cast(int) max(Entity_ID),
			cast(int) globals.gl_standard.UNIFORM_BUFFER_OFFSET_ALIGNMENT
		)

		// 1. Init Globals /////////////////////////////////////////////////////////
		globals.game_view = 1
		globals.ui_view = 1
		game_entities := make([]^Entity_Memory, max(Entity_ID))
		globals.game_entities = slice.into_dynamic(game_entities)
		ui_entities := make([]^Entity_Memory, max(Entity_ID))
		globals.ui_entities = slice.into_dynamic(ui_entities)
		entities := make([]^Entity_Memory, max(Entity_ID))
		globals.entities = slice.into_dynamic(entities)
		globals.ren = ren_make()	
		ren_init(globals.ren)
		v,i := make_circle_2D(44.0)
		asset := ren_make_basic_asset(globals.ren, v, i, globals.ren.instance_UBO)
		ent := make_entity()
		ent._asset = asset
		ent.position = Vec3{88,88, 0}

		// 2. Init Inputs //////////////////////////////////////////////////////////
		globals.quit = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Escape],
		}
		globals.left_click = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Left_Mouse],
		}
		globals.right_click = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Right_Mouse],
		}
		globals.space = sugar.Button_Action {
			button = &sugar.g_state.input.keys[sugar.Key.Space],
		}
	}

	// 2. Simulate //////////////////////////////////////////////////////////// 
	clear(&globals.entities)
	clear(&globals.game_entities)
	clear(&globals.ui_entities)
	for &e in globals._entity_storage {
		if e._used {
			append(&globals.entities, &e)
		}
	}

	if sugar.on_release(&globals.quit) {
		return false // stop the app
	}
	
	finalize_simulation_frame :: proc () {
		for &entity in globals.entities {
			if entity.hidden {
				// INTENT: If an object is hidden, don't add it to render-lists.
				continue
			}

			entity.model_transform =
				linalg.matrix4_translate(entity.position) *
				linalg.matrix4_from_euler_angles_xyz_f32(entity.rotation.x, entity.rotation.y, entity.rotation.z) *
				linalg.matrix4_scale(entity.scale)
			if entity._ui {
				append(&globals.ui_entities, entity)
			} else {
				// TODO: Bucket Opaque from Transparent
				// ASSUME: Centroid is 0,0,0 in model coordinates
				centroid: Vec4 : { 0, 0, 0, 1 }
		    entity_centroid_in_world := entity.model_transform * centroid
				entity._distance_from_camera = glsl.distance(entity_centroid_in_world.xyz, globals.camera.position)
				append(&globals.game_entities, entity)
			}
		}
		// IDEA: Could use the same sort for UI and interpret it at Z index.
	  slice.sort_by(globals.game_entities[:], proc (i,j: ^Entity_Memory) -> bool {
	    return i._distance_from_camera > j._distance_from_camera
	  })
	}
	finalize_simulation_frame()
	ren_draw(globals.ren)

	return true // keep going
}
