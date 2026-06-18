:: Purpose:      Interactive SSH connection helper for legacy hosts. Prompts for a host and username (unless pre-set below), then connects using older key exchange and host-key algorithms that modern OpenSSH disables by default. Logs timestamped connection attempts to a file
:: Requirements: Windows 10 (1809) and up with the built-in OpenSSH client, or any Windows with the OpenSSH client installed
:: Author:       reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:      1.0.0   Initial write


::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
@echo off
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2026-06-18
cls
call :set_cur_date


:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
:: Optionally pre-set a host and/or username to skip the prompts. Leave blank to be prompted.
:: set HOST=10.0.0.1
:: set SSH_USER=admin
set HOST=
set SSH_USER=

:: Legacy algorithms to offer. Modern OpenSSH disables these by default; the leading + appends them to the client defaults rather than replacing them.
set KEX_ALGORITHMS=+diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1
set HOSTKEY_ALGORITHMS=+ssh-rsa
set LOGPATH=%SystemDrive%\logs
set LOGFILE=ssh_using_deprecated_encryption.log

:: make the log directory if it doesn't exist
if not exist "%LOGPATH%" mkdir "%LOGPATH%" >nul


:::::::::::::
:: EXECUTE ::
:::::::::::::
title Legacy SSH
echo %CUR_DATE% %TIME%   Initializing legacy SSH connection script
echo                          Executing as   %USERDOMAIN%\%USERNAME% on '%COMPUTERNAME%'
echo                          Logging to:    %LOGPATH%\%LOGFILE%
echo                          kEx algos:     %KEX_ALGORITHMS%
echo                          Hostkey algos: %HOSTKEY_ALGORITHMS%
:: This block creates the log entries
echo %CUR_DATE% %TIME%   Initializing legacy SSH connection script >> "%LOGPATH%\%LOGFILE%"
echo                          Executing as   %USERDOMAIN%\%USERNAME% on '%COMPUTERNAME%' >> "%LOGPATH%\%LOGFILE%"
echo                          Logging to:    %LOGPATH%\%LOGFILE% >> "%LOGPATH%\%LOGFILE%"
echo                          kEx algos:     %KEX_ALGORITHMS% >> "%LOGPATH%\%LOGFILE%"
echo                          Hostkey algos: %HOSTKEY_ALGORITHMS% >> "%LOGPATH%\%LOGFILE%"

echo.
:: Prompt for host if one wasn't pre-set above
if "%HOST%"=="" set /p HOST="                         Enter host (IP or hostname): "
if "%HOST%"=="" (
	call :set_cur_date
	echo %CUR_DATE% %TIME% ! No host entered, exiting.
	echo %CUR_DATE% %TIME% ! No host entered, exiting. >> "%LOGPATH%\%LOGFILE%"
	pause
	exit /b 1
)
:: Prompt for username if one wasn't pre-set above
if "%SSH_USER%"=="" set /p SSH_USER="                         Enter username: "
if "%SSH_USER%"=="" (
	call :set_cur_date
	echo %CUR_DATE% %TIME% ! No username entered, exiting.
	echo %CUR_DATE% %TIME% ! No username entered, exiting. >> "%LOGPATH%\%LOGFILE%"
	pause
	exit /b 1
)
echo.
call :set_cur_date
echo %CUR_DATE% %TIME%   Connecting to %SSH_USER%@%HOST% ...
echo %CUR_DATE% %TIME%   Connecting to %SSH_USER%@%HOST% ... >> "%LOGPATH%\%LOGFILE%"
title SSH: %SSH_USER%@%HOST%
echo.
ssh -oKexAlgorithms=%KEX_ALGORITHMS% -oHostKeyAlgorithms=%HOSTKEY_ALGORITHMS% %SSH_USER%@%HOST%
:: Capture ssh's exit code immediately, before set_cur_date resets ERRORLEVEL
set SSH_EXIT=%ERRORLEVEL%
call :set_cur_date
echo.
echo %CUR_DATE% %TIME%   Session ended ^(exit code %SSH_EXIT%^).
echo %CUR_DATE% %TIME%   Session ended (exit code %SSH_EXIT%). >> "%LOGPATH%\%LOGFILE%"
pause
goto :eof


:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it 
:set_cur_date
for /f %%a in ('powershell -NoProfile -Command "$d = Get-Date; $d.ToString(\"yyyyMMddHHmmss.fff\") + $d.ToString(\"zzz\").Replace(\":\",\"\")"') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
goto :eof
