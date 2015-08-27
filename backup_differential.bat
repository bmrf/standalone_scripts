:: Purpose:       Rotating differential backup using 7-Zip for compression.
:: Requirements:  - forfiles.exe from Microsoft
::                - 7-Zip
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: Version:       1.5.1 * Add standard boilerplate comments
::                1.5.0 * Overhauled Date/Time conversion so we can handle ALL versions of Windows using ANY local date-time format
::                1.4.9 * Reworked CUR_DATE variable to handle more than one Date/Time format
::                        Can now handle all Windows date formats
::                1.4.8 + Added SCRIPT_UPDATED variable to timestamp last update of the script
::                1.4.7 - Removed some redundant %TIME% stamps in the logs, under the Cleanup section
::                1.4.6 + Added two additional "help" flags: "-h" and "--help"
::                1.4.5 + Added better instructions for what variables can be set to
::                1.4.4 + Added quotes around variables that could contain spaces in a few places
::                      * Some comment cleanup, and some logging formatting cleanup.
::                1.4.3 / Tweaked logging to only display exclamation point if there was an error
::                      / Tweaked logging to display time correctly (no extra spaces)
::                1.4.2 / Some logging tweaks
::                1.4.1 / Some logging tweaks
::                1.4   + Added quotes around SOURCE variable that were missing in a couple places
::                1.3   * Fixed backup archiving - wasn't rotating properly on network paths. We use pushd to get around this
::                      - Added "-s" option to show job options that the script WOULD execute with
::                      - Major overhaul of code order and logic. Stuff should break less now.
::                      - Many fixes to exclusions file checking
::                1.2   - Fixed problem with cleaning backups. Now cleans staging area and long-term destination area. 
::                        Normally an archive (-a) switch cleans the staging area, but now the -c switch does as well, just in case.
::                      - Also fixed issue with forfiles.exe not being able to read UNC paths. We use pushd to get around this.
::                        Pushd auto-assigns the next available drive letter to a UNC path, then discards it when we use popd.
::                1.1   - Added option to use an exclude file to specify files/folders to exclude from the backup
::                1.0b    Some tweaks to logging
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
::                 -c   clean up (delete) old backup sets from staging and destination. If you specify a number 
::                      of days after the command it will run automatically without any confirmation. Be careful with this!
::                 -s   show job options (show what the variables are set to)

:: Important:     If you want to set this script up in Windows Task Scheduler, be aware that Task Scheduler
::                can't use mapped network drives (X:\, Z:\, etc) when it is set to "Run even if user isn't logged on."
::                The task will simply fail to do anything (because Scheduler can't see the drives). To work around this use
::                UNC paths instead (\\server\backup_folder etc) for your source, destination, and staging areas.

:: TODO:          1. Add md5sum checksum file in the backup directory (md5sum each full and diff and store in a file)


:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
SETLOCAL
@echo off && cls
set SCRIPT_VERSION=1.5.1
set SCRIPT_UPDATED=2015-08-27
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
set JOB_TYPE=%1
set JOB_ERROR=0
set DAYS=%2
set RESTORE_TYPE=NUL
set SCRIPT_NAME=%0%

:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "c:\directory\path"       )
::  * NO trailing slashes on the path! (bad:   c:\directory\            )
::  * Spaces are okay                  (okay:  c:\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )
:: Specify the folder you want to back up here.
set SOURCE=R:\

:: Work area where everything is stored while compressing. Should be a fast drive or something that can handle a lot of writes
:: Recommend not using a network share unless it's Gigabit or faster.
set STAGING=P:\backup_staging

:: This is the final, long-term destination for your backup after it is compressed.
set DESTINATION=\\SERVERNAME\backup\path

:: If you want to customize the prefix of the backup files, do so here. Don't use any special characters (like underscores)
:: The script automatically suffixes an underscore to this name. Recommend not changing this unless you really need to.
::  * Spaces are NOT OKAY to use here!
set BACKUP_PREFIX=backup

:: OPTIONAL: If you want to exclude some files or folders, you can specify your exclude file here. The exclude file is a list of 
:: files or folders (wildcards in the form of * are allowed and recommended) to exclude.
:: If you specify a file here and the script can't find it, it will abort.
:: If you leave this blank, the script won't ignore any files.
set EXCLUSIONS_FILE=c:\scripts\backup_differential_excludes.txt

:: Log settings. Max size is how big (in bytes) the log can be before it is archived. 1048576 bytes is one megabyte
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_%BACKUP_PREFIX%_differential.log
set LOG_MAX_SIZE=104857600

:: Location of 7-Zip and forfiles.exe
set SEVENZIP="C:\Program Files\7-Zip\7z.exe"
set FORFILES=%WINDIR%\system32\forfiles.exe


:: --------------------------- Don't edit anything below this line --------------------------- ::


::::::::::::::::::::::::::::
:: JOB TYPE DETERMINATION ::
::::::::::::::::::::::::::::
:job_type_determination
if '%JOB_TYPE%'=='' set JOB_TYPE=help
if '%JOB_TYPE%'=='/?' set JOB_TYPE=help
if '%JOB_TYPE%'=='-?' set JOB_TYPE=help
if '%JOB_TYPE%'=='-h' set JOB_TYPE=help
if '%JOB_TYPE%'=='--help' set JOB_TYPE=help
if /i '%1'=='/f' set JOB_TYPE=full
if /i '%1'=='-f' set JOB_TYPE=full
if /i '%1'=='/d' set JOB_TYPE=differential
if /i '%1'=='-d' set JOB_TYPE=differential
if /i '%1'=='/r' set JOB_TYPE=restore
if /i '%1'=='-r' set JOB_TYPE=restore
if /i '%1'=='/a' set JOB_TYPE=archive_backup_set
if /i '%1'=='-a' set JOB_TYPE=archive_backup_set
if /i '%1'=='/c' set JOB_TYPE=cleanup_archives
if /i '%1'=='-c' set JOB_TYPE=cleanup_archives
if /i '%1'=='/s' goto show_options
if /i '%1'=='-s' goto show_options
:: If none of the above were specified then show the help screen
if %JOB_TYPE%==help (
	echo. 
	echo   %SCRIPT_NAME% v%SCRIPT_VERSION%
	echo.
	echo   Usage: %SCRIPT_NAME% ^< -f ^| -d ^| -r ^| -a ^| -c ^[days^] ^>
	echo.
	echo   Flags:
	echo    -f:  create a full backup
	echo    -d:  create a differential backup ^(requires an existing full backup^)
	echo    -r:  restore from a backup ^(extracts to %STAGING%\%BACKUP_PREFIX%_restore^)
	echo    -a:  archive the current backup set. This will:
	echo           1. move all .7z files located in:
	echo              %DESTINATION% 
	echo              into a dated archive folder.
	echo           2. purge ^(delete^) all copies in the staging area ^(%STAGING%^)
	echo    -c:  clean ^(AKA delete^) archived backup sets from staging and long-term storage.
	echo         Optionally specify number of days to run automatically. Be careful with this!
	echo         Note that this requires a previously-archived backup set ^(-a option^)
	echo    -s:  show job options ^(show what parameters the script WOULD execute with^)
	echo.
	echo   Edit this script before running it to specify your source, destination, and work directories.
	goto end
	)


:::::::::::::::::::::::
:: LOG FILE HANDLING ::
:::::::::::::::::::::::
:log
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
		cls
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
		cls
		goto end 
		)
:: Make sure we can find forfiles.exe
IF NOT EXIST %FORFILES% (
		echo %TIME%   ERROR: Couldn't find forfiles.exe when script was invoked.>> %LOGPATH%\%LOGFILE%
		cls
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
		cls
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
if '%JOB_TYPE%'=='cleanup_archives' goto %JOB_TYPE%
goto end


::::::::::::::::::::::
:: SHOW JOB OPTIONS ::
::::::::::::::::::::::
:show_options
echo.
echo  Current configuration:
echo.
echo   Script Version:       %SCRIPT_VERSION%
echo   Script Updated:       %SCRIPT_UPDATED%
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
IF NOT EXIST %EXCLUSIONS_FILE% (
		echo.
		echo %TIME%   ERROR: An exclusions file was specified but couldn't be found:>> %LOGPATH%\%LOGFILE%
		echo                %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
		echo %TIME%   ERROR: An exclusions file was specified but couldn't be found:
		echo                %EXCLUSIONS_FILE%
		goto end
		)
:full_go
echo.
echo.>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% at%TIME% by %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Script location:  %~dp0\%SCRIPT_NAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Job Options>> %LOGPATH%\%LOGFILE%
echo   Job type:        Full backup>> %LOGPATH%\%LOGFILE%
echo   Source:          %SOURCE%>> %LOGPATH%\%LOGFILE%
echo   Destination:     %DESTINATION%>> %LOGPATH%\%LOGFILE%
echo   Staging area:    %STAGING%>> %LOGPATH%\%LOGFILE%
echo   Exclusions file: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
echo   Backup prefix:   %BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
echo   Log location:    %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo   Log max size:    %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo %TIME%   Performing full backup of %SOURCE%...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Performing full backup of %SOURCE%...

:: Build archive
echo.
echo %TIME%   Building archive in staging area %STAGING%...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Building archive in staging area %STAGING%...
echo.>> %LOGPATH%\%LOGFILE%
echo ------- [ Beginning of 7zip output ] ------->> %LOGPATH%\%LOGFILE% 2>&1
if not '%EXCLUSIONS_FILE%'=='' %SEVENZIP% a "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -xr@"%EXCLUSIONS_FILE%" >> %LOGPATH%\%LOGFILE%
if '%EXCLUSIONS_FILE%'=='' %SEVENZIP% a "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" >> %LOGPATH%\%LOGFILE%
echo ------- [    End of 7zip output    ] ------->> %LOGPATH%\%LOGFILE% 2>&1
echo.>> %LOGPATH%\%LOGFILE%
echo.

:: Report on the build
if %ERRORLEVEL%==0 (
		echo %TIME%   Archive built successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Archive built successfully.
		)
if not %ERRORLEVEL%==0 (
		set JOB_ERROR=1
		echo %TIME% ! Archive built with errors.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Archive built with errors.
		)
:: Upload to destination
echo.
echo %TIME%   Uploading %BACKUP_PREFIX%_full.7z to %DESTINATION%...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Uploading %BACKUP_PREFIX%_full.7z to %DESTINATION%...
echo.
echo.>> %LOGPATH%\%LOGFILE%
xcopy "%STAGING%\%BACKUP_PREFIX%_full.7z" "%DESTINATION%\" /Q /J /Y /Z >> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%

:: Report on the upload
if %ERRORLEVEL%==0 (
		echo %TIME%   Uploaded full backup to '%DESTINATION%' successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Uploaded full backup to '%DESTINATION%' successfully.
		) ELSE (
		set JOB_ERROR=1
		echo %TIME% ! Upload of full backup to '%DESTINATION%' failed.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Upload of full backup to '%DESTINATION%' failed.
		)

goto done


::::::::::::::::::::::::::::::::
:: CREATE DIFFERENTIAL BACKUP ::
::::::::::::::::::::::::::::::::
:differential
:: Check for an exclude file and make sure it exists.
if '%EXCLUSIONS_FILE%'=='' goto differential_go
IF NOT EXIST %EXCLUSIONS_FILE% (
		echo %TIME%   An exclusions file was specified but couldn't be found. Aborting.>> %LOGPATH%\%LOGFILE%
		echo           Looked here: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
		echo %TIME%   An exclusions file was specified but couldn't be found. Aborting.
		echo           Looked here: %EXCLUSIONS_FILE%
		goto end
		)
:differential_go
echo.>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% at%TIME% by %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Script location:  %SCRIPT_NAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Job Options>> %LOGPATH%\%LOGFILE%
echo   Job type:        Differential backup>> %LOGPATH%\%LOGFILE%
echo   Source:          %SOURCE%>> %LOGPATH%\%LOGFILE%
echo   Destination:     %DESTINATION%>> %LOGPATH%\%LOGFILE%
echo   Staging area:    %STAGING%>> %LOGPATH%\%LOGFILE%
echo   Exclusions file: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
echo   Backup prefix:   %BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
echo   Log location:    %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo   Log max size:    %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo.
:: Check for full backup existence
if not exist "%STAGING%\%BACKUP_PREFIX%_full.7z" (
		set JOB_ERROR=1
		echo %TIME% ! ERROR: Couldn't find full backup file ^(%BACKUP_PREFIX%_full.7z^). You must create a full backup before a differential can be created.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! ERROR: Couldn't find full backup file ^(%BACKUP_PREFIX%_full.7z^). You must create a full backup before a differential can be created.
		goto end
		) ELSE (
		:: Backup existed, so go ahead
		echo %TIME%   Performing differential backup of %SOURCE%...>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Performing differential backup of %SOURCE%...
		)
		
:: Build archive
:differential_build
echo.
echo %TIME%   Building archive in staging area %STAGING%...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Building archive in staging area %STAGING%...
echo.>> %LOGPATH%\%LOGFILE%
echo ------- [ Beginning of 7zip output ] ------->> %LOGPATH%\%LOGFILE% 2>&1
if not '%EXCLUSIONS_FILE%'=='' %SEVENZIP% u "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -ms=off -mx=9 -xr@"%EXCLUSIONS_FILE%" -t7z -u- -up0q3r2x2y2z0w2!"%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" >> %LOGPATH%\%LOGFILE% 2>&1
if '%EXCLUSIONS_FILE%'=='' %SEVENZIP% u "%STAGING%\%BACKUP_PREFIX%_full.7z" "%SOURCE%" -ms=off -mx=9 -t7z -u- -up0q3r2x2y2z0w2!"%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" >> %LOGPATH%\%LOGFILE% 2>&1
echo ------- [    End of 7zip output    ] ------->> %LOGPATH%\%LOGFILE% 2>&1
echo.>> %LOGPATH%\%LOGFILE%
echo.
:: Report on the build
if %ERRORLEVEL%==0 (
		echo %TIME%   Archive built successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Archive built successfully.
		)
if not %ERRORLEVEL%==0 (
		set JOB_ERROR=1
		echo %TIME% ! Archive built with errors.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Archive built with errors.
		)


:: Upload to destination
echo.
echo %TIME%   Uploading %BACKUP_PREFIX%_differential_%CUR_DATE%.7z to %DESTINATION%... >> %LOGPATH%\%LOGFILE%
echo %TIME%   Uploading %BACKUP_PREFIX%_differential_%CUR_DATE%.7z to %DESTINATION%...
echo.>> %LOGPATH%\%LOGFILE%
xcopy "%STAGING%\%BACKUP_PREFIX%_differential_%CUR_DATE%.7z" "%DESTINATION%\" /Q /J /Y /Z >> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
:: Report on the upload
if %ERRORLEVEL%==0 (
		echo %TIME%   Uploaded differential file successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Uploaded differential file successfully.
		)

if not %ERRORLEVEL%==0 (
		set JOB_ERROR=1
		echo %TIME% ! Upload of differential file failed.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Upload of differential file failed.
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
echo  Enter the filename to restore from exactly as it appears above.
echo  ^(Note: archived backup sets are not shown^)
echo.
:restore_menu
set BACKUP_FILE=
set /p BACKUP_FILE=Filename: 
if %BACKUP_FILE%==exit goto end
echo.
:: Make sure user didn't fat-finger the file name
if not exist "%STAGING%\%BACKUP_FILE%" (
		echo  ! ERROR: That file wasn^'t found. Check your typing and try again. && echo. && goto restore_menu
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
echo  ! Starting restoration at%TIME% on %CUR_DATE%
echo    This might take a while, be patient...

:: Test if we're doing a full or differential restore.
if %BACKUP_FILE%==%BACKUP_PREFIX%_full.7z set RESTORE_TYPE=full
if not %BACKUP_FILE%==%BACKUP_PREFIX%_full.7z set RESTORE_TYPE=differential


:restore_go
echo.>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% at%TIME% by %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Script location:  %SCRIPT_NAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Job Options>> %LOGPATH%\%LOGFILE%
echo   Job type:        %RESTORE_TYPE% restore>> %LOGPATH%\%LOGFILE%
echo   Source:          %STAGING%\%BACKUP_PREFIX%_full.7z>> %LOGPATH%\%LOGFILE%
echo   Destination:     %STAGING%\%BACKUP_PREFIX%\>> %LOGPATH%\%LOGFILE%
echo   Staging area:    %STAGING%>> %LOGPATH%\%LOGFILE%
echo   Exclusions file: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
echo   Backup prefix:   %BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
echo   Log location:    %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo   Log max size:    %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.
:: Detect our backup type and inform the user
if %RESTORE_TYPE%==differential (
		echo %TIME%   Restoring from differential backup. Will unpack full backup then differential.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Restoring from differential backup. Will unpack full backup then differential.
		)
if %RESTORE_TYPE%==full (
		echo %TIME%   Restoring from full backup.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Restoring from full backup.
		echo %TIME%   Unpacking full backup...>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Unpacking full backup...
		)

:: Start the restoration
echo.>> %LOGPATH%\%LOGFILE%
echo.
echo ------- [ Beginning of 7zip output ] ------->> %LOGPATH%\%LOGFILE% 2>&1
%SEVENZIP% x "%STAGING%\%BACKUP_PREFIX%_full.7z" -y -o"%STAGING%\%BACKUP_PREFIX%_restore\">> %LOGPATH%\%LOGFILE% 2>&1
echo ------- [    End of 7zip output    ] ------->> %LOGPATH%\%LOGFILE% 2>&1
:: Report on the unpack
if %ERRORLEVEL%==0 (
		echo %TIME%   Full backup unpacked successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Full backup unpacked successfully.
		)
if not %ERRORLEVEL%==0 (
		set JOB_ERROR=1
		echo %TIME% ! Full backup unpacked with errors.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Full backup unpacked with errors.
		)
:: If we're just doing a full restore (no differential), then go to the end
if %RESTORE_TYPE%==full goto done
		
:: Now we unpack our differential file
echo.
echo %TIME%   Unpacking differential file %BACKUP_FILE%...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Unpacking differential file %BACKUP_FILE%...
echo.>> %LOGPATH%\%LOGFILE%
echo ------- [ Beginning of 7zip output ] ------->> %LOGPATH%\%LOGFILE% 2>&1
%SEVENZIP% x "%STAGING%\%BACKUP_FILE%" -aoa -y -o"%STAGING%\%BACKUP_PREFIX%_restore\">> %LOGPATH%\%LOGFILE% 2>&1
echo ------- [    End of 7zip output    ] ------->> %LOGPATH%\%LOGFILE% 2>&1
echo.
:: Report on the unpack
if %ERRORLEVEL%==0 (
		echo %TIME%   Differential file unpacked successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Differential file unpacked successfully.
		) ELSE (
		:: Something broke!
		set JOB_ERROR=1
		echo %TIME% ! Differential file unpacked with errors.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Differential file unpacked with errors.
		)
goto done


::::::::::::::::::::::::
:: ARCHIVE BACKUP SET :: aka rotate backups
::::::::::::::::::::::::
:archive_backup_set
echo.>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% at%TIME% by %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Script location:  %SCRIPT_NAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Job Options>> %LOGPATH%\%LOGFILE%
echo   Job type:        Archive/rotate backup set>> %LOGPATH%\%LOGFILE%
echo   Source:          %SOURCE%>> %LOGPATH%\%LOGFILE%
echo   Destination:     %DESTINATION%>> %LOGPATH%\%LOGFILE%
echo   Staging area:    %STAGING%>> %LOGPATH%\%LOGFILE%
echo   Exclusions file: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
echo   Backup prefix:   %BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
echo   Log location:    %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo   Log max size:    %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo %TIME%   Archiving current backup set to %DESTINATION%\%CUR_DATE%_%BACKUP_PREFIX%_set.>> %LOGPATH%\%LOGFILE%
echo %TIME%   Archiving current backup set to %DESTINATION%\%CUR_DATE%_%BACKUP_PREFIX%_set.
:: Final destination: Make directory, move files
pushd "%DESTINATION%"
mkdir %CUR_DATE%_%BACKUP_PREFIX%_set >> %LOGPATH%\%LOGFILE%
move /Y *.* %CUR_DATE%_%BACKUP_PREFIX%_set >> %LOGPATH%\%LOGFILE%
popd
echo.
echo %TIME%   Deleting all copies in the staging area...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Deleting all copies in the staging area...
:: Staging area: Delete old files
del /Q /F "%STAGING%\*.7z">> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo.

:: Report
echo.>> %LOGPATH%\%LOGFILE%
echo %TIME%   Backup set archived. All unarchived files in staging area were deleted.>> %LOGPATH%\%LOGFILE%
echo %TIME%   Backup set archived. All unarchived files in staging area were deleted.
echo.>> %LOGPATH%\%LOGFILE%
goto done


:::::::::::::::::::::::::::::::::::
:: CLEAN UP ARCHIVED BACKUP SETS :: aka delete old sets
:::::::::::::::::::::::::::::::::::
:cleanup_archives
IF NOT '%DAYS%'=='' goto cleanup_archives_go

:: List the backup sets
:cleanup_archives_list
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
:cleanup_archives_list2
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
if /i %HMMM%==n echo. && echo Canceled. Returning to menu. && goto cleanup_archives_list2
if %DAYS%==exit goto end
echo.
set CHOICE=n
set /p CHOICE=Are you absolutely sure [%CHOICE%]?: 
if not %CHOICE%==y echo. && echo Canceled. Returning to menu. && goto cleanup_archives_list2
echo.
echo  Okay, starting deletion.

:: Go ahead and do the cleanup. 
:cleanup_archives_go
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo  Differential Backup Script v%SCRIPT_VERSION% - initialized %CUR_DATE% at%TIME% by %USERDOMAIN%\%USERNAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo  Script location:  %SCRIPT_NAME%>> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo   Job type:        Delete archived backup sets older than %DAYS% days.>> %LOGPATH%\%LOGFILE%
echo   Source:          %SOURCE%>> %LOGPATH%\%LOGFILE%
echo   Destination:     %DESTINATION%>> %LOGPATH%\%LOGFILE%
echo   Staging area:    %STAGING%>> %LOGPATH%\%LOGFILE%
echo   Exclusions file: %EXCLUSIONS_FILE%>> %LOGPATH%\%LOGFILE%
echo   Backup prefix:   %BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
echo   Log location:    %LOGPATH%\%LOGFILE%>> %LOGPATH%\%LOGFILE%
echo   Log max size:    %LOG_MAX_SIZE% bytes>> %LOGPATH%\%LOGFILE%
echo --------------------------------------------------------------------------------------------------->> %LOGPATH%\%LOGFILE%
echo.>> %LOGPATH%\%LOGFILE%
echo.
echo %TIME%   Deleting backup sets that are older than %DAYS% days...>> %LOGPATH%\%LOGFILE%
echo %TIME%   Deleting backup sets that are older than %DAYS% days...

:: This cleans out the staging area.
:: First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
pushd "%STAGING%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" >> %LOGPATH%\%LOGFILE%
FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
popd

:: This cleans out the destination / long-term storage area.
:: First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
pushd "%DESTINATION%"
FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" >> %LOGPATH%\%LOGFILE%
FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
popd

echo.
:: Report on the cleanup
if %ERRORLEVEL%==0 (
		echo %TIME%   Cleanup completed successfully.>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Cleanup completed successfully.
		)
if not %ERRORLEVEL%==0 (
		set JOB_ERROR=1
		echo %TIME% ! Cleanup completed with errors.>> %LOGPATH%\%LOGFILE%
		echo %TIME% ! Cleanup completed with errors.
		)
goto done


:::::::::::::::::::::::
:: COMPLETION REPORT ::
:::::::::::::::::::::::
:done
:: One of these displays if the operation was a restore operation
if %RESTORE_TYPE%==full (
		echo %TIME%   Restored full backup to %STAGING%\%BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Restored full backup to %STAGING%\%BACKUP_PREFIX%
		)

if %RESTORE_TYPE%==differential (
		echo.
		echo %TIME%   Restored full and differential backup to %STAGING%\%BACKUP_PREFIX%>> %LOGPATH%\%LOGFILE%
		echo %TIME%   Restored full and differential backup to %STAGING%\%BACKUP_PREFIX%
		)

echo.
echo %TIME%   %SCRIPT_NAME% complete.>> %LOGPATH%\%LOGFILE%
echo %TIME%   %SCRIPT_NAME% complete.
if '%JOB_ERROR%'=='1' echo. && echo %TIME% ! Note: Script exited with errors.>> %LOGPATH%\%LOGFILE%
if '%JOB_ERROR%'=='1' echo. && echo %TIME% ! Note: Script exited with errors. Maybe check the log.

:end
:: Clean up our temp exclude file
if exist %TEMP%\DEATH_BY_HAMSTERS.txt del /F /Q %TEMP%\DEATH_BY_HAMSTERS.txt
ENDLOCAL
