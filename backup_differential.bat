:: Purpose:       Rotating differential backup using 7-Zip for compression.
:: Requirements:  - forfiles.exe from Microsoft
::                - 7-Zip
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: Version:       1.5.2 + Merge :log function from Tron; convert most echo commands to use log function
::                1.5.1 * Add standard boilerplate comments
::                < -- remove outdate changelog comments -->
::                1.0     Initial write

:: Notes:         My intention for this script was to keep the logic controlling schedules, backup type, etc out of the script and
::                let an invoking program handle it (e.g. Task Scheduler). You simply run this script with a flag to perform an action.
::                If you want to schedule monthly backups, purge old files, etc, just set up task scheduler jobs for those tasks, 
::                where each job calls the script with a different flag.

:: Usage:         Run this script without any flags for a list of possible actions. Run it with a flag to perform that action.
::                Flags:
::                 -f   create full backup
::                 -d   create differential backup (full backup must already exist)
::                 -r   restore from a backup (extracts to your staging area)
::                 -a   archive (close out/rotate) the current backup set. This:
::                      1. moves all .7z files in the %DESTINATION% into a folder named with the current date
::                      2. deletes all .7z files from the staging area
::                 -p   purge (delete) old backup sets from staging and destination. If you specify a number 
::                      of days after the command it will run automatically without any confirmation. Be careful with this!
::                 -c   show job options (show what the variables are set to)

:: Important:     If you want to set this script up in Windows Task Scheduler, be aware that Task Scheduler
::                can't use mapped network drives (X:\, Z:\, etc) when it is set to "Run even if user isn't logged on."
::                The task will simply fail to do anything (because Scheduler can't see the drives). To work around this use
::                UNC paths instead (\\server\backup_folder etc) for your source, destination, and staging areas.

:: TODO:          1. Add md5sum checksum file in the backup directory (md5sum each full and diff and store in a file)
@echo off
SETLOCAL


:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )
:: Specify the folder you want to back up here.
set SOURCE=%userprofile%\root\scripts\sysadmin

:: Work area where everything is stored while compressing. Should be a fast drive or something that can handle a lot of writes
:: Recommend not using a network share unless it's Gigabit or faster.
set STAGING=%TEMP%\backup_staging

:: This is the final, long-term destination for your backup after it is compressed.
set DESTINATION=%userprofile%\desktop\backups

:: If you want to customize the prefix of the backup files, do so here. Don't use any special characters (like underscores)
:: The script automatically suffixes an underscore to this name. Recommend not changing this unless you really need to.
::  * Spaces are NOT OKAY to use here!
set BACKUP_PREFIX=backup

:: OPTIONAL: If you want to exclude some files or folders, you can specify your exclude file here. The exclude file is a list of 
:: files or folders (wildcards in the form of * are allowed and recommended) to exclude.
:: If you specify a file here and the script can't find it, it will abort.
:: If you leave this blank, the script won't ignore any files.
set EXCLUSIONS_FILE=

:: Log settings. Max size is how big (in bytes) the log can be before it is archived. 1048576 bytes is one megabyte
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_%BACKUP_PREFIX%_differential.log
set LOG_MAX_SIZE=104857600

:: Location of 7-Zip and forfiles.exe
set SEVENZIP="C:\Program Files\7-Zip\7z.exe"
set FORFILES=%WINDIR%\system32\forfiles.exe



:: --------------------------- Don't edit anything below this line --------------------------- ::



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
set SCRIPT_VERSION=1.5.2
set SCRIPT_DATE=2015-11-03
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

:: Preload variables for use later
set JOB_TYPE=%1
set JOB_ERROR=0
set DAYS=%2
set RESTORE_TYPE=NUL
set SCRIPT_NAME=%0%



::::::::::::::::::::::::::::
:: JOB TYPE DETERMINATION ::
::::::::::::::::::::::::::::

:: Parse command-line arguments (functions are at bottom of script)
call :parse_cmdline_args %*

:: Show help if requested
if %JOB_TYPE%==help (
	echo. 
	echo  %SCRIPT_NAME% v%SCRIPT_VERSION% ^(%SCRIPT_DATE%^)
	echo.
	echo  Usage: %SCRIPT_NAME% ^< -f ^| -d ^| -r ^| -a ^| -p ^[days^] ^| -c ^>
	echo.
	echo  Flags:
	echo   -f:  create a full backup
	echo   -d:  create a differential backup ^(requires an existing full backup^)
	echo   -r:  restore from a backup, extracts to:
	echo          %STAGING%\%BACKUP_PREFIX%_restore
	echo   -a:  archive the current backup set. This will:
	echo          1. move all .7z files located in:
	echo              %DESTINATION% 
	echo             ...into a dated archive folder.
	echo          2. purge ^(delete^) all copies from the staging area:
	echo              %STAGING%
	echo   -p:  purge ^(delete^) archived backup sets from staging and long-term storage
	echo        Optionally specify number of days to run automatically. Be careful with this!
	echo        Note that this requires a previously-archived backup set ^(-a option^)
	echo   -c:  show job options ^(show what parameters the script WOULD execute with^)
	echo.
	echo  Edit this script before running it to specify your source, destination, and work directories.
	goto end
)


:::::::::::::::::::::::
:: LOG FILE HANDLING ::
:::::::::::::::::::::::
:: Make the logfile if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%
if not exist %LOGPATH%\%LOGFILE% echo. > %LOGPATH%\%LOGFILE%

:: Check log size. If it's less than our max, then go ahead and get started
for %%R in (%LOGPATH%\%LOGFILE%) do if %%~zR LSS %LOG_MAX_SIZE% goto required_files_check

:: If the log was too big, go ahead and rotate it.
pushd %LOGPATH% 2>&1
del /F %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.oldest %LOGFILE%.ancient 2>NUL
rename %LOGFILE%.older %LOGFILE%.oldest 2>NUL
rename %LOGFILE%.old %LOGFILE%.older 2>NUL
rename %LOGFILE% %LOGFILE%.old 2>NUL
popd


::::::::::::::::::::::::::
:: REQUIRED FILES CHECK ::
::::::::::::::::::::::::::
:required_files_check
:: Make sure we can find 7-Zip
IF NOT EXIST %SEVENZIP% (
	echo %TIME%   ERROR: Couldn't find 7z.exe when script was invoked.>> %LOGPATH%\%LOGFILE%
	color 0c
	echo.
	echo  ERROR:
	echo.
	echo  Cannot find 7z.exe. You must edit this script
	echo  and specify the location of 7-Zip before continuing.
	echo.
	echo  Script tried to find it here:
	echo  %SEVENZIP%
	echo.
	pause
	color
	goto end 
)
:: Make sure we can find forfiles.exe
IF NOT EXIST %FORFILES% (
	echo %TIME%   ERROR: Couldn't find forfiles.exe when script was invoked.>> %LOGPATH%\%LOGFILE%
	color 0c
	echo.
	echo  ERROR:
	echo.
	echo  Cannot find forfiles.exe. You must edit this script
	echo  and specify the location of forfiles.exe before continuing.
	echo.
	echo  Script tried to find it here:
	echo  %FORFILES%
	echo.
	pause
	color
	goto end
)


::::::::::::::::::::
:: DECISION POINT ::
::::::::::::::::::::
:decision_point
if '%JOB_TYPE%'=='full' goto %JOB_TYPE%
if '%JOB_TYPE%'=='differential' goto %JOB_TYPE%
if '%JOB_TYPE%'=='restore' goto %JOB_TYPE%
if '%JOB_TYPE%'=='archive_backup_set' goto %JOB_TYPE%
if '%JOB_TYPE%'=='purge_archives' goto %JOB_TYPE%
goto end


:::::::::::::::::
:: Config dump ::
:::::::::::::::::
:config_dump
echo.
echo  Current configuration:
echo.
echo   Script Version:       %SCRIPT_VERSION%
echo   Script Updated:       %SCRIPT_DATE%
echo   Source:               %SOURCE%
echo   Destination:          %DESTINATION%
echo   Staging area:         %STAGING%
echo   Exclusions file:      %EXCLUSIONS_FILE%
echo   Backup prefix:        %BACKUP_PREFIX%
echo   Restores unpacked to: %STAGING%\%BACKUP_PREFIX%_restore
echo   Log file:             %LOGPATH%\%LOGFILE%
echo   Log max size:         %LOG_MAX_SIZE% bytes
echo.
echo  Edit this script with a text editor to customize these options.
echo.
goto end


