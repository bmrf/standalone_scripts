:: Purpose:       1. Nuke ALL versions of JavaFX and the Java Runtime, series 3 through 11, x86 and x64
::                2. Leaves Java Development Kit installations intact
::                3. Reinstalls the latest JRE (if you want it to)
::                4. Puts the lotion on its skin.
:: Requirements:  local administrative rights
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
::                Latest version is always here: http://www.reddit.com/r/usefulscripts/comments/2hzt5c/batch_java_runtime_nuker_purge_all_versions_of/
::                additional thanks to: 
::                 - /u/sdjason         : JRE reinstall functionality; selective process killing; et al
::                 - /u/MrYiff          : bug fix related to OS_VERSION variable
::                 - /u/cannibalkitteh  : additional registry & file cleaning locations
::                 - forums.oracle.com/people/mattmn : a lot of stuff from his Java removal script
:: Version:       1.8.7 + ADDITION:    Add commands to remove JRE 11
::                      - REMOVAL:     Remove "re-install JRE after removal" functionality. It was buggy, and it makes more sense to have re-installation handled by a separate script or task
::                1.8.6 + ADDITION:    Add GUID for JRE 10.0.2
::                1.8.5 + ADDITION:    Add GUID for JRE 9.0.4
::                1.8.4 + ADDITION:    Add support for removal of JRE series 9
::                1.8.3 * IMPROVEMENT: Add deletion of orphaned Java binaries from the Windows system folders. Thanks to /u/Mikkehy
::                1.8.2 * IMPROVEMENT: Expand JRE8 mask to catch versions over 99 (3-digit identifier vs. 2). Thanks to /u/flash44007
::                1.8.1 ! BUG FIX:     Fix crash error on unescaped "*" character
::                1.8.0 ! BUG FIX:     Fix uncommon failure where JRE uninstallers fail because they can't find certain files. Thanks to /u/GoogleDrummer
::                      * IMPROVEMENT: Import logging function used in Tron and convert all double "echo" statements to log calls
::                      * COMMENTS:    Minor comment cleanup
::                1.7.2 * IMPROVEMENT: Add section to remove leftover symlinks in PATH folder to JRE exes. Thanks to /u/turnerf
::                1.7.1 * IMPROVEMENT: Remove all /va flags. This had the effect of deleting key values but leaving keys intact, which could break re-installations that thought Java was still installed when in fact it was not. Big thanks to /u/RazorZero
::                      * IMPROVEMENT: Reduce 10 JavaSoft registry key deletion commands to 2 by deleting entire JavaSoft key instead of individual subkeys. Thanks to /u/RazorZero
::                1.7.0 * IMPROVEMENT: Target additional JRE8 GUID {26A24AE4-039D-4CA4-87B4-2F8__180__F0}. Thanks to /u/Caboose816
::                1.6.9 * IMPROVEMENT: Add process "jp2launcher" to target for killing (or checking) before running. Thanks to /u/citricacidx
::                1.6.8 ! BUG FIX:     Expand WMI uninstaller mask to catch MSI code for JRE7u67. Thanks to /u/placebonocebo
::                1.6.7 * IMPROVEMENT: Delete %ProgramData%\Microsoft\Windows\Start Menu\Programs\Java\ if it exists. Thanks to /u/placebonocebo
::                <outdated changelog comments removed>
::                1.0.0   Initial write
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





:: =============================================================================================== ::
:: ======  Think of everything below this line like a feral badger: Look, but Do Not Touch  ====== ::
:: =============================================================================================== ::




:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off && cls
set SCRIPT_VERSION=1.8.7
set SCRIPT_UPDATED=2019-10-16
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
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
if %OS_VERSION%==XP echo. && call :log "%CUR_DATE% %TIME%  ! Windows XP detected, using alternate command set to compensate."
echo.
call :log "%CUR_DATE% %TIME%   Beginning removal of Java Runtime Environments (series 3-8, x86 and x64) and JavaFX..."

