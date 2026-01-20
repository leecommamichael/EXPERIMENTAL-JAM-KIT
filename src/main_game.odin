package main

import "base:runtime"
import "core:fmt"
import "core:time"
import "core:log"
import "core:sys/windows"
import "core:math/rand"
import "sugar"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

@export
hot_reload :: proc (engine_globals: ^Globals, engine_gs: ^Game_State) {
	ensure(engine_gs != nil)
	ensure(engine_globals != nil)
	gs = engine_gs
	globals = engine_globals
	sugar.set_memory(&globals.sugar)
	sugar.load_gl()
	globals.hot_reloaded_this_frame = true
}

////////////////////////////////////////////////////////////////////////////////
// Brainless Minigame Jam: Simpler Times
////////////////////////////////////////////////////////////////////////////////
// RG35SP_RES: Vec2 = {640, 480}
// STEAM_DECK_RES: Vec2 = {1280, 800}
TILE_GAP :: 1
ROWS :: 23
COLUMNS :: 30
TILES :: ROWS * COLUMNS
TILE_SIZE_PX :: 16

gs: ^Game_State

Game_State :: struct {
	in_action_menu: bool,
	in_submenu:     bool,
	menu:     Enumerated_Union(Submenu),
	focused_tile: int,
	player:   Resources,
	enemy:    Resources,
	tiles:    [TILES]Tile,
	zoom:     bool,
}

Tile_Menu_Option :: enum {
	Build_Structure,
	Build_Transport,
	Build_Upgrade,
	Do_Mission,
}

Submenu :: union #no_nil {
	Structure_Menu_Option,
	Transport_Menu_Option,
	Barracks_Upgrade_Menu_Option,
	Mission_Menu_Option,
}

Structure_Menu_Option :: enum {
	Build_Barracks,
	Build_Forge
}
Transport_Menu_Option :: enum {
	Road,
	Aqueduct,
	Train,
}
Barracks_Upgrade_Menu_Option :: enum {
	Unit_Speed,
	Unit_Health,
	Unit_Power,
	Unit_Capacity,
}
Mission_Menu_Option :: enum {
	Laner_Gather_Resource,
	Laner_Fight, // Retreats at low health. If speed too low, can die.
	Spy_Tile,
	Spy_Sabotage_Tile,
}

// The last user to work the improvement.
Tile_Owner :: enum {
	None,
	Player,
	Enemy,
}

Tile :: struct {
	index:    int,
	resource: Tile_Type,
	owner:    Tile_Owner, // Determines who is doing the project.
	project:  Project,
	entity:   ^Entity,
}

Tile_Type :: enum {
	Grass,
	Ore,         // Build roads, forge, markets, barracks
	Food, Water, // Modulates spawn rate
	Workshop,    // improve/unlock units/resources
	Market,      // strengthen population
	Barracks,    // raise population
	Path,        // Allows non-scout units to move fast.
	// Enhanced water source. Maybe auto resource.
	Canal,
}

Project :: struct {
	start_time: time.Tick,
	max_time:   time.Duration,
	cost:       Resources,
	finished:   bool,
}

Resources :: struct {
	ore:     int,
	food:    int,
	water:   int,
	workers: int,
}

project_completion_pct :: proc (it: Project) -> f32 {
	return f32(time.tick_diff(it.start_time, time.tick_now()) / it.max_time)
}

try_start_project :: proc (tile: ^Tile, project: Project) -> (started: bool) {
	if gs.player.ore >= project.cost.ore\
	&& gs.player.food >= project.cost.food\
	&& gs.player.water >= project.cost.water\
	&& gs.player.workers >= project.cost.workers {
		start_project(tile, project)
		return true
	}
	return false
}

start_project :: proc (tile: ^Tile, project: Project) {
	ensure(tile.owner == .None && tile.project.finished)
	tile.project = project
	tile.owner = .Player
	gs.player.ore -= tile.project.cost.ore
	gs.player.food -= tile.project.cost.food
	gs.player.water -= tile.project.cost.water
	gs.player.workers -= tile.project.cost.workers
}

finish_project :: proc (tile: ^Tile) {
	ensure(tile.owner == .Player && !tile.project.finished)
	tile.project.finished = true
	gs.player.workers += tile.project.cost.workers
}

import gl "angle"
game_init :: proc () {
	gl.BindSampler(cast(u32) Texture_Unit.Framebuffer_Texture, globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Texture,             globals.ren.nearest_sampler)
	gl.BindSampler(cast(u32) Texture_Unit.Font,                globals.ren.nearest_sampler)
	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.cursor.position.xy = globals.mouse_position.xy
	globals.draw_colliders = false
	globals.canvas_size_px = {640,400}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect
	globals.canvas_stretching = .Integer_Aspect

	r := rand.create(10)
	context.random_generator = rand.default_random_generator(&r)
	// How many ore, food, water to spawn?
	// Where to spawn them?
	// Well, there are 936 tiles.
	// if 1% chance for food, water, ore each, I'd get 9 of each.
	// So there's a relation between N tiles and N desired resources.
	// Let's say I want to spawn 5 things, SOMEWHAT evenly spaced through the tiles.
	// So I don't really want randomness...
	ore_remaining := 6
	water_remaining := 6
	food_remaining := 6

	gs = new(Game_State)

	for i in 0..<TILES {
		tile: ^Tile = &gs.tiles[i]
		tile.index = i
		tile.resource = .Grass
		f01 := rand.float32()
		if f01 <= 0.005 && ore_remaining > 0 {
			tile.resource = .Ore
			ore_remaining -= 1
		} else if f01 <= 0.01 && food_remaining > 0 {
			tile.resource = .Food
			food_remaining -= 1
		} else if f01 < 0.015 && water_remaining > 0 {
			tile.resource = .Water
			water_remaining -= 1
		}
	}
	gs.tiles[0].resource = .Barracks
	gs.tiles[0].owner = .Player
	gs.tiles[TILES-1].resource = .Barracks
	gs.tiles[TILES-1].owner = .Enemy
	gs.player.workers = 1
}

PANEL_SIZE: Vec2 = {120, 400}
SPACER :: 16

@export
game_step :: proc () {
	eph_in_action_menu: bool
	eph_in_submenu: bool
	if gs.in_action_menu {
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			eu_prev_tag(&gs.menu)
			eu_print(&gs.menu)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			eu_next_tag(&gs.menu)
			eu_print(&gs.menu)
			// fmt.printfln("Menu Case: %v", gs.menu)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			gs.in_submenu = true
			eph_in_submenu = true
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			gs.in_action_menu = false
		}
	} else if gs.in_submenu {
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			eu_add_to_case(&gs.menu, -1)
			fmt.printfln("SubMenu Case: %v", gs.menu)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			eu_add_to_case(&gs.menu, +1)
			fmt.printfln("SubMenu Case: %v", gs.menu)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			fmt.printfln("Entered SubMenu %v", gs.menu)
			// try_start_project()
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			gs.in_action_menu = true
			eph_in_action_menu = true
		}
	} else /* In overworld */ {
		// TODO: Wraps to 0 and TILES-1 on vertical movement.
		if sugar.on_button_press(.Up) || sugar.on_key_press(.W) {
			gs.focused_tile = clamp(gs.focused_tile + COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Down) || sugar.on_key_press(.S) {
			gs.focused_tile = clamp(gs.focused_tile - COLUMNS, 0, TILES-1)
		}
		if sugar.on_button_press(.Left) || sugar.on_key_press(.A) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile - 1, row_min, row_max)
		}
		if sugar.on_button_press(.Right) || sugar.on_key_press(.D) {
			row := gs.focused_tile / COLUMNS 
			row_min := row * COLUMNS
			row_max := row_min + COLUMNS - 1
			gs.focused_tile = clamp(gs.focused_tile + 1, row_min, row_max)
		}
		if sugar.on_button_press(.A) || sugar.on_key_press(.Space) {
			fmt.printfln("Entered Menu %v", gs.menu)
			gs.in_action_menu = true
			eph_in_action_menu = true
		}
		if sugar.on_button_press(.B) || sugar.on_key_press(.Q) {
			// On tiles, nothing to go back to.
		}
	}

	if sugar.on_button_press(.Y) || sugar.on_key_press(.E) {
		gs.zoom = !gs.zoom
	}

	bg := rect()
	bg.basis.scale.xy = globals.canvas_size_px
	uncenter_rect(bg)
	bg.color = color("#234")

	panel := rect()
	panel.basis.scale.xy = PANEL_SIZE
	uncenter_rect(panel)
	panel.color = color("#0126")

	for i in 0..< TILES {
		basis: Transform
		basis.scale = TILE_SIZE_PX * tile_scale()
		basis.position.xy = basis.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
		it := tile_entity(basis, &gs.tiles[i], loop_hash("tile", i))
		gs.tiles[i].entity = it
	}

	focused_tile := &gs.tiles[gs.focused_tile]

	tile_highlight := rect()
	tile_highlight.basis = focused_tile.entity.basis
	tile_highlight.position.xy = focused_tile.entity.position.xy
	tile_highlight.position.z += 100 // KILL
	// sin01 :: proc (theta: f32) -> f32 { return (sin(theta) + 1) / 2 }
	// sinq2q :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.25 }
	sinbh :: proc (theta: f32) -> f32 { return ((sin(theta) + 1) / 4) + 0.2 }
	@static time: f32; time += globals.tick
	tile_highlight.color = color("ff6")
	tile_highlight.color.a = sinbh(2*time)

	menu_structure := text("+ Structure", .bold_pixel) // Barracks, Forge,
	menu_transport := text("+ Transport", .bold_pixel) // Road, Aqueduct, Train
	menu_upgrade := text("+ Upgrade", .bold_pixel)     // Barracks, Forge (unit stats, city stats)
	menu_mission := text("+ Mission", .bold_pixel)     // Spy, Sabotage, Gather-Resource(N)

	col := ui_element(
		column(
			pad_box(16),
			text_list_item("ORE:", fmt.tprintf("%d", gs.player.ore)),
			text_list_item("FOOD:", fmt.tprintf("%d", gs.player.food)),
			text_list_item("WATER:", fmt.tprintf("%d", gs.player.water)),
			text_list_item("WORKER:", fmt.tprintf("%d", gs.player.workers)),
			pad_box(16),
			text_list_item("THIS TILE:", fmt.tprintf("%v", focused_tile.resource)),
			pad_box(16),
			text("ACTIONS:", .bold_pixel),
			menu_structure,
			menu_transport,
			menu_upgrade,
			menu_mission,
			pad_box(16),
		),
		position = Vec2{6, 100},
	)

	// lerp a highlighter from the tile to the menu
	menu_highlight := rect()
	Transform_Lerp_Data :: struct { sink: ^Transform, start: Transform, end: Transform }
	if eph_in_action_menu {
		lerp_data: Transform_Lerp_Data = {
			sink  = &menu_highlight.transform,
			start = transform_combine(tile_highlight.basis, tile_highlight.transform),
			end   = transform_combine(menu_structure.basis, menu_structure.transform),
		}
		lerp_data.end.scale.xy = measure_text(menu_structure^)
		lerp_data.end.position.x = lerp_data.end.scale.x / 2 + 6
		timed_effect(lerp_data, 0.2, proc (data: ^Transform_Lerp_Data, percent: f32) {
			data.sink^ = lerp_transform(data.start, data.end, percent)
			// data.sink.position.z = next_z()
		})
	}
	menu_highlight.color = color("ff6")
	menu_highlight.color.a = sinbh(2*time)

	if gs.in_action_menu {
		tile_highlight.color.a = 0.3
	} else {
		menu_highlight.color.a = 0	
	}

}// game step