::::::::::::::::::::::::
:: CREATE FULL BACKUP ::
::::::::::::::::::::::::
:full
:: Check for an exclude file and make sure it exists.
if '%EXCLUSIONS_FILE%'=='' goto full_go
if not exist %EXCLUSIONS_FILE% (
	echo. && echo.>>%LOGPATH%\%LOGFILE%
	call :log "%TIME%   ERROR: An exclusions file was specified but couldn't be found:"
	call :log "           %EXCLUSIONS_FILE%"
	echo. && echo.>>%LOGPATH%\%LOGFILE%
	goto end
)
:full_go
call :log "---------------------------------------------------------------------------------------------------"
call :log "  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% %TIME% by %USERDOMAIN%\%USERNAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "  Script location:"
call :log "   %~dp0%SCRIPT_NAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " Job Options"
call :log "  Job type:        %JOB_TYPE%"
call :log "  Source:          %SOURCE%"
call :log "  Destination:     %DESTINATION%"
call :log "  Staging area:    %STAGING%"
call :log "  Exclusions file: %EXCLUSIONS_FILE%"
call :log "  Backup prefix:   %BACKUP_PREFIX%"
call :log "  Log location:    %LOGPATH%\%LOGFILE%"
call :log "  Log max size:    %LOG_MAX_SIZE% bytes"
call :log "---------------------------------------------------------------------------------------------------"
call :log "%TIME%   Performing full backup of %SOURCE%..."

:: Build archive
call :log "%TIME%   Building archive in staging area %STAGING%..."
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " ------- [ Beginning of 7zip output ] ------- "
if not '%EXCLUSIONS_FILE%'=='' %SEVENZIP% a "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -xr@"%EXCLUSIONS_FILE%" >> %LOGPATH%\%LOGFILE%
if '%EXCLUSIONS_FILE%'=='' %SEVENZIP% a "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" >> %LOGPATH%\%LOGFILE%
call :log " ------- [    End of 7zip output    ] ------- "
echo. && echo.>>%LOGPATH%\%LOGFILE%

:: Report on the build
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Archive built successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Archive built with errors."
)

:: Upload to destination
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   Uploading %BACKUP_PREFIX%_full.7z to %DESTINATION%..."

xcopy "%STAGING%\%BACKUP_PREFIX%_full.7z" "%DESTINATION%\" /Q /J /Y /Z >> %LOGPATH%\%LOGFILE%

:: Report on the upload
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Uploaded full backup to '%DESTINATION%' successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Upload of full backup to '%DESTINATION%' failed."
)

goto done


::::::::::::::::::::::::::::::::
:: CREATE DIFFERENTIAL BACKUP ::
::::::::::::::::::::::::::::::::
:differential
:: Check for an exclude file and make sure it exists.
if '%EXCLUSIONS_FILE%'=='' goto differential_go
if not exist %EXCLUSIONS_FILE% (
	echo. && echo.>>%LOGPATH%\%LOGFILE%
	call :log "%TIME%   ERROR: An exclusions file was specified but couldn't be found:"
	call :log "           %EXCLUSIONS_FILE%"
	echo. && echo.>>%LOGPATH%\%LOGFILE%
	goto end
)
:differential_go
call :log "---------------------------------------------------------------------------------------------------"
call :log "  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% %TIME% by %USERDOMAIN%\%USERNAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "  Script location:"
call :log "   %~dp0%SCRIPT_NAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " Job Options"
call :log "  Job type:        %JOB_TYPE%"
call :log "  Source:          %SOURCE%"
call :log "  Destination:     %DESTINATION%"
call :log "  Staging area:    %STAGING%"
call :log "  Exclusions file: %EXCLUSIONS_FILE%"
call :log "  Backup prefix:   %BACKUP_PREFIX%"
call :log "  Log location:    %LOGPATH%\%LOGFILE%"
call :log "  Log max size:    %LOG_MAX_SIZE% bytes"
call :log "---------------------------------------------------------------------------------------------------"
echo. && echo.>>%LOGPATH%\%LOGFILE%

:: Check for full backup existence
if not exist "%STAGING%\%BACKUP_PREFIX%_full.7z" (
	set JOB_ERROR=1
	call :log "%TIME% ! ERROR: Couldn't find full backup file ^(%BACKUP_PREFIX%_full.7z^). You must create a full backup before a differential can be created."
	goto end
) else (
	call :log "%TIME%   Performing differential backup of %SOURCE%..."
)
		
:: Build archive
:differential_build
call :log "%TIME%   Building archive in staging area %STAGING%..."
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " ------- [ Beginning of 7zip output ] -------"
if not '%EXCLUSIONS_FILE%'=='' %SEVENZIP% u "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -ms=off -mx=9 -xr@"%EXCLUSIONS_FILE%" -t7z -u- -up0q3r2x2y2z0w2!"%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" >> %LOGPATH%\%LOGFILE% 2>&1
if '%EXCLUSIONS_FILE%'=='' %SEVENZIP% u "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -ms=off -mx=9 -t7z -u- -up0q3r2x2y2z0w2!"%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" >> %LOGPATH%\%LOGFILE% 2>&1
call :log " ------- [    End of 7zip output    ] -------"
echo. && echo.>>%LOGPATH%\%LOGFILE%

:: Report on the build
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Archive built successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Archive built with errors."
)


:: Upload to destination
call :log "%TIME%   Uploading %BACKUP_PREFIX%_differential_%CUR_DATE%.7z to %DESTINATION%..."
xcopy "%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" "%DESTINATION%\" /Q /J /Y /Z >> %LOGPATH%\%LOGFILE%

:: Report on the upload
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Uploaded differential file successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Upload of differential file failed."
)

goto done


:::::::::::::::::::::::::::
:: RESTORE FROM A BACKUP ::
:::::::::::::::::::::::::::
:restore
echo.
echo  Restoring from a backup set.
echo.
echo   These backups are available:
echo.
dir /B /A:-D "%STAGING%" 2>NUL
echo.
echo  Enter the filename to restore from EXACTLY as it appears above.
echo  ^(Note: archived backup sets are not shown^)
echo.
:restore_menu
set BACKUP_FILE=
set /p BACKUP_FILE=Filename: 
if %BACKUP_FILE%==exit goto end
echo.
:: Make sure user didn't fat-finger the file name
if not exist "%STAGING%\%BACKUP_FILE%" (
	echo  ! ERROR: That file wasn^'t found. Check your typing and try again. && echo.
	goto restore_menu
)

set CHOICE=y
echo  ! Selected file '%BACKUP_FILE%' 
echo.
set /p CHOICE=Is this correct [y]?: 
	if not %CHOICE%==y echo  Going back to menu... && goto restore_menu
echo.
echo  Great. Press any key to get started.
pause >NUL
echo  ! Starting restoration at %TIME% on %CUR_DATE%
echo    This might take a while, be patient...

:: Test if we're doing a full or differential restore.
if %BACKUP_FILE%==%BACKUP_PREFIX%_full.7z set RESTORE_TYPE=full
if not %BACKUP_FILE%==%BACKUP_PREFIX%_full.7z set RESTORE_TYPE=differential


:restore_go
call :log "---------------------------------------------------------------------------------------------------"
call :log "  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% %TIME% by %USERDOMAIN%\%USERNAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "  Script location:"
call :log "   %~dp0%SCRIPT_NAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " Job Options"
call :log "  Job type:        %JOB_TYPE%"
call :log "  Source:          %SOURCE%"
call :log "  Destination:     %DESTINATION%"
call :log "  Staging area:    %STAGING%"
call :log "  Exclusions file: %EXCLUSIONS_FILE%"
call :log "  Backup prefix:   %BACKUP_PREFIX%"
call :log "  Log location:    %LOGPATH%\%LOGFILE%"
call :log "  Log max size:    %LOG_MAX_SIZE% bytes"
call :log "---------------------------------------------------------------------------------------------------"
echo. && echo.>>%LOGPATH%\%LOGFILE%
:: Detect our backup type and inform the user
if %RESTORE_TYPE%==differential (
	call :log "%TIME%   Restoring from differential backup. Will unpack full backup then differential."
)
if %RESTORE_TYPE%==full (
	call :log "%TIME%   Restoring from full backup."
	call :log "%TIME%   Unpacking full backup..."
)

