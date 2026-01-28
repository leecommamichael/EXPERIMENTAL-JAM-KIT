// Globals:
	// layers:       map[string]Depth_Layer,
	// layer_offset: int,

// Framework:
	// Depth_Layer :: struct {
	// 	base:   i16,
	// 	offset: i16,
	// 	size:   i16,
	// }

	// // Stop `next_z` from returning the z_cursor, and to use a layer instead.
	// set_depth_layer :: proc () {
		
	// }

	// make_depth_layer :: proc (key_name: string, size: int) -> ^Depth_Layer {
	// 	globals.layers[key_name] = {
	// 		base   = cast(i16) globals.layer_offset,
	// 		offset = cast(i16) globals.layer_offset,
	// 		size   = cast(i16) size,
	// 	}
	// 	globals.layer_offset += size
	// 	return &globals.layers[key_name]
	// }

	// destroy_depth_layers :: proc () {
	// 	delete_map(globals.layers)
	// }

	// reset_depth_layer :: proc (layer: ^Depth_Layer, reset_to_offset: int = 0) {
	// 	layer.offset = cast(i16) reset_to_offset
	// }

	// next_z_in_depth_layer :: proc (layer: ^Depth_Layer) -> f32 {
	// 	z := layer.offset
	// 	layer.offset += 1
	// 	assert(layer.offset >= layer.base && layer.offset <= layer.base + layer.size)
	// 	return f32(z)
	// }

// SimplerTimes game (XXX)
	// @static layer_background: ^Depth_Layer
	// @static layer_tile: ^Depth_Layer
	// @static layer_action: ^Depth_Layer
	// if layer_background == nil {
	// 	layer_background := make_depth_layer("BG", 100)
	// 	layer_tile := make()
	// 	layer_action := make_depth_layer()
	// }
