/// @desc Configs

// REMEMBER TO TURN ON "disable file system sandbox" WHEN USING LIVE UPDATING
// ...and to set this macro to 0 when building the game!
#macro LDTK_LIVE 1


if (LDTK_LIVE) {
	// live reload config
	LDtkConfig({
		// change this to your project directory
		file: "C:\\Projects\\GameMaker Projects\\LDtkParser\\datafiles\\LDtkTest.ldtk",
		level_name: "LDtkTest1"
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
		Tiles: "PlaceholderTiles" // now "Tiles" layer in LDtk = "PlaceholderTiles" layer in GM
	},
	enums: {
		TestEnum: {
			//First: "First", // first is undefined, should just return the name
			Second: "This is second",
			Third: 3
		}
	},
	tilesets: {
		PlaceholderTiles: "tTiles"
	}
})