:: Do a quick check to make sure WMI is working, and if not, repair it
%WMIC% timezone >NUL
if not %ERRORLEVEL%==0 (
    call :log "%CUR_DATE% %TIME% ! WMI appears to be broken. Running WMI repair. This might take a minute, please be patient..."
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
	call :log "%CUR_DATE% %TIME%   Looking for and closing all running browsers and Java instances..."
	if %OS_VERSION%==XP (
		:: XP version of the task killer
		:: this loop contains the processes we should kill
		echo.
		FOR %%i IN (java,javaw,javaws,jqs,jusched,jp2launcher,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
			echo Searching for %%i.exe...
			%WinDir%\system32\tskill.exe /a /v %%i >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
		echo.
	) else (
		:: 7/8/2008/2008R2/2012/etc version of the task killer
		:: this loop contains the processes we should kill
		echo.
		FOR %%i IN (java,javaw,javaws,jqs,jusched,jp2launcher,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
			echo Searching for %%i.exe...
			%WinDir%\system32\taskkill.exe /f /im %%i.exe /T >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
		echo.
	)
)

:: If we DON'T want to force-close Java, then check for possible running Java processes and abort the script if we find any
if %FORCE_CLOSE_PROCESSES%==no (
	call :log "%CUR_DATE% %TIME%   Variable FORCE_CLOSE_PROCESSES is set to '%FORCE_CLOSE_PROCESSES%'. Checking for running processes before execution."

	:: Don't ask...
	:: Okay so basically we loop through this list of processes, and for each one we dump the result of the search in the '%%a' variable. 
	:: Then we check that variable, and if it's not null (e.g. FIND.exe found something) we abort the script, returning the exit code
	:: specified at the beginning of the script. Normally you'd use ERRORLEVEL for this, but because it is very flaky (it doesn't 
	:: always get set, even when it should) we instead resort to using this method of dumping the results in a variable and checking it.
	FOR %%i IN (java,javaw,javaws,jqs,jusched,jp2launcher,iexplore,iexplorer,firefox,chrome,palemoon,opera) DO (
		call :log "%CUR_DATE% %TIME%   Searching for %%i.exe...
		for /f "delims=" %%a in ('tasklist ^| find /i "%%i"') do (
			if not [%%a]==[] (
				call :log "%CUR_DATE% %TIME% ! ERROR: Process '%%i' is currently running, aborting."
				exit /b %FORCE_CLOSE_PROCESSES_EXIT_CODE%
			)
		)
	)
	:: If we made it this far, we didn't find anything, so we can go ahead
	call :log "%CUR_DATE% %TIME%   All clear, no running processes found. Going ahead with removal..."
)




::::::::::::::::
:: PRE-DELETE ::
::::::::::::::::
:: Sometimes the JRE uninstallers will fail if they can't find some files; deleting the reg keys seems to resolve it
:: Thanks to /u/GoogleDrummer for this section
regedit /e "%TEMP%\dump.txt" HKEY_CLASSES_ROOT\Installer\Products
find "HKEY_CLASSES_ROOT\Installer\Products\4EA42A62" "%TEMP%\dump.txt" > "%TEMP%\keys_to_delete.txt"
for /f "delims=[]" %%i in (%TEMP%\keys_to_delete.txt) do reg delete "%%i" /f >> "%LOGPATH%\%LOGFILE%" 2>NUL
del "%TEMP%\dump.txt" >> "%LOGPATH%\%LOGFILE%" 2>NUL
del "%TEMP%\keys_to_delete.txt" >> "%LOGPATH%\%LOGFILE%" 2>NUL



:::::::::::::::::::::::::
:: UNINSTALLER SECTION :: -- Here we brute-force every "normal" method for removing
:::::::::::::::::::::::::    Java, then resort to more painstaking methods later
call :log "%CUR_DATE% %TIME%   Targeting individual JRE versions..."
call :log "%CUR_DATE% %TIME%   This might take a few minutes. Don't close this window."

:: EXPOSITION DUMP: OK, so all JRE runtimes (series 4-9) use certain GUIDs that increment with each new update (e.g. Update 66)
:: This makes it easy to catch them through liberal use of WMI wildcards ("_" is single character, "%" is any number of characters)
:: Additionally, JRE 6 introduced 64-bit runtimes, so in addition to the two-digit Update XX revision number, we also check for the architecture
:: type, which always equals '32' or '64'. The first wildcard is the architecture, the second is the revision/update number.
:: Beginning with JRE versions over 99 (JRE8 was first major version to have subversions go over 99), the GUID string "2F8__", which identified architecture, switched to "2F__", presumably to make room for the new 3rd digit in the version identifying section. You can see this in the JRE8 portion below.

:: JRE 11
call :log "%CUR_DATE% %TIME%   JRE 11..."
%WMIC% product where "name like 'Java 11%%'" uninstall /nointeractive

:: JRE 10
call :log "%CUR_DATE% %TIME%   JRE 10..."
%WMIC% product where "IdentifyingNumber like ''" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "IdentifyingNumber like '{EECB2736-D013-5AC5-9917-7656712F6931}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'Java 10%%'" uninstall /nointeractive

:: JRE 9
call :log "%CUR_DATE% %TIME%   JRE 9..."
:: Wildcards aren't used here because Oracle is stupid and generates random GUIDs per release now instead of doing the old wildcard system
:: Script will be updated when the first Update to series 9 is released by Oracle
%WMIC% product where "IdentifyingNumber like '{DA69628A-2608-5BA9-8749-1EE90CB29D95}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "IdentifyingNumber like '{2590B9D6-4310-52BC-808E-1A585861A836}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "IdentifyingNumber like '{885A3911-0760-5252-92C2-001B92997DEA}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'Java 9%%'" uninstall /nointeractive

:: JRE 8
call :log "%CUR_DATE% %TIME%   JRE 8..."
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F8__180__F_}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
:: This line catches any version above 99 since it's three characters instead of two. Oracle also dropped the "8" from
:: the last part of the GUID, so instead of "2F8__" it's now "2F__", presumably to make room for the 3rd digit on the right
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F__180___F_}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"

