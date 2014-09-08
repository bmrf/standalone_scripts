:: Purpose:       1. Nuke ALL versions of JavaFX and the Java Runtime, series 3 through 8, x86 and x64
::                2. Leaves Java Development Kit installations intact
::                3. Reinstalls the latest JRE (if you want it to)
::                4. Puts the lotion on its skin.
:: Requirements:  local administrative rights
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
::                Latest version is always here: http://www.reddit.com/r/usefulscripts/comments/1i6kyy/batch_java_runtime_nuker_purge_all_versions_of/
::                additional thanks to: 
::                 - reddit.com/user/sdjason         : JRE reinstall functionality; selective process killing; et al
::                 - reddit.com/user/MrYiff          : bug fix related to OS_VERSION variable
::                 - reddit.com/user/cannibalkitteh  : additional registry & file cleaning locations
::                 - forums.oracle.com/people/mattmn : a lot of stuff from his Java removal script
:: History:       1.6.5 / MISC:         Minor header change; Variables section now before Prep and Checks
::                1.6.4 * IMPROVEMENT:  Overhauled Date/Time conversion so we can handle all versions of Windows using any local date-time format
::                1.6.3 * BUG FIX:      Updated some outdated references to JRE v3-7 (updated to reflect addition of JRE8)
::                1.6.2 * IMPROVEMENT:  Added /salvagerepository and /resyncperf flags to WMIC winmgmt.exe repair section
::                1.6.1 * IMPROVEMENT:  Added deletion of Java Update directory in C:\Program Files\Common Files\Java\Java Update\
::                1.6.0 + FEATURE:      Added code blocks to catch and remove JRE 8 x86 and x64
::                      * IMPROVEMENT:  Added Opera browser to list of running exe's to look for prior to performing any action
::                      * IMPROVEMENT:  Added 2>NUL flags to suppress error output when running the usually-unnecessary official Oracle uninstallers
::                      / MISC:         Changed example JRE reinstaller variable flags to match up with JRE8-series flags
::                1.5.1 * IMPROVEMENT:  Reworked CUR_DATE variable to handle more than one Date/Time format
::                                      Can now handle ISO standard dates (yyyy-mm-dd) and Windows default dates (e.g. "Fri 01/24/2014")
::                1.5.0 + FEATURE:      Added ability to choose whether or not to kill running Java processes before executing,
::                                      along with a variable to specify an exit code to use                   (sdjason)
::                      + FEATURE:      Added ability to selectively reinstall x64 and x86 versions of the JRE (sdjason)
::                      * IMPROVEMENT:  Converted JRE 3 uninstaller section to a FOR loop
::                      * IMPROVEMENT:  Converted many commands into FOR loops with test cases to check if they should run or not (sdjason)
::                      * IMPROVEMENT:  File deletion commands now aren't run if their target doesn't exist.
::                                      This should reduce unecessary errors in the console and log.     (sdjason)
::                      / FIX:			Fixed incorrect search string in XP version of Java installer cache purge
::                1.4.1 / FIX:          Re-enabled "echo off" statement at beginning of script
::                      / FIX:          Fixed empty OS_VERSION variable on Vista/7/2008/8/2012           (MrYiff)
::                1.4   + FEATURE:      Added check to see if we're on Windows XP, to run different code for certain sections
::                      + FEATURE:      Added comprehensive WMI repair if it's broken
::                      + FEATURE:      Added XP versions of a lot of the code
::                1.3   + FEATURE:      Added variables to reinstall Java after cleanup (off by default) (sdjason)
::                      + FILE CLEANUP: Added C:\Users*\AppData\LocalLow\Sun\Java\jre*                   (cannibalkitteh)
::                      + FILE CLEANUP: Added C:\Users*\AppData\LocalLow\Sun\Java\AU                     (cannibalkitteh)
::                1.2   + COMMENTS:     Improved a lot of commenting
::                      + UNINSTALLER:  Added WMIC wildcard-matching to catch all JRE GUIDs, including future revisions
::                      + FILE CLEANUP: Major overhaul to section                                        (mattm)
::                      + REGISTRY:     Added additional locations:                                      (cannibalkitteh)
::                        - HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
::                        - HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
::                      + PREP:         Added Chrome to the list of browsers to kill before starting
::                      + PREP:         Added /T flag (terminate child processes) to all browser and Java kill lines
::                      * LOGGING:      Minor improvements
::                1.1   + Overhaul of functionality and logging
::                1.0     Initial write
SETLOCAL


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
set LOGFILE=%COMPUTERNAME%_java_runtime_removal.log

