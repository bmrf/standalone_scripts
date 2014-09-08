:: Purpose:       DHCP server Watchdog & Failover script. Read notes below
:: Requirements:  1. Domain administrator credentials & "Logon as a batch job" rights
::                2. Proper firewall configuration to allow connection
::                3. Proper permissions on the DHCP backup directory
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: Version:       1.3a * Minor header update; Variables now above prep and checks
::                1.3  * Overhauled Date/Time conversion so we can handle ALL versions of Windows using ANY local date-time format
::                1.2c * Reworked CUR_DATE variable to handle more than one Date/Time format
::                1.2b + Added comment block explaining syntax rules for variables
::                1.2  + Added functionality to recover the DHCP database BACK to the primary server after a failure. Now when the backup server detects that
::                       the primary server has come back online after an outage, it will export its current copy of the DHCP database, upload it back to the 
::                       primary server, import it, and spin it back up using the most recent copy. This addresses the issue of new leases being passed out during
::                       an outage of the primary server and it not being aware of those leases when it comes back online.
::                     + Added "REMOTE_OPERATIING_PATH" variable that lets us specify where the remote server keeps its DHCP working files during operation
::                     + Added "UPDATED" variable to note when the script was last updated
::                1.1c + Added quotes around all variables that could contain paths
::                     + Added full path to SC.exe to prevent failure in the event %PATH% gets corrupted or mangled (this happened in testing)
::                     * Fixed a glitch that could occur when pinging an assumed-down primary server that would incorrectly think it was back up
::                     - Removed almost every entry of "2>&1" since it's really not needed
::                1.1b - Changed DATE to CUR_DATE format to be consistent with all other scripts
::                1.1  - Comments improvement
::                     / Tuned some parameters (ping count on checking)
::                     / Some logging tweaks
::                     / Renamed FAILOVER_DELAY to FAILOVER_RECHECK_DELAY for clarity
::                1.0d * Some logging tweaks
::                1.0c * Some logging tweaks
::                1.0 Initial write
:: Notes:         I wrote this script after failing to find a satisfactory method of performing
::                watchdog/failover between two Windows Server 2008 R2 DHCP servers.
::
:: Use:           This script has two modes: "Watchdog" and "Failover." 
::                - Watchdog checks the status of the remote DHCP service, logs it, and then grabs the remote DHCP db backup file and imports it.
::                - Failover mode is activated when the script cannot determine the status of the remote DHCP server. The script then activates 
::                  the local DHCP server with the latest backup copy it successfully retrieved from the primary server.
::
:: Instructions:  1. Tune the variables in this script to your desired backup location and frequency
::                2. On the primary server: set the DHCP backup interval to your desired backup frequency. The value is in minutes; I recommend 5 minutes.
::                   You do this by modifying this registry key: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DHCPServer\Parameters\BackupInterval
::                3. On the backup server:  set this script to run as a scheduled task. I recommend every 10 minutes. 
:: Notice:
::               !! Make sure to set it only to run if it isn't already running! If there is a failover you could have 
::                  Task Scheduler spawn a new instance of the script every n minutes and end up with hundreds of copies
::                  of this script running.
SETLOCAL



:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )
:: Remote server is the PRIMARY DHCP server we're watching. Use a hostname or IP address.
set REMOTE_SERVER=SERVER-NAME

:: Location of the automatic DHCP backup file on the primary server. Windows generates this automatically.
:: Best practice is to leave this alone, unless you have a custom backup location.
:: The script builds the backup line like this: \\%REMOTE_SERVER%\c$\%REMOTE_BACKUP_PATH%
set REMOTE_BACKUP_PATH=Windows\system32\dhcp\backup

:: Location of the operational DHCP database files on the remote (primary) server.
:: Best practice is to leave this alone, unless you have a custom location. Changing this will break the 
:: function that re-uploads the most current db back to the primary server after a failure. This doesn't 
:: ruin the script, but if the backup server passed out any IP's while the primary server was down, the 
:: primary server won't know about them when it comes back up.
set REMOTE_OPERATING_PATH=Windows\system32\dhcp

