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
ROWS :: 3
COLUMNS :: 5
TILES :: ROWS * COLUMNS
TILE_SIZE_PX :: 16

gs: ^Game_State

Game_State :: struct {
	focused_tile: int,
	player:   Faction,
	enemy:    Faction,
	tiles:    [TILES]Tile,
	projects: [dynamic]^Tile,
	zoom:     bool,
}

Faction :: struct {
	population: int,
	ore:        int,
	food:       int,
	water:      int,
}

// The last user to work the improvement.
Tile_Owner :: enum {
	None,
	Player,
	Enemy,
}

Tile :: struct {
	index:    int,
	owner:    Tile_Owner,
	resource: Tile_Type,
	project:  Project,
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
	in_progress:  bool,
	start_time:   time.Tick,
	max_time:     time.Duration,
	temp_workers: int,
	ore_cost:     int,
	food_cost:    int,
	water_cost:   int,
}

game_init :: proc () {
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

	globals.cursor = make_entity()
	globals.cursor.flags += {.Hidden}
	globals.draw_colliders = false
	globals.canvas_size_px = {640,400}
	globals.canvas_scaling = .None
	globals.canvas_stretching = .Integer_Aspect

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
}

@export
game_step :: proc () {
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
	if sugar.on_key_press(.Space) {
		gs.zoom = !gs.zoom
	}

	globals.cursor.position.xy = globals.mouse_position

	for i in 0..<TILES {
		// ctx := build_context()
		// ctx.scale =
		// ctx.position =
		grid: Transform
		grid.scale = TILE_SIZE_PX * tile_scale()
		grid.position.xy = grid.scale.x/2 + Vec2{TILE_SIZE_PX * 8 - 2, 5}
		it := tile_entity(grid, &gs.tiles[i], loop_hash("tile", i))
		if i == gs.focused_tile {
			text(fmt.tprintf("Tile: %v", gs.tiles[i].resource))
		}
	}
}

tile_scale :: proc () -> f32 { return 2.0 if gs.zoom else 1.0 }

tile_entity :: proc (
	basis: Transform,
	tile: ^Tile,
	hash: Located_Hash_Input = #caller_location,
) -> (^Entity, bool) #optional_ok {
	it, is_new := rect(hash)
	it.basis = basis
	row := tile.index % COLUMNS
	column := tile.index / COLUMNS
	it.position.xy = {f32(row), f32(column)} * (TILE_GAP + basis.scale.x)
	it.color.rgb = resource_colors[tile.resource]
	if tile.resource == .Ore {
		img, new_ore := image("ore16.ase", loop_hash("tile", tile.index))
		img.basis = basis
		img.position.xy = it.position.xy
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Food {
		img, new_food := image("food16.ase", loop_hash("food", tile.index))
		img.basis = basis
		img.position.xy = it.position.xy
		it.color.rgb = resource_colors[tile.resource]
	} else if tile.resource == .Water {
	} else if tile.resource == .Grass {
	} else if tile.resource == .Barracks {
	} else {
		log.infof("undecorated resource: %v", tile.resource)
	}
	return it, is_new
}

project_completion_pct :: proc (it: Project) -> f32 {
	return f32(time.tick_diff(it.start_time, time.tick_now()) / it.max_time)
}

start_project :: proc (tile: ^Tile, project: Project) {
	tile.project = project
	append(&gs.projects, tile)
}

finish_project :: proc (tile: ^Tile) {
	ensure(tile.project.in_progress)
	idx, found := find(gs.projects[:], tile)
	ensure(found)
	ordered_remove(&gs.projects, idx)
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
