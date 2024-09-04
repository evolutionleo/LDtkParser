# LDtkParser
A feature-rich parser for .ldtk levels for GameMaker: Studio 2.3

Maintained by [@evolutionleo](https://github.com/evolutionleo/) (me)

❤️ Huge thanks to [@FaultyFunctions](https://github.com/FaultyFunctions) for his various contributions! ❤️

## Join the [Discord](https://discord.gg/bRpMgTquAr) if you have any questions/suggestions/issues with the parser!



## Features
- Load LDtk levels with all their contents with one function call!
- Powerful mapping configuration to map layers/entities/fields/enums names in LDtk to their equivallents in GMS (in case they don't match)
- Entities fields and Enums support!
- **Live Updating!** Reload levels in real time!

## Installing
### 1) Go to [Releases](https://github.com/evolutionleo/LDtkParser/releases/latest) and download the latest .yymps
### 2) Import it to your project via Tools/Import Local Package
### 3) PROFIT!

## Setting Up
- Put an instance of `oLDtk` somewhere
- `LDtkConfig()` (oLDtk has the basic configuration, you can modify it)
- (Optional) if any of your objects use Variable Definitions, you'll need to enable the `escape_fields` config and call `LDtkReloadFields()` in their Create Event

## Live Updating
- Disable file system sandbox in the settings
- Enable the macro `LDTK_LIVE`
- Change the live config's file path so that it loads the .ldtk file from your project's folder


## Contributing
Open an issue or make a pull request