:: Start the restoration
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " ------- [ Beginning of 7zip output ] -------"
%SEVENZIP% x "%STAGING%\%BACKUP_PREFIX%_full.7z" -y -o"%STAGING%\%BACKUP_PREFIX%_restore\">> %LOGPATH%\%LOGFILE% 2>&1
call :log " ------- [    End of 7zip output    ] -------"
echo. && echo.>>%LOGPATH%\%LOGFILE%

:: Report on the unpack
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Full backup unpacked successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Full backup unpacked with errors."
)
:: If we're just doing a full restore (no differential), then go to the end
if %RESTORE_TYPE%==full goto done

:: Now we unpack our differential file
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   Unpacking differential file %BACKUP_FILE%..."
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " ------- [ Beginning of 7zip output ] -------"
%SEVENZIP% x "%STAGING%\%BACKUP_FILE%" -aoa -y -o"%STAGING%\%BACKUP_PREFIX%_restore\">> %LOGPATH%\%LOGFILE% 2>&1
call :log " ------- [    End of 7zip output    ] -------"
echo. && echo.>>%LOGPATH%\%LOGFILE%

:: Report on the unpack
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Differential file unpacked successfully."
) else (
	:: Something broke!
	set JOB_ERROR=1
	call :log "%TIME% ! Differential file unpacked with errors."
)
goto done


::::::::::::::::::::::::
:: ARCHIVE BACKUP SET :: aka rotate backups
::::::::::::::::::::::::
:archive_backup_set
call :log "---------------------------------------------------------------------------------------------------"
call :log "  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% %TIME% by %USERDOMAIN%\%USERNAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "  Script location:"
call :log "   %~dp0%SCRIPT_NAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " Job Options"
call :log "  Job type:        %JOB_TYPE%"
call :log "  Source:          %SOURCE%"
call :log "  Destination:     %DESTINATION%"
call :log "  Staging area:    %STAGING%"
call :log "  Exclusions file: %EXCLUSIONS_FILE%"
call :log "  Backup prefix:   %BACKUP_PREFIX%"
call :log "  Log location:    %LOGPATH%\%LOGFILE%"
call :log "  Log max size:    %LOG_MAX_SIZE% bytes"
call :log "---------------------------------------------------------------------------------------------------"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   Archiving current backup set to %DESTINATION%\%CUR_DATE%_%BACKUP_PREFIX%_set."
:: Final destination: Make directory, move files
pushd "%DESTINATION%"
mkdir %CUR_DATE%_%BACKUP_PREFIX%_set >> %LOGPATH%\%LOGFILE%
move /Y *.* %CUR_DATE%_%BACKUP_PREFIX%_set >> %LOGPATH%\%LOGFILE%
popd
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   Deleting all copies in the staging area..."
:: Staging area: Delete old files
del /Q /F "%STAGING%\*.7z">> %LOGPATH%\%LOGFILE%

:: Report
call :log "%TIME%   Backup set archived. All unarchived files in staging area were deleted."

goto done


:::::::::::::::::::::::::::::::::::
:: CLEAN UP ARCHIVED BACKUP SETS :: aka delete old sets
:::::::::::::::::::::::::::::::::::
:purge_archives
IF NOT '%DAYS%'=='' goto purge_archives_go

:: List the backup sets
:purge_archives_list
echo.
echo CURRENT BACKUP SETS:
echo.
echo IN STAGING          : ^(%STAGING%^)
echo ---------------------
dir /B /A:D "%STAGING%" 2>&1
echo.
echo.
echo IN LONG-TERM STORAGE: ^(%DESTINATION%^)
echo ---------------------
dir /B /A:D "%DESTINATION%" 2>&1
echo.
:purge_archives_list2
echo.
set DAYS=180
echo Delete backup sets older than how many days? ^(you will be prompted for confirmation^)
set /p DAYS=[%DAYS%]?: 
if %DAYS%==exit goto end
echo.
:: Tell user what will happen
echo THESE BACKUP SETS WILL BE DELETED:
echo ----------------------------------
:: List files that would match. 
:: We have to use PushD to get around forfiles.exe not using UNC paths. pushd automatically assigns the next free drive letter
echo From staging:
pushd "%STAGING%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 2>NUL
popd
echo.
echo From long-term storage:
pushd "%DESTINATION%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 2>NUL
popd
echo.
set HMMM=n
set /p HMMM=Is this okay [%HMMM%]?: 
if /i %HMMM%==n echo. && echo Canceled. Returning to menu. && goto purge_archives_list2
if %DAYS%==exit goto end
echo.
set CHOICE=n
set /p CHOICE=Are you absolutely sure [%CHOICE%]?: 
if not %CHOICE%==y echo. && echo Canceled. Returning to menu. && goto purge_archives_list2
echo.
echo  Okay, starting deletion.

