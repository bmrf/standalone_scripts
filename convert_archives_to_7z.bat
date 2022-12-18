:: Purpose:       Recursively converts all .rar and .zip files to the .7z format at max compression
:: Requirements:  1. Specify the location of 7z.exe (below in variables section)
::                2. Specify the desired archive formats to convert (below in variables section)
:: Author:        vocatus.gate@gmail.com // github.com/bmrf // reddit.com/user/vocatus // PGP: 0x07d1490f82a211a2
:: Usage:         1. Place this file in the top-level directory containing the files you want to convert
::                2. Run this file (preferably with Administrator rights, although it's not strictly necessary)
:: History:       1.0.4 + Add rudimentary conversion verification, to avoid removing source file if conversion failed. Thanks to u/CompWizrd
::                      + Add creation of log directory if it doesn't exist. Thanks to u/jimicus
::                1.0.3 + Add multithreading and compression level 9 (highest)
::                1.0.2 + Add logging
::                1.0.1 + Add recursion
::                1.0.0 + Initial write
@echo off


:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
set SEVENZIP=%ProgramFiles%\7-Zip\7z.exe
set FILETYPES=*.rar *.zip
set LOGPATH=%SystemDrive%\logs
set LOGFILE=%COMPUTERNAME%_convert_archives_to_7z.log


:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
set SCRIPT_VERSION=1.0.4
set SCRIPT_UPDATED=2022-12-18
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
for /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') do set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
:: Create the log directory if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%


:::::::::::::
:: EXECUTE ::
:::::::::::::
:: Get in the correct drive (~d0) and path (~dp0). Sometimes needed when run from a network or thumb drive.
%~d0 2>NUL
pushd "%~dp0" 2>NUL


:: Header
echo.
call :log " CONVERT ARCHIVES TO .7z FORMAT v%SCRIPT_VERSION% (%SCRIPT_UPDATED%)"
echo.
call :log "  Script:    github.com/bmrf/standalone_scripts"
call :log "  Logfile:   %LOGPATH%\%LOGFILE%"
call :log "  Filetypes: %FILETYPES%"
echo.
call :log "  Recursively repacks various archive formats to 7-Zip's"
call :log "  .7z format, configured for maximum compression. Starts"
call :log "  from the directory you ran it from."
echo.
echo  ORIGINAL ARCHIVES WILL BE REPLACED WITH .7z VERSION!
echo.
echo  Proceed?
echo.
pause
echo.

:: Begin conversion
call :log "%CUR_DATE% %TIME%   Converting files..."

:: For each file, extract it to a temp folder, re-pack it, and delete the original file
setlocal enabledelayedexpansion
for /r %%f in (%FILETYPES%) do (

	:: Build some easier to read variables
	set FILE=%%f
	set FILE_NO_EXT=%%~nf
	set FILE_PATH=%%~dpf
	set NEW_FILE=!FILE_NO_EXT!.7z
	set UNPACK_DIR=!FILE_PATH!!FILE_NO_EXT!_tmp

	:: Do the conversion
	call :log "%CUR_DATE% %TIME%    !FILE!..."
	"%SEVENZIP%" x -y -o"!UNPACK_DIR!" "!FILE!" * >> %LOGPATH%\%LOGFILE% 2>&1
	pushd "!UNPACK_DIR!"
    "%SEVENZIP%" a -y -r -mmt4 -mx9 -t7z ..\"!NEW_FILE!" *  >> %LOGPATH%\%LOGFILE% 2>&1

	:: Make sure we were able to create the .7z archive before deleting the original file
	if exist ..\"!NEW_FILE!" (
		del /f /q "!FILE!" >> %LOGPATH%\%LOGFILE% 2>&1
	) else (
		call :log "%CUR_DATE% %TIME% ^^^!  Conversion verification of '!FILE!' failed, original not removed."
	)
    popd

	:: Cleanup unpack directory
    rmdir /s /q "!UNPACK_DIR!" >> %LOGPATH%\%LOGFILE% 2>&1
)
endlocal

call :log "%CUR_DATE% %TIME%   Conversion complete."
echo.




:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof
