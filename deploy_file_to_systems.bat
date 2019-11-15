:: Purpose:       Deploys a file to remote system(s) All Users startup folder
:: Requirements:  1. Administrative rights on the target machines
::                2. The file you are deploying must be in the same directory as this file
::                3. The list of systems you are deploying to must be in the same directory as this file
:: Author:        vocatus.gate@gmail.com // github.com/bmrf // reddit.com/user/vocatus // PGP: 0x07d1490f82a211a2
:: Usage:         Run like this:  .\deploy_all_users_autorun_file.bat
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
set LOGPATH=%TEMP%
set LOGFILE=deploy_all_users_autorun_file.log

:: Target information
set SYSTEMS=systems.txt
set FILE=iCafe_Printers.pol

:: PSexec location
set PSEXEC=psexec.exe


:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set FILE_VERSION=1.0.0
set FILE_UPDATED=2019-11-15
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title Deploying %FILE% to targets...

:: Check that the target list exists
if not exist "%SYSTEMS%" (
	echo.
	echo ERROR: Cannot find %SYSTEMS%
	echo.
	echo        Place %SYSTEMS% in the same
	echo        directory as this file.
	echo.
	pause
	goto :eof
)

:: Check that our FILE exists
if not exist "%FILE%" (
	echo.
	echo ERROR: Cannot find %FILE%
	echo.
	echo        Place %FILE% in the same
	echo        directory as this FILE.
	echo.
	pause
	goto :eof
)

:: Check that psexec exists
if not exist "%PSEXEC%" (
	echo.
	echo ERROR: Cannot find %PSEXEC%
	echo.
	echo        Place %PSEXEC% in the same
	echo        directory as this PSEXEC.
	echo.
	pause
	goto :eof
)



:::::::::::::
:: EXECUTE ::
:::::::::::::


echo %CUR_DATE% %TIME%   Deploying %FILE% to systems listed in %SYSTEMS%...

:: Upload the file to the remote system(s)
SETLOCAL ENABLEDELAYEDEXPANSION
for /f %%i in (%SYSTEMS%) do (
	ping %%i -n 1 >nul
	if /i not !ERRORLEVEL!==0 (
		echo %CUR_DATE% %TIME%  ! %%i seems to be offline, skipping...
	) else (		
		copy %FILE% /y "\\%%i\c$\windows\system32\group policy\machine" >> "%LOGPATH%\%LOGFILE%" 2>&1
		echo %CUR_DATE% %TIME%    Uploaded to %%i, now triggering gpupdate.
		%PSEXEC% -accepteula -nobanner -n 3 -d \\%%i gpupdate /force
		echo %CUR_DATE% %TIME%    gpupdated /force triggered on %%i, moving to next target.
	)
)
ENDLOCAL


:: Done
echo.
echo %CUR_DATE% %TIME%   Done.










:eof
