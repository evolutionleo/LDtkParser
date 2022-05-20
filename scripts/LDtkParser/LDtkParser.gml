// REMEMBER TO TURN ON "disable file system sandbox" WHEN USING LIVE UPDATING
// ...and to set this macro to false when building the game!
#macro LDTK_LIVE true
#macro LDTK_LIVE_FREQUENCY 15

global.__ldtk_initialized = false;
global.__ldtk_live_hash = ""
global.__ldtk_live_timer = -1
global.__ldtk_live_update_pending = false
global.__ldtk_stacked_tilemaps = {}

// Set up live reloading
if (LDTK_LIVE) {
	global.__ldtk_time_source = time_source_create(time_source_global, LDTK_LIVE_FREQUENCY, time_source_units_frames, function() {
		__LDtkLive()
	}, [], -1)
	
	time_source_start(global.__ldtk_time_source)
}

function __LDtkConfigInit() {
	if (global.__ldtk_initialized) {
		// This means we've already initialized our config, so just return b/c
		// we don't wanna overwrite what the user has set already
		return
	}
	
	global.__ldtk_config = {
		file: "",
		level_name: "", // argument passed into LDtkLoad > config.level_name > current room level name
	
		// also note that LDtk defaults to the first letter being uppercase, this can be changed in the LDtk settings
		room_prefix: "r",
		object_prefix: "o",

		stacked_tiles_support: true, // Whether stacked tiles will create new layers (true) or overwrite tiles underneath (false)
									  // LDtkParser will complain if this is set to true and stacked tiles are detected
		stacked_tiles_depth_delta: 1, // How much depth separation to give to stacked tile layers
	
		mappings: { // if a mapping doesn't exist - ldtk name (with a prefix) is used
			levels: { // ldtk_level_name -> gm_room_name
			
			},
			layers: { // ldtk_layer_name -> gm_room_layer_name
				Entities: "Instances"
			},
			enums: { // ldtk_enum_name -> { ldtk_enum_value -> gml_value }
			
			},
			entities: { // ldtk_entity_name -> gm_object_name
			
			},
			fields: { // ldtk_entity_name -> { ldtk_entity_field_name -> gm_instance_variable_name }
			
			},
			tilesets: { // ldtk_tileset_name -> gm_tileset_name
			
			}
		}
	}
	
	global.__ldtk_initialized = true;
}
__LDtkConfigInit()

///@function	LDtkConfig(config)
///@description Changes some config variables
function LDtkConfig(config) {
	// Ensure our config exists
	__LDtkConfigInit();
	
	var config_names = variable_struct_get_names(config)
	
	for(var i = 0; i < array_length(config_names); ++i) {
		var config_name = config_names[i]
		var config_value = variable_struct_get(config, config_name)
		
		if (config_name == "mappings") {
			// nested struct
			LDtkMappings(config_value)
		}
		else {
			variable_struct_set(global.__ldtk_config, config_name, config_value)
		}
	}
}

///@function	LDtkMappings(mappings)
///@description	Updates __ldtk_config.mappings
function LDtkMappings(mappings) {
	// Ensure our config exists
	__LDtkConfigInit();
	
	__LDtkDeepInheritVariables(mappings, global.__ldtk_config.mappings)
}

