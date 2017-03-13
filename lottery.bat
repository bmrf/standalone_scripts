:: Loops through a comparison of %RANDOM% and any time %RANDOM% is less than 3, adds a point to the "tick counter"
:: At *2:30 the script terminates and displays how many tick hits there were (how many times %RANDOM% was less than 3)

@echo off
set LAUNCH_TIME=%TIME%
echo  %LAUNCH_TIME%   Contest start (%username%)
setlocal EnableDelayedExpansion
:s
if %RANDOM% LSS 3 (
	color 0a
	set /a "WINS=%WINS%+1"
	echo  %TIME%   TICK HIT ^(hits: !WINS!^)
	if %time:~1,3% equ 2:3 goto :done
	)
goto :s


:done
echo  %TIME% ^! Time limit reached
echo  %TIME%   TOTAL HITS: %WINS%
pause
