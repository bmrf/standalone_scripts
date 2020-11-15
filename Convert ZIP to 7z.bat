:: Place .bat file in same directory as the .zip files you want to convert
:: 7-Zip must be installed to C:\Program Files\7-Zip

:: Get in the correct drive (~d0) and path (~dp0). Sometimes needed when run from a network or thumb drive.
@echo off
%~d0 2>NUL
pushd "%~dp0" 2>NUL

for %%F in (*.zip) do ( "C:\Program Files\7-Zip\7z.exe" x -y -o"%%F_tmp" "%%F" * & pushd %%F_tmp & "C:\Program Files\7-Zip\7z.exe" a -y -r -t7z ..\"%%~nF".7z * & popd & rmdir /s /q "%%F_tmp" )
