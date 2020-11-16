:: Purpose:         Performs an update-backup operation on two folders, mirroring changes from one to the other
:: Requirements:    None
:: Author:          reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:         1.0.0
:: Usage:           run from a Windows shortcut or command-line. First argument is source, second argument is destination, third argument (if present, "yes") skips a purge backup (don't delete extra files)

::					--Switches Used--
:: --robocopy--
:: /V			Verbose logging
:: /L			List files but don't write/copy/touch them
:: /PURGE		Delete files that no longer exist in source
:: /E			Copy all directories (including sub-dirs)
:: /LOG+:		Stick a logfile here [ path ], and append+ any new stuff to the end
:: /XD " "		Exlude any directory containing this string [ "string" ]
:: /COPY: DAT	Copy only Data (the file), attributes (read-only, etc), and Timestamps
:: /NP			No progress (don't display progress)
:: /MT:8		Use 8 threads to copy
::
:: --findstr--
:: /I			Search is NOT case-sensitive
:: /V			Include any line that does NOT match the search string (I.E. "don't find this")
:: "john doe"	Multiple search strings separated by a space

:: Prepare the environment
@echo off
pushd %~dp0

:: Source and destination
set SOURCE=%1
set DESTINATION=%2
set SKIP_PURGE=no
if "%3"=="yes" (set SKIP_PURGE=yes)


:: Log file
set LOGPATH=%SystemDrive%\logs
set LOGFILE=simple_backup.log


:: Build log directories if they don't exist
for %%D in ("%LOGPATH%","%DESTINATION%") do (
	if not exist %%D mkdir %%D
)




cls
title Backing up %source%...
echo.
echo  %TIME% Backup started.
echo.
echo   Source:      %SOURCE%
echo   Destination: %DESTINATION%
echo.

::
:: Do the copy
::
title Copying files...
:: robocopy "%source%" "%destination%" /E /NP /PURGE /ZB /LOG:"%LOGPATH%\%LOGFILE%"

if %SKIP_PURGE%==yes (
	robocopy "%source%" "%destination%" /E /ZB /FFT /MT:8 /R:2 /W:5
) else (
	robocopy "%source%" "%destination%" /E /PURGE /ZB /FFT /MT:8 /R:2 /W:5
)