:: Force-close Java processes? Recommend leaving this set to 'yes' unless you
:: specifically want to abort the script if the target machine is currently using Java.
:: If you change this to 'no', the script will exit with an error code if it finds any running processes.
set FORCE_CLOSE_PROCESSES=yes
:: Exit code to use when FORCE_CLOSE_PROCESSES is "no" and a running Java process is detected
set FORCE_CLOSE_PROCESSES_EXIT_CODE=1618

:: Java re-install. Do you want to reinstall Java afterwards?
:: Change either of these to 'yes' if you want to reinstall Java after cleanup.
:: If you do, make sure to set the location, file names and arguments below!
set REINSTALL_JAVA_x64=no
set REINSTALL_JAVA_x86=no

:: The JRE installer must be in a place the script can find it (e.g. network path, same directory, etc)
:: JRE 64-bit reinstaller
set JAVA_LOCATION_x64=%~dp0
set JAVA_BINARY_x64=jre-8u20-windows-x64.exe
set JAVA_ARGUMENTS_x64=/s

:: JRE 32-bit reinstaller
set JAVA_LOCATION_x86=%~dp0
set JAVA_BINARY_x86=jre-8u20-windows-x86.exe
set JAVA_ARGUMENTS_x86=/s



:: =============================================================================================== ::
:: ======  Think of everything below this line like a feral badger: Look, but Do Not Touch  ====== ::
:: =============================================================================================== ::



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
set SCRIPT_VERSION=1.6.5
set SCRIPT_UPDATED=2014-09-08
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title Java Runtime Nuker v%SCRIPT_VERSION% (%SCRIPT_UPDATED%)


:: Check if we're on XP. This affects some commands later, because XP uses slightly
:: different binaries for reg.exe and various other Windows utilities
set OS_VERSION=OTHER
ver | find /i "XP" >NUL
IF %ERRORLEVEL%==0 set OS_VERSION=XP

:: Force WMIC location in case the system PATH is messed up
set WMIC=%WINDIR%\system32\wbem\wmic.exe

:: Create the log directory if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%
if exist "%LOGPATH%\%LOGFILE%" del "%LOGPATH%\%LOGFILE%"


:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
echo.
echo  JAVA RUNTIME NUKER
echo  v%SCRIPT_VERSION%, updated %SCRIPT_UPDATED%
if %OS_VERSION%==XP echo. && echo  ! Windows XP detected, using alternate command set to compensate.
echo.
echo %CUR_DATE% %TIME%   Beginning removal of Java Runtime Environments (series 3-8, x86 and x64) and JavaFX...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Beginning removal of Java Runtime Environments (series 3-8, x86 and x64) and JavaFX...

:: Do a quick check to make sure WMI is working, and if not, repair it
wmic timezone >NUL
if not %ERRORLEVEL%==0 (
    echo %CUR_DATE% %TIME% ! WMI appears to be broken. Running WMI repair. This might take a minute, please be patient...>> "%LOGPATH%\%LOGFILE%"
    echo %CUR_DATE% %TIME% ! WMI appears to be broken. Running WMI repair. This might take a minute, please be patient...
    net stop winmgmt
    pushd %WINDIR%\system32\wbem
    for %%i in (*.dll) do RegSvr32 -s %%i
    :: Kill this random window that pops up
    tskill wbemtest /a 2>NUL
    scrcons.exe /RegServer
    unsecapp.exe /RegServer
    start "" wbemtest.exe /RegServer
    tskill wbemtest /a 2>NUL
    tskill wbemtest /a 2>NUL
    :: winmgmt.exe /resetrepository       -- optional; forces full rebuild instead of a repair like the line below this
	winmgmt.exe /salvagerepository /resyncperf
    wmiadap.exe /RegServer
    wmiapsrv.exe /RegServer
    wmiprvse.exe /RegServer
    net start winmgmt
    popd
)


:::::::::::::::::::::::::::
:: FORCE-CLOSE PROCESSES :: -- Do we want to kill Java before running? If so, this is where it happens
:::::::::::::::::::::::::::
if %FORCE_CLOSE_PROCESSES%==yes (
	:: Kill all browsers and running Java instances
	echo %CUR_DATE% %TIME%   Looking for and closing all running browsers and Java instances...>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   Looking for and closing all running browsers and Java instances...
	if %OS_VERSION%==XP (
		:: XP version of the task killer
		:: this loop contains the processes we should kill
		echo.
		FOR %%i IN (java,javaw,javaws,jqs,jusched,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
			echo Searching for %%i.exe...
			tskill /a /v %%i >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
		echo.
	) else (
		:: 7/8/2008/2008R2/2012/etc version of the task killer
		:: this loop contains the processes we should kill
		echo.
		FOR %%i IN (java,javaw,javaws,jqs,jusched,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
			echo Searching for %%i.exe...
			taskkill /f /im %%i.exe /T >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
		echo.
	)
)

:: If we DON'T want to force-close Java, then check for possible running Java processes and abort the script if we find any
if %FORCE_CLOSE_PROCESSES%==no (
	echo %CUR_DATE% %TIME%   Variable FORCE_CLOSE_PROCESSES is set to '%FORCE_CLOSE_PROCESSES%'. Checking for running processes before execution.>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   Variable FORCE_CLOSE_PROCESSES is set to '%FORCE_CLOSE_PROCESSES%'. Checking for running processes before execution.

	:: Don't ask...
	:: Okay so basically we loop through this list of processes, and for each one we dump the result of the search in the '%%a' variable. 
	:: Then we check that variable, and if it's not null (e.g. FIND.exe found something) we abort the script, returning the exit code
	:: specified at the beginning of the script. Normally you'd use ERRORLEVEL for this, but because it is very flaky (it doesn't 
	:: always get set, even when it should) we instead resort to using this method of dumping the results in a variable and checking it.
	FOR %%i IN (java,javaw,javaws,jqs,jusched,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
		echo %CUR_DATE% %TIME%   Searching for %%i.exe...
		for /f "delims=" %%a in ('tasklist ^| find /i "%%i"') do (
			if not [%%a]==[] (
				echo %CUR_DATE% %TIME% ! ERROR: Process '%%i' is currently running, aborting.>> "%LOGPATH%\%LOGFILE%"
				echo %CUR_DATE% %TIME% ! ERROR: Process '%%i' is currently running, aborting.
				exit /b %FORCE_CLOSE_PROCESSES_EXIT_CODE%
			)
		)
	)
	:: If we made it this far, we didn't find anything, so we can go ahead
	echo %CUR_DATE% %TIME%   All clear, no running processes found. Going ahead with removal...>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   All clear, no running processes found. Going ahead with removal...
)


:::::::::::::::::::::::::
:: UNINSTALLER SECTION :: -- Basically here we just brute-force every "normal" method for
:::::::::::::::::::::::::    removing Java, and then resort to more painstaking methods later
echo %CUR_DATE% %TIME%   Targeting individual JRE versions...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Targeting individual JRE versions...
echo %CUR_DATE% %TIME%   This might take a few minutes. Don't close this window.

:: Okay, so all JRE runtimes (series 4-8) use product GUIDs, with certain numbers that increment with each new update (e.g. Update 25)
:: This makes it easy to catch ALL of them through liberal use of WMI wildcards ("_" is single character, "%" is any number of characters)
:: Additionally, JRE 6 introduced 64-bit runtimes, so in addition to the two-digit Update XX revision number, we also check for the architecture 
:: type, which always equals '32' or '64'. The first wildcard is the architecture, the second is the revision/update number.

:: JRE 8
echo %CUR_DATE% %TIME%   JRE 8...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 8...
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F8__180__FF}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"

:: JRE 7
echo %CUR_DATE% %TIME%   JRE 7...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 7...
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F8__170__FF}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"

:: JRE 6
echo %CUR_DATE% %TIME%   JRE 6...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 6...
:: 1st line is for updates 23-xx, after 64-bit runtimes were introduced.
:: 2nd line is for updates 1-22, before Oracle released 64-bit JRE 6 runtimes
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F8__160__FF}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "IdentifyingNumber like '{3248F0A8-6813-11D6-A77B-00B0D0160__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 5
echo %CUR_DATE% %TIME%   JRE 5...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 5...
%WMIC% product where "IdentifyingNumber like '{3248F0A8-6813-11D6-A77B-00B0D0150__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 4
echo %CUR_DATE% %TIME%   JRE 4...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 4...
%WMIC% product where "IdentifyingNumber like '{7148F0A8-6813-11D6-A77B-00B0D0142__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 3 (AKA "Java 2 Runtime Environment Standard Edition" v1.3.1_00-25)
echo %CUR_DATE% %TIME%   JRE 3 (AKA Java 2 Runtime v1.3.xx)...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JRE 3 (AKA Java 2 Runtime v1.3.xx)...
:: This version is so old we have to resort to different methods of removing it
:: Loop through each sub-version
FOR %%i IN (01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25) DO (
	%SystemRoot%\IsUninst.exe -f"%ProgramFiles%\JavaSoft\JRE\1.3.1_%%i\Uninst.isu" -a 2>NUL
	%SystemRoot%\IsUninst.exe -f"%ProgramFiles(x86)%\JavaSoft\JRE\1.3.1_%%i\Uninst.isu" -a 2>NUL
)
:: This one wouldn't fit in the loop above
%SystemRoot%\IsUninst.exe -f"%ProgramFiles%\JavaSoft\JRE\1.3\Uninst.isu" -a 2>NUL
%SystemRoot%\IsUninst.exe -f"%ProgramFiles(x86)%\JavaSoft\JRE\1.3\Uninst.isu" -a 2>NUL

:: Wildcard uninstallers
echo %CUR_DATE% %TIME%   Specific targeting done. Now running WMIC wildcard catchall uninstallation...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Specific targeting done. Now running WMIC wildcard catchall uninstallation...
%WMIC% product where "name like '%%J2SE Runtime%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'Java%%Runtime%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'JavaFX%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Done.>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Done.


::::::::::::::::::::::
:: REGISTRY CLEANUP :: -- This is where it gets hairy. Don't read ahead if you have a weak constitution.
::::::::::::::::::::::
:: If we're on XP we skip this entire block due to differences in the reg.exe binary
if '%OS_VERSION%'=='XP' (
    echo %CUR_DATE% %TIME% ! Registry cleanup doesn't work on Windows XP. Skipping...>> "%LOGPATH%\%LOGFILE%"
    echo %CUR_DATE% %TIME% ! Registry cleanup doesn't work on Windows XP. Skipping...
	goto file_cleanup
	)

echo %CUR_DATE% %TIME%   Commencing registry cleanup...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Commencing registry cleanup...
echo %CUR_DATE% %TIME%   Searching for residual registry keys...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Searching for residual registry keys...

:: Search MSIExec installer class hive for keys
echo %CUR_DATE% %TIME%   Looking in HKLM\software\classes\installer\products...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Looking in HKLM\software\classes\installer\products...
reg query HKLM\software\classes\installer\products /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: Search the Add/Remove programs list (this helps with broken Java installations)
echo %CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall...
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: Search the Add/Remove programs list, x86/Wow64 node (this helps with broken Java installations)
echo %CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall...
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: List the leftover registry keys
echo %CUR_DATE% %TIME%   Found these keys...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Found these keys...
echo.>> "%LOGPATH%\%LOGFILE%"
echo.
type %TEMP%\java_purge_registry_keys.txt>> "%LOGPATH%\%LOGFILE%"
type %TEMP%\java_purge_registry_keys.txt
echo.>> "%LOGPATH%\%LOGFILE%"
echo.

