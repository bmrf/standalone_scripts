:: Purpose:       Rebuilds and repairs WMI on a system
:: Requirements:  A broken WMI configuration
:: Author:        akp982 at http://community.spiceworks.com/scripts/show/113-rebuild-wmi
::                .bat-wrapped by vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x07d1490f82a211a2
:: Version:       1.0.0   Initial write


:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
:: Set where to save the logfile here
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_WMI_repair.log


::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
@echo off
SETLOCAL
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2015-02-11
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%


:::::::::::::
:: EXECUTE ::
:::::::::::::
echo.
echo Rebuilding WMI.....Please wait. > "%LOGPATH%\%LOGFILE%"
echo Rebuilding WMI.....Please wait.
echo.

net stop sharedaccess >> "%LOGPATH%\%LOGFILE%"
net stop winmgmt /y >> "%LOGPATH%\%LOGFILE%"

pushd %SystemRoot%\system32\wbem >> "%LOGPATH%\%LOGFILE%"
for %%i in (*.dll) do RegSvr32 -s %%i
tskill wbemtest /a 2>NUL
scrcons.exe /RegServer
unsecapp.exe /RegServer
wmiadap.exe /RegServer
wmiapsrv.exe /RegServer
wmiprvse.exe /RegServer
start "" wbemtest.exe /RegServer
tskill wbemtest /a 2>NUL
tskill wbemtest /a 2>NUL
del /Q Repository >> "%LOGPATH%\%LOGFILE%"
mofcomp cimwin32.mof >> "%LOGPATH%\%LOGFILE%"
mofcomp cimwin32.mfl >> "%LOGPATH%\%LOGFILE%"
mofcomp rsop.mof >> "%LOGPATH%\%LOGFILE%"
mofcomp rsop.mfl >> "%LOGPATH%\%LOGFILE%"
for /f %%s in ('dir /b /s *.dll') do regsvr32 /s %%s >> "%LOGPATH%\%LOGFILE%"
for /f %%s in ('dir /b *.mof') do mofcomp %%s >> "%LOGPATH%\%LOGFILE%"
for /f %%s in ('dir /b *.mfl') do mofcomp %%s >> "%LOGPATH%\%LOGFILE%"
mofcomp exwmi.mof >> "%LOGPATH%\%LOGFILE%"
mofcomp -n:root\cimv2\applications\exchange wbemcons.mof >> "%LOGPATH%\%LOGFILE%"
mofcomp -n:root\cimv2\applications\exchange smtpcons.mof >> "%LOGPATH%\%LOGFILE%"
mofcomp exmgmt.mof >> "%LOGPATH%\%LOGFILE%"
net stop winmgmt >> "%LOGPATH%\%LOGFILE%"
net start winmgmt >> "%LOGPATH%\%LOGFILE%"
:: Most aggressive option
winmgmt.exe /resetrepository
:: Less aggressive option
:: winmgmt.exe /salvagerepository /resyncperf

:: Get 64-bit stuff
if exist %SystemRoot%\SysWOW64\wbem ( 
		pushd %SystemRoot%\SysWOW64\wbem
		for %%j in (*.dll) do RegSvr32 -s %%j
		:: Most aggressive option
		winmgmt.exe /resetrepository
		:: Less aggressive option
		:: winmgmt.exe /salvagerepository /resyncperf
		wmiadap.exe /RegServer
		wmiprvse.exe /RegServer
		popd
		)
	popd


:: finished
echo.
echo WMI rebuild finished, recommend rebooting now.>> "%LOGPATH%\%LOGFILE%"
echo WMI rebuild finished, recommend rebooting now.
echo.
pause
