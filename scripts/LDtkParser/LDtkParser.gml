global.__ldtk_config = {
	file: "",
	level_name: "", // argument passed into LDtkLoad > config.level_name > current room level name
	live_frequency: 15,
	
	escape_fields: true, // write loaded fields/variables into isolated struct to be reloaded at create event
						 // (so that they don't get overwritten by Variable Definitions)
						 // you will have to call LDtkReloadFields() somewhere in the Create Event
	
	// also note that LDtk forces the first letter to be Uppercase
	room_prefix: "r",
	object_prefix: "o",
	
	mappings: { // if a mapping doesn't exist - ldtk name (with a prefix) is used
		levels: { // ldtk_level_name -> gms_room_name
			
		},
		layers: { // ldtk_layer_name -> gms_room_layer_name
			Entities: "Instances"
		},
		enums: { // ldtk_enum_name -> { ldtk_enum_value -> gml_value }
			
		},
		entities: { // ldtk_entity_name -> gms_object_name
			
		},
		fields: { // ldtk_entity_name -> { ldtk_entity_field_name -> gms_instance_variable_name }
			
		}
	}
}


global.__ldtk_live_hash = ""

global.__ldtk_live_timer = -1


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

///@function	LDtkConfig(config)
///@description Changes some config variables
function LDtkConfig(config) {
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

///@function	LDtkMappings(mappings)
///@description	Updates __ldtk_config.mappings
function LDtkMappings(mappings) {
	__LDtkDeepInheritVariables(mappings, global.__ldtk_config.mappings)
}

///@function	LDtkLoad(level_name*)
///@description	Loads a level from an LDtk project
///@param		{string} level_name*
function LDtkLoad(level_name) {
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
		__LDtkTrace("Error! Cannot find the matching level")
		return -1
	}
	
	// resize the room
	var level_w = level.pxWid
	var level_h = level.pxHei
	
	room_set_width(room, level_w)
	room_set_height(room, level_h)
	
	
	// for each layer in the level
	for(var i = 0; i < array_length(level.layerInstances); i++) {
		var this_layer = level.layerInstances[i]
		var _layer_name = this_layer.__identifier
		
		var gm_layer_name = config.mappings.layers[$ (_layer_name)]
		if gm_layer_name == undefined
			gm_layer_name = _layer_name
		
		var gm_layer_id = layer_get_id(gm_layer_name)
		
		switch(this_layer.__type) {
			case "Entities": // instances
				var tile_size = this_layer.__gridSize // for scaling
				
				// for every entity in the level
				for(var e = 0; e < array_length(this_layer.entityInstances); ++e) {
					var entity = this_layer.entityInstances[e]
					var entity_name = entity.__identifier
					
					var obj_name = config.mappings.entities[$ (entity_name)]
					if obj_name == undefined
						obj_name = entity_name
					
					if string_char_at(obj_name, 1) != config.object_prefix
						obj_name = config.object_prefix + obj_name
					
					var object_id = asset_get_index(obj_name)
					
					var _x = entity.px[0]
					var _y = entity.px[1]
					
					var inst = instance_create_layer(_x, _y, gm_layer_id, oEmpty) // we'll need instance_change() to work around the create event
					
					
					var spr = object_get_sprite(object_id)
					var sw = sprite_get_width(spr)
					var sh = sprite_get_height(spr)
					
					inst.image_xscale = entity.width / sw
					inst.image_yscale = entity.height / sh
					
					
					var prepare_point = function(point, tile_size) {
						if !is_struct(point) and point == pointer_null { // if the field is null
							//show_message(point)
							return undefined
						}
						return { x: point.cx * tile_size, y: point.cy * tile_size }
					}
					
					var prepare_color = function(color) {
						// cut the #
						color = string_copy(color, 2, string_length(color)-1)
						// extract the colors
						var red = hex_to_dec(string_copy(color, 1, 2))
						var green = hex_to_dec(string_copy(color, 3, 2))
						var blue = hex_to_dec(string_copy(color, 5, 2))
							
						return make_color_rgb(red, green, blue)
					}
					
					var prepare_enum = function(_enum_name, value) {
						if value == pointer_null
							return value
						
						var result = global.__ldtk_config.mappings.enums[$ (_enum_name)][$ (value)]
						
						if result == undefined
							return value // just return the string
						else
							return result
					}
					
					
					// Load the fields
					
					if (config.escape_fields) {
						inst.__ldtk_fields = {}
					}
					
					// for each field of the entity
					for(var f = 0; f < array_length(entity.fieldInstances); ++f) {
						var field = entity.fieldInstances[f]
						
						var field_name = field.__identifier
						var field_value = field.__value
						var field_type = field.__type
						
						var gm_field_name = config.mappings.fields[$ (field_name)]
						if gm_field_name == undefined
							gm_field_name = field_name
						
						
						
						
						// some types require additional work
						switch(field_type) {
							case "Point":
								field_value = prepare_point(field_value, tile_size)
								break
							case "Array<Point>":
								for(var j = 0; j < array_length(field_value); j++) {
									field_value[@ j] = prepare_point(field_value[j])
								}
								break
							case "Color": // colors should be actual colors
								field_value = prepare_color(field_value)
								break
							case "Array<Color>":
								for(var j = 0; j < array_length(field_value); j++) {
									field_value[@ j] = prepare_color(field_value[j])
								}
								break
							default:
								if (string_pos("LocalEnum", field_type)) {
									var enum_name_idx = string_pos(".", field_type)
									var enum_name_len = string_length(field_type)
									var _enum_name = string_copy(field_type, enum_name_idx+1, 999)
									
									if (string_pos("Array<", field_type)) {
										for(var j = 0; j < array_length(field_value); j++) {
											field_value[@ j] = prepare_enum(_enum_name, field_value[j])
										}
									}
									else {
										field_value = prepare_enum(_enum_name, field_value)
									}
								}
								
								break
						}
						
						
						variable_instance_set(inst, gm_field_name, field_value)
						
						if (config.escape_fields) {
							variable_struct_set(inst.__ldtk_fields, gm_field_name, field_value)
						}
					}
					
					// so that we carry over all the variables
					with(inst) {
						instance_change(object_id, true)
					}
					
					__LDtkTrace("Loaded Entity! GM instance id=%", inst)
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
				
				for(var ts = 0; ts < array_length(data.defs.tilesets); ++ts) {
					var tileset_def = data.defs.tilesets[ts]
					
					if tileset_def.uid == this_layer.__tilesetDefUid {
						cwid = tileset_def.__cWid
						chei = tileset_def.__cHei
					}
				}
				
				
				var tile_size = this_layer.__gridSize
				
				for(var t = 0; t < array_length(this_layer.gridTiles); ++t) {
					var this_tile = this_layer.gridTiles[t]
					
					var _x = this_tile.px[0]
					var _y = this_tile.px[1]
					var cell_x = _x div tile_size
					var cell_y = _y div tile_size
					
					var tile_src_x = this_tile.src[0],
						tile_src_y = this_tile.src[1]
					var tile_id = tile_src_x/tile_size + tile_src_y/tile_size*cwid
					
					var tile_data = tile_id
					var x_flip = this_tile.f & 1
					var y_flip = this_tile.f & 2
					tile_data = tile_set_mirror(tile_data, x_flip)
					tile_data = tile_set_flip(tile_data, y_flip)
					
					tilemap_set(tilemap, tile_data, cell_x, cell_y)
				}
				
				__LDtkTrace("Loaded a Tile Layer! name=%, gm_name=%", _layer_name, gm_layer_name)
				break
			default:
				__LDtkTrace("warning! undefined layer type! (%)", this_layer.__type)
				break
		}
	}
	
	__LDtkTrace("Loaded!")
	return 0
}

///@function	LDtkLive(level_name*)
///@description	Similar to LDtkLoad(), but only reloads when changes are detected
///@param		{string} level_name*
function LDtkLive(level_name) {
	var config = global.__ldtk_config
	
	var _ = argument[0]; _ = _
	
	
	global.__ldtk_live_timer -= 1
	
	if (global.__ldtk_live_timer <= 0) {
		global.__ldtk_live_timer = config.live_frequency
		
		//var hash = sha1_file(config.file)
		var hash = md5_file(config.file)
		
		if (hash != global.__ldtk_live_hash) {
			__LDtkTrace("Updating...")
			__LDtkClear()
			
			var res = LDtkLoad(level_name)
			global.__ldtk_live_hash = hash
			
			if (res < 0) {
				__LDtkTrace("Live Update Failed!")
			}
			else
				__LDtkTrace("Live Updated!")
		}
	}
}

function __LDtkClear() {
	// yes
	room_restart()
}

///@function	LDtkReloadFields()
///@description	Reloads fileds from an isolated struct.
///				This works around the Variable Definitions tab
///				You don't need this in most cases
///				You would want to call this in the Create Event
///				Only works if __ldtk_config.escape_fields is set to `true`
function LDtkReloadFields() {
	if (!global.__ldtk_config.escape_fields) {
		__LDtkTrace("Warning: LDtkReloadFields() is called, but the `escape fields` config is turned off.\Did you mean to enable the config or not call the function? (Variables are loaded automatically by default)")
		return -1
	}
	
	if (!variable_instance_exists(self, "__ldtk_fields"))
		return 0
	
	var field_names = variable_struct_get_names(self.__ldtk_fields)
	for(var i = 0; i < array_length(field_names); ++i) {
		var field_name = field_names[i]
		var field_value = variable_struct_get(self.__ldtk_fields, field_name)
		
		variable_instance_set(id, field_name, field_value)
	}
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