:: Backup the various registry keys that will get deleted (if they exist)
:: We do this mainly because we're using wildcards, so we want a method to roll back if we accidentally nuke the wrong thing
echo %CUR_DATE% %TIME%   Backing up keys...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Backing up keys...
if exist "%TEMP%\java_purge_registry_backup" rmdir /s /q "%TEMP%\java_purge_registry_backup" 2>NUL
mkdir %TEMP%\java_purge_registry_backup >NUL
:: This line walks through the file we generated and dumps each key to a file
for /f "tokens=* delims= " %%a in (%TEMP%\java_purge_registry_keys.txt) do (reg query %%a) >> %TEMP%\java_purge_registry_backup\java_reg_keys_1.bak

echo.
echo %CUR_DATE% %TIME%   Keys backed up to %TEMP%\java_purge_registry_backup\ >> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Keys backed up to %TEMP%\java_purge_registry_backup\
echo %CUR_DATE% %TIME%   This directory will be deleted at next reboot, so get it now if you need it! >> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   This directory will be deleted at next reboot, so get it now if you need it!

:: Purge the keys
echo %CUR_DATE% %TIME%   Purging keys...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Purging keys...
echo.
:: This line walks through the file we generated and deletes each key listed
for /f "tokens=* delims= " %%a in (%TEMP%\java_purge_registry_keys.txt) do reg delete %%a /va /f >> "%LOGPATH%\%LOGFILE%" 2>NUL

:: These lines delete some specific Java locations
:: These keys AREN'T backed up because these are specific, known Java keys, whereas above we were nuking
:: keys based on wildcards, so those need backups in case we nuke something we didn't want to.

:: Delete keys for 32-bit Java installations on a 64-bit copy of Windows
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft\Auto Update" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft\Java Plug-in" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft\Java Runtime Environment" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft\Java Update" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft\Java Web Start" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JreMetrics" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL

:: Delete keys for for 32-bit and 64-bit Java installations on matching Windows architecture
reg delete "HKLM\SOFTWARE\JavaSoft\Auto Update" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JavaSoft\Java Plug-in" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JavaSoft\Java Runtime Environment" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JavaSoft\Java Update" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JavaSoft\Java Web Start" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JreMetrics" /va /f>> "%LOGPATH%\%LOGFILE%" 2>NUL

echo.
echo %CUR_DATE% %TIME%   Keys purged.>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Keys purged.
echo %CUR_DATE% %TIME%   Registry cleanup done.>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Registry cleanup done.
echo.


::::::::::::::::::::::::::::::::
:: FILE AND DIRECTORY CLEANUP ::
::::::::::::::::::::::::::::::::
:file_cleanup
echo %CUR_DATE% %TIME%   Commencing file and directory cleanup...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Commencing file and directory cleanup...

:: Kill the accursed Java tasks in Task Scheduler
echo %CUR_DATE% %TIME%   Removing Java tasks from the Windows Task Scheduler...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Removing Java tasks from the Windows Task Scheduler...
if exist %WINDIR%\tasks\Java*.job del /F /Q %WINDIR%\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\System32\tasks\Java*.job del /F /Q %WINDIR%\System32\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\SysWOW64\tasks\Java*.job del /F /Q %WINDIR%\SysWOW64\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
echo.

:: Kill the accursed Java Quickstarter service
sc query JavaQuickStarterService >NUL
if not %ERRORLEVEL%==1060 (
	echo %CUR_DATE% %TIME%   De-registering and removing Java Quickstarter service...>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   De-registering and removing Java Quickstarter service...
	net stop JavaQuickStarterService >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete JavaQuickStarterService >> "%LOGPATH%\%LOGFILE%" 2>NUL
)

:: Kill the accursed Java Update Scheduler service
sc query jusched >NUL
if not %ERRORLEVEL%==1060 (
	echo %CUR_DATE% %TIME%   De-registering and removing Java Update Scheduler service...>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   De-registering and removing Java Update Scheduler service...
	net stop jusched >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete jusched >> "%LOGPATH%\%LOGFILE%" 2>NUL
)

:: This is the Oracle method of disabling the Java services. 99% of the time these commands aren't required and will just throw an error message.
if exist "%ProgramFiles(x86)%\Java\jre6\bin\jqs.exe" "%ProgramFiles(x86)%\Java\jre6\bin\jqs.exe" -disable>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles(x86)%\Java\jre7\bin\jqs.exe" "%ProgramFiles(x86)%\Java\jre7\bin\jqs.exe" -disable>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles%\Java\jre6\bin\jqs.exe" "%ProgramFiles%\Java\jre6\bin\jqs.exe" -disable>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles%\Java\jre7\bin\jqs.exe" "%ProgramFiles%\Java\jre7\bin\jqs.exe" -disable>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles(x86)%\Java\jre6\bin\jqs.exe" "%ProgramFiles(x86)%\Java\jre6\bin\jqs.exe" -unregister>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles(x86)%\Java\jre7\bin\jqs.exe" "%ProgramFiles(x86)%\Java\jre7\bin\jqs.exe" -unregister>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles%\Java\jre6\bin\jqs.exe" "%ProgramFiles%\Java\jre6\bin\jqs.exe" -unregister>> "%LOGPATH%\%LOGFILE%" 2>NUL
if exist "%ProgramFiles%\Java\jre7\bin\jqs.exe" "%ProgramFiles%\Java\jre7\bin\jqs.exe" -unregister>> "%LOGPATH%\%LOGFILE%" 2>NUL
msiexec.exe /x {4A03706F-666A-4037-7777-5F2748764D10} /qn /norestart

:: Nuke 32-bit Java installation directories
if exist "%ProgramFiles(x86)%" (
	echo %CUR_DATE% %TIME%   Removing "%ProgramFiles(x86)%\Java\jre*" directories...>> "%LOGPATH%\%LOGFILE%"
	echo %CUR_DATE% %TIME%   Removing "%ProgramFiles(x86)%\Java\jre*" directories...
	for /D /R "%ProgramFiles(x86)%\Java\" %%x in (j2re*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
	for /D /R "%ProgramFiles(x86)%\Java\" %%x in (jre*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
	if exist "%ProgramFiles(x86)%\JavaSoft\JRE" rmdir /S /Q "%ProgramFiles(x86)%\JavaSoft\JRE" >> "%LOGPATH%\%LOGFILE%"
	)

:: Nuke 64-bit Java installation directories
echo %CUR_DATE% %TIME%   Removing "%ProgramFiles%\Java\jre*" directories...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Removing "%ProgramFiles%\Java\jre*" directories...
for /D /R "%ProgramFiles%\Java\" %%x in (j2re*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
for /D /R "%ProgramFiles%\Java\" %%x in (jre*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
if exist "%ProgramFiles%\JavaSoft\JRE" rmdir /S /Q "%ProgramFiles%\JavaSoft\JRE" >> "%LOGPATH%\%LOGFILE%"

:: Nuke the Java Update directory (normally contains jaureg.exe, jucheck.exe, and jusched.exe)
rmdir /S /Q "%CommonProgramFiles%\Java\Java Update\">> "%LOGPATH%\%LOGFILE%" 2>NUL
rmdir /S /Q "%CommonProgramFiles(x86)%\Java\Java Update\">> "%LOGPATH%\%LOGFILE%" 2>NUL

:: Nuke Java installer cache ( thanks to cannibalkitteh )
echo %CUR_DATE% %TIME%   Purging Java installer cache...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Purging Java installer cache...
:: XP VERSION
if %OS_VERSION%==XP (
    :: Get list of users, put it in a file, then use it to iterate through each users profile, deleting the AU folder
    dir "%SystemDrive%\Documents and Settings\" /B > %TEMP%\userlist.txt
    for /f "tokens=* delims= " %%a in (%TEMP%\userlist.txt) do (
		if exist "%SystemDrive%\Documents and Settings\%%a\AppData\LocalLow\Sun\Java\AU" rmdir /S /Q "%SystemDrive%\Documents and Settings\%%a\AppData\LocalLow\Sun\Java\AU" 2>NUL
	)
    for /D /R "%SystemDrive%\Documents and Settings\" %%x in (jre*) do if exist "%%x" rmdir /S /Q "%%x" 2>NUL
) else (
	:: ALL OTHER VERSIONS OF WINDOWS
    :: Get list of users, put it in a file, then use it to iterate through each users profile, deleting the AU folder
    dir %SystemDrive%\Users /B > %TEMP%\userlist.txt
    for /f "tokens=* delims= " %%a in (%TEMP%\userlist.txt) do rmdir /S /Q "%SystemDrive%\Users\%%a\AppData\LocalLow\Sun\Java\AU" 2>NUL
    :: Get the other JRE directories
    for /D /R "%SystemDrive%\Users" %%x in (jre*) do rmdir /S /Q "%%x" 2>NUL
    )

:: Miscellaneous stuff, sometimes left over by the installers
echo %CUR_DATE% %TIME%   Searching for and purging other Java Runtime-related directories...>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Searching for and purging other Java Runtime-related directories...
del /F /Q %SystemDrive%\1033.mst >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /S /Q "%SystemDrive%\J2SE Runtime Environment*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
echo.

echo %CUR_DATE% %TIME%   File and directory cleanup done.>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   File and directory cleanup done.
echo. >> "%LOGPATH%\%LOGFILE%"
echo.


:::::::::::::::::::::::::
:: JAVA REINSTALLATION :: -- If we wanted to reinstall the JRE after cleanup, this is where it happens
:::::::::::::::::::::::::
:: x64
if %REINSTALL_JAVA_x64%==yes (
    echo %CUR_DATE% %TIME% ! Variable "REINSTALL_JAVA_x64" was set to 'yes'. Now installing %JAVA_BINARY_x64%...>> "%LOGPATH%\%LOGFILE%"
    echo %CUR_DATE% %TIME% ! Variable "REINSTALL_JAVA_x64" was set to 'yes'. Now installing %JAVA_BINARY_x64%...
    "%JAVA_LOCATION_x64%\%JAVA_BINARY_x64%" %JAVA_ARGUMENTS_x64%
    java -version
    echo Done.>> "%LOGPATH%\%LOGFILE%"
    )

:: x86
if %REINSTALL_JAVA_x86%==yes (
    echo %CUR_DATE% %TIME% ! Variable "REINSTALL_JAVA_x86" was set to 'yes'. Now installing %JAVA_BINARY_x86%...>> "%LOGPATH%\%LOGFILE%"
    echo %CUR_DATE% %TIME% ! Variable "REINSTALL_JAVA_x86" was set to 'yes'. Now installing %JAVA_BINARY_x86%...
    "%JAVA_LOCATION_x86%\%JAVA_BINARY_x86%" %JAVA_ARGUMENTS_x86%
    java -version
    echo Done.>> "%LOGPATH%\%LOGFILE%"
    )

:: Done.
echo %CUR_DATE% %TIME%   Registry hive backups: %TEMP%\java_purge_registry_backup\>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Registry hive backups: %TEMP%\java_purge_registry_backup\
echo %CUR_DATE% %TIME%   Log file: "%LOGPATH%\%LOGFILE%">> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   Log file: "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JAVA NUKER COMPLETE. Recommend rebooting and washing your hands.>> "%LOGPATH%\%LOGFILE%"
echo %CUR_DATE% %TIME%   JAVA NUKER COMPLETE. Recommend rebooting and washing your hands.

:: Return exit code to SCCM/PDQ Deploy/PSexec/etc
exit /B %EXIT_CODE%