text_list_item :: proc (
	label: string,
	value: string,
	hash: Hash = #caller_location
) -> ^Entity {
	_label := text(label, .bold_pixel, hash=loop_hash(label, 1))
	_label.color = color("#aaa")
	_value := text(value, .bold_pixel, hash=loop_hash(label, 2))
	return ui_element(
		column(
			_label,
			_value,
			hash = loop_hash(label, 3)
		)
	)
}

tile_scale :: proc () -> f32 { return 2.0 if gs.zoom else 1.0 }
// TBD
// row_column_of_index :: proc (index: int) -> (row, column: int) {
// 	row = index % COLUMNS
// 	column = index / COLUMNS
// }

// position_of_tile_at_index :: proc () {
// 		grid: Transform
// 		grid.scale = TILE_SIZE_PX * tile_scale()
// 		grid.position.xy = grid.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
// 		it := tile_entity(grid, &gs.tiles[i], loop_hash("tile", i))
// 		it.position.xy = {f32(row), f32(column)} * (TILE_GAP + basis.scale.x)
// }


tile_entity :: proc (
	basis: Transform,
	tile: ^Tile,
	hash: Hash = #caller_location,
) -> (^Entity, bool) #optional_ok {
	it, is_new := rect(hash)
	it.basis = basis
	row := tile.index % COLUMNS
	column := tile.index / COLUMNS
	it.position.xy = {f32(row), f32(column)} * (TILE_GAP + basis.scale.x)
	if tile.resource == .Ore {
		img := image("ore16.ase", loop_hash("ore", tile.index))
		transform(img, it^)
	} else if tile.resource == .Food {
		img := image("food16.ase", loop_hash("food", tile.index))
		transform(img, it^)
	} else if tile.resource == .Water {
		shape := circle(loop_hash("water", tile.index))
		shape.basis = basis
		shape.position.xy = it.position.xy
		shape.color.rgb = resource_colors[.Water]
		shape.basis.scale.xy += 0
		it.color.rgb = 0
	} else if tile.resource == .Grass {
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Barracks {
		it.color.rgb = resource_colors[tile.resource]
	} else {
		log.infof("undecorated resource: %v", tile.resource)
	}
	return it, is_new
}

resource_colors: [Tile_Type]Color3 = {
	.Grass    = {0.412, 0.651, 0.255},

	.Ore      = {0.859, 0.686, 0.235},
	.Food     = {0.761, 0.494, 0.184},
	.Water    = {0.208, 0.514, 0.749},

	.Workshop = {0.451, 0.224, 0.176},
	.Market   = {0.580, 0.329, 0.239},
	.Barracks = {0.769, 0.561, 0.376},

	.Path     = {0.541, 0.290, 0.192},
	.Canal    = {0.208, 0.514, 0.749},
}