:: Location of your backup/standby file. I normally copy directly to my backup server's DHCP directory. 
:: The script builds the local backup line like this: c:\windows\system32\dhcp\[backup folders]
set LOCAL_BACKUP_PATH=%SystemRoot%\system32\dhcp

:: When a failover is triggered, how many seconds should we wait in between each attempt to contact the primary server again?
set FAILOVER_RECHECK_DELAY=10

:: Log options. Don't put an extension on the log file name. (Important!) The script sets this later on.
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_DHCP_watchdog

:: Max log file size allowed (in bytes) before rotation and archive. I recommend setting this to 2 MB (2097152).
:: Example: 524288 is half a megabyte (~500KB)
set LOG_MAX_SIZE=10485760




:: --------------------------- Don't edit anything below this line --------------------------- ::




:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
cls
set VERSION=1.3a
set UPDATED=2014-09-08
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
title [DHCP Server Watchdog v%VERSION%]


:::::::::::::::::::::::
:: LOG FILE HANDLING :: - This section handles the log file
:::::::::::::::::::::::
:: Make the logfile if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%
if not exist %LOGPATH%\%LOGFILE%.log goto new_log

:: Check log size. If it hasn't exceeded our size limit, jump straight to Watchdog mode
for %%R in (%LOGPATH%\%LOGFILE%.log) do if %%~zR LSS %LOG_MAX_SIZE% goto newrun

:: However, if the log was too big, go ahead and rotate it.
pushd %LOGPATH%
del %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.oldest %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.older %LOGFILE%.oldest 2>NUL
rename %LOGFILE%.old %LOGFILE%.older 2>NUL
rename %LOGFILE%.log %LOGFILE%.old 2>NUL
popd

:: And then create the header for the new log file
:new_log
echo ------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%.log
echo  Initializing new DHCP Server Watchdog log on %CUR_DATE% at %TIME%, max log size %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%.log
echo ------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%.log
echo.>> %LOGPATH%\%LOGFILE%.log

:: New run section - if we just launched the script, write a header for this run
:newrun
echo ------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%.log
echo  DHCP Server Watchdog v%VERSION%, %CUR_DATE%>> %LOGPATH%\%LOGFILE%.log
echo   Running as %USERDOMAIN%\%USERNAME% on %COMPUTERNAME%>> %LOGPATH%\%LOGFILE%.log
echo.>> %LOGPATH%\%LOGFILE%.log
echo  Job Options>> %LOGPATH%\%LOGFILE%.log
echo   Log location:            %LOGPATH%\%LOGFILE%.log>> %LOGPATH%\%LOGFILE%.log
echo   Log max size:            %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%.log
echo   Watching primary server: %REMOTE_SERVER%>> %LOGPATH%\%LOGFILE%.log
echo   Mirroring this DHCP db:  %REMOTE_BACKUP_PATH%>> %LOGPATH%\%LOGFILE%.log
echo   Local backup location:   %LOCAL_BACKUP_PATH%>> %LOGPATH%\%LOGFILE%.log
echo ------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Starting Watchdog mode.>> %LOGPATH%\%LOGFILE%.log
echo.
echo  DHCP Server Watchdog v%VERSION%
echo   Running as: %USERDOMAIN%\%USERNAME% on %COMPUTERNAME%
echo   Log:        %LOGPATH%\%LOGFILE%.log


:::::::::::::::::::
:: WATCHDOG MODE ::
:::::::::::::::::::
:watchdog

:: Ping the server to see if it's up
echo.
echo   Verifying proper operation of DHCP server on %REMOTE_SERVER%, please wait...
echo.
echo %CUR_DATE% %TIME%         Pinging %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Pinging %REMOTE_SERVER%...
ping %REMOTE_SERVER% -n %FAILOVER_RECHECK_DELAY% >NUL
if %ERRORLEVEL%==1 echo %CUR_DATE% %TIME% WARNING %REMOTE_SERVER% failed to respond to ping. && echo %CUR_DATE% %TIME% WARNING %REMOTE_SERVER% failed to respond to ping.>> %LOGPATH%\%LOGFILE%.log
if not %ERRORLEVEL%==1 echo %CUR_DATE% %TIME% SUCCESS %REMOTE_SERVER% responded to ping. && echo %CUR_DATE% %TIME% SUCCESS %REMOTE_SERVER% responded to ping.>> %LOGPATH%\%LOGFILE%.log

:: Check & Log
echo %CUR_DATE% %TIME%         Checking DHCP server status on %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Checking DHCP server status on %REMOTE_SERVER%...

:: Reset ERRORLEVEL back to 0
ver > NUL

:: Use "SC" to check the status of "Dhcpserver" service, find the "RUNNING" state, and act accordingly based on the return code
%WINDIR%\System32\sc.exe \\%REMOTE_SERVER% query Dhcpserver | find "RUNNING" >NUL
if %ERRORLEVEL%==0 echo %CUR_DATE% %TIME% SUCCESS The DHCP service is running on %REMOTE_SERVER%.>> %LOGPATH%\%LOGFILE%.log
if %ERRORLEVEL%==0 echo %CUR_DATE% %TIME% SUCCESS The DHCP service is running on %REMOTE_SERVER%.

:: This section only executes if the test failed.
if not %ERRORLEVEL%==0 ( 
	echo %CUR_DATE% %TIME% FAILURE The DHCP service is not running on %REMOTE_SERVER%.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Activating failover procedure. Local DHCP server will be initialized using most recent successful backup.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME% FAILURE The DHCP service is not running on %REMOTE_SERVER%.
	echo %CUR_DATE% %TIME%         Activating failover procedure. Local DHCP server will be initialized using most recent successful backup.
	goto failover
	)

:: Reset ERRORLEVEL back to 0
ver > NUL

:: Fetch
echo %CUR_DATE% %TIME%         Fetching DHCP database backup from %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Fetching DHCP database backup from %REMOTE_SERVER%...
xcopy "\\%REMOTE_SERVER%\c$\%REMOTE_BACKUP_PATH%\*" "%LOCAL_BACKUP_PATH%\backup_new_pending\" /E /Y /Q >NUL

:: If the copy SUCCEEDED, this executes
if %ERRORLEVEL%==0 ( 
	echo %CUR_DATE% %TIME% SUCCESS Backup fetched from %REMOTE_SERVER%.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME% SUCCESS Backup fetched from %REMOTE_SERVER%.
	echo %CUR_DATE% %TIME%         Rotating database backups...>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Rotating database backups...
	:: Rotate backups and use newest copy
	rmdir /S /Q %LOCAL_BACKUP_PATH%\backup5
	if exist "%LOCAL_BACKUP_PATH%\backup4" move /Y "%LOCAL_BACKUP_PATH%\backup4" "%LOCAL_BACKUP_PATH%\backup5"
	if exist "%LOCAL_BACKUP_PATH%\backup3" move /Y "%LOCAL_BACKUP_PATH%\backup3" "%LOCAL_BACKUP_PATH%\backup4"
	if exist "%LOCAL_BACKUP_PATH%\backup2" move /Y "%LOCAL_BACKUP_PATH%\backup2" "%LOCAL_BACKUP_PATH%\backup3"
	if exist "%LOCAL_BACKUP_PATH%\backup" move /Y "%LOCAL_BACKUP_PATH%\backup" "%LOCAL_BACKUP_PATH%\backup2"
	move /Y "%LOCAL_BACKUP_PATH%\backup_new_pending" "%LOCAL_BACKUP_PATH%\backup" >NUL
	echo %CUR_DATE% %TIME%         Database backups rotated.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Database backups rotated.
	)

