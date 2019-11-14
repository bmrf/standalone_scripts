:: Purpose:       Deploys a script to a remote system(s) All Users startup folder
:: Requirements:  1. Administrative rights on the target machines
::                2. The script you are deploying must be in the same directory as this script
::                3. The list of systems you are deploying to must be in the same directory as this script
:: Author:        vocatus.gate@gmail.com // github.com/bmrf // reddit.com/user/vocatus // PGP: 0x07d1490f82a211a2
:: Usage:         Run like this:  .\deploy_all_users_autorun_script.bat
:: History:       1.0.0 + Initial write



:::::::::::::::
:: VARIABLES :: ---- Set these to your desired values
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )

:: Log settings
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=deploy_all_users_autorun_script.log

:: Target information
set SYSTEMS=.\systems.txt
set SCRIPT=.\map_printers.bat



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2019-11-14
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title Deploying %SCRIPT% to targets...

:: Check that target list exists
if not exist "%SYSTEMS%" (
	echo.
	echo ERROR: Cannot find %SYSTEMS%
	echo.
	echo        Place %SYSTEMS% in the same
	echo        directory as this script.
	echo.
	pause
	goto :eof
)

:: Check that our script exists
if not exist "%SCRIPT%" (
	echo.
	echo ERROR: Cannot find %SCRIPT%
	echo.
	echo        Place %SCRIPT% in the same
	echo        directory as this script.
	echo.
	pause
	goto :eof
)



:::::::::::::
:: EXECUTE ::
:::::::::::::

:: Copy the script to the All Users startup folder of every system listed in %SYSTEMS%
echo %CUR_DATE% %TIME% Deploying %SCRIPT% to systems listed in %SYSTEMS%...
echo.

:: Upload the script to the remote system(s)
SETLOCAL ENABLEDELAYEDEXPANSION
for /f %%i in (%SYSTEMS%) do (
	ping %%i -n 1 >nul
	if /i not !ERRORLEVEL!==0 echo %%i seems to be offline, skipping... && goto :skip_system
	copy %SCRIPT% /y "\\%%i\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" >> "%LOGPATH%\%LOGFILE%" 2>&1
	echo Uploaded to %%i.
	:skip_system
)
ENDLOCAL


:: Done
echo.
echo %TIME% Done.














:eof