///@function	LDtkLoad([level_name])
///@description	Loads a level from an LDtk project
///@param		{string} [level_name]
function LDtkLoad(level_name) {
	// Ensure our config exists
	__LDtkConfigInit();
	
	__LDtkTrace("Starting to load!")
	
	var config = global.__ldtk_config
	
	if is_undefined(argument[0]) or level_name == "" {
		if config.level_name != ""
			level_name = config.level_name
		else
			level_name = "" // then defined below
	}
	
	var file = config.file
	if (!file_exists(file)) {
		if (global.__ldtk_live_update_pending) {
			global.__ldtk_live_update_pending = false
			__LDtkTrace("Live Updated Failed!")
		} 
		throw "Warning! LDtk project file is not specified or file does not exist! (" + string(file) + ")"
		return -1
	}
	
	// load file contents
	var buffer = buffer_load(file)
	var json = buffer_read(buffer, buffer_string)
	buffer_delete(buffer)
	
	var data = json_parse(json)
	
	
	var level = undefined
	// find the current level
	for(var i = 0; i < array_length(data.levels); ++i) {
		var _level = data.levels[i]
		var _level_name = _level.identifier
		
		if (level_name == "") { // level mapped to the current room
			var _room_name = config.mappings.levels[$ (_level_name)]
			//var _room_name = variable_struct_get(config.mappings.levels, _level_name)
			if _room_name == undefined
				_room_name = _level_name
			
			if string_char_at(_room_name, 1) != config.room_prefix
				_room_name = config.room_prefix + _room_name
			
			if (_room_name == room_get_name(room)) {
				level = _level
				break
			}
		}
		else { // load target level
			if (_level_name == level_name) {
				level = _level
				break
			}
		}
	}
	
	if is_undefined(level) {
		if (global.__ldtk_live_update_pending) {
			global.__ldtk_live_update_pending = false
			__LDtkTrace("Live Updated Failed!")
		} 
		__LDtkTrace("Error! Cannot find the matching level")
		return -1
	}
	
	// resize the room
	var level_w = level.pxWid
	var level_h = level.pxHei
	
	room_width = level_w
	room_height = level_h
	
	
	// for each layer in the level
	for(var i = 0; i < array_length(level.layerInstances); i++) {
		var this_layer = level.layerInstances[i]
		var _layer_name = this_layer.__identifier
		
		var gm_layer_name = __LDtkMappingGetLayer(_layer_name)
		if gm_layer_name == undefined
			gm_layer_name = _layer_name
		
		var gm_layer_id = layer_get_id(gm_layer_name)
		
		if (gm_layer_id == -1) {
			__LDtkTrace(gm_layer_name, "not found, ignoring layer!")
			continue
		}
		
		switch(this_layer.__type) {
			case "Entities": // instances
				var tile_size = this_layer.__gridSize // for scaling
				
				var entity_references = {}
				var entity_ref_fetch_list = []
				
				// for every entity in the level
				for(var e = 0; e < array_length(this_layer.entityInstances); ++e) {
					var entity = this_layer.entityInstances[e]
					var entity_name = entity.__identifier
					
					var obj_name = __LDtkMappingGetEntity(entity_name)
					if obj_name == undefined
						obj_name = entity_name
					
					if string_char_at(obj_name, 1) != config.object_prefix
						obj_name = config.object_prefix + obj_name
					
					var object_id = asset_get_index(obj_name)
					
					if (object_id == -1) {
						__LDtkTrace(obj_name, "not found in GM, ignoring!")
						continue
					}
					
					var _x = entity.px[0] + this_layer.__pxTotalOffsetX
					var _y = entity.px[1] + this_layer.__pxTotalOffsetY
					
					// Build field struct
					var _field_struct = {
						image_xscale: 1,
						image_yscale: 1
					}
					
					var spr = object_get_sprite(object_id)
					if (sprite_exists(spr)) {
						var sw = sprite_get_width(spr)
						var sh = sprite_get_height(spr)
						
						_field_struct.image_xscale = entity.width / sw
						_field_struct.image_yscale = entity.height / sh
					}
					
					// for each field of the entity
					for(var f = 0; f < array_length(entity.fieldInstances); ++f) {
						var field = entity.fieldInstances[f]
						
						var field_name = field.__identifier
						var field_value = field.__value
						var field_type = field.__type
						
						var gm_field_name = __LDtkMappingGetField(entity_name, field_name)
						if gm_field_name == undefined
							gm_field_name = field_name
						
						// some types require additional work
						switch(field_type) {
							case "Point":
								field_value = __LDtkPreparePoint(field_value, tile_size)
								break
							case "Array<Point>":
								for(var j = 0; j < array_length(field_value); j++) {
									field_value[@ j] = __LDtkPreparePoint(field_value[j])
								}
								break
							case "Color": // colors should be actual colors
								field_value = __LDtkPrepareColor(field_value)
								break
							case "Array<Color>":
								for(var j = 0; j < array_length(field_value); j++) {
									field_value[@ j] = __LDtkPrepareColor(field_value[j])
								}
								break
							case "EntityRef":
								// add to entity_ref_fetch_list so we can add the proper reference later
								array_push(entity_ref_fetch_list, {
									"gm_instance": inst,
									"gm_var_name": gm_field_name,
									"entity_ref": field_value.entityIid
								})
								break
							default:
								if (string_pos("LocalEnum", field_type)) {
									var enum_name_idx = string_pos(".", field_type)
									var enum_name_len = string_length(field_type)
									var _enum_name = string_copy(field_type, enum_name_idx+1, 999)
									
									if (string_pos("Array<", field_type)) {
										for(var j = 0; j < array_length(field_value); j++) {
											field_value[@ j] = __LDtkPrepareEnum(_enum_name, field_value[j])
										}
									}
									else {
										field_value = __LDtkPrepareEnum(_enum_name, field_value)
									}
								}
								break
						}
						
						variable_struct_set(_field_struct, gm_field_name, field_value)
					}
					
					var inst = instance_create_layer(_x, _y, gm_layer_id, object_id, _field_struct)
					
					entity_references[$ entity.iid] = inst
					
					__LDtkTrace("Loaded Entity! GM instance id=%", inst)
				}
				
				// Add proper instance references to entity reference fields
				for (var j = 0; j < array_length(entity_ref_fetch_list); ++j) {
					var _fetch = entity_ref_fetch_list[j]
					var _gm_inst = _fetch.gm_instance
					variable_instance_set(_gm_inst, _fetch.gm_var_name, entity_references[$ _fetch.entity_ref])
				}
				
				__LDtkTrace("Loaded an Entities Layer! name=%, gm_name=%", _layer_name, gm_layer_name)
				break
			case "IntGrid": // just ignore...
				__LDtkTrace("IntGrid layers are ignored")
				break
			case "AutoLayer":
				__LDtkTrace("AutoLayers are ignored")
				break
			case "Tiles": // tile map!
				var tilemap = layer_tilemap_get_id(gm_layer_id)
				// if this is commented, you can pipe different layers to 
				//var empty_tile = 0
				//tilemap_clear(tilemap, empty_tile)
				
				// this is layer's cell size
				//var cwid = this_layer.__cWid
				//var chei = this_layer.__cHei
				
				// this is tileset's cell size
				var cwid = -1
				var chei = -1
				var tileset_def = undefined
				
				for(var ts = 0; ts < array_length(data.defs.tilesets); ++ts) {
					tileset_def = data.defs.tilesets[ts]
					
					if tileset_def.uid == this_layer.__tilesetDefUid {
						cwid = tileset_def.__cWid
						chei = tileset_def.__cHei
						
						break
					}
				}
				
				if tileset_def == undefined
					break
				
				var tile_size = this_layer.__gridSize
				
				// create tilemap if it doesn't exist on the layer
				if (tilemap == -1) {
					var tileset_name = tileset_def.identifier
					var gm_tileset_name = __LDtkMappingGetTileset(tileset_name)
					
					if gm_tileset_name == undefined
						gm_tileset_name = tileset_name
					
					var gm_tileset_id = asset_get_index(gm_tileset_name)
					
					if gm_tileset_id == -1
						break
					
					tilemap = layer_tilemap_create(gm_layer_id, this_layer.__pxTotalOffsetX, this_layer.__pxTotalOffsetY, gm_tileset_id, cwid * tile_size, chei * tile_size)
				} else { // respect layer offsets
					tilemap_x(tilemap, this_layer.__pxTotalOffsetX)
					tilemap_y(tilemap, this_layer.__pxTotalOffsetY)
				}
				
				for(var t = 0; t < array_length(this_layer.gridTiles); ++t) {
					var this_tile = this_layer.gridTiles[t]
					
					var _x = this_tile.px[0]
					var _y = this_tile.px[1]
					var cell_x = _x div tile_size
					var cell_y = _y div tile_size
					
					var tile_src_x = this_tile.src[0],
						tile_src_y = this_tile.src[1]
					var tile_id = this_tile.t
					
					var tile_data = tile_id
					var x_flip = this_tile.f & 1
					var y_flip = this_tile.f & 2
					tile_data = tile_set_mirror(tile_data, x_flip)
					tile_data = tile_set_flip(tile_data, y_flip)

					// Check if this is a stacked tile
					var _tilemap_original = tilemap
					var _current_layer = gm_layer_id
					var _stack_depth = 1
					while (tilemap_get(tilemap, cell_x, cell_y) != 0 and tilemap_get(tilemap, cell_x, cell_y) != tile_data) {
						if (config.stacked_tiles_support) {
							var _stack_layer_name = gm_layer_name + "_" + string(_stack_depth)
							var _stack_layer_id = layer_get_id(_stack_layer_name)
						
							// Check if a new stack layer needs to be created
							if (_stack_layer_id == -1) {
								// Create new stack layer
								var _layer_depth = layer_get_depth(_current_layer) - config.stacked_tiles_depth_delta
								_stack_layer_id = layer_create(_layer_depth, _stack_layer_name)
								var _x = tilemap_get_x(tilemap)
								var _y = tilemap_get_y(tilemap)
								var _tileset = tilemap_get_tileset(tilemap)
								var _width = tilemap_get_width(tilemap)
								var _height = tilemap_get_height(tilemap)
								tilemap = layer_tilemap_create(_stack_layer_id, _x, _y, _tileset, _width, _height)
								global.__ldtk_stacked_tilemaps[$ _stack_layer_name] = tilemap // Store in global to delete on update
								__LDtkTrace("Stacked layer required! Creating new tile layer \"%\" @ depth=%", _stack_layer_name, _layer_depth)
							} else {
								tilemap = global.__ldtk_stacked_tilemaps[$ _stack_layer_name]
								_current_layer = _stack_layer_name
								_stack_depth++
							}
						} else {
							__LDtkTrace("Stacked tile detected with stacked tile support disabled! layer=% @ cell (%, %)", _layer_name, cell_x, cell_y);
							break
						}
					}
					
					tilemap_set(tilemap, tile_data, cell_x, cell_y)
					tilemap = _tilemap_original
				}
				
				delete global.__ldtk_stacked_tilemaps
				global.__ldtk_stacked_tilemaps = {}
				
				__LDtkTrace("Loaded a Tile Layer! name=%, gm_name=%", _layer_name, gm_layer_name)
				break
			default:
				__LDtkTrace("warning! undefined layer type! (%)", this_layer.__type)
				break
		}
	}
	
	global.__ldtk_live_hash = md5_file(config.file)
	if (global.__ldtk_live_update_pending) {
		global.__ldtk_live_update_pending = false
		__LDtkTrace("Live Updated!")
	} else {
		__LDtkTrace("Loaded!")
	}
	
	return 0
}

function __LDtkTrace(str) {
	if !is_string(str)
		str = string(str)
	
	for(var i = 1; i < argument_count; i++) {
		if string_pos("%", str)
			str = string_replace( str, "%", string(argument[i]) )
		else
			str += " " + string(argument[i])
	}
	show_debug_message("[LDtk parser] " + str)
}

// if this is a useful script for you, you can copy it and rename to something like InheritVariables(src, dest)
function __LDtkDeepInheritVariables(src, dest) {
	var var_names = variable_struct_get_names(src)
	
	for(var i = 0; i < array_length(var_names); ++i) {
		var var_name = var_names[i]
		var var_value = variable_struct_get(src, var_name)
		
		if (is_struct(var_value) and is_struct(dest[$ (var_name)])) {
			__LDtkDeepInheritVariables(var_value, dest[$ (var_name)])
		}
		else {
			variable_struct_set(dest, var_name, var_value)
		}
	}
}

function __LDtkPreparePoint(point, tile_size) {
	if !is_struct(point) and point == pointer_null { // if the field is null
		//show_message(point)
		return undefined
	}
	
	if tile_size == undefined
		return { x: point.cx, y: point.cy }
	else
		return { x: point.cx * tile_size, y: point.cy * tile_size }
}

function __LDtkPrepareColor(color) {
	// cut the #
	color = string_copy(color, 2, string_length(color)-1)
	// extract the colors
	var red = hex_to_dec(string_copy(color, 1, 2))
	var green = hex_to_dec(string_copy(color, 3, 2))
	var blue = hex_to_dec(string_copy(color, 5, 2))
	
	return make_color_rgb(red, green, blue)
}

