:: Purpose:       Remove the "Libraries" icon that appears on the desktop after certain Windows Updates are applied
:: Requirements:  Run this script as an Administrator
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       1.0.0   Initial write
SETLOCAL


:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::
:: No user-set variables for this script

:: --------------------------- Don't edit anything below this line --------------------------- ::

:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
%SystemDrive% && cls
set SCRIPT_VERSION=1.0.0
set SCRIPT_UPDATED=2015-08-27
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

title [Remove desktop "Libraries" Icon v%SCRIPT_VERSION%]

:::::::::::::
:: EXECUTE ::
:::::::::::::
reg delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{031E4825-7B94-4dc3-B131-E946B44C8DD5} /f
