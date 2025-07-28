/// @desc Configs

// REMEMBER TO TURN ON "disable file system sandbox" WHEN USING LIVE UPDATING
// ...and to set this macro to 0 when building the game!
#macro LDTK_LIVE 1


if (LDTK_LIVE) {
    
	/* Get a dynamic project directory for multi-developer teams
     * =========================================================
     * Note that this has only been tested on the Windows IDE.
     */
    var _project_root_dir= string_copy(working_directory, 0, string_last_pos_ext("\\", working_directory, string_length(working_directory)-1) );
    if( file_exists($"{_project_root_dir}build.bff") == true){
        var _buffer= buffer_load($"{_project_root_dir}build.bff");
        var _json= json_parse( buffer_read(_buffer, buffer_string) );// Parse the json of the build file.
        buffer_delete(_buffer);
        
        project_directory= _json.projectDir + "\\";
        show_debug_message($"project_directory: {project_directory}")
    }
    
    
    // live reload config
	LDtkConfig({
		// change this to your project directory
		file: project_directory + "datafiles\\test.ldtk",
		level_name: "AutoLayers_advanced_demo"
	})
}
else {
	// release config
	LDtkConfig({
		file: "LDtkTest.ldtk",
		level_name: "LDtkTest1"
	})
}



LDtkMappings({
	layers: {
		Tiles: "PlaceholderTiles", // now "Tiles" layer in LDtk = "PlaceholderTiles" layer in GM
        AutoLayerTest: "tiles_a",
        IntGrid_layer_OG: "tiles_i",
        Sky: "tiles_s",
	},
	enums: {
		TestEnum: {
			//First: "First", // first is undefined, should just return the name
			Second: "This is second",
			Third: 3
		}
	},
	tilesets: {
		PlaceholderTiles: "tTiles",
        Cavernas_by_Adam_Saltsman: "tTest",
	}
});

