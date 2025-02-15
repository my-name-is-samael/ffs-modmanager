# Fast Food Simulator - Mod Manager
### The all-in-one mod manager for Fast Food Simulator

## How to install:
- Download the latest release [here](https://github.com/my-name-is-samael/ffs-modmanager/releases) (you will need to download the .zip file in the `Assets` section)
- If you have UE4SS 3.0.1 Beta (or superior version) already installed:
  - Extract the content from the `Extract_in_ProjectBakery/Content/Paks/` folder to `ProjectBakery/Content/Paks/` folder in your game
  - Extract both files `dsound.dll` and `dsound.dll = bitfix` from the `Extract_in_ProjectBakery/Binaries/Win64/` folder to `ProjectBakery/Binaries/Win64/` folder in your game
  - Extract the content from the `Extract_in_ProjectBakery/Binaries/Win64/ue4ss/Mods/` folder to `ProjectBakery/Binaries/Win64/ue4ss/Mods/` folder in your game
- Otherwise if you do not have UE4SS installed already:
  - Simply extract the content of the `Extract_in_ProjectBakery` folder inside the `ProjectBakery` folder inside the root folder of your game (not where the .exe is located)

## Usage
Once your game is launched, press [key] to toggle the interface's visibility (configurable ?).<br>
From here, you can check active mods, update their own settings and reload them.

## Mods using this Manager
- [DayExtender](#)
- [CustomersFlowBalancer](#)
- [OnlyDriveThru](#)
- [OrderMonitor](#)

[*(Feel free to contact us to have your own mod here)*](https://github.com/my-name-is-samael/ffs-modmanager/issues/new?template=add-your-mod-to-the-featured-mods-list.md)

## Libs included:
- [UE4SS 3.0.1 Beta (30/12/2024)](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest)
- [bitfix 80af6c2](https://github.com/trumank/bitfix/releases/tag/latest)