:: If the copy FAILED, this executes:
if not %ERRORLEVEL%==0 ( 
	echo %CUR_DATE% %TIME% WARNING There was an error copying the backup from %REMOTE_SERVER%.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         You may want to look into this since we were able to check the DHCPserver service status but the file copy failed.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Skipping new database import due to copy failure.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Job complete with errors.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME% WARNING There was an error copying the backup from %REMOTE_SERVER%.
	echo %CUR_DATE% %TIME%         You may want to look into this since we were able to check the DHCPserver service status but the file copy failed.
	echo %CUR_DATE% %TIME%         Skipping new database import due to copy failure.
	echo %CUR_DATE% %TIME%         Job complete with errors.
	)
	
:: Import database
echo %CUR_DATE% %TIME%         Starting local DHCP server to import new database...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Starting local DHCP server to import new database...
	net start Dhcpserver
echo %CUR_DATE% %TIME%         Local DHCP server running. Performing import...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Local DHCP server running. Performing import...
	netsh dhcp server restore "%LOCAL_BACKUP_PATH%\backup"
echo %CUR_DATE% %TIME%         Import complete.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Import complete.
echo %CUR_DATE% %TIME%         Stopping local DHCP server...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Stopping local DHCP server...
	sc stop Dhcpserver
echo %CUR_DATE% %TIME%         Local DHCP server stopped.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Local DHCP server stopped.
echo %CUR_DATE% %TIME% SUCCESS Job complete, DHCP database backed up and ready for use. Exiting.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME% SUCCESS Job complete, DHCP database backed up and ready for use. Exiting.
goto EOF


:::::::::::::::::::
:: FAILOVER MODE ::
:::::::::::::::::::

:failover
:: Log this AND display to console
echo %CUR_DATE% %TIME% WARNING Failover activated.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Starting local DHCP server using most recent successful backup...>> %LOGPATH%\%LOGFILE%.log
echo.
echo %CUR_DATE% %TIME% WARNING Could not contact primary DHCP server %REMOTE_SERVER%. Failover activated.
echo %CUR_DATE% %TIME%         Starting local DHCP server using most recent successful backup...
echo.
	net start Dhcpserver
echo %CUR_DATE% %TIME%         Local DHCP server started.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Entering monitoring loop. Checking if %REMOTE_SERVER% is back up every %FAILOVER_RECHECK_DELAY% seconds...>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME%         Local DHCP server started.
echo %CUR_DATE% %TIME%         Entering monitoring loop. Checking if %REMOTE_SERVER% is back up every %FAILOVER_RECHECK_DELAY% seconds...


:failover_loop
:: First we ping the server
ping %REMOTE_SERVER% -n 5 >NUL
:: If no ping response, this section executes
IF NOT %ERRORLEVEL%==0 (
	echo %CUR_DATE% %TIME% FAILURE No ping response from %REMOTE_SERVER%. Waiting %FAILOVER_RECHECK_DELAY% seconds to check again.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME% FAILURE No ping response from %REMOTE_SERVER%. Waiting %FAILOVER_RECHECK_DELAY% seconds to check again.
	ping localhost -n %FAILOVER_RECHECK_DELAY% >NUL
	goto failover_loop
	)

