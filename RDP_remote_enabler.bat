:: Purpose:      Enables RDP on a Vista/7/8/10 system remotely
:: Requirements: 1. Run this script with a network admin account
::               2. reg.exe, psexec.exe, and ntrights.exe must be in any of these locations:
::                   a) the directory you run the script from
::                   b) c:\windows\system32\
::                   c) the system PATH variable
:: Author:       reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: History:      1.7.0 * Reworked CUR_DATE variable to handle more than one Date/Time format
::                       Can now handle all Windows date formats
::               1.6.0 + Added new Step 7 to show who's logged in at the remote box instead of disable CAC-only login
::                     + Added workaround method for Step 1 (was failing when passing IP's for some reason).
::               1.5.0 + Added a 1-count ping before running operations
::               1.4.0 / Changed step 1 to stack ALL usernams in a single command (instead one separate /ADD command per user)
::               1.3.0 + Added code to allow run-once behavior (specify computer name when starting the script).
::                       example: rdp_enabler.bat computername
::               1.2.0 * Cleaned up comments and information that displays while the script is running
::                     - Removed 4th section that added Remote Interactive rights for individual users, 
::                       since this is accomplished by verifying RI rights are present for the RDU group
::               1.0.0   Initial write
@echo off
cls


:::::::::::::::
:: VARIABLES :: --  Set these
:::::::::::::::

:: Which user to enable RDP for
set RDP_USER=vocatus

:: Connection timeout (in seconds)
set TIMEOUT=4


::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
set SCRIPT_VERSION=1.7.0
set SCRIPT_UPDATED=2020-07-22
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set TARGET=%1%
title RDP Enabler v%SCRIPT_VERSION%


:::::::::::::
:: EXECUTE ::
:::::::::::::
:: Test if we're hitting one system then quitting
if not '%1%'=='' goto run_once

:: Start menu
:start
echo.
echo  Remote RDP Enabler v%SCRIPT_VERSION%
echo  Requires reg.exe, psexec.exe and ntrights.exe
echo.
echo  Enter the IP or name of the remote computer to enable
echo  Remote Desktop access.
:loop
echo.
@set /P TARGET= Target Computer: 
if %TARGET%==exit goto end
:: Eight steps:
:: 0. Ping to wake up any sleeping connections (this helps for some reason)
:: 1. Enable RDP on the remote box (flip the registry bit)
:: 2. Add appropriate users to "Remote Desktop Users" user group
:: 3. Bug fix 1: On some Vista images, the Remote Desktop Users group is missing the Remote Interactive Logon right
:: 4. Bug fix 2: "Deny Remote Interactive Logon" includes the "Everyone" group for some reason. Revoke (disable/undo) this.
:: 5. Start Terminal Services services and dependencies
:: 6. Disable CAC-only login (bonus!)
:: 7. Report who (if anyone) is logged on locally at the box. This fails quite a bit.
:: 8. Report results and loop back, if RUN_ONCE is set to false. Otherwise quit.

:run_once
:: Built-in Windows method. Sometimes fails when using an IP address instead of a system name for some reason.
::reg add "\\%TARGET%\HKLM\SYSTEM\ControlSet001\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

:: Workaround method using SysInternals PsExec. Usually works fine.
psexec \\%TARGET% reg add "HKLM\SYSTEM\ControlSet001\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

:: Step 2 - Add users to "Remote Desktop Users" group; you can add multiple users in one command. Enclose full usernames in quotes, separated by a space
psexec -accepteula -n %TIMEOUT% -d \\%TARGET% net localgroup "Remote Desktop Users" /add "%RDP_USER%"

:: Step 3 - Fix some annoyances - make sure the Remote Desktop Users group has access to login remotely
ntrights -u "Remote Desktop Users" +r SeNetworkLogonRight -m \\%TARGET%
ntrights -u "Remote Desktop Users" +r SeRemoteInteractiveLogonRight -m \\%TARGET%

:: step 4 - Revoke (remove/disable) all the "deny" rights for "everyone" just in case. These will usually fail, not a problem.
ntrights -u Everyone -r SeDenyRemoteInteractiveLogonRight -m \\%TARGET%
ntrights -u Everyone -r SeDenyServiceLogonRight -m \\%TARGET%
ntrights -u Everyone -r SeDenyBatchLogonRight -m \\%TARGET%
ntrights -u Everyone -r SeDenyNetworkLogonRight -m \\%TARGET%

:: Step 5 - Start up the Terminal Services dependencies and set to auto-start
psexec -accepteula -n %TIMEOUT% -d \\%TARGET% sc config termservice start= auto && net start termservice

:: Step 6 - Disable CAC login (bonus!)
reg add \\%TARGET%\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system /v scforceoption /t REG_DWORD /d 0 /f

:: Step 7 - Report who (if anyone) is logged in locally at the box
echo.
echo  Currently Logged-In User:
echo  =========================
echo.
:: Method #1: WMIC. Most accurate, only works on XP and up. Usually works
WMIC /NODE: %TARGET% computersystem GET name, username

:: Method #2: SysInternals utility. Works most of the time if you have the exe.
::PsLoggedon.exe -l \\%target%

:: Method #3: Windows built-in. Usually doesn't work
::psexec -accepteula -n %TIMEOUT% \\%TARGET% query user


:: Step 8 - Report results and loop back
echo.
psexec \\%TARGET% netstat -an | find "3389"
title RDP Enabler
echo.
echo If you see port 3389 listed above, or "netstat exited with error code 0"
echo then Remote Desktop is listening correctly.
echo.
echo.
:: reset target and check to see if this is a one-time deal
set TARGET=
if '%1%'=='' goto loop

:end
title %USERNAME%