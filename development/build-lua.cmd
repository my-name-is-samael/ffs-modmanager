@echo off

set targetpath="<path_to_Win64_folder>\ue4ss\Mods\ModManager\"

xcopy /y /e /q ".\Lua" %targetpath%

echo [92m ModManager built ![0m
exit 0