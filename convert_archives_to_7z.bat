:: Purpose:       Recursively converts all .rar and .zip files to the .7z format at max compression
:: Requirements:  1. Specify the location of 7z.exe (below in variables section)
::                2. Specify the desired archive formats to convert (below in variables section)
:: Author:        vocatus.gate@gmail.com // github.com/bmrf // reddit.com/user/vocatus // PGP: 0x07d1490f82a211a2
:: Usage:         1. Place this file in the top-level directory containing the files you want to convert
::                2. Run this file (preferably with Administrator rights, although it's not strictly necessary)
:: History:       1.0.2 + Add logging
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
set SCRIPT_VERSION=1.0.2
set SCRIPT_UPDATED=2022-12-16
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%


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
for /r %%f in (%FILETYPES%) do ( 
    call :log "%CUR_DATE% %TIME%    %%f..."
    "%SEVENZIP%" x -y -o"%%f_tmp" "%%f" * >> %LOGPATH%\%LOGFILE% 2>&1
    pushd %%f_tmp
    "%SEVENZIP%" a -y -r -t7z ..\"%%~nf".7z *  >> %LOGPATH%\%LOGFILE% 2>&1
    popd
    rmdir /s /q "%%f_tmp" >> %LOGPATH%\%LOGFILE% 2>&1
    del /f /q "%%f" >> %LOGPATH%\%LOGFILE% 2>&1
)

call :log "%CUR_DATE% %TIME%   Conversion complete."
echo.



:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof
