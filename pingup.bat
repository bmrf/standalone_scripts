:: Purpose:      Simple script to check if a host is online and turn the window green (up) or red (down) based on the result. Also logs the result to a file
:: Requirements: Windows XP and up
:: Author:       reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:      1.2.1 ! Fix date not correctly updating at start of each check
::               1.2.0 * Rework CUR_DATE to use function we call instead of static conversion
::               1.1.0 * Reworked CUR_DATE variable to handle more than one Date/Time format
::                       Can now handle all Windows date formats
::               1.0.0   Initial write


::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
@echo off
set SCRIPT_VERSION=1.2.1
set SCRIPT_UPDATED=2020-07-16
cls
call :set_cur_date

:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
:: Set host to check here
::set HOST=72.201.99.26
set HOST=8.8.4.4
set DISPLAY_NAME=GoogleDNS
set LOGPATH=%SystemDrive%\logs
set LOGFILE=pingup_%DISPLAY_NAME%.log
set PINGS_PER_CHECK=3
set RECHECK_COOLDOWN_DELAY=10

:: make the log directory if it doesn't exist
if not exist "%LOGPATH%" mkdir "%LOGPATH%" >nul


:::::::::::::
:: EXECUTE ::
:::::::::::::
echo %CUR_DATE% %TIME%   Initializng PINGUP monitoring script
echo                          Executing as %USERDOMAIN%\%USERNAME% on '%COMPUTERNAME%'
echo                          Monitoring:       %HOST% ^(%DISPLAY_NAME%^)
echo                          Pings per check:  %PINGS_PER_CHECK%
echo                          Recheck cooldown: %RECHECK_COOLDOWN_DELAY%

:: This block creates the log entries
echo %CUR_DATE% %TIME%   Initializng PINGUP monitoring script >>"%LOGPATH%\%LOGFILE%"
echo                          Executing as %USERDOMAIN%\%USERNAME% on '%COMPUTERNAME%' >>"%LOGPATH%\%LOGFILE%"
echo                          Monitoring:       %HOST% (%DISPLAY_NAME%) >>"%LOGPATH%\%LOGFILE%"
echo                          Pings per check:  %PINGS_PER_CHECK%  >>"%LOGPATH%\%LOGFILE%"
echo                          Recheck cooldown: %RECHECK_COOLDOWN_DELAY%  >>"%LOGPATH%\%LOGFILE%"
 
echo.
echo %CUR_DATE% %TIME%   Performing initial test...
echo %CUR_DATE% %TIME%   Performing initial test... >>"%LOGPATH%\%LOGFILE%"
echo.


:start
call :set_cur_date
ping %HOST% -n %PINGS_PER_CHECK% | find /i "TTL" > nul


:::::::::::::
:: HOST UP ::
:::::::::::::
:: Host is UP: Black text on green background
if %ERRORLEVEL%==0 (
	title UP: %HOST% 
	color a0
	echo %CUR_DATE% %TIME%   Host %HOST% ^(%DISPLAY_NAME%^) up.
	echo %CUR_DATE% %TIME%   Host %HOST% ^(%DISPLAY_NAME%^) up. >>"%LOGPATH%\%LOGFILE%"
) ELSE (
	REM Host is DOWN: Black text on red background 
	title DWN: %HOST%
	color c0
	echo %CUR_DATE% %TIME% ! Host %HOST% ^(%DISPLAY_NAME%^) down.
	echo %CUR_DATE% %TIME% ! Host %HOST% ^(%DISPLAY_NAME%^) down. >>"%LOGPATH%\%LOGFILE%"
)


:: Cooldown until next check
ping localhost -n 60 >NUL
goto start





:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it 
:set_cur_date
for /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
goto :eof
