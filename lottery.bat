:: Loops through a comparison of %RANDOM% and any time %RANDOM% is less than 3, adds a point to the "tick counter"
:: At *2:30 the script terminates and displays how many tick hits there were (how many times %RANDOM% was less than 3)

@echo off
set LAUNCH_TIME=%TIME%
echo  %LAUNCH_TIME%   Contest start (%username%)
setlocal EnableDelayedExpansion

:: TICK LOOP
:s
if %time:~1,3% equ 2:5 goto :done
set /a "ITERATIONS=%ITERATIONS%+1"
if %RANDOM% LSS 3 (
	color 0a
	set /a "HITS=%HITS%+1"
	echo  %TIME%   TICK HIT ^(hits: !HITS! iterations: %ITERATIONS%^)
	)
goto :s


:done
echo  %TIME% ^! Time limit reached
echo           TOTAL ITERATIONS: %ITERATIONS%
echo           TOTAL HITS:       %HITS%
pause
