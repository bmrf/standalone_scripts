:: Purpose:       Flushes the Windows printer queue when it's full and stuck
:: Requirements:  Must run as administrator
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       1.0.1 * Reworked CUR_DATE variable to handle more than one Date/Time format
::                        Can now handle all Windows date formats
::                1.0.0   Initial write


::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
@echo off
set SCRIPT_VERSION=1.0.1
set SCRIPT_UPDATED=2014-01-27
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
cls

:::::::::::::::
:: VARIABLES :: -- Set these to your desired values
:::::::::::::::
:: No user-set variables in this script


:::::::::::::::
:: Execution ::
:::::::::::::::
echo Stopping print spooler.
echo.
net stop spooler
echo Deleting old print jobs...
echo.
FOR %%i IN (%systemroot%\system32\spool\printers\*.*) DO DEL %%i
echo Starting print spooler.
echo.
net start spooler
