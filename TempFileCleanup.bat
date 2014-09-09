:: Purpose:       Temp file cleanup
:: Requirements:  Admin access helps but is not required
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: Version:       3.4.0 ! Fix failing FOR loops due to missing opening or closing quotes. Thanks to reddit.com/user/savagebunny
::                      ! Fix broken Flash cookie cleanup section
::                      ! Fix broken logging in some sections (was calling obsolete variable %LOGFILENAME% instead of %LOGFILE%)
::                      * Improve OS detection routine; OS version checks now more fine-grained
::                      * Improve hotfix cleanup and server media file cleanup sections
::                      * Split all jobs into Windows version-specific and version-agnostic jobs for better readability
::                3.3a  / Minor header cleanup; Variables section now about PREP AND CHECKS
::                3.3   / Renamed VERSION and UPDATED to SCRIPT_VERSION and SCRIPT_UPDATED
::                3.2   * Reworked CUR_DATE variable to handle all Windows date formats regardless of local date-time format
::                2.9   * Update user temp file deletion to loop through every users temp files instead of just current user.
::                        Thanks to reddit.com/user/srisinger
::                2.8   + Add emptying of ALL user's recycle bins
::                2.7   + Add removal of C:\AMD folder
::                      + Add removal of C:\ATI folder
::                      * Tweak job footer to include what user the script executed as
::                2.6   + Improve detection of Windows XP/2003 hotfix folders
::                2.5   + Improve detection of operating system and added new OS detection section near script start
::                      + Add section to remove C:\Windows\Media on Server-based operating systems
::                      - Comment cleanup and removal of unneeded error piping (2>&1)
::                2.2   + Log files now rotate and delete old versions
::                2.0   * Major re-write
::                         + Added section to test for and delete hotfix uninstallers on XP
::                         + Added log file
::                1.8   / Split into USER and SYSTEM subsections 
::                1.7   + Add section to delete Windows update log files and built-in .bmp files
::                1.6   / Change some delete flags to /F /S /Q instead of just /F /Q
::                        The "/S" flag says to recurse into subdirectories. 
::                1.5   + Add new areas to clean -- %TEMP%\ folder
::                1.0     Initial write
SETLOCAL


:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::
:: Set your paths here. Don't use trailing slashes (\) in directory paths
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_TempFileCleanup.log
:: Max log file size allowed in bytes before rotation and archive. 1048576 bytes is one megabyte
set LOG_MAX_SIZE=104857600




:: --------------------------- Don't edit anything below this line --------------------------- ::




:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
%SystemDrive% && cls
set SCRIPT_VERSION=3.4.0
set SCRIPT_UPDATED=2014-09-09
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it 
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
echo. >> %LOGPATH%\%LOGFILE% %% echo  ! Cleaning USER temp files...>> %LOGPATH%\%LOGFILE% %% echo. >> %LOGPATH%\%LOGFILE%

:: User temp files, history, and random My Documents stuff
del /F /S /Q "%TEMP%" >> %LOGPATH%\%LOGFILE% 2>NUL



::::::::::::::::::::::
:: Version-specific :: (these jobs run depending on OS version)
::::::::::::::::::::::
:: JOB: Windows XP 
if "%WIN_VER%"=="Microsoft Windows XP" (
    for /D %%x in ("%SystemDrive%\Documents and Settings\*") do ( 
        del /F /Q "%%x\Local Settings\Temp\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Recent\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Local Settings\Temporary Internet Files\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Local Settings\Application Data\ApplicationHistory\*">> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\My Documents\*.tmp" >> %LOGPATH%\%LOGFILE% 2>NUL
    )
)

:: JOB: Windows Server 2003: and if not, run code applicable to Windows Vista and later
if "%WIN_VER%"=="Microsoft Windows Server 2003" (
    for /D %%x in ("%SystemDrive%\Documents and Settings\*") do ( 
        del /F /Q "%%x\Local Settings\Temp\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Recent\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Local Settings\Temporary Internet Files\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\Local Settings\Application Data\ApplicationHistory\*">> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\My Documents\*.tmp" >> %LOGPATH%\%LOGFILE% 2>NUL
		)
) else (
    for /D %%x in ("%SystemDrive%\Users\*") do ( 
        del /F /Q "%%x\AppData\Local\Temp\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\AppData\Roaming\Microsoft\Windows\Recent\*" >> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\AppData\Local\Microsoft\Windows\Temporary Internet Files\*">> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\AppData\Local\ApplicationHistory\*">> %LOGPATH%\%LOGFILE% 2>NUL
        del /F /Q "%%x\My Documents\*.tmp" >> %LOGPATH%\%LOGFILE% 2>NUL
    )
)


