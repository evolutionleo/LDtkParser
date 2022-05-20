/// @desc Configs

var _file = LDTK_LIVE ? "D:\\Projects\\GameMaker Projects\\LDtkParser\\datafiles\\LDtkTest.ldtk" : "LDtkTest.ldtk";

LDtkConfig({
	file: _file,
	level_name: "LDtkTest1"
})

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