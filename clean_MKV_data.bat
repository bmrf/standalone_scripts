:: Purpose:       Cleans all metadata off supported media files (typically MKV)
:: Requirements:  Edit the script to specify location of mkvpropedit.exe and the directory to clean. Operates recursively.
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       1.0.0 + Initial write


:::::::::::::::
:: VARIABLES :: ---- Set these to your desired values. The defaults should work fine though ------ ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )

:: Log settings
set LOGPATH=%SystemDrive%\logs
set LOGFILE=%COMPUTERNAME%_clean_MKV_data.log

:: Set these variables
set MKVPROPEDIT=R:\utilities\cli_utils\mkvpropedit.exe
set TARGETDIR=\\10.0.0.4\Media\TV Shows



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2024-05-12
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title Clean MKV Data v%SCRIPT_VERSION% (%SCRIPT_UPDATED%)


:::::::::::::
:: EXECUTE ::
:::::::::::::
pushd "%TARGETDIR%"

for /r %%i in (*.mkv,*.webm,*.mp4) do (
	echo %CUR_DATE%   Processing "%%i"
	echo %CUR_DATE%   Processing "%%i" >> "%LOGPATH%\%LOGFILE%" 2>NUL
	"%MKVPROPEDIT%" "%%i" -d title >> "%LOGPATH%\%LOGFILE%" 2>NUL
)

popd
pause