:: JRE 7
call :log "%CUR_DATE% %TIME%   JRE 7..."
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F___170__FF}'" call uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"

:: JRE 6
call :log "%CUR_DATE% %TIME%   JRE 6..."
:: 1st line is for updates 23-xx, after Oracle introduced 64-bit runtimes
:: 2nd line is for updates 1-22, before 64-bit JRE 6 runtimes existed
%WMIC% product where "IdentifyingNumber like '{26A24AE4-039D-4CA4-87B4-2F8__160__FF}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "IdentifyingNumber like '{3248F0A8-6813-11D6-A77B-00B0D0160__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 5
call :log "%CUR_DATE% %TIME%   JRE 5..."
%WMIC% product where "IdentifyingNumber like '{3248F0A8-6813-11D6-A77B-00B0D0150__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 4
call :log "%CUR_DATE% %TIME%   JRE 4..."
%WMIC% product where "IdentifyingNumber like '{7148F0A8-6813-11D6-A77B-00B0D0142__0}'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: JRE 3 (AKA "Java 2 Runtime Environment Standard Edition" v1.3.1_00-25)
call :log "%CUR_DATE% %TIME%   JRE 3 (AKA Java 2 Runtime v1.3.xx)..."
:: This version is so old we have to resort to different methods of removing it
:: Loop through each sub-version
FOR %%i IN (01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25) DO (
	%SystemRoot%\IsUninst.exe -f"%ProgramFiles%\JavaSoft\JRE\1.3.1_%%i\Uninst.isu" -a 2>NUL
	%SystemRoot%\IsUninst.exe -f"%ProgramFiles(x86)%\JavaSoft\JRE\1.3.1_%%i\Uninst.isu" -a 2>NUL
)
:: This wouldn't fit in the loop above
%SystemRoot%\IsUninst.exe -f"%ProgramFiles%\JavaSoft\JRE\1.3\Uninst.isu" -a 2>NUL
%SystemRoot%\IsUninst.exe -f"%ProgramFiles(x86)%\JavaSoft\JRE\1.3\Uninst.isu" -a 2>NUL

:: Java Update Service
call :log "%CUR_DATE% %TIME%   Java Update Service..."
%WMIC% product where "name like 'Java Auto Updater'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"

:: Wildcard uninstallers
call :log "%CUR_DATE% %TIME%   Specific targeting done. Now running WMIC wildcard catchall uninstallation..."
%WMIC% product where "name like '%%J2SE Runtime%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'Java%%Runtime%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'Java%%Update%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
%WMIC% product where "name like 'JavaFX%%'" call uninstall /nointeractive>> "%LOGPATH%\%LOGFILE%"
call :log "%CUR_DATE% %TIME%   Done."


::::::::::::::::::::::
:: REGISTRY CLEANUP :: -- This is where it gets hairy. Don't read ahead if you have a weak constitution.
::::::::::::::::::::::
:: If we're on XP we skip this entire block due to differences in the reg.exe binary
if '%OS_VERSION%'=='XP' (
	call :log "%CUR_DATE% %TIME% ! Registry cleanup doesn't work on Windows XP. Skipping..."
	goto file_cleanup
	)

call :log "%CUR_DATE% %TIME%   Commencing registry cleanup..."
call :log "%CUR_DATE% %TIME%   Searching for residual registry keys..."

:: Search MSIExec installer class hive for keys
call :log "%CUR_DATE% %TIME%   Looking in HKLM\software\classes\installer\products..."
reg query HKLM\software\classes\installer\products /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\software\classes\installer\products /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: Search the Add/Remove programs list (this helps with broken Java installations)
call :log "%CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall..."
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: Search the Add/Remove programs list, x86/Wow64 node (this helps with broken Java installations)
call :log "%CUR_DATE% %TIME%   Looking in HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall..."
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "J2SE Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java(TM) 6 Update" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 7" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java 8" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt
reg query HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall /f "Java*Runtime" /s | find "HKEY_LOCAL_MACHINE" >> %TEMP%\java_purge_registry_keys.txt

:: List the leftover registry keys
call :log "%CUR_DATE% %TIME%   Found these keys..."
echo.>> "%LOGPATH%\%LOGFILE%"
echo.
type %TEMP%\java_purge_registry_keys.txt>> "%LOGPATH%\%LOGFILE%"
type %TEMP%\java_purge_registry_keys.txt
echo.>> "%LOGPATH%\%LOGFILE%"
echo.

:: Backup the various registry keys that will get deleted (if they exist)
:: We do this mainly because we're using wildcards, so we want a method to roll back if we accidentally nuke the wrong thing
call :log "%CUR_DATE% %TIME%   Backing up keys..."
if exist "%TEMP%\java_purge_registry_backup" rmdir /s /q "%TEMP%\java_purge_registry_backup" 2>NUL
mkdir %TEMP%\java_purge_registry_backup >NUL
:: This line walks through the file we generated and dumps each key to a file
for /f "tokens=* delims= " %%a in (%TEMP%\java_purge_registry_keys.txt) do (reg query %%a) >> %TEMP%\java_purge_registry_backup\java_reg_keys_1.bak

echo.
call :log "%CUR_DATE% %TIME%   Keys backed up to %TEMP%\java_purge_registry_backup\"
call :log "%CUR_DATE% %TIME%   This directory will be deleted at next reboot, so get it now if you need it!"

:: Purge the keys
call :log "%CUR_DATE% %TIME%   Purging keys..."
echo.
:: This line walks through the file we generated and deletes each key listed
for /f "tokens=* delims= " %%a in (%TEMP%\java_purge_registry_keys.txt) do reg delete %%a /f >> "%LOGPATH%\%LOGFILE%" 2>NUL

