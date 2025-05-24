# LDtkParser
### a feature-rich parser for [LDtk](https://ldtk.io) levels in GameMaker

## Credits

### Maintained by [Evoleo](https://github.com/evolutionleo/) (me)

### Huge thanks to [@FaultyFunctions](https://github.com/FaultyFunctions) and Ponno for their contributions! ❤️

### Join the [Discord](https://discord.gg/bRpMgTquAr) if you have any issues/questions/suggestions regarding the parser!


## Features
- Load LDtk levels with all their contents with one function call!
- Powerful mapping configuration to map layers/entities/fields/enums names in LDtk to their equivallents in GMS (in case they don't match)
- Entities fields and Enums support!
- **Live Updating!** Change and reload levels in real time!

## Installing
1) Go to [Releases](https://github.com/evolutionleo/LDtkParser/releases/latest) and download the latest .yymps
2) Import it to your project via Tools/Import Local Package
3) PROFIT!

## Setting Up
1) Put an instance of `oLDtk` somewhere
2) Call `LDtkConfig()` with your custom configuration settings (or modify the default ones in `oLDtk` itself)
3) (Optional) if any of your objects use Variable Definitions, you'll need to enable the `escape_fields` config and call `LDtkReloadFields()` in their Create Event

## Live Updating
1) Check "Disable file system sandbox" in the settings
2) Enable the macro `LDTK_LIVE`
3) Change the live config's file path so that it loads the .ldtk file from your project's folder


## Contributing
Open an issue or make a pull request here on GitHub