echo. && echo   Done. && echo.
echo. >> %LOGPATH%\%LOGFILE% && echo   Done.>> %LOGPATH%\%LOGFILE% && echo. >>%LOGPATH%\%LOGFILE%



::::::::::::::::::::::::::::
:: SYSTEM CLEANUP SECTION :: -- Most stuff here requires Admin rights
::::::::::::::::::::::::::::
echo.
echo   Cleaning SYSTEM temp files...
echo   Cleaning SYSTEM temp files... >> %LOGPATH%\%LOGFILE% && echo.>> %LOGPATH%\%LOGFILE%


::::::::::::::::::::::
:: Version-agnostic :: (these jobs run regardless of OS version)
::::::::::::::::::::::
:: JOB: System temp files
del /F /S /Q "%WINDIR%\TEMP\*" >> %LOGPATH%\%LOGFILE% 2>NUL

:: JOB: Root drive garbage (usually C drive)
rmdir /S /Q %SystemDrive%\Temp >> %LOGPATH%\%LOGFILE% 2>NUL
for %%i in (bat,txt,log,jpg,jpeg,tmp,bak,backup,exe) do (
			del /F /Q "%SystemDrive%\*.%%i">> "%LOGPATH%\%LOGFILE%" 2>NUL
		)

:: JOB: Remove files left over from installing Nvidia/ATI/AMD/Dell/Intel drivers
for %%i in (NVIDIA,ATI,AMD,Dell,Intel) do (
			rmdir /S /Q "%SystemDrive%\%%i">> "%LOGPATH%\%LOGFILE%" 2>NUL
		)

:: JOB: Remove the Microsoft Office installation cache. Usually around ~1.5 GB
if exist %SystemDrive%\MSOCache rmdir /S /Q %SystemDrive%\MSOCache >> %LOGPATH%\%LOGFILE%

:: JOB: Remove the Microsoft Windows installation cache. Can be up to 1.0 GB
if exist %SystemDrive%\i386 rmdir /S /Q %SystemDrive%\i386 >> %LOGPATH%\%LOGFILE%
		
:: JOB: Empty all recycle bins on Windows 5.1 (XP/2k3) and 6.x (Vista and up) systems
if exist %SystemDrive%\RECYCLER rmdir /s /q %SystemDrive%\RECYCLER
if exist %SystemDrive%\$Recycle.Bin rmdir /s /q %SystemDrive%\$Recycle.Bin

:: JOB: Windows update logs & built-in backgrounds (space waste)
del /F /Q %WINDIR%\*.log >> %LOGPATH%\%LOGFILE% 2>NUL
del /F /Q %WINDIR%\*.txt >> %LOGPATH%\%LOGFILE% 2>NUL
del /F /Q %WINDIR%\*.bmp >> %LOGPATH%\%LOGFILE% 2>NUL
del /F /Q %WINDIR%\*.tmp >> %LOGPATH%\%LOGFILE% 2>NUL
del /F /Q %WINDIR%\Web\Wallpaper\*.* >> %LOGPATH%\%LOGFILE% 2>NUL
rmdir /S /Q %WINDIR%\Web\Wallpaper\Dell >> %LOGPATH%\%LOGFILE% 2>NUL

:: JOB: Flash cookies (both locations)
rmdir /S /Q "%APPDATA%\Macromedia\Flash Player\#SharedObjects" >> %LOGPATH%\%LOGFILE% 2>NUL
rmdir /S /Q "%APPDATA%\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys" >> %LOGPATH%\%LOGFILE% 2>NUL



::::::::::::::::::::::
:: Version-specific :: (these jobs run depending on OS version)
::::::::::::::::::::::
:: JOB: Windows XP: "guided tour" annoyance
if "%WIN_VER%"=="Microsoft Windows XP" (
	del %WINDIR%\system32\dllcache\tourstrt.exe >> %LOGPATH%\%LOGFILE% 2>NUL
	del %WINDIR%\system32\dllcache\tourW.exe >> %LOGPATH%\%LOGFILE% 2>NUL
	rmdir /S /Q %WINDIR%\Help\Tours >> %LOGPATH%\%LOGFILE% 2>NUL
	)
