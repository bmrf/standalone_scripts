:: Purpose:       Temp file cleanup
:: Requirements:  Admin access helps but is not required
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       3.7.1 ! Fix syntax bug that was preventing CBS log cleanup. Thanks to github:jonasjovaisas
::                3.7.0 * Improve logging significantly. Wrap all references to %LOGPATH% and %LOGFILE% in quotes (to protect against paths or file names with spaces or special characters), and add logging to many commands that were previously dumping to NUL. Thanks to github:kezxo for the suggestion
::                3.6.0 + Add additional cleaning procedures to Vista+ block from tron edition of TempFileCleanup. Thanks to github:bknickelbine
::                3.5.9 + Add removal of "%WINDIR%\System32\tourstart.exe" on Windows XP. Thanks to /u/Perma_dude
::                3.5.8 ! Move IE ClearMyTracksByProcess to Vista and up section (does not run on XP/2003)
::                3.5.7 * Add /u/neonicacid's suggestion to purge leftover NVIDIA driver installation files
::                3.5.6 * Merge nemchik's pull request to delete .blf and.regtrans-ms files (ported from Tron project)
::                      * Merge nemchik's pull request to purge Flash and Java temp locations (ported from Tron project)
::                3.5.5 + Add purging of additional old Windows version locations (left in place from Upgrade installations)
::                3.5.4 + Add purging of queued Windows Error Reporting reports. Thanks to /u/neonicacid
::                <-- outdated changelog comments removed -->
::                1.0.0   Initial write
SETLOCAL


:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::
:: Set your paths here. Don't use trailing slashes (\) in directory paths
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_TempFileCleanup.log
:: Max log file size allowed in bytes before rotation and archive. 1048576 bytes is one megabyte
set LOG_MAX_SIZE=2097152




:: --------------------------- Don't edit anything below this line --------------------------- ::




:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
%SystemDrive% && cls
set SCRIPT_VERSION=3.7.1
set SCRIPT_UPDATED=2017-12-18
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title [TempFileCleanup v%SCRIPT_VERSION%]


:::::::::::::::::::::::
:: LOG FILE HANDLING ::
:::::::::::::::::::::::
:: Make the logfile if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%
if not exist %LOGPATH%\%LOGFILE% echo. > %LOGPATH%\%LOGFILE%

:: Check log size. If it's less than our max, then jump to the cleanup section
for %%R in (%LOGPATH%\%LOGFILE%) do IF %%~zR LSS %LOG_MAX_SIZE% goto os_version_detection

:: If the log was too big, go ahead and rotate it.
pushd %LOGPATH%
del %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.oldest %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.older %LOGFILE%.oldest 2>NUL
rename %LOGFILE%.old %LOGFILE%.older 2>NUL
rename %LOGFILE% %LOGFILE%.old 2>NUL
popd



::::::::::::::::::::::::::
:: OS VERSION DETECTION ::
::::::::::::::::::::::::::
:os_version_detection
:: Detect the version of Windows we're on. This determines a few things later in the script
set WIN_VER=undetected
for /f "tokens=3*" %%i IN ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName ^| Find "ProductName"') DO set WIN_VER=%%i %%j



::::::::::::::::::::::::::
:: USER CLEANUP SECTION :: -- Most stuff in here doesn't require Admin rights
::::::::::::::::::::::::::
:: Create the log header for this job
echo -------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  %CUR_DATE% %TIME%  TempFileCleanup v%SCRIPT_VERSION%, executing as %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo -------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.
echo  Starting temp file cleanup
echo  --------------------------
echo.
echo   Cleaning USER temp files...


::::::::::::::::::::::
:: Version-agnostic :: (these jobs run regardless of OS version)
::::::::::::::::::::::
:: Create log line
echo. >> "%LOGPATH%\%LOGFILE%" %% echo  ! Cleaning USER temp files...>> "%LOGPATH%\%LOGFILE%" %% echo.>> "%LOGPATH%\%LOGFILE%"

:: User temp files, history, and random My Documents stuff
del /F /S /Q "%TEMP%" >> "%LOGPATH%\%LOGFILE%" 2>NUL

:: Previous Windows versions cleanup. These are left behind after upgrading an installation from XP/Vista/7/8 to a higher version. Thanks to /u/bodkov and others
if exist %SystemDrive%\Windows.old\ (
	takeown /F %SystemDrive%\Windows.old\* /R /A /D Y>> "%LOGPATH%\%LOGFILE%"
	echo y| cacls %SystemDrive%\Windows.old\*.* /C /T /grant administrators:F>> "%LOGPATH%\%LOGFILE%"
	rmdir /S /Q %SystemDrive%\Windows.old\>> "%LOGPATH%\%LOGFILE%"
	)
if exist %SystemDrive%\$Windows.~BT\ (
	takeown /F %SystemDrive%\$Windows.~BT\* /R /A>> "%LOGPATH%\%LOGFILE%"
	icacls %SystemDrive%\$Windows.~BT\*.* /T /grant administrators:F>> "%LOGPATH%\%LOGFILE%"
	rmdir /S /Q %SystemDrive%\$Windows.~BT\>> "%LOGPATH%\%LOGFILE%"
	)
if exist %SystemDrive%\$Windows.~WS (
	takeown /F %SystemDrive%\$Windows.~WS\* /R /A>> "%LOGPATH%\%LOGFILE%"
	icacls %SystemDrive%\$Windows.~WS\*.* /T /grant administrators:F>> "%LOGPATH%\%LOGFILE%"
	rmdir /S /Q %SystemDrive%\$Windows.~WS\>> "%LOGPATH%\%LOGFILE%"
	)


::::::::::::::::::::::
:: Version-specific :: (these jobs run depending on OS version)
::::::::::::::::::::::
:: First block handles XP/2k3, second block handles Vista and up
:: Read 9 characters into the WIN_VER variable. Only versions of Windows older than Vista had "Microsoft" as the first part of their title,
:: so if we don't find "Microsoft" in the first 9 characters we can safely assume we're not on XP/2k3.
if /i "%WIN_VER:~0,9%"=="Microsoft" (
	for /D %%x in ("%SystemDrive%\Documents and Settings\*") do (
		del /F /Q "%%x\Local Settings\Temp\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Recent\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Local Settings\Temporary Internet Files\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Local Settings\Application Data\ApplicationHistory\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\My Documents\*.tmp" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Application Data\Sun\Java\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Application Data\Adobe\Flash Player\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Application Data\Macromedia\Flash Player\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
	)
) else (
	for /D %%x in ("%SystemDrive%\Users\*") do (
		del /F /S /Q "%%x\*.blf" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\*.regtrans-ms" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\LocalLow\Sun\Java\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Google\Chrome\User Data\Default\Cache\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Google\Chrome\User Data\Default\JumpListIconsOld\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Google\Chrome\User Data\Default\JumpListIcons\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Google\Chrome\User Data\Default\Local Storage\http*.*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Google\Chrome\User Data\Default\Media Cache\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Internet Explorer\Recovery\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Terminal Server Client\Cache\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\Caches\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\Explorer\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\History\low\*" /AH 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\INetCache\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Microsoft\Windows\WebCache\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Local\Temp\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Roaming\Adobe\Flash Player\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Roaming\Macromedia\Flash Player\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\AppData\Roaming\Microsoft\Windows\Recent\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /S /Q "%%x\Recent\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		del /F /Q "%%x\Documents\*.tmp" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		:: Internet Explorer cleanup
		rundll32.exe inetcpl.cpl,ClearMyTracksByProcess 4351
	)
)


echo. && echo   Done. && echo.
echo. >> "%LOGPATH%\%LOGFILE%" && echo   Done.>> "%LOGPATH%\%LOGFILE%" && echo. >>%LOGPATH%\%LOGFILE%



::::::::::::::::::::::::::::
:: SYSTEM CLEANUP SECTION :: -- Most stuff here requires Admin rights
::::::::::::::::::::::::::::
echo.
echo   Cleaning SYSTEM temp files...
echo   Cleaning SYSTEM temp files... >> "%LOGPATH%\%LOGFILE%" && echo.>> %LOGPATH%\%LOGFILE%


::::::::::::::::::::::
:: Version-agnostic :: (these jobs run regardless of OS version)
::::::::::::::::::::::
:: JOB: System temp files
del /F /S /Q "%WINDIR%\TEMP\*" >> "%LOGPATH%\%LOGFILE%" 2>NUL

:: JOB: Root drive garbage (usually C drive)
rmdir /S /Q %SystemDrive%\Temp >> "%LOGPATH%\%LOGFILE%" 2>NUL
for %%i in (bat,txt,log,jpg,jpeg,tmp,bak,backup,exe) do (
			del /F /Q "%SystemDrive%\*.%%i">> "%LOGPATH%\%LOGFILE%" 2>NUL
		)

:: JOB: Remove files left over from installing Nvidia/ATI/AMD/Dell/Intel/HP drivers
for %%i in (NVIDIA,ATI,AMD,Dell,Intel,HP) do (
			rmdir /S /Q "%SystemDrive%\%%i" >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)

:: JOB: Clear additional unneeded files from NVIDIA driver installs
if exist "%ProgramFiles%\Nvidia Corporation\Installer2" rmdir /s /q "%ProgramFiles%\Nvidia Corporation\Installer2"
if exist "%ALLUSERSPROFILE%\NVIDIA Corporation\NetService" del /f /q "%ALLUSERSPROFILE%\NVIDIA Corporation\NetService\*.exe"

:: JOB: Remove the Microsoft Office installation cache. Usually around ~1.5 GB
if exist %SystemDrive%\MSOCache rmdir /S /Q %SystemDrive%\MSOCache >> "%LOGPATH%\%LOGFILE%"

:: JOB: Remove the Microsoft Windows installation cache. Can be up to 1.0 GB
if exist %SystemDrive%\i386 rmdir /S /Q %SystemDrive%\i386 >> "%LOGPATH%\%LOGFILE%"

:: JOB: Empty all recycle bins on Windows 5.1 (XP/2k3) and 6.x (Vista and up) systems
if exist %SystemDrive%\RECYCLER rmdir /s /q %SystemDrive%\RECYCLER
if exist %SystemDrive%\$Recycle.Bin rmdir /s /q %SystemDrive%\$Recycle.Bin

:: JOB: Clear queued and archived Windows Error Reporting (WER) reports
echo. >> "%LOGPATH%\%LOGFILE%"
if exist "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportArchive" rmdir /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportArchive"
if exist "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportQueue" rmdir /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportQueue"
if exist "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportArchive" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportArchive"
if exist "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportQueue" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportQueue"

:: JOB: Windows update logs & built-in backgrounds (space waste)
del /F /Q %WINDIR%\*.log >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /Q %WINDIR%\*.txt >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /Q %WINDIR%\*.bmp >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /Q %WINDIR%\*.tmp >> "%LOGPATH%\%LOGFILE%" 2>NUL
del /F /Q %WINDIR%\Web\Wallpaper\*.* >> "%LOGPATH%\%LOGFILE%" 2>NUL
rmdir /S /Q %WINDIR%\Web\Wallpaper\Dell >> "%LOGPATH%\%LOGFILE%" 2>NUL

:: JOB: Flash cookies (both locations)
rmdir /S /Q "%APPDATA%\Macromedia\Flash Player\#SharedObjects" >> "%LOGPATH%\%LOGFILE%" 2>NUL
rmdir /S /Q "%APPDATA%\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys" >> "%LOGPATH%\%LOGFILE%" 2>NUL

::::::::::::::::::::::
:: Version-specific :: (these jobs run depending on OS version)
::::::::::::::::::::::
:: JOB: Windows XP/2k3: "guided tour" annoyance
if /i "%WIN_VER:~0,9%"=="Microsoft" (
	del /f /q %WINDIR%\system32\dllcache\tourstrt.exe 2>NUL
	del /f /q %WINDIR%\system32\dllcache\tourW.exe 2>NUL
	del /f /q "%WINDIR%\System32\tourstart.exe"
	rmdir /S /Q %WINDIR%\Help\Tours 2>NUL
	)

:: JOB: Disable Windows Tour bubble popup (Windows XP only; new user accounts only)
if /i "%WIN_VER:~0,9%"=="Microsoft" reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Applets\Tour" /v RunCount /t REG_DWORD /d 00000000 /f

:: JOB: Windows Server: remove built-in media files (all Server versions)
echo %WIN_VER%  | findstr /i /%SystemDrive%"server" >NUL
if %ERRORLEVEL%==0 (
	echo.
	echo  ! Server operating system detected.
	echo    Removing built-in media files ^(.wav, .midi, etc^)...
	echo.
	echo. >> "%LOGPATH%\%LOGFILE%" && echo  ! Server operating system detected. Removing built-in media files ^(.wave, .midi, etc^)...>> "%LOGPATH%\%LOGFILE%" && echo. >> "%LOGPATH%\%LOGFILE%"

	:: 2. Take ownership of the files so we can actually delete them. By default even Administrators have Read-only rights.
	echo    Taking ownership of %WINDIR%\Media in order to delete files... && echo.
	echo    Taking ownership of %WINDIR%\Media in order to delete files... >> "%LOGPATH%\%LOGFILE%" && echo.>> "%LOGPATH%\%LOGFILE%"
	if exist %WINDIR%\Media takeown /f %WINDIR%\Media /r /d y >> "%LOGPATH%\%LOGFILE%" 2>NUL && echo.>> "%LOGPATH%\%LOGFILE%"
	if exist %WINDIR%\Media icacls %WINDIR%\Media /grant administrators:F /t >> "%LOGPATH%\%LOGFILE%" && echo.>> "%LOGPATH%\%LOGFILE%"

	:: 3. Do the cleanup
	rmdir /S /Q %WINDIR%\Media>> "%LOGPATH%\%LOGFILE%" 2>NUL

	echo    Done.
	echo.
	echo    Done.>> "%LOGPATH%\%LOGFILE%"
	echo.>> "%LOGPATH%\%LOGFILE%"
	)

:: JOB: Windows CBS logs
::      these only exist on Vista and up, so we look for "Microsoft", and assuming we don't find it, clear out the folder
echo %WIN_VER% | findstr /v /i /c:"Microsoft" >NUL && del /F /Q %WINDIR%\Logs\CBS\* 2>NUL

:: JOB: Windows XP/2003: Cleanup hotfix uninstallers. They use a lot of space so removing them is beneficial.
:: Really we should use a tool that deletes their corresponding registry entries, but oh well.

::  0. Check Windows version.
::    We simply look for "Microsoft" in the version name, because only versions prior to Vista had the word "Microsoft" as part of their version name
::    Everything after XP/2k3 drops the "Microsoft" prefix
echo %WIN_VER%  | findstr /i /%SystemDrive%"Microsoft" >NUL
if %ERRORLEVEL%==0 (
	:: 1. If we made it here we're doing the cleanup. Notify user and log it.
	echo.
	echo  ! Windows XP/2003 detected.
	echo    Removing hotfix uninstallers...
	echo.
	echo. >> "%LOGPATH%\%LOGFILE%" && echo  ! Windows XP/2003 detected. Removing hotfix uninstallers...>> %LOGPATH%\%LOGFILE%

	:: 2. Build the list of hotfix folders. They always have "$" signs around their name, e.g. "$NtUninstall092330$" or "$hf_mg$"
	pushd %WINDIR%
	dir /A:D /B $*$ > %TEMP%\hotfix_nuke_list.txt 2>NUL

	:: 3. Do the hotfix clean up
	for /f %%i in (%TEMP%\hotfix_nuke_list.txt) do (
		echo Deleting %%i...
		echo Deleted folder %%i>> "%LOGPATH%\%LOGFILE%"
		rmdir /S /Q %%i >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)

	:: 4. Log that we are done with hotfix cleanup and leave the Windows directory
	echo    Done. >> "%LOGPATH%\%LOGFILE%" && echo.>> %LOGPATH%\%LOGFILE%
	echo    Done.
	del %TEMP%\hotfix_nuke_list.txt>> %LOGPATH%\%LOGFILE%
	echo.
	popd
)

echo   Done. && echo.
echo   Done.>> "%LOGPATH%\%LOGFILE%" && echo. >>%LOGPATH%\%LOGFILE%

::::::::::::::::::::::::::
:: Cleanup and complete ::
::::::::::::::::::::::::::
:complete
@echo off
echo -------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  %CUR_DATE% %TIME%  TempFileCleanup v%SCRIPT_VERSION%, finished. Executed as %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo -------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.
echo  Cleanup complete.
echo.
echo  Log saved at: %LOGPATH%\%LOGFILE%
echo.
ENDLOCAL