:: These lines delete some specific Java locations
:: These keys AREN'T backed up because these are specific, known Java keys, whereas above we nuke
:: keys based on wildcards, so those need backups in case we get something we didn't want to

:: Delete keys for 32-bit Java installations on a 64-bit copy of Windows
reg delete "HKLM\SOFTWARE\Wow6432Node\JavaSoft" /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\Wow6432Node\JreMetrics" /f>> "%LOGPATH%\%LOGFILE%" 2>NUL

:: Delete keys for for 32-bit and 64-bit Java installations on matching Windows architecture
reg delete "HKLM\SOFTWARE\JavaSoft" /f>> "%LOGPATH%\%LOGFILE%" 2>NUL
reg delete "HKLM\SOFTWARE\JreMetrics" /f>> "%LOGPATH%\%LOGFILE%" 2>NUL

echo.
call :log "%CUR_DATE% %TIME%   Keys purged."
call :log "%CUR_DATE% %TIME%   Registry cleanup done."
echo.


::::::::::::::::::::::::::::::::
:: FILE AND DIRECTORY CLEANUP ::
::::::::::::::::::::::::::::::::
:file_cleanup
call :log "%CUR_DATE% %TIME%   Commencing file and directory cleanup..."

:: Kill the Java tasks in Task Scheduler
call :log "%CUR_DATE% %TIME%   Removing Java tasks from the Windows Task Scheduler..."
if exist %WINDIR%\tasks\Java*.job del /F /Q %WINDIR%\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\System32\tasks\Java*.job del /F /Q %WINDIR%\System32\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\SysWOW64\tasks\Java*.job del /F /Q %WINDIR%\SysWOW64\tasks\Java*.job >> "%LOGPATH%\%LOGFILE%"
echo.

:: Kill the hellspawn known as the Java Quickstarter service
sc query JavaQuickStarterService >NUL
if not %ERRORLEVEL%==1060 (
	call :log "%CUR_DATE% %TIME%   De-registering and removing Java Quickstarter service..."
	net stop JavaQuickStarterService >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete JavaQuickStarterService >> "%LOGPATH%\%LOGFILE%" 2>NUL
)

:: Kill the Java Update Scheduler service
sc query jusched >NUL
if not %ERRORLEVEL%==1060 (
	call :log "%CUR_DATE% %TIME%   De-registering and removing Java Update Scheduler service..."
	net stop jusched >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete jusched >> "%LOGPATH%\%LOGFILE%" 2>NUL
)

:: Kill any leftover binaries in the Windows system folders
if exist %WINDIR%\System32\java.exe del /F /Q %WINDIR%\System32\java.exe >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\System32\javaw.exe del /F /Q %WINDIR%\System32\javaw.exe >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\System32\javaws.exe del /F /Q %WINDIR%\System32\javaws.exe >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\SysWOW64\java.exe del /F /Q %WINDIR%\SysWOW64\java.exe >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\SysWOW64\javaw.exe del /F /Q %WINDIR%\SysWOW64\javaw.exe >> "%LOGPATH%\%LOGFILE%"
if exist %WINDIR%\SysWOW64\javaws.exe del /F /Q %WINDIR%\SysWOW64\javaws.exe >> "%LOGPATH%\%LOGFILE%" 

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
	call :log "%CUR_DATE% %TIME%   Removing '%ProgramFiles(x86)%\Java\jre*' directories..."
	for /D /R "%ProgramFiles(x86)%\Java\" %%x in (j2re*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
	for /D /R "%ProgramFiles(x86)%\Java\" %%x in (jre*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
	if exist "%ProgramFiles(x86)%\JavaSoft\JRE" rmdir /S /Q "%ProgramFiles(x86)%\JavaSoft\JRE" >> "%LOGPATH%\%LOGFILE%"
	)

:: Nuke 64-bit Java installation directories
call :log "%CUR_DATE% %TIME%   Removing '%ProgramFiles%\Java\jre*' directories..."
for /D /R "%ProgramFiles%\Java\" %%x in (j2re*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
for /D /R "%ProgramFiles%\Java\" %%x in (jre*) do if exist "%%x" rmdir /S /Q "%%x">> "%LOGPATH%\%LOGFILE%"
if exist "%ProgramFiles%\JavaSoft\JRE" rmdir /S /Q "%ProgramFiles%\JavaSoft\JRE" >> "%LOGPATH%\%LOGFILE%"

:: Nuke the Java Update directory (normally contains jaureg.exe, jucheck.exe, and jusched.exe)
rmdir /S /Q "%CommonProgramFiles%\Java\Java Update\">> "%LOGPATH%\%LOGFILE%" 2>NUL
rmdir /S /Q "%CommonProgramFiles(x86)%\Java\Java Update\">> "%LOGPATH%\%LOGFILE%" 2>NUL

:: Nuke Java installer cache ( thanks to cannibalkitteh )
call :log "%CUR_DATE% %TIME%   Purging Java installer cache..."
:: XP VERSION
if %OS_VERSION%==XP (
    :: Dump list of users to a file, then iterate through the list of profiles deleting the respective AU folder
    dir "%SystemDrive%\Documents and Settings\" /B > %TEMP%\userlist.txt
    for /f "tokens=* delims= " %%a in (%TEMP%\userlist.txt) do (
		if exist "%SystemDrive%\Documents and Settings\%%a\AppData\LocalLow\Sun\Java\AU" rmdir /S /Q "%SystemDrive%\Documents and Settings\%%a\AppData\LocalLow\Sun\Java\AU">> "%LOGPATH%\%LOGFILE%" 2>NUL
	)
    for /D /R "%SystemDrive%\Documents and Settings\" %%b in (jre*) do if exist "%%x" rmdir /S /Q "%%b">> "%LOGPATH%\%LOGFILE%" 2>NUL
) else (
	:: ALL OTHER VERSIONS OF WINDOWS
    :: Dump list of users to a file, then iterate through the list of profiles deleting the respective AU folder
    dir %SystemDrive%\Users /B > %TEMP%\userlist.txt
    for /f "tokens=* delims= " %%a in (%TEMP%\userlist.txt) do (
		if exist "%SystemDrive%\Users\%%a\AppData\LocalLow\Sun\Java\AU" rmdir /S /Q "%SystemDrive%\Users\%%a\AppData\LocalLow\Sun\Java\AU">> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
    REM Get the other JRE directories
    for /D /R "%SystemDrive%\Users" %%b in (jre*) do rmdir /S /Q "%%b">> "%LOGPATH%\%LOGFILE%" 2>NUL
    )

:: Miscellaneous stuff, sometimes left over by the installers
call :log "%CUR_DATE% %TIME%   Searching for and purging other Java Runtime-related directories..."
del /F /Q %SystemDrive%\1033.mst >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /S /Q "%SystemDrive%\J2SE Runtime Environment*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /S /Q "%SystemDrive%\Documents and Settings\All Users\Application Data\Oracle\Java\javapath\*.exe" 2>NUL
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Java\" rmdir /s /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Java\"
echo.


call :log "%CUR_DATE% %TIME%   File and directory cleanup done."
echo. >> "%LOGPATH%\%LOGFILE%"
echo.


:: Done.
call :log "%CUR_DATE% %TIME%   Registry hive backups: %TEMP%\java_purge_registry_backup\"
call :log "%CUR_DATE% %TIME%   Log file: "%LOGPATH%\%LOGFILE%""
call :log "%CUR_DATE% %TIME%   COMPLETE. Recommend rebooting and washing your hands."

:: Return exit code to SCCM/PDQ Deploy/PSexec/etc
exit /B %EXIT_CODE%








:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof
