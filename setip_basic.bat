:: Purpose:       Allows you to quickly change your IP address without using the GUI
:: Requirements:  Windows XP and up
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       1.0.0   Initial write
@echo off


:::::::::::::::
:: VARIABLES :: --------------- These are the defaults. Change them if you so desire. -------- ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )

:: Static IP config
set ADAPTER_NAME=eth1
set IP=192.168.100.10
set MASK=255.255.255.0
set GATEWAY=192.168.100.1
set DNS1=
set DNS2=84.200.69.80
set DNS3=84.200.70.40




:: --------------------------- Don't edit anything below this line --------------------------- ::



:: Prep and checks
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2020-07-16
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%






:: Ask whether DHCP or static
echo.
echo  Quick IP change script v%SCRIPT_VERSION%
echo  -----------------------------
echo  Static config (if loaded):
echo.
echo   Adapter name: %ADAPTER_NAME%
echo   IP:           %IP%
echo   Subnet:       %MASK%
echo   Gateway:      %GATEWAY%
echo   DNS servers:  %DNS1%
echo                 %DNS2%
echo                 %DNS3%                   
echo  -----------------------------
echo.
:choice_prompt
set choice=a
set /p choice=Enter 'a' for auto (DHCP) or 'b' to load the static config above [A/b]: 
if not '%choice%'=='' set choice=%choice:~0,1%
	if '%choice%'=='a' goto auto_dhcp
	if '%choice%'=='b' goto manual_static
echo.
echo  "%choice%" is not valid, please try again
echo.
goto choice_prompt



:: Manual/static
:manual_static
echo.
echo Applying the static TCP/IP configuration.
echo This could take up to 30 seconds, please be patient...
echo.
echo Setting IP address to %IP%...
	netsh interface ip set address name=%ADAPTER_NAME% source=static %IP% %MASK% %GATEWAY% 1 > NUL 2>&1
echo Setting the default gateway %GATEWAY% as primary DNS...
	netsh interface ip set dns name=%ADAPTER_NAME% static %DNS1% primary > NUL 2>&1
echo Setting %DNS2% and %DNS3% as the alternate DNS servers...
	netsh interface ip add dns name=%ADAPTER_NAME% %DNS2% index=2 > NUL 2>&1
	netsh interface ip add dns name=%ADAPTER_NAME% %DNS3% index=3 > NUL 2>&1
goto end


:: Auto DHCP
:auto_dhcp
echo.
echo Using DHCP to acquire IP address for adapter %ADAPTER_NAME%...
echo.
netsh interface ip set address name=%ADAPTER_NAME% source=dhcp > NUL 2>&1
echo Using DHCP to acquire DNS servers...
netsh interface ip set dns name=%ADAPTER_NAME% source=dhcp > NUL 2>&1
ipconfig /renew "%ADAPTER_NAME%" > NUL 2>&1



:end
del "%TEMP%\tempLANconfig.txt" /Q 2>nul
del "%TEMP%\tempLANconfig2.txt" /Q 2>nul