:: Purpose:       Removes all versions of Microsoft Silverlight from a system. Saves a log to c:\logs by default
:: Requirements:  Run this script with an admin account
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: History:       1.0.0 + Initial write
SETLOCAL


:::::::::::::::
:: VARIABLES :: ---- Set these to your desired values. The defaults should work fine though ------ ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "%SYSTEMDRIVE%\directory\path"       )
::  * NO trailing slashes on the path! (bad:   %SYSTEMDRIVE%\directory\            )
::  * Spaces are okay                  (okay:  %SYSTEMDRIVE%\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )

:: Log location and name. Do not use trailing slashes (\)
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_microsoft_silverlight_nuker.log

:: Force-close processes that might be using Silverlight? Recommend leaving this set to 'yes' unless you
:: specifically want to abort the script if the target machine might possibly be using Silverlight.
:: If you change this to 'no', the script will exit with an error code if it thinks Silverlight could be in use.
set FORCE_CLOSE_PROCESSES=yes
:: Exit code to use when FORCE_CLOSE_PROCESSES is "no" and a potential Silverlight-dependent process is detected
set FORCE_CLOSE_PROCESSES_EXIT_CODE=1618



:: =============================================================================================== ::
:: ======  Think of everything below this line like a feral badger: Look, but Do Not Touch  ====== ::
:: =============================================================================================== ::



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2019-10-17
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

:: This is useful if we start from a network share; converts CWD to a drive letter
pushd "%~dp0"

:: Create the log directory if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%

:: Check if we're on XP. This affects some commands later, because XP uses slightly
:: different binaries for reg.exe and various other Windows utilities
set OS_VERSION=OTHER
ver | find /i "XP" >NUL
IF %ERRORLEVEL%==0 set OS_VERSION=XP

title Silverlight Nuker v%SCRIPT_VERSION% (%SCRIPT_UPDATED%)


