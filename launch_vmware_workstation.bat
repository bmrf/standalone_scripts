:: Purpose:       Starts and stops the services required by VMWare Workstation
::                Frees up roughly 33MB of RAM
:: Requirements:  VMware workstation installed
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: History:       1.1.2 ! Add /y switch to VMwareAuthD stop command to force through prompt
::                1.1.1 * Converted GOTO's to FOR loops
::                1.1.0 * Reworked CUR_DATE variable to handle more than one Date/Time format
::                        Can now handle all Windows date formats
::                1.0.0   Initial write



::::::::::
:: Prep ::
::::::::::
@echo off
cls
set SCRIPT_VERSION=1.1.2
set SCRIPT_UPDATED=2019-12-19
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%


:::::::::::::
:: EXECUTE ::
:::::::::::::
:: If we passed "start" or "stop" to the batch file then just directly run that portion
if /i '%1'=='-stop' set CHOICE=stop && goto evaluate
if /i '%1'=='-start' set CHOICE=start && goto evaluate

echo.
echo  Stops and starts the services required by VMware Workstation.
echo.
set /p CHOICE=Enter 'stop', 'start' or 'exit': 


:evaluate
if %CHOICE%==stop (
	net stop VMnetDHCP
	net stop VMwareHostd
	net stop VMAuthdService
	net stop "VMware NAT Service"
	net stop VMUSBArbService
	sc config VMnetDHCP start= disabled
	sc config VMwareHostd start= disabled
	sc config VMAuthdService start= disabled
	sc config "VMware NAT Service" start= disabled
	sc config VMUSBArbService start= disabled
	)
	
if %CHOICE%==start (
	sc config VMnetDHCP start= demand
	sc config VMwareHostd start= demand
	sc config VMAuthdService start= demand
	sc config "VMware NAT Service" start= demand
	sc config VMUSBArbService start= demand
	net start VMnetDHCP
	net start VMwareHostd
	net start "VMware NAT Service"
	echo.
	echo  You can minimize this window, it will stay open until VMware Workstation closes.
	echo.
	"%ProgramFiles(x86)%\VMware\VMware Workstation\vmware.exe"
	net stop VMnetDHCP
	net stop VMwareHostd
	net stop VMAuthdService /y
	net stop "VMware NAT Service"
	net stop VMUSBArbService
	sc config VMnetDHCP start= disabled
	sc config VMwareHostd start= disabled
	sc config VMAuthdService start= disabled
	sc config "VMware NAT Service" start= disabled
	sc config VMUSBArbService start= disabled
	)

:: These get automatically started for dependencies so there's no need to start them manually
::net start VMAuthdService
::net start VMUSBArbService

:end