if "%WIN_VER%"=="Microsoft Windows Server 2003" (
	del %WINDIR%\system32\dllcache\tourstrt.exe >> %LOGPATH%\%LOGFILE% 2>NUL
	del %WINDIR%\system32\dllcache\tourW.exe >> %LOGPATH%\%LOGFILE% 2>NUL
	rmdir /S /Q %WINDIR%\Help\Tours >> %LOGPATH%\%LOGFILE% 2>NUL
	)


:: JOB: Windows Server: remove built-in media files (all Server versions)
echo.%WIN_VER% | findstr /i /c:"server" >NUL
if %ERRORLEVEL%==0 (
	echo.
	echo  ! Windows Server operating system detected.
	echo    Removing built-in media files ^(.wav, .midi, etc^)...
	echo.
	echo. >> %LOGPATH%\%LOGFILE% && echo  ! Windows Server operating system detected. Removing built-in media files ^(.wave, .midi, etc^)...>> %LOGPATH%\%LOGFILE% && echo. >> %LOGPATH%\%LOGFILE%

	:: 2. Take ownership of the files so we can actually delete them. By default even Administrators have Read-only rights. 
	echo  ! Taking ownership of %WINDIR%\Media in order to delete files... && echo.
	echo  ! Taking ownership of %WINDIR%\Media in order to delete files... >> %LOGPATH%\%LOGFILE% && echo. >> %LOGPATH%\%LOGFILE%
	if exist %WINDIR%\Media takeown /f %WINDIR%\Media /r /d y >> %LOGPATH%\%LOGFILE% 2>NUL && echo. >> %LOGPATH%\%LOGFILE%
	if exist %WINDIR%\Media icacls %WINDIR%\Media /grant administrators:F /t >> %LOGPATH%\%LOGFILE% && echo. >> %LOGPATH%\%LOGFILE%
	
	:: 3. Do the cleanup
	rmdir /S /Q %WINDIR%\Media>> %LOGPATH%\%LOGFILE% 2>NUL
	
	echo    Done.
	echo.
	echo    Done. >> %LOGPATH%\%LOGFILE%
	echo. >> %LOGPATH%\%LOGFILE%
 )


:: JOB: Windows XP/2003: Cleanup hotfix uninstallers. They use a lot of space so removing them is beneficial.
:: Really we should use a tool that deletes their corresponding registry entries, but oh well.

::  0. Check Windows version.
::    We simply look for "Microsoft" in the version name, because only versions prior to Vista had the word "Microsoft" as part of their version name
::    Everything after XP/2k3 drops the "Microsoft" prefix
echo.%WIN_VER% | findstr /i /c:"Microsoft" >NUL
if %ERRORLEVEL%==0 (
	:: 1. If we made it here we're doing the cleanup. Notify user and log it.
	echo.
	echo  ! Windows XP/2003 detected.
	echo    Removing hotfix uninstallers...
	echo.
	echo. >> %LOGPATH%\%LOGFILE% && echo  ! Windows XP/2003 detected. Removing hotfix uninstallers...>> %LOGPATH%\%LOGFILE%

	:: 2. Build the list of hotfix folders. They always have "$" signs around their name, e.g. "$NtUninstall092330$" or "$hf_mg$"
	pushd %WINDIR%
	dir /A:D /B $*$ > %TEMP%\hotfix_nuke_list.txt 2>NUL

	:: 3. Do the hotfix clean up
	for /f %%i in (%TEMP%\hotfix_nuke_list.txt) do (
		echo Deleting %%i...
		echo Deleted folder %%i >> %LOGPATH%\%LOGFILE%
		rmdir /S /Q %%i >> %LOGPATH%\%LOGFILE% 2>NUL
		)

	:: 4. Log that we are done with hotfix cleanup and leave the Windows directory
	echo    Done. >> %LOGPATH%\%LOGFILE% && echo.>> %LOGPATH%\%LOGFILE%
	echo    Done. 
	del %TEMP%\hotfix_nuke_list.txt>> %LOGPATH%\%LOGFILE%
	echo.
	popd
)

echo   Done. && echo.
echo   Done.>> %LOGPATH%\%LOGFILE% && echo. >>%LOGPATH%\%LOGFILE%

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