:::::::::::::::::::::::::::
:: FORCE-CLOSE PROCESSES :: -- Do we want to kill Silverlight before running? If so, this is where it happens
:::::::::::::::::::::::::::
if %FORCE_CLOSE_PROCESSES%==yes (
	REM Kill all browsers and running Silverlight instances
	call :log "%CUR_DATE% %TIME%   Looking for and closing all running browsers and Silverlight instances..."
	if %OS_VERSION%==XP (
		REM XP version of the task killer
		REM this loop contains the processes we should kill
		for %%i in (battle,chrome,firefox,silverlight,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
			echo     Searching for %%i.exe...
			%WINDIR%\system32\tskill.exe /a /v %%i* >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
	) else (
		REM 7/8/2008/2008R2/2012/etc version of the task killer
		REM this loop contains the processes we should kill
		FOR %%i in (battle.net,chrome,firefox,Silverlight,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
			echo     Searching for %%i.exe...
			%WINDIR%\system32\taskkill.exe /f /fi "IMAGENAME eq %%i*" /T >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
	)
)

:: If we DON'T want to force-close Silverlight, then check for possible running Silverlight processes and abort the script if we find any
if %FORCE_CLOSE_PROCESSES%==no (
	call :log "%CUR_DATE% %TIME%   Variable FORCE_CLOSE_PROCESSES is set to '%FORCE_CLOSE_PROCESSES%'. Checking for running processes before execution..."

	REM Don't ask...
	REM Okay so basically we loop through this list of processes, and for each one we dump the result of the search in the '%%a' variable.
	REM Then we check that variable, and if it's not null (e.g. FIND.exe found something) we abort the script, returning the exit code
	REM specified at the beginning of the script. Normally you'd use ERRORLEVEL for this, but because it is very flaky (it doesn't
	REM always get set, even when it should) we instead resort to using this method of dumping the results in a variable and checking it.
	for %%i IN (battle.net,chrome,firefox,silverlight,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
		call :log "%CUR_DATE% %TIME%   Searching for %%i.exe...
		for /f "delims=" %%a in ('tasklist ^| find /i "%%i"') do (
			if not [%%a]==[] (
				call :log "%CUR_DATE% %TIME% ! ERROR: Process '%%i' is currently running, aborting."
				exit /b %FORCE_CLOSE_PROCESSES_EXIT_CODE%
			)
		)
	)
	REM If we made it this far, we didn't find anything, so we can go ahead
	call :log "%CUR_DATE% %TIME%   All clear, no Silverlight-related processes found. Going ahead with removal..."
)




:::::::::::::
:: EXECUTE ::
:::::::::::::
:: Log that we started
call :log "%CUR_DATE% %TIME%   Beginning removal of Silverlight, all versions..."



:::::::::::::::::::::::::
:: UNINSTALLER SECTION :: -- Here we just brute-force every "normal" method for removing
:::::::::::::::::::::::::    Silverlight, then resort to more painstaking methods later

:: Attempt WMIC by name, this should usually catch most installations
call :log "%CUR_DATE% %TIME%    Attempting removal via WMIC name wildcard..."
wmic product where "name like 'Silverlight%%'" uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
call :log "%CUR_DATE% %TIME%    Done."

:: Attempt WMIC by specific GUID listing
call :log "%CUR_DATE% %TIME%    Attempting removal via specific GUID listing..."
	:: Silverlight ActiveX ProductCodes
	:: Silverlight
	MsiExec.exe /uninstall {A1591282-1198-4647-A2B1-27E5FF5F6F3B} /quiet /norestart
	:: Silverlight v5.1.41212.0
	MsiExec.exe /uninstall {89F4137D-6C26-4A84-BDB8-2E5A4BB71E00} /quiet /norestart
call :log "%CUR_DATE% %TIME%    Done."




::::::::::::::::::::::::::::::::
:: FILE AND DIRECTORY CLEANUP ::
::::::::::::::::::::::::::::::::
call :log "%CUR_DATE% %TIME%   Launching manual purge of leftover files..."

:: JOB: Directories
call :log "%CUR_DATE% %TIME%    Removing directories..."
	if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Silverlight" rmdir "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Silverlight" /s /q >> "%LOGPATH%\%LOGFILE%" 2>NUL
	if exist "%ProgramFiles%\Microsoft Silverlight" rmdir "%ProgramFiles%\Microsoft Silverlight" /s /q >> "%LOGPATH%\%LOGFILE%" 2>NUL
	if exist "%ProgramFiles(x86)%\Microsoft Silverlight" rmdir "%ProgramFiles(x86)%\Microsoft Silverlight" /s /q >> "%LOGPATH%\%LOGFILE%" 2>NUL
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Prefetch and cache files
call :log "%CUR_DATE% %TIME%    Purging prefetch and cache files..."
	if exist "%WINDIR%\Prefetch\SILVERLIGHT*.pf" del "%WINDIR%\Prefetch\SILVERLIGHT*.pf" >> "%LOGPATH%\%LOGFILE%" 2>NUL
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Registry entries
call :log "%CUR_DATE% %TIME%    Purging registry entries..."
	reg delete HKLM\Software\Microsoft\Silverlight /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_CLASSES_ROOT\Installer\Products\D7314F9862C648A4DB8BE2A5B47BE100 /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D7314F9862C648A4DB8BE2A5B47BE100 /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_CLASSES_ROOT\TypeLib\{283C8576-0726-4DBC-9609-3F855162009A} /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\install.exe /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_CLASSES_ROOT\AgControl.AgControl /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_CLASSES_ROOT\AgControl.AgControl.5.1 /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
	reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{89F4137D-6C26-4A84-BDB8-2E5A4BB71E00} /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
call :log "%CUR_DATE% %TIME%    Done."


call :log "%CUR_DATE% %TIME%   Removal complete. Recommend rebooting immediately."

REM Return exit code to SCCM/PDQ Deploy/etc
exit /B %EXIT_CODE%






:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof
