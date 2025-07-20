global.__ldtk_config = {
	file: "", // the project file
	level_name: "", // the priority is: argument passed into LDtkLoad > config.level_name > current room level name
	live_frequency: 15,
	
	escape_fields: true, // write loaded fields/variables into isolated struct to be reloaded at create event
						 // (so that they don't get overwritten by Variable Definitions)
						 // you will have to call LDtkReloadFields() somewhere in the Create Event
	
	// prefixes to add to LDtk names to get GM names (by default/if there is no mapping specified)
	// (also note that LDtk defaults to the first letter being uppercase, this can be changed in the LDtk settings)
	room_prefix: "r",
	layer_prefix: "",
	tileset_prefix: "",
	object_prefix: "o",
	field_prefix: "",
	
	ignore_intgrids: false,
	
	clear_tilemaps: false, // clear tilemaps on reload with empty tiles
    auto_swap_tileset: true,// Update the tileset of the imported tilemap if it differs.
	
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
			
		},
		intgrids: { // ldtk_intgrid_layer_name -> global.ldtk_intgrids' key
			
		}
	}
}

// All IntGrids are loaded here
global.ldtk_intgrids = {}


///feather ignore GM2017

///@function	LDtkIntGrid(csv_array, w, h)
///@param		{Array<Real>} csv_array
///@param		{Real} width
///@param		{Real} height
function LDtkIntGrid(csv_array, width, height) constructor {
	contents = csv_array
	self.width = width
	self.height = height
	
	///@param	{Real} x
	///@param	{Real} y
	static get = function(x, y) {
		var idx = y * width + x
		return contents[idx]
	}
	
	// fills an existing ds_grid
	///@param	{Id.DsGrid<Real>} grid
	static fillDsGrid = function(grid) {
		ds_grid_resize(grid, width, height)
		for(var _x = 0; _x < width; ++_x) {
			for(var _y = 0; _y < height; ++_y) {
				ds_grid_set(grid, _x, _y, get(_x, _y))
			}
		}
		
		return grid
	}
}


///@function	LDtkConfig(config)
///@desc			Sets config variables
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

///@function	LDtkMappings(mappings)
///@desc			Updates __ldtk_config.mappings
function LDtkMappings(mappings) {
	__LDtkDeepInheritVariables(mappings, global.__ldtk_config.mappings)
}

///@function	LDtkLoad([level_name])
///@desc			Loads a level from an LDtk project specified in __ldtk_config.file
///@param		{String} [level_name]
function LDtkLoad(level_name) {
	__LDtkTrace("Starting to load!")
	
	var config = global.__ldtk_config
	
	#region Find the file
	
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
	
	#endregion
	#region Load the file contents
	
	var buffer = buffer_load(file)
	var json = buffer_read(buffer, buffer_string)
	buffer_delete(buffer)
	
	var data = json_parse(json)
	
	#endregion
	#region Find the current level
	
	var level = undefined
	
	for(var i = 0; i < array_length(data.levels); ++i) {
		var _level = data.levels[i]
		var _level_name = _level.identifier
		
		if (level_name == "") { // level mapped to the current room by default
			var _room_name = config.mappings.levels[$ (_level_name)]
			_room_name ??= config.room_prefix + _level_name
			
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
			else continue
		}
	}
	
	if is_undefined(level) {
		__LDtkTrace("Error! Cannot find the matching level")
		return -1
	}
	
	#endregion
	#region Resize the room
	
	var level_w = level.pxWid
	var level_h = level.pxHei
	
	room_set_width(room, level_w)
	room_set_height(room, level_h)
	
	room_width = level_w
	room_height = level_h
	
	#endregion
	#region Handle layers


	// a workaround for entities and fields
	var created_entities = [] // an array of { inst, object_id }
	var entity_references = {}
	var entity_refs = [] // an array of { inst, gm_field_name, ref }
	
	// for each layer
	for(var i = 0; i < array_length(level.layerInstances); i++) {
		var this_layer = level.layerInstances[i]
		var layer_type = this_layer.__type
		
		#region Map the layer name
		
		var _layer_name = this_layer.__identifier
		
		var gm_layer_name = config.mappings.layers[$ (_layer_name)]
		gm_layer_name ??= config.layer_prefix + _layer_name
		
		var gm_layer_id = layer_get_id(gm_layer_name)
		
		#endregion
		#region Potentially ignoring the layer
		
		var ignore_layer = gm_layer_id == -1 and layer_type != "IntGrid"
		
		if (ignore_layer) {
			__LDtkTrace(gm_layer_name, "not found, ignoring layer!")
			continue
		}
		
		#endregion
		
		// Load depending on layer type
		switch(layer_type) {
			#region Entity Layers
			case "Entities": // instances
			{
				var tile_size = this_layer.__gridSize // for scaling
				
				// for every entity in the level
				for(var e = 0; e < array_length(this_layer.entityInstances); ++e) {
					var entity = this_layer.entityInstances[e]
					var entity_name = entity.__identifier
					
					#region Match with a GM object
					
					var obj_name = config.mappings.entities[$ (entity_name)]
					obj_name ??= config.object_prefix + entity_name
					
					var object_id = asset_get_index(obj_name)
					
					if (object_id == -1) {
						__LDtkTrace("object/entity", obj_name, "not found in GM, ignoring!")
						continue
					}
					
					#endregion
					#region Create the instance
					
					var _x = entity.px[0] + this_layer.__pxTotalOffsetX
					var _y = entity.px[1] + this_layer.__pxTotalOffsetY
					
					var inst = instance_create_layer(_x, _y, gm_layer_id, oEmpty)
					array_push(created_entities, { inst, object_id, fields: undefined })
					
					// add to entity_reference
					entity_references[$ entity.iid] = inst
					
					#endregion
					#region Set the scale
					
					var spr = object_get_sprite(object_id)
					if (sprite_exists(spr)) {
						var sw = sprite_get_width(spr)
						var sh = sprite_get_height(spr)
					
						inst.image_xscale = entity.width / sw
						inst.image_yscale = entity.height / sh
					}
					else {
						inst.image_xscale = 1
						inst.image_yscale = 1
					}
					
					#endregion
					#region Load the fields
					
					var fields_struct = {}
					
					// for each field of the entity
					for(var f = 0; f < array_length(entity.fieldInstances); ++f) {
						var field = entity.fieldInstances[f]
						
						var field_name = field.__identifier
						var field_value = field.__value
						var field_type = field.__type
						
						// map the field name
						var gm_field_name = config.mappings.fields[$ (field_name)]
						gm_field_name ??= config.field_prefix + field_name
						
						#region Prepare the value
						
						// some types require additional work
						switch(field_type) {
							case "Point":
								field_value = __LDtkPreparePoint(field_value, tile_size)
								break
							case "Array<Point>":
								for(var j = 0; j < array_length(field_value); j++) {
									field_value[@ j] = __LDtkPreparePoint(field_value[j], tile_size)
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
								// add to entity_refs so we can add the proper reference later
								array_push(entity_refs, {
									inst,
									gm_field_name,
									ref: field_value.entityIid
								})
								field_value = noone // a placeholder to be resolved to an actual instance
								break
							default:
								if (string_pos("LocalEnum", field_type)) {
									var enum_name_idx = string_pos(".", field_type)
									var enum_name_len = string_length(field_type)
									var enum_name = string_copy(field_type, enum_name_idx+1, 999)
									
									if (string_pos("Array<", field_type)) {
										enum_name = string_replace(enum_name, ">", "")
										
										for(var j = 0; j < array_length(field_value); j++) {
											field_value[@ j] = __LDtkPrepareEnum(enum_name, field_value[j])
										}
									}
									else {
										field_value = __LDtkPrepareEnum(enum_name, field_value)
									}
								}
								else { // everything else is just the value itself as it was parsed
									field_value = field_value
								}
								break
						}
						
						#endregion
						
						// set the value
						variable_struct_set(fields_struct, gm_field_name, field_value)
					}
					
					if (config.escape_fields) {
						inst.__ldtk_fields = fields_struct
					}
					
					array_last(created_entities).fields = fields_struct
					
					#endregion
					
					__LDtkTrace("Loaded Entity! GM instance id=%", inst)
				}
				
				__LDtkTrace("Loaded an Entities Layer! name=%, gm_name=%", _layer_name, gm_layer_name)
				break
			}
			#endregion
			#region IntGrid Layers
			case "IntGrid":
			{
				if (config.ignore_intgrids) {
					__LDtkTrace("IntGrid layers are ignored because of config.ignore_intgrids.")
					break
				}
				
				var csv_array = this_layer.intGridCsv
				var cwid = this_layer.__cWid
				var chei = this_layer.__cHei
				
                // Get intgrid mapping if it exists
				var grid_name = _layer_name
				if (variable_struct_exists(config.mappings.intgrids, grid_name)){
					grid_name = config.mappings.intgrids[$ grid_name];
                }
				
				global.ldtk_intgrids[$ grid_name] = new LDtkIntGrid(csv_array, cwid, chei);
				
				__LDtkTrace("Loaded IntGrid! name=%, gm_name=%", _layer_name, grid_name)
				
				break
			}
			#endregion
			#region AutoLayers
			case "AutoLayer": // autolayer tilemap
			{
				var _level_path = this_layer.__tilesetRelPath
				for(var u = 0; u < array_length(data.defs.tilesets); ++u)
				{
					var _tilsets = data.defs.tilesets[u]
					var _tilsets_path = _tilsets.relPath
					//if _tilsets_path = _level_path
					{
						var tilemap = layer_tilemap_get_id(gm_layer_id)
				
						// this is the layers's size in cells
						var cwidTileset = _tilsets.__cWid
						var cheiTileset = _tilsets.__cHei
						
						var cwid = this_layer.__cWid
						var chei = this_layer.__cHei
						
						// find the tileset definition
						var tileset_def = undefined
						var found_tileset_def = false
				
						for(var ts = 0; ts < array_length(data.defs.tilesets); ++ts)
						{
							tileset_def = data.defs.tilesets[ts]
					
							if tileset_def.uid == this_layer.__tilesetDefUid {
								found_tileset_def = true
								__LDtkTrace("found tileset")
								break
							}
						}
				
						if !found_tileset_def
						{
							__LDtkTrace("!found_tileset_def")
							break
						} 
                        
                        // Get the tileset info for the layer
						var tile_size = this_layer.__gridSize;
                        
                        var tileset_name = tileset_def.identifier;
                        var gm_tileset_name = config.mappings.tilesets[$ (tileset_name)] ;
                        gm_tileset_name ??= config.tileset_prefix + tileset_name;
                        var gm_tileset_id = asset_get_index(gm_tileset_name);
				
						// create tilemap if it doesn't exist on the layer
						if (tilemap == -1) {
					
							if gm_tileset_id == -1
								break
					
							tilemap = layer_tilemap_create(gm_layer_id, this_layer.__pxTotalOffsetX, this_layer.__pxTotalOffsetY, gm_tileset_id, cwid, chei)
						}
						else { // the tilemap is already there
							// resize it
							tilemap_set_width(tilemap, cwid)
							tilemap_set_height(tilemap, chei)
					
							// clear of any remaining tiles
							if (config.clear_tilemaps)
								tilemap_clear(tilemap, 0)
                            
							// respect layer offsets
							tilemap_x(tilemap, this_layer.__pxTotalOffsetX)
							tilemap_y(tilemap, this_layer.__pxTotalOffsetY)
                            
                            // Change the layer's tileset if it differs from imported tilemap
                            if(config.auto_swap_tileset && (tilemap_get_tileset(tilemap) != gm_tileset_id)){
                                tilemap_tileset(tilemap, gm_tileset_id);
                                __LDtkTrace("Swapped tileset of layer=% from % -> %", gm_layer_name, tileset_get_name(tilemap_get_tileset(tilemap)), gm_tileset_name)
                            }
						}
				
						for(var t = 0; t < array_length(this_layer.autoLayerTiles); ++t) {
							var this_tile = this_layer.autoLayerTiles[t]
					
							var _x = this_tile.px[0]
							var _y = this_tile.px[1]
							var cell_x = _x div tile_size
							var cell_y = _y div tile_size
					
							var tile_src_x = this_tile.src[0],
								tile_src_y = this_tile.src[1]
							
							var tile_id = tile_src_x/tile_size + tile_src_y/tile_size*(cwidTileset)
							var tile_data = tile_id
							
							var x_flip = this_tile.f & 1
							var y_flip = this_tile.f & 2
							
							tile_data = tile_set_mirror(tile_data, x_flip)
							tile_data = tile_set_flip(tile_data, y_flip)
					
							tilemap_set(tilemap, tile_data, cell_x, cell_y)
						}
				
						__LDtkTrace("Loaded a Autolayer! name=%, gm_name=%", _layer_name, gm_layer_name)
						break;
					}
				}
                break;
			} //end case
			#endregion
			#region Tile Layers
			case "Tiles": // tile map!
			{
				var _level_path = this_layer.__tilesetDefUid
				for(var u = 0; u < array_length(data.defs.tilesets); ++u)
				{
					var _tilsets = data.defs.tilesets[u]
					var _tilsets_path = _tilsets.uid
					if _tilsets_path = _level_path
					{
						var tilemap = layer_tilemap_get_id(gm_layer_id)

						// this is the layers's size in cells
						var cwidTileset = _tilsets.__cWid
						var cheiTileset = _tilsets.__cHei
						
						var cwid = this_layer.__cWid
						var chei = this_layer.__cHei
						//global.cwid = tilemap_get_tile_width(tilemap)
						
						// find the tileset definition
						var tileset_def = undefined
						var found_tileset_def = false
						
						for(var ts = 0; ts < array_length(data.defs.tilesets); ++ts) {
							tileset_def = data.defs.tilesets[ts]
							
							if tileset_def.uid == this_layer.__tilesetDefUid {
								found_tileset_def = true
								break
							}
						}
						
						if !found_tileset_def
							break
						
						// Get the tileset info for the layer
						var tile_size = this_layer.__gridSize;
                        
                        var tileset_name = tileset_def.identifier;
                        var gm_tileset_name = config.mappings.tilesets[$ (tileset_name)] ;
                        gm_tileset_name ??= config.tileset_prefix + tileset_name;
                        var gm_tileset_id = asset_get_index(gm_tileset_name);
						
						// create tilemap if it doesn't exist on the layer
						if (tilemap == -1) {
                            
							if gm_tileset_id == -1 {
								break
							}
					
							tilemap = layer_tilemap_create(gm_layer_id, this_layer.__pxTotalOffsetX, this_layer.__pxTotalOffsetY, gm_tileset_id, cwid, chei)
						}
						else
						{
							// the tilemap is already there -
							// resize it
							tilemap_set_width(tilemap, cwid)
							tilemap_set_height(tilemap, chei)
					
							// clear of any remaining tiles
							if (config.clear_tilemaps)
								tilemap_clear(tilemap, 0)
					
							// respect layer offsets
							tilemap_x(tilemap, this_layer.__pxTotalOffsetX)
							tilemap_y(tilemap, this_layer.__pxTotalOffsetY)
                            
                            // Change the layer's tileset if it differs from imported tilemap
                            if(config.auto_swap_tileset && (tilemap_get_tileset(tilemap) != gm_tileset_id)){
                                tilemap_tileset(tilemap, gm_tileset_id);
                                __LDtkTrace("Swapped tileset of layer=% from % -> %", gm_layer_name, tileset_get_name(tilemap_get_tileset(tilemap)), gm_tileset_name)
                            }
						}
				
						for(var t = 0; t < array_length(this_layer.gridTiles); ++t)
						{
							var this_tile = this_layer.gridTiles[t]
					
							var _x = this_tile.px[0]
							var _y = this_tile.px[1]
							var cell_x = _x div tile_size
							var cell_y = _y div tile_size
							//global.cwid = tilemap_get_tile_width(tilemap)
					
							var tile_src_x = this_tile.src[0],
								tile_src_y = this_tile.src[1]
							
							var tile_id = tile_src_x/tile_size + tile_src_y/tile_size*(cwidTileset)
							var tile_data = tile_id
							
							var x_flip = this_tile.f & 1
							var y_flip = this_tile.f & 2
							
							tile_data = tile_set_mirror(tile_data, x_flip)
							tile_data = tile_set_flip(tile_data, y_flip)
					
							tilemap_set(tilemap, tile_data, cell_x, cell_y)
						}
				
						__LDtkTrace("Loaded a Tile Layer! name=%, gm_name=%", _layer_name, gm_layer_name)
						break;
					}
                    
				}
                break;
			}
			#endregion
			default:
			{
				__LDtkTrace("warning! undefined layer type! (%)", this_layer.__type)
				break
			}
		}
	}
	
	#endregion
	#region A workaround for entity fields
	
	#region instance_change() + set most variables
	
	// instance_change() every entity so that we only perform the Create event
	// after all the fields have been resolved and all the entities have been created
	for(var j = 0; j < array_length(created_entities); ++j) {
		var entity = created_entities[j]
		var inst = entity.inst
		var object_id = entity.object_id
		var fields = entity.fields
		
		with(inst) {
			// don't trigger the Create events yet
			instance_change(object_id, false)
		}
		
		#region Set all entity fields/instace variables
		
		var field_names = struct_get_names(fields)
		var field_names_len = struct_names_count(fields)
		for(var k = 0; k < field_names_len; ++k) {
			var field_name = field_names[k]
			var field_value = fields[$ field_name]
			
			variable_instance_set(inst, field_name, field_value)
		}
		
		#endregion
	}
	
	#endregion
	#region Resolve entity ref fields
	
	for (var j = 0; j < array_length(entity_refs); ++j) {
		var entity_ref = entity_refs[j]
		var gm_inst = entity_ref.inst
		var target_field = entity_ref.gm_field_name
		
		var entity_ref_inst = entity_references[$ entity_ref.ref]
					
		variable_instance_set(gm_inst, target_field, entity_ref_inst)
		variable_struct_set(gm_inst.__ldtk_fields, target_field, entity_ref_inst)
	}
	
	#endregion
	#region Trigger the Create events
	
	for(var j = 0; j < array_length(created_entities); ++j) {
		var entity = created_entities[j]
		var inst = entity.inst
		
		with(inst) {
			event_perform(ev_create, 0)
		}
	}
	
	#endregion
	
	#endregion
	
	__LDtkTrace("Loaded!")
	return 0
}

///@function	LDtkLive([level_name])
///@desc			Similar to LDtkLoad(), but only reloads when changes are detected
///@param		{String} [level_name]
function LDtkLive(level_name) {
	static __ldtk_live_timer = 0
	static __ldtk_live_hash = ""
	
	var config = global.__ldtk_config
	
	var _ = argument[0]; _ = _
	
	
	__ldtk_live_timer -= 1
	
	if (__ldtk_live_timer <= 0) {
		__ldtk_live_timer = config.live_frequency
		
		//var hash = sha1_file(config.file)
		var hash = md5_file(config.file)
		
		if (hash != __ldtk_live_hash) {
			__LDtkTrace("Updating...")
			room_restart()
			
			var res = LDtkLoad(level_name)
			__ldtk_live_hash = hash
			
			if (res < 0) {
				__LDtkTrace("Live Update Failed!")
			}
			else
				__LDtkTrace("Live Updated!")
		}
	}
}

///@function	LDtkReloadFields()
///@desc			Reloads fields from an isolated struct.
///						This works around the Variable Definitions tab
///						You don't need this in most cases
///						You would want to call this in the Create Event
///						Only works if __ldtk_config.escape_fields is set to `true`
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

#region Utility functions	

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

// used for decoding colors' hex codes
function __LDtkHexToDec(str) {
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
	var red = __LDtkHexToDec(string_copy(color, 1, 2))
	var green = __LDtkHexToDec(string_copy(color, 3, 2))
	var blue = __LDtkHexToDec(string_copy(color, 5, 2))
	
	return make_color_rgb(red, green, blue)
}

function __LDtkPrepareEnum(_enum_name, value) {
	if value == pointer_null
		return value
	
	var result = global.__ldtk_config.mappings.enums[$ (_enum_name)]
	
	if result == undefined or result[$ (value)] == undefined
		return value // just return the string
	else
		return result[$ (value)]
}

#endregion