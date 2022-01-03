/// @desc Configs

// REMEMBER TO TURN ON "disable file system sandbox" WHEN USING LIVE UPDATING
// ...and to set this macro to 0 when building the game!
#macro LDTK_LIVE 1


if (LDTK_LIVE) {
	LDtkConfig({
		// this will load the bundled version (live updating won't work)
		//file: "LDtkTest.ldtk",
		// so we need to load directly from the project folder
		
		// change this to your project directory
		file: "D:\\Projects\\GameMaker Projects\\LDtkParser\\datafiles\\LDtkTest.ldtk",
		level_name: "LDtkTest1"
	})
}
else {
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
	}
})