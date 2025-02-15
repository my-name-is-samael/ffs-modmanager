@echo off

:: require the chunk ID as argument
set chunkID=%1
if "%chunkID%" == "" (
    echo Arg 1 must be the chunk ID
    exit 1
)

set buildPath="<path_to_UE_build_folder>\ProjectBakery\Content\Paks\"
set targetpath="<path_to_ProjectBakery_folder>\Content\Paks\LogicMods\"

if not exist "%buildPath%pakchunk%chunkID%-Windows.pak" (
    echo Chunk %chunkID% is invalid
    exit 1
)

if not exist %targetpath% (
    mkdir %targetpath%
)


echo f | xcopy /y /q "%buildPath%pakchunk%chunkID%-Windows.pak" "%targetpath%ModManager.pak"
echo f | xcopy /y /q "%buildPath%pakchunk%chunkID%-Windows.ucas" "%targetpath%ModManager.ucas"
echo f | xcopy /y /q "%buildPath%pakchunk%chunkID%-Windows.utoc" "%targetpath%ModManager.utoc"

echo [92m ModManager BP built ![0m
exit 0