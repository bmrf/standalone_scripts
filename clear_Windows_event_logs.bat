:: Purpose:       Clears all event logs on a Windows system
:: Requirements:  Administrative rights
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: History:       1.0.0   Initial write

::::::::::
:: Prep :: -- Don't change anything in this section
::::::::::
@echo off
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2014-06-10
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%
echo.
echo  Clearing event logs...
echo.

:: Perform the clear
for /f %%x in ('wevtutil el') do wevtutil cl "%%x"

:: finished
echo.
echo  It's done.
echo.
pause