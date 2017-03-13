:: Loops through a comparison of %RANDOM% and any time %RANDOM% is less than 3, adds a point to the "tick counter"
:: At STOPTIME the script terminates and displays how many tick hits there were (how many times %RANDOM% was less than 3)

:: VARIABLES
set LOG=%userprofile%\root\unsorted\lottery.log
set STOPTIME=14:55


:: PREP
@echo off
set LAUNCH_TIME=%TIME%
echo  %LAUNCH_TIME%   Contest start (%username%)
setlocal EnableDelayedExpansion


:: TICK LOOP
:loop
if %time:0,5% equ %STOPTIME% goto :done
set /a "ITERATIONS=%ITERATIONS%+1"
if %RANDOM% LSS 3 (
	color 0a
	set /a "HITS=%HITS%+1"
	echo  %TIME%   TICK HIT ^(!HITS! hits, %ITERATIONS% iterations^)
	)
goto :loop


:: COMPLETION
:done
echo  %TIME% ^! Time limit reached
echo                TOTAL ITERATIONS: %ITERATIONS%
echo                TOTAL HITS:       %HITS%
echo LAUNCH: %LAUNCH_TIME%  FINISH: %TIME%  ITERATIONS: %ITERATIONS%  HITS: %HITS%>>%LOG%
pause