function __LDtkPrepareEnum(_enum_name, value) {
	if value == pointer_null
		return value
	
	var result = __LDtkMappingGetEnum(_enum_name)
	
	if result == undefined or result[$ (value)] == undefined
		return value // just return the string
	else
		return result[$ (value)]
}

function __LDtkMappingGetLevel(key) {
	return global.__ldtk_config.mappings.levels[$ key]
}

function __LDtkMappingGetLayer(key) {
	return global.__ldtk_config.mappings.layers[$ key]
}

function __LDtkMappingGetEnum(key) {
	return global.__ldtk_config.mappings.enums[$ key]
}

function __LDtkMappingGetEntity(key) {
	return global.__ldtk_config.mappings.entities[$ key]
}

function __LDtkMappingGetField(entity, key) {
	var _fields = global.__ldtk_config.mappings.fields[$ entity]
	return (_fields != undefined) ? _fields[$ key] : undefined
}

function __LDtkMappingGetTileset(key) {
	return global.__ldtk_config.mappings.tilesets[$ key]
}

///@function	LDtkLive(level_name*)
///@description	Similar to LDtkLoad(), but only reloads when changes are detected
///@param		{string} level_name*
function __LDtkLive(level_name) {
	var config = global.__ldtk_config
	
	var _ = argument[0]; _ = _
	
	
	global.__ldtk_live_timer -= 1
	
	if (global.__ldtk_live_timer <= 0) {
		global.__ldtk_live_timer = LDTK_LIVE_FREQUENCY
		
		//var hash = sha1_file(config.file)
		var hash = md5_file(config.file)
		
		if (hash != global.__ldtk_live_hash) {
			__LDtkTrace("Updating...")
			__LDtkClear()
			
			global.__ldtk_live_update_pending = true
			global.__ldtk_live_hash = hash
		}
	}
}

function __LDtkClear() {
	// yes
	room_restart()
}

// used for decoding colors' hex codes
function hex_to_dec(str) {
	if !is_string(str) str = string(str)
	str = string_upper(str)
	
	var ans = 0
	for(var i = 1; i <= string_length(str); ++i) {
		var c = string_char_at(str, i)
		
		if ord(c) >= ord("A")
			ans += ord(c) - ord("A") + 10
		else
			ans += ord(c) - ord("0")
		
		ans *= 16
	}
	
	return ans
}