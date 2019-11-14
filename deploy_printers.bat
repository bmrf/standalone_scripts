:: Purpose:       Remotely connects to a list of machines and either installs printers system-wide, or maps them using an "All Users" logon script. Uncomment the method you want below
:: Requirements:  Administrative rights on target machines
::                psexec.exe in location specified below
:: Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key ID: 0x07d1490f82a211a2
:: Usage:         Run like this:  .\deploy_printers.bat
:: History:       1.0.0 + Initial write



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
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_map_printers.log

:: Target information
set SYSTEMS=.\systems.txt
::set PRINTERS=.\printers.txt      // currently unused
set PRINTER1=\\blisw6syaaps004\DPTMS Bldg 1011 Basement iCafe RICOH MP C4504
set PRINTER2=\\blisw6syaaps004\DPTMS Bldg 1011 Basement iCafe 2 RICOH MP C4504
set PRINTER3=\\blisw6syaaps004\DPTMS Bldg 1011 Rm iCafe 3c RICOH MP C4504

:: psexec location
set PSEXEC=.\psexec.exe




:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2019-11-13
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title Deploying printer mappings...


:::::::::::::
:: EXECUTE ::
:::::::::::::

:: METHOD ONE: ALL-USERS STARTUP SCRIPT
:: Copies the printer mapping script to the All Users startup folder of every system listed in %SYSTEMS%

:: Make the script for uploading to the remote system if it doesn't exist
if not exist "%TEMP%\map_printers.bat" (
	echo @echo off>> %TEMP%\map_printers.bat
	echo echo.>> %TEMP%\map_printers.bat
	echo Mapping printers, please wait...>> %TEMP%\map_printers.bat
	echo echo.>> %TEMP%\map_printers.bat
	echo rundll32 printui.dll,PrintUIEntry /in /n"%PRINTER1%">> %TEMP%\map_printers.bat 2>nul
	echo rundll32 printui.dll,PrintUIEntry /in /n"%PRINTER2%">> %TEMP%\map_printers.bat 2>nul
	echo rundll32 printui.dll,PrintUIEntry /in /n"%PRINTER3%">> %TEMP%\map_printers.bat 2>nul
)

:: Upload the script to the remote system(s)
for /f %%i in (%SYSTEMS%) do (
	copy %TEMP%\map_printers.bat /y "\\%%i\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
)



:: METHOD TWO: MACHINE-WIDE (examples below this FOR statement; this uses the list of systems to act against)
:: For each system listed in systems.txt, connect with PSExec and map the printers system-wide
:: for /f %%i in (%SYSTEMS%) do (
:: 
:: 	%PSEXEC% -accepteula -nobanner -n 10 \\%%i rundll32 printui.dll,PrintUIEntry /ga /in /n"%PRINTER1%"
:: 	%PSEXEC% -accepteula -nobanner -n 10 \\%%i rundll32 printui.dll,PrintUIEntry /ga /in /n"%PRINTER2%"
:: 	%PSEXEC% -accepteula -nobanner -n 10 \\%%i rundll32 printui.dll,PrintUIEntry /ga /in /n"%PRINTER3%"
:: 
:: )


:: System-Wide Examples:

:: Map a printer
:: rundll32 printui.dll,PrintUIEntry /ga /in /n%PRINTER%

:: Map a printer and make it the default
:: rundll32 printui.dll,PrintUIEntry /ga /in /y /n%PRINTER%

:: Delete a printer
:: rundll32 printui.dll,PrintUIEntry /gd /n%PRINTER%

:: List printer connections (pops up GUI window)
:: rundll32 printui.dll,PrintUIEntry /ge