:: Go ahead and do the cleanup. 
:purge_archives_go
call :log "---------------------------------------------------------------------------------------------------"
call :log "  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% %TIME% by %USERDOMAIN%\%USERNAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "  Script location:"
call :log "   %~dp0%SCRIPT_NAME%"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log " Job Options"
call :log "  Job type:        %JOB_TYPE%"
call :log "  Source:          %SOURCE%"
call :log "  Destination:     %DESTINATION%"
call :log "  Staging area:    %STAGING%"
call :log "  Exclusions file: %EXCLUSIONS_FILE%"
call :log "  Backup prefix:   %BACKUP_PREFIX%"
call :log "  Log location:    %LOGPATH%\%LOGFILE%"
call :log "  Log max size:    %LOG_MAX_SIZE% bytes"
call :log "---------------------------------------------------------------------------------------------------"
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   Deleting backup sets that are older than %DAYS% days..."

:: This cleans out the staging area.
:: First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
pushd "%STAGING%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" >> %LOGPATH%\%LOGFILE% 2>NUL
FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
popd

:: This cleans out the destination / long-term storage area.
:: First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
pushd "%DESTINATION%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" >> %LOGPATH%\%LOGFILE% 2>NUL
FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
popd

echo.
:: Report on the cleanup
if %ERRORLEVEL%==0 (
	call :log "%TIME%   Cleanup completed successfully."
) else (
	set JOB_ERROR=1
	call :log "%TIME% ! Cleanup completed with errors."
)
goto done


:::::::::::::::::::::::
:: COMPLETION REPORT ::
:::::::::::::::::::::::
:done
:: One of these displays if the operation was a restore operation
if %RESTORE_TYPE%==full (call :log "%TIME%   Restored full backup to %STAGING%\%BACKUP_PREFIX%")
if %RESTORE_TYPE%==differential (call :log "%TIME%   Restored full and differential backup to %STAGING%\%BACKUP_PREFIX%")
echo. && echo.>>%LOGPATH%\%LOGFILE%
call :log "%TIME%   %SCRIPT_NAME% complete."
if '%JOB_ERROR%'=='1' call :log "%TIME% ! Note: Script exited with errors. Maybe check the log."


:end
:: Clean up our temp exclude file
if exist %TEMP%\DEATH_BY_HAMSTERS.txt del /F /Q %TEMP%\DEATH_BY_HAMSTERS.txt

goto :eof


:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:: Since no new variable names are defined, there's no need for SETLOCAL.
:: The %1 reference contains the first argument passed to the function. When the
:: whole argument string is wrapped in double quotes, it is sent as an argument.
:: The tilde syntax (%~1) removes the double quotes around the argument.
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof


:parse_cmdline_args
for %%i in (%1) do (
	if /i '%%i'=='/f' set JOB_TYPE=full
	if /i '%%i'=='-f' set JOB_TYPE=full
	if /i '%%i'=='/d' set JOB_TYPE=differential
	if /i '%%i'=='-d' set JOB_TYPE=differential
	if /i '%%i'=='/r' set JOB_TYPE=restore
	if /i '%%i'=='-r' set JOB_TYPE=restore
	if /i '%%i'=='/a' set JOB_TYPE=archive_backup_set
	if /i '%%i'=='-a' set JOB_TYPE=archive_backup_set
	if /i '%%i'=='/p' set JOB_TYPE=purge_archives
	if /i '%%i'=='-p' set JOB_TYPE=purge_archives
	if /i '%%i'=='' set JOB_TYPE=help
	if /i '%%i'=='/?' set JOB_TYPE=help
	if /i '%%i'=='-?' set JOB_TYPE=help
	if /i '%%i'=='-h' set JOB_TYPE=help
	if /i '%%i'=='--help' set JOB_TYPE=help
	if /i '%%i'=='/c' goto config_dump
	if /i '%%i'=='-c' goto config_dump
	)
goto :eof


ENDLOCAL
:eof
color