:: If yes ping response, this section executes
:: This declaration is required to get the nested IF ERRORLEVEL test to function correctly
SETLOCAL ENABLEDELAYEDEXPANSION
if not %ERRORLEVEL%==1 (
	echo %CUR_DATE% %TIME% NOTICE  %REMOTE_SERVER% is responding to pings.>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME% NOTICE  %REMOTE_SERVER% is responding to pings.
	echo %CUR_DATE% %TIME%         Checking DHCP server status on %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
	echo %CUR_DATE% %TIME%         Checking DHCP server status on %REMOTE_SERVER%...
	
	:: This section checks to see if the Dhcpserver service is back up and acts accordingly
	%WINDIR%\System32\sc.exe \\%REMOTE_SERVER% query Dhcpserver | find "RUNNING" >NUL
		:: The exclamation points around ERRORLEVEL here prevent it from incorrectly being expanded using the external ERRORLEVEL results from the first IF statement
		if !ERRORLEVEL!==0 (
				echo %CUR_DATE% %TIME% SUCCESS The DHCP service is running on %REMOTE_SERVER%.>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME% SUCCESS The DHCP service is running on %REMOTE_SERVER%.
				echo %CUR_DATE% %TIME%         Primary DHCP server %REMOTE_SERVER% is back up. Beginning recovery procedures...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Primary DHCP server %REMOTE_SERVER% is back up. Beginning recovery procedures...
				
				:: Back up the database that we've been running temporarily while the primary server was down
				echo %CUR_DATE% %TIME%         Exporting the current DHCP database...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Exporting the current DHCP database...
				netsh dhcp server backup %TEMP%\DHCP-RECOVERY
				
				:: Stop our local server since we're done performing DHCP server duties
				echo %CUR_DATE% %TIME%         Stopping local DHCP server...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Stopping local DHCP server...
				sc stop Dhcpserver
				
				:: Send the database back to the primary server
				echo %CUR_DATE% %TIME%         Uploading current DHCP database to %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Uploading current DHCP database to %REMOTE_SERVER%...
				xcopy "%TEMP%\DHCP-RECOVERY\*" "\\%REMOTE_SERVER%\c$\%REMOTE_OPERATING_PATH%\DHCP-RECOVERY\" /S /Y /Q 2>NUL

				:: Import the current database on the primary server
				echo %CUR_DATE% %TIME%         Importing current DHCP database on %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Importing current DHCP database on %REMOTE_SERVER%...
				netsh dhcp server \\%REMOTE_SERVER% restore "\\%REMOTE_SERVER%\c$\%REMOTE_OPERATING_PATH%\DHCP-RECOVERY"
				:: force a delay to let it stop
				ping -n 4 localhost >NUL
				
				:: Spin the primary server back up. For some reason we have to run the command twice for it to actually start. Don't ask.
				echo %CUR_DATE% %TIME%         Restarting DHCP server on %REMOTE_SERVER%...>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Restarting DHCP server on %REMOTE_SERVER%...
				sc \\%REMOTE_SERVER% stop Dhcpserver
				ping localhost -n 8 >NUL
				sc \\%REMOTE_SERVER% start Dhcpserver
				ping localhost -n 5 >NUL
				sc \\%REMOTE_SERVER% query Dhcpserver
				ping localhost -n 8 >NUL
				sc \\%REMOTE_SERVER% start Dhcpserver
				
				REM :: Check to make sure it's working
				REM echo %CUR_DATE% %TIME%         Verifying functionality on primary server...>> %LOGPATH%\%LOGFILE%.log
				REM echo %CUR_DATE% %TIME%         Verifying functionality on primary server...
				REM sc \\%REMOTE_SERVER% query Dhcpserver | find "RUNNING"
				REM if not %ERRORLEVEL%==0 echo %CUR_DATE% %TIME% FAILURE DHCP server on %REMOTE_SERVER% is not running. You should investigate this manually.>> %LOGPATH%\%LOGFILE%.log
				REM if %ERRORLEVEL%==0 echo %CUR_DATE% %TIME% SUCCESS DHCP server on %REMOTE_SERVER% is up and running. Recovery complete.>> %LOGPATH%\%LOGFILE%.log

				:: Clean up
				rmdir /S /Q %TEMP%\DHCP-RECOVERY
				
				:: Done.
				echo %CUR_DATE% %TIME%         Exiting.>> %LOGPATH%\%LOGFILE%.log
				echo %CUR_DATE% %TIME%         Exiting.
				goto EOF
				)
	)
ENDLOCAL

:: If the host responds to pings but the DHCP service isn't running, this executes
echo %CUR_DATE% %TIME% FAILURE %REMOTE_SERVER% is responding to pings, but DHCP isn't responding (yet?). Will try again in %FAILOVER_RECHECK_DELAY% seconds.>> %LOGPATH%\%LOGFILE%.log
echo %CUR_DATE% %TIME% FAILURE %REMOTE_SERVER% is responding to pings, but DHCP isn't responding (yet?). Will try again in %FAILOVER_RECHECK_DELAY% seconds.
ver >NUL
goto failover_loop

ENDLOCAL
echo.>> %LOGPATH%\%LOGFILE%.log
:EOF
