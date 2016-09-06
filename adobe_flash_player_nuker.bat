:: Purpose:       Removes all versions of Adobe Flash Player from a system. Saves a log to c:\logs by default
:: Requirements:  Run this script with an admin account
:: Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
:: History:       2.0.0 + Complete overhaul to more closely match the effectiveness of the Java Runtime Nuker script
SETLOCAL


:::::::::::::::
:: VARIABLES :: ---- Set these to your desired values. The defaults should work fine though ------ ::
:::::::::::::::
:: Rules for variables:
::  * NO quotes!                       (bad:  "%SYSTEMDRIVE%\directory\path"       )
::  * NO trailing slashes on the path! (bad:   %SYSTEMDRIVE%\directory\            )
::  * Spaces are okay                  (okay:  %SYSTEMDRIVE%\my folder\with spaces )
::  * Network paths are okay           (okay:  \\server\share name      )
::                                     (       \\172.16.1.5\share name  )

:: Log location and name. Do not use trailing slashes (\)
set LOGPATH=%SystemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_adobe_flash_player_nuker.log

:: Force-close processes that might be using Flash? Recommend leaving this set to 'yes' unless you
:: specifically want to abort the script if the target machine might possibly be using Flash.
:: If you change this to 'no', the script will exit with an error code if it thinks Flash could be in use.
set FORCE_CLOSE_PROCESSES=yes
:: Exit code to use when FORCE_CLOSE_PROCESSES is "no" and a potential Flash-dependent process is detected
set FORCE_CLOSE_PROCESSES_EXIT_CODE=1618



:: =============================================================================================== ::
:: ======  Think of everything below this line like a feral badger: Look, but Do Not Touch  ====== ::
:: =============================================================================================== ::



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
set SCRIPT_VERSION=2.0.0
set SCRIPT_UPDATED=2016-09-06
:: Get the date into ISO 8601 standard format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%

:: This is useful if we start from a network share; converts CWD to a drive letter
pushd "%~dp0"

:: Create the log directory if it doesn't exist
if not exist %LOGPATH% mkdir %LOGPATH%

:: Check if we're on XP. This affects some commands later, because XP uses slightly
:: different binaries for reg.exe and various other Windows utilities
set OS_VERSION=OTHER
ver | find /i "XP" >NUL
IF %ERRORLEVEL%==0 set OS_VERSION=XP

title Flash Player Nuker v%SCRIPT_VERSION% (%SCRIPT_UPDATED%)


:::::::::::::::::::::::::::
:: FORCE-CLOSE PROCESSES :: -- Do we want to kill Flash before running? If so, this is where it happens
:::::::::::::::::::::::::::
if %FORCE_CLOSE_PROCESSES%==yes (
	REM Kill all browsers and running Flash instances
	call :log "%CUR_DATE% %TIME%   Looking for and closing all running browsers and Flash instances..."
	if %OS_VERSION%==XP (
		REM XP version of the task killer
		REM this loop contains the processes we should kill
		for %%i in (battle,chrome,firefox,flash,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
			echo     Searching for %%i.exe...
			%WINDIR%\system32\tskill.exe /a /v %%i* >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
	) else (
		REM 7/8/2008/2008R2/2012/etc version of the task killer
		REM this loop contains the processes we should kill
		FOR %%i in (battle.net,chrome,firefox,flash,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
			echo     Searching for %%i.exe...
			%WINDIR%\system32\taskkill.exe /f /fi "IMAGENAME eq %%i*" /T >> "%LOGPATH%\%LOGFILE%" 2>NUL
		)
	)
)

:: If we DON'T want to force-close Flash, then check for possible running Flash processes and abort the script if we find any
if %FORCE_CLOSE_PROCESSES%==no (
	call :log "%CUR_DATE% %TIME%   Variable FORCE_CLOSE_PROCESSES is set to '%FORCE_CLOSE_PROCESSES%'. Checking for running processes before execution..."

	REM Don't ask...
	REM Okay so basically we loop through this list of processes, and for each one we dump the result of the search in the '%%a' variable.
	REM Then we check that variable, and if it's not null (e.g. FIND.exe found something) we abort the script, returning the exit code
	REM specified at the beginning of the script. Normally you'd use ERRORLEVEL for this, but because it is very flaky (it doesn't
	REM always get set, even when it should) we instead resort to using this method of dumping the results in a variable and checking it.
	for %%i IN (battle.net,chrome,firefox,flash,iexplore,iexplorer,opera,palemoon,plugin-container,skype,steam,yahoo) do (
		call :log "%CUR_DATE% %TIME%   Searching for %%i.exe...
		for /f "delims=" %%a in ('tasklist ^| find /i "%%i"') do (
			if not [%%a]==[] (
				call :log "%CUR_DATE% %TIME% ! ERROR: Process '%%i' is currently running, aborting."
				exit /b %FORCE_CLOSE_PROCESSES_EXIT_CODE%
			)
		)
	)
	REM If we made it this far, we didn't find anything, so we can go ahead
	call :log "%CUR_DATE% %TIME%   All clear, no Flash-related processes found. Going ahead with removal..."
)




:::::::::::::
:: EXECUTE ::
:::::::::::::
:: Log that we started
call :log "%CUR_DATE% %TIME%   Beginning removal of Adobe Flash Player, all versions..."



:::::::::::::::::::::::::
:: UNINSTALLER SECTION :: -- Here we just brute-force every "normal" method for removing
:::::::::::::::::::::::::    Flash, then resort to more painstaking methods later
:: Attempt to run the official Adobe Flash removal utility, if it exists in the same directory as the script
call :log "%CUR_DATE% %TIME%   Attempting normal removal methods first..."
if exist uninstall_flash_player.exe (
	call :log "%CUR_DATE% %TIME%    Official Adobe uninstaller detected, running it first..."
	uninstall_flash_player.exe -uninstall >> "%LOGPATH%\%LOGFILE%"
	call :log "%CUR_DATE% %TIME%    Done."
)

:: Attempt WMIC by name
call :log "%CUR_DATE% %TIME%    Attempting removal via WMIC name wildcard..."
wmic product where "name like 'Adobe Flash Player%%'" uninstall /nointeractive >> "%LOGPATH%\%LOGFILE%"
call :log "%CUR_DATE% %TIME%    Done."

:: Attempt WMIC by specific GUID listing
call :log "%CUR_DATE% %TIME%    Attempting removal via specific GUID listing..."
	:: Adobe Flash Player ActiveX ProductCodes
	:: Adobe Flash Player v7.0
	MsiExec.exe /uninstall {cdf0cc64-4741-4e43-bf97-fef8fa1d6f1c} /quiet /norestart
	:: Adobe Flash Player v7.0.73.0
	MsiExec.exe /uninstall {1ae3b442-f6e5-49a0-bf8b-0e8d56d7d450} /quiet /norestart
	:: Adobe Flash Player v8.0.0.442 and earlier
	MsiExec.exe /uninstall {436EE5F2-71F0-4738-B8E7-93741EF4828F} /quiet /norestart
	MsiExec.exe /uninstall {0B575FB2-30B1-48F2-80A3-977638C2D6BA} /quiet /norestart
	:: Adobe Flash Player v8.0.0.443 to 8.0.0.453
	MsiExec.exe /uninstall {F180E599-CC04-4971-8140-3F71F95D7944} /quiet /norestart
	MsiExec.exe /uninstall {9600BCE2-9DEF-4930-ABF7-FB68ED538BF7} /quiet /norestart
	:: Adobe Flash Player v8.0.0.454 to 8.0.9.0
	MsiExec.exe /uninstall {0A28C610-EE06-4A33-BB56-A2155B524916} /quiet /norestart
	MsiExec.exe /uninstall {0CB2ABF4-BB8D-4F87-9223-50F106B50D95} /quiet /norestart
	:: Adobe Flash Player v8.0.10.0 to 8.0.22.0
	MsiExec.exe /uninstall {6815FCDD-401D-481E-BA88-31B4754C2B46} /quiet /norestart
	MsiExec.exe /uninstall {885A63EA-382B-4DD4-A755-14809B8557D6} /quiet /norestart
	:: Adobe Flash Player v8.0.24.0
	MsiExec.exe /uninstall {5E8A1B08-0FBD-4543-9646-F2C2D0D05750} /quiet /norestart
	MsiExec.exe /uninstall {CD5C7EB6-937A-4E39-B847-A8A50568EE9B} /quiet /norestart
	:: Adobe Flash Player v8.0.33.0
	MsiExec.exe /uninstall {E8590564-FD80-4864-B219-619BD4B3EB83} /quiet /norestart
	MsiExec.exe /uninstall {E67FAA8D-58E0-433C-833C-6647CDB14AB0} /quiet /norestart
	:: Adobe Flash Player v8.0.34.0
	MsiExec.exe /uninstall {F7BE8C66-4DFF-4480-A9B6-410E6FE4D399} /quiet /norestart
	MsiExec.exe /uninstall {0B991365-EB79-40B3-92AE-5E09B4008553} /quiet /norestart
	:: Adobe Flash Player v8.0.35.0
	MsiExec.exe /uninstall {B0D584DC-3B46-4F6C-B9C3-BDC61304D3CD} /quiet /norestart
	MsiExec.exe /uninstall {2927FFE6-25C2-4C86-B93C-EDEEA97B7CB7} /quiet /norestart
	:: Adobe Flash Player v8.0.36.0
	MsiExec.exe /uninstall {6D7EE95D-ADFB-4454-B28B-FAC56F84F186} /quiet /norestart
	MsiExec.exe /uninstall {8A90EC49-E132-4AA5-BF74-A18CC3C6DF6D} /quiet /norestart
	:: Adobe Flash Player v8.0.39.0
	MsiExec.exe /uninstall {00C10AC2-32C3-4281-B8EB-011E00B5AE20} /quiet /norestart
	MsiExec.exe /uninstall {2BBA59AE-9246-4348-8BB8-54EA1182817B} /quiet /norestart
	:: Adobe Flash Player v8.0.42.0
	MsiExec.exe /uninstall {A3703922-84E3-4318-B0A1-04EFAD449A04} /quiet /norestart
	MsiExec.exe /uninstall {8A7DC982-6A96-4C3C-BBE1-D5025CD85AF5} /quiet /norestart
	:: Adobe Flash Player v9.0.16.0
	MsiExec.exe /uninstall {BB65C393-C76E-4F06-9B0C-2124AA8AF97B} /quiet /norestart
	MsiExec.exe /uninstall {116E6EEC-0CBA-460E-8DEB-55CFF8E28C7D} /quiet /norestart
	:: Adobe Flash Player v9.0.28.0
	MsiExec.exe /uninstall {685A56F8-75B6-44AD-B3DA-FB0A3266B47C} /quiet /norestart
	MsiExec.exe /uninstall {D26FEB21-3495-401F-9046-0A39050A9324} /quiet /norestart
	:: Adobe Flash Player v9.0.45.0
	MsiExec.exe /uninstall {8186E1B9-DDC6-45B6-B9EB-C28947CBC4CF} /quiet /norestart
	MsiExec.exe /uninstall {6EB45C70-7B6E-456C-8C23-58A8409C0E3D} /quiet /norestart
	MsiExec.exe /uninstall {BC4F8E84-5E29-49EC-B4E7-E6F9CB50986C} /quiet /norestart
	:: Adobe Flash Player v 9.0.XX.0
	MsiExec.exe /uninstall {786547F9-59BB-4FA3-B2D8-327FF1F14870} /quiet /norestart
	MsiExec.exe /uninstall {3420E724-6DDB-49C2-BA39-165F543C147C} /quiet /norestart
	:: Adobe Flash Player v 9.0.XX.0
	MsiExec.exe /uninstall {8E9DB7EF-5DD3-499E-BA2A-A1F3153A4DF8} /quiet /norestart
	MsiExec.exe /uninstall {0A621EC5-B98B-45C9-95FE-A7D0DA3150EA} /quiet /norestart
	:: Adobe Flash Player v 9.4.XX.0
	MsiExec.exe /uninstall {58BAA8D0-404E-4585-9FD3-ED1BB72AC2EE} /quiet /norestart
	MsiExec.exe /uninstall {483CFBDB-5870-41ED-82DC-992D1A2CBA87} /quiet /norestart
	:: Adobe Flash Player v 9.0.151.0
	MsiExec.exe /uninstall {74B3FB8A-2A0F-4CEA-84FD-12C9B03EE377} /quiet /norestart
	MsiExec.exe /uninstall {693E05C4-15CF-4EC4-8298-AFCC049F4B94} /quiet /norestart
	:: Adobe Flash Player v 9.4.XX.0
	MsiExec.exe /uninstall {6FEFB724-6655-492B-9D10-00F530FC39D3} /quiet /norestart
	MsiExec.exe /uninstall {41FA4099-8AAA-495C-B1F0-E0447F9F4A93} /quiet /norestart
	:: Adobe Flash Player v 9.0.246
	MsiExec.exe /uninstall {9BA8B441-9E83-4307-A582-03EC9A456C72} /quiet /norestart
	MsiExec.exe /uninstall {03E99F0B-3A02-4821-BD44-70D4463F897B} /quiet /norestart
	:: Adobe Flash Player v9r260
	MsiExec.exe /uninstall {BB79ADDE-9369-44C4-84DB-221C853ABEDC} /quiet /norestart
	MsiExec.exe /uninstall {B4D79216-306A-400B-858B-00C05F0B0E80} /quiet /norestart
	:: Adobe Flash Player v 9.0.262
	MsiExec.exe /uninstall {C64CF7F5-92A0-4615-AA2D-A1237AD3F332} /quiet /norestart
	MsiExec.exe /uninstall {211986FD-3BB6-4B0D-8AAF-C22A6DBC7E36} /quiet /norestart
	:: Adobe Flash Player v 9.0.277
	MsiExec.exe /uninstall {4FB5B082-6906-4764-9486-332393B33C9F} /quiet /norestart
	MsiExec.exe /uninstall {7EC95A10-14F2-496A-99FA-772454E44566} /quiet /norestart
	:: Adobe Flash Player v 9.0.280
	MsiExec.exe /uninstall {2CB88388-9DFB-46f7-B7F1-862EB29A6FAB} /quiet /norestart
	MsiExec.exe /uninstall {17EDE3E8-7AF0-4c54-B6E7-0CA4129E9C21} /quiet /norestart
	:: Adobe Flash Player v10.0.2
	MsiExec.exe /uninstall {3A6829EF-0791-4FDD-9382-C690DD0821B9} /quiet /norestart
	MsiExec.exe /uninstall {685A56F8-75B6-44AD-B3DA-FB0A3266B47C} /quiet /norestart
	:: Adobe Flash Player v10.0.12
	MsiExec.exe /uninstall {2BD2FA21-B51D-4F01-94A7-AC16737B2163} /quiet /norestart
	MsiExec.exe /uninstall {A19AA51E-C145-4323-947E-D0D71EC84E47} /quiet /norestart
	:: Adobe Flash Player v10.0.22
	MsiExec.exe /uninstall {922E8525-AC7E-4294-ACAA-43712D4423C0} /quiet /norestart
	MsiExec.exe /uninstall {CECF7500-69B8-4EEE-9A5F-8D2FC2625760} /quiet /norestart
	:: Adobe Flash Player v10.0.32
	MsiExec.exe /uninstall {B7B3E9B3-FB14-4927-894B-E9124509AF5A} /quiet /norestart
	MsiExec.exe /uninstall {AFCD87D7-46F9-4923-84F0-987F12D0C28C} /quiet /norestart
	:: Adobe Flash Player v10.0.42
	MsiExec.exe /uninstall {24762012-C6C8-4AAD-A02D-71A009FA1683} /quiet /norestart
	MsiExec.exe /uninstall {D4B2F658-FCCC-4C50-952B-A8A5E5BC110F} /quiet /norestart
	:: Adobe Flash Player v10.0.45
	MsiExec.exe /uninstall {66E3BA00-6B3D-466B-96FA-6309A7F42BB0} /quiet /norestart
	MsiExec.exe /uninstall {20B3FD5B-A987-406B-A5B5-CDE3CA1EF4E1} /quiet /norestart
	:: Adobe Flash Player v10.1.52
	MsiExec.exe /uninstall {6E9EF98E-259E-416D-B5F8-0ABDB99942CE} /quiet /norestart
	MsiExec.exe /uninstall {EFB786FD-D916-416B-A23A-1EBEAF4A9DDC} /quiet /norestart
	:: Adobe Flash Player v10.1.55
	MsiExec.exe /uninstall {FFB768E4-E427-4553-BC36-A11F5E62A94D} /quiet /norestart
	MsiExec.exe /uninstall {95A0B13E-F09A-425F-9D5F-E7C5EC470D06} /quiet /norestart
	:: Adobe Flash Player v10.1.82
	MsiExec.exe /uninstall {406A89D6-09E6-4550-B370-8D376DDB56BE} /quiet /norestart
	MsiExec.exe /uninstall {03A3CDEE-94D7-49c1-B373-D342653A22E8} /quiet /norestart
	:: Adobe Flash Player v10.1.85
	MsiExec.exe /uninstall {95468B00-C081-4B27-AC96-0A2A31359E60} /quiet /norestart
	MsiExec.exe /uninstall {C6C0E5B3-19B9-45D4-B76A-177F500A276C} /quiet /norestart
	:: Adobe Flash Player v10.1.102
	MsiExec.exe /uninstall {148D9D03-5D23-4D4F-B5D0-BA6030C45DCF} /quiet /norestart
	MsiExec.exe /uninstall {65EAFCCB-4057-4184-9145-137DED9E0144} /quiet /norestart
	:: Adobe Flash Player v10.2.152
	MsiExec.exe /uninstall {E5D03B2E-B2D4-477F-A60D-8E1969D821FA} /quiet /norestart
	MsiExec.exe /uninstall {87AE8A8F-6040-42B5-A7E5-644B1EA70163} /quiet /norestart
	:: Adobe Flash Player v10.2.152
	MsiExec.exe /uninstall {18BBF24A-6D04-4CA4-B6B4-1CF372162EEC} /quiet /norestart
	MsiExec.exe /uninstall {37C80158-721A-440E-8102-8C5B71BFE2DE} /quiet /norestart
	:: Adobe Flash Player v10.2.153
	MsiExec.exe /uninstall {B001064C-D061-4BAE-9031-416A838D5536} /quiet /norestart
	MsiExec.exe /uninstall {FFE07581-220F-47B7-8EDE-26059EF9FB26} /quiet /norestart
	:: Adobe Flash Player v10.2.159
	MsiExec.exe /uninstall {FA1D6742-0515-4A94-AD5D-F0484026E4A2} /quiet /norestart
	MsiExec.exe /uninstall {9A80D7E7-4C48-484E-9C16-F4E300366F1D} /quiet /norestart
	:: Adobe Flash Player v10.3.181.14
	MsiExec.exe /uninstall {DCC90D9D-4F8D-4A06-9050-ADDB284FF9FA} /quiet /norestart
	MsiExec.exe /uninstall {23885D98-F1AF-4579-81FB-C57CA71B7E89} /quiet /norestart
	:: Adobe Flash Player v10.3.181.22
	MsiExec.exe /uninstall {A6FD09C6-E363-4986-8ABD-2165B4485EEC} /quiet /norestart
	MsiExec.exe /uninstall {397B615E-7442-4BEA-8098-61BBCF703C74} /quiet /norestart
	:: Adobe Flash Player v10.3.181.23
	MsiExec.exe /uninstall {88D881EF-0567-443A-9A84-E5AAEF29BB34} /quiet /norestart
	MsiExec.exe /uninstall {04F9616D-BEB9-40DD-88EA-0D404F67C775} /quiet /norestart
	:: Adobe Flash Player v10.3.181.26
	MsiExec.exe /uninstall {0483BE07-260D-4E4D-815E-F737C0A72E40} /quiet /norestart
	MsiExec.exe /uninstall {332FDA1D-0B1E-460C-9961-65515CADB9B7} /quiet /norestart
	:: Adobe Flash Player v10.3.181.34
	MsiExec.exe /uninstall {48DB5914-8772-472D-B8DF-E2092BE598F6} /quiet /norestart
	MsiExec.exe /uninstall {EA5AFEE8-17F9-4DC6-AB10-A41C34A35893} /quiet /norestart
	:: Adobe Flash Player v10.3.183.5
	MsiExec.exe /uninstall {72D4DD4C-0749-4352-B63E-7A7C9286430E} /quiet /norestart
	MsiExec.exe /uninstall {A3F073DB-01A6-4e24-A0F5-950EAB651355} /quiet /norestart
	:: Adobe Flash Player v10.3.183.6+
	MsiExec.exe /uninstall {DB093E0B-0934-4183-BA60-5C1ADC9F6424} /quiet /norestart
	MsiExec.exe /uninstall {C0D8060A-8E3B-458c-9434-FBBE04F823D3} /quiet /norestart
	:: Adobe Flash Player v10.3.230
	MsiExec.exe /uninstall {E24A0015-C73F-4B57-B8DF-5EB84D2E9685} /quiet /norestart
	MsiExec.exe /uninstall {39BCE53F-F8C8-4545-A5D8-F210E7608360} /quiet /norestart
	:: Adobe Flash Player v10.3.183.11
	MsiExec.exe /uninstall {54DAAD16-A57A-4524-9C4F-391500945D14} /quiet /norestart
	MsiExec.exe /uninstall {A437E1A3-F0AA-4EA2-8E43-845DDC2221D1} /quiet /norestart
	:: Adobe Flash Player v10.3.183.15
	MsiExec.exe /uninstall {36B194F6-D57F-4E58-B99D-9A4565356A66} /quiet /norestart
	MsiExec.exe /uninstall {E84F69A8-5357-4C1F-B8AA-63919FA0BDA6} /quiet /norestart
	:: Adobe Flash Player v10.3.183.16
	MsiExec.exe /uninstall {FEE2740C-D52A-4C76-8857-335E35AB7037} /quiet /norestart
	MsiExec.exe /uninstall {1D424BAA-E25C-456C-B502-0B9C9F164BDE} /quiet /norestart
	:: Adobe Flash Player v10.3.183.18
	MsiExec.exe /uninstall {212719F5-89EE-4B3A-A8EB-121D931E5547} /quiet /norestart
	MsiExec.exe /uninstall {AB36B93A-7B6A-4693-99DE-95143819EE78} /quiet /norestart
	:: Adobe Flash Player v10.3.183.19
	MsiExec.exe /uninstall {2B2D7C9F-F652-4C9C-86AD-7298D2989D88} /quiet /norestart
	MsiExec.exe /uninstall {DA69776C-A93F-4077-8874-25DF521EAA8A} /quiet /norestart
	:: Adobe Flash Player v10.3.183.20
	MsiExec.exe /uninstall {5C017C03-0DCF-47DD-8113-9CDE442C30E7} /quiet /norestart
	MsiExec.exe /uninstall {C9BDE2F9-88BE-429B-B63B-5D40BA2FCE7F} /quiet /norestart
	:: Adobe Flash Player v10.3.183.23
	MsiExec.exe /uninstall {35685EF6-CB29-4FDE-8950-F570ED2BACB7} /quiet /norestart
	MsiExec.exe /uninstall {654BA71A-B93E-4085-ABD7-83BA7DCA6C23} /quiet /norestart
	:: Adobe Flash Player v10.3.183.25
	MsiExec.exe /uninstall {CBCA1B4E-1DB3-4BBF-BD05-CF3A3F2CC32B} /quiet /norestart
	MsiExec.exe /uninstall {09343F1F-926F-4DFD-8784-079E67D783DB} /quiet /norestart
	:: Adobe Flash Player v10.3.183.x
	MsiExec.exe /uninstall {1BB7D2BB-D4EB-4680-A707-FC3D526E90A1} /quiet /norestart
	MsiExec.exe /uninstall {66C8B9D7-25FF-4BF9-A515-096E8D3B73EF} /quiet /norestart
	:: Adobe Flash Player v11.0.1
	MsiExec.exe /uninstall {23D79730-EC1A-435E-83F8-AAEBFE5237B0} /quiet /norestart
	MsiExec.exe /uninstall {726D93B8-C973-4C5B-881B-96FBDE459D39} /quiet /norestart
	MsiExec.exe /uninstall {A10EE46B-C2E8-4FAB-A8F8-3E80D0662BA9} /quiet /norestart
	MsiExec.exe /uninstall {6C119C52-528E-4115-A05D-E78893FB01F6} /quiet /norestart
	:: Adobe Flash Player v11.1.102
	MsiExec.exe /uninstall {4278B780-6CB5-437A-BA6A-31C7F9FAB980} /quiet /norestart
	MsiExec.exe /uninstall {DBC42D80-FE3F-4F45-91EA-972F0EDC8603} /quiet /norestart
	MsiExec.exe /uninstall {421976B6-DEC6-4CA5-941F-F0663B3A2B74} /quiet /norestart
	MsiExec.exe /uninstall {C2840D4B-5DD8-4813-A9D8-C2B72E821226} /quiet /norestart
	:: Adobe Flash Player v11.1.102.62
	MsiExec.exe /uninstall {D0F112BB-7902-43AC-AF50-4D1117C9152E} /quiet /norestart
	MsiExec.exe /uninstall {B88C181E-D594-4A3C-9767-07E4794234D6} /quiet /norestart
	MsiExec.exe /uninstall {62DD0E85-7A25-47A4-8F0F-95D749F9F102} /quiet /norestart
	MsiExec.exe /uninstall {7DBA4E0E-C43E-4BD8-859E-DA4E8284473E} /quiet /norestart
	:: Adobe Flash Player v11.1.102.63
	MsiExec.exe /uninstall {8D7DDFA2-3A50-49A4-99C5-6D8BE66FE0B9} /quiet /norestart
	MsiExec.exe /uninstall {3D093B2E-1E39-4097-A0EF-C70351A16CA6} /quiet /norestart
	MsiExec.exe /uninstall {E7C06D29-B16A-4D88-A917-55422FAB4E9D} /quiet /norestart
	MsiExec.exe /uninstall {82833D13-CE67-4DD9-A270-30265F12DCB7} /quiet /norestart
	:: Adobe Flash Player v11.1.102.64
	MsiExec.exe /uninstall {90790D5D-80D8-4C7E-8BDC-23DBB8C6AEC7} /quiet /norestart
	MsiExec.exe /uninstall {CF722882-1ED7-4FB9-B98A-589544A15F40} /quiet /norestart
	MsiExec.exe /uninstall {D3F3D07F-4B4F-440B-9DC9-355848A8103C} /quiet /norestart
	MsiExec.exe /uninstall {14190A51-2712-42C1-B7DB-011ABEAF33E2} /quiet /norestart
	:: Adobe Flash Player v11.2.202.228
	MsiExec.exe /uninstall {5C804EBB-475F-4555-A225-1D6573F158BD} /quiet /norestart
	MsiExec.exe /uninstall {E3C99F7A-60C3-40C4-BC9D-FB6B0C2F2671} /quiet /norestart
	MsiExec.exe /uninstall {8DB09D25-8E79-4F23-854D-02B95062A5B2} /quiet /norestart
	MsiExec.exe /uninstall {94B87B26-B746-4AEA-B301-4AB281AF3B7A} /quiet /norestart
	:: Adobe Flash Player v11.2.202.233
	MsiExec.exe /uninstall {9E25236A-E313-4853-9C8C-DB7015E9F9C4} /quiet /norestart
	MsiExec.exe /uninstall {0EF12658-CB6B-4A73-923D-2CABE04976A6} /quiet /norestart
	MsiExec.exe /uninstall {6B393C32-A8CE-4663-9D5B-EA75C8D1233C} /quiet /norestart
	MsiExec.exe /uninstall {853E9330-9717-4504-BDA2-BB8743D458DD} /quiet /norestart
	:: Adobe Flash Player v11.2.202.x
	MsiExec.exe /uninstall {F40AC5E5-55AB-469A-BA8B-839CE0146380} /quiet /norestart
	MsiExec.exe /uninstall {43E79717-8760-480E-8408-98D090DA10A7} /quiet /norestart
	MsiExec.exe /uninstall {A13AB67F-697F-47DC-AA7B-F70B8B7ACDB8} /quiet /norestart
	MsiExec.exe /uninstall {628185FB-FA33-49C3-B7AC-A31F30EDDB6E} /quiet /norestart
	:: Adobe Flash Player v11.3.300.257
	MsiExec.exe /uninstall {DC48E09D-4E5F-4039-B93A-FCED36EFBE55} /quiet /norestart
	MsiExec.exe /uninstall {F856A189-24F9-4443-A40C-58CC70A1B336} /quiet /norestart
	:: Adobe Flash Player v11.3.300.265
	MsiExec.exe /uninstall {BEE621F9-F94D-493C-BC45-D1B315DC8839} /quiet /norestart
	MsiExec.exe /uninstall {1F25D9AF-12DF-4A9D-B190-C6ED384520AF} /quiet /norestart
	:: Adobe Flash Player v11.3.300.268
	MsiExec.exe /uninstall {98616875-CF30-4BE5-AAED-36EF4AC6EE27} /quiet /norestart
	MsiExec.exe /uninstall {8E55A5FE-A5D2-4791-A725-A8BA275BD3C2} /quiet /norestart
	:: Adobe Flash Player v11.3.300.270
	MsiExec.exe /uninstall {A02F7026-D635-465C-80D8-FB47AF185934} /quiet /norestart
	MsiExec.exe /uninstall {0A665F5E-78A3-4BDB-B702-61B56815F91C} /quiet /norestart
	:: Adobe Flash Player v11.3.300.271
	MsiExec.exe /uninstall {25F2AB39-E3DD-4cd7-8697-E98CF27BA1F1} /quiet /norestart
	MsiExec.exe /uninstall {98CBB17F-A22C-43e3-8521-99A3F413C882} /quiet /norestart
	:: Adobe Flash Player v11.3.300.272
	MsiExec.exe /uninstall {CA6C70E3-1878-47c3-97BA-8DB0E2221511} /quiet /norestart
	MsiExec.exe /uninstall {ABE4FCDC-7D0B-40ea-ACD4-122BABC6E78A} /quiet /norestart
	:: Adobe Flash Player v11.4.402.265
	MsiExec.exe /uninstall {3F67CDB0-824E-435E-BE14-D7BCA8256E3E} /quiet /norestart
	MsiExec.exe /uninstall {8A48D60D-7D7F-4C4D-AC92-AC3150BF75FE} /quiet /norestart
	:: Adobe Flash Player v11.4.402.278
	MsiExec.exe /uninstall {6F702A65-629F-4E5A-B686-1A4826C83AB4} /quiet /norestart
	MsiExec.exe /uninstall {D488AE94-47DF-443E-8CE7-1A9A919B368A} /quiet /norestart
	:: Adobe Flash Player v11.4.402.287
	MsiExec.exe /uninstall {D01750A5-49E5-4BF4-92CC-F72F5F20DBEC} /quiet /norestart
	MsiExec.exe /uninstall {A5FC3413-878E-4A9E-903A-7E32079C70F3} /quiet /norestart
	:: Flash Player Plug-in ProductCodes
	:: Adobe Flash Player v8.0.0.442 and earlier
	MsiExec.exe /uninstall {F6E23569-A22A-4924-93A4-3F215BEF63D2} /quiet /norestart
	MsiExec.exe /uninstall {AF6106EF-F27F-4729-922B-FDD56869C9D0} /quiet /norestart
	:: Adobe Flash Player v8.0.0.443 to 8.0.0.453
	MsiExec.exe /uninstall {B9E91AEF-2A3C-4B48-BF18-456BE6EDF863} /quiet /norestart
	MsiExec.exe /uninstall {5F2B85E0-66F2-4E61-BA50-12784EFAE696} /quiet /norestart
	:: Adobe Flash Player v8.0.0.454 to 8.0.9.0
	MsiExec.exe /uninstall {555D21DF-105A-48A7-AFFE-F5B4495F7F1D} /quiet /norestart
	MsiExec.exe /uninstall {27DCBDC9-00D0-4A57-BDFD-E618820495CB} /quiet /norestart
	:: Adobe Flash Player v8.0.10.0 to 8.0.22.0
	MsiExec.exe /uninstall {23AEBB83-CB47-4739-8A0C-92CC1E32AA2F} /quiet /norestart
	MsiExec.exe /uninstall {91057632-CA70-413C-B628-2D3CDBBB906B} /quiet /norestart
	:: Adobe Flash Player v8.0.24.0
	MsiExec.exe /uninstall {E3D278BD-FC97-4F87-BB1F-689AE0CB9122} /quiet /norestart
	MsiExec.exe /uninstall {13816489-2692-49A2-9615-0F2830E1740D} /quiet /norestart
	:: Adobe Flash Player v8.0.33.0
	MsiExec.exe /uninstall {465B0B1A-06E1-4C99-BB0A-ED23262DF156} /quiet /norestart
	MsiExec.exe /uninstall {C0C08739-EA05-443C-BE3F-2B4E46D6A74E} /quiet /norestart
	:: Adobe Flash Player v8.0.34.0
	MsiExec.exe /uninstall {7DCC858F-082F-4E01-9DD4-CF3645640F41} /quiet /norestart
	MsiExec.exe /uninstall {8672D374-FC95-45E0-B85C-BEB639C14F1F} /quiet /norestart
	:: Adobe Flash Player v8.0.35.0
	MsiExec.exe /uninstall {EFEC4901-E9F0-4FB0-87F2-90E3058DA015} /quiet /norestart
	MsiExec.exe /uninstall {0402AE0D-C6B5-4CBD-9A84-A0C32785D407} /quiet /norestart
	:: Adobe Flash Player v8.0.36.0
	MsiExec.exe /uninstall {D60837D1-6881-4414-AD27-8A2042D043B3} /quiet /norestart
	MsiExec.exe /uninstall {C1CC20FA-52A7-4F67-BCCC-5E55E9A61C6A} /quiet /norestart
	:: Adobe Flash Player v8.0.39.0
	MsiExec.exe /uninstall {63C0B69C-6630-44F2-B3A4-1F50DDEF6ADD} /quiet /norestart
	MsiExec.exe /uninstall {E1475528-CAC4-4919-81FD-EDC556097048} /quiet /norestart
	:: Adobe Flash Player v8.0.42.0
	MsiExec.exe /uninstall {48D9A460-9FA3-4E16-9533-2DF1C1F5129F} /quiet /norestart
	MsiExec.exe /uninstall {E686D1C1-78B5-4E1A-8269-A023B43C2D76} /quiet /norestart
	:: Adobe Flash Player v9.0.16.0
	MsiExec.exe /uninstall {1E37DD02-3E30-49B6-9FF2-F4A3DFF95717} /quiet /norestart
	MsiExec.exe /uninstall {626CA84A-FFAE-4978-A600-B0196F0F817D} /quiet /norestart
	:: Adobe Flash Player v9.0.28.0
	MsiExec.exe /uninstall {0234731F-1444-4215-BBCE-968CDDB4BCA4} /quiet /norestart
	MsiExec.exe /uninstall {008F31A9-4B8E-4411-AA19-2CB3C8DD7507} /quiet /norestart
	MsiExec.exe /uninstall {391474F7-0DF1-445C-8888-34EEA7480927} /quiet /norestart
	:: Adobe Flash Player v9.0.45.0
	MsiExec.exe /uninstall {685A56F8-75B6-44AD-B3DA-FB0A3266B47C} /quiet /norestart
	MsiExec.exe /uninstall {B91D3B4D-001F-4ABF-B8A5-B5A926DB63AD} /quiet /norestart
	MsiExec.exe /uninstall {56E0400B-3C4E-4600-A4D7-425EAE09E079} /quiet /norestart
	MsiExec.exe /uninstall {88D422DB-E9C7-4E16-9D80-2999F4FD6AD9} /quiet /norestart
	:: Adobe Flash Player v9.0.XX.0
	MsiExec.exe /uninstall {04B848BE-8B67-4B44-929D-BC14D9B4FFF4} /quiet /norestart
	MsiExec.exe /uninstall {3EA70573-43D9-4F0F-B197-6015B404EFB5} /quiet /norestart
	:: Adobe Flash Player v9.0.XX.0
	MsiExec.exe /uninstall {9802AB7D-9BB2-4FC9-A9B6-681696F1E2DA} /quiet /norestart
	MsiExec.exe /uninstall {5746C6E3-DC6E-4762-9445-F89C50B5E1D2} /quiet /norestart
	:: Adobe Flash Player v9.4.XX.0
	MsiExec.exe /uninstall {61E8B062-51F9-4BBB-B1FC-E2A4A40944F5} /quiet /norestart
	MsiExec.exe /uninstall {ECF27176-4815-4F75-98DC-3E5568166C97} /quiet /norestart
	:: Adobe Flash Player v9.0.151.0
	MsiExec.exe /uninstall {84490045-A165-4E48-9513-F9624D2CEBEE} /quiet /norestart
	MsiExec.exe /uninstall {A03AF447-5F61-43EC-880A-A65ED11C9720} /quiet /norestart
	:: Adobe Flash Player v9.4.XX.0
	MsiExec.exe /uninstall {15769488-ECC7-482D-B222-96281A8C36C7} /quiet /norestart
	MsiExec.exe /uninstall {3F38C13F-97A6-44B5-AB0F-5013801454B7} /quiet /norestart
	:: Adobe Flash Player v9.0.246.0
	MsiExec.exe /uninstall {EAC34337-5F49-41FF-86C6-A370DAB69CB2} /quiet /norestart
	MsiExec.exe /uninstall {AF214EE7-1AF3-498F-918C-581F97B1EE79} /quiet /norestart
	:: Adobe Flash Player v9r260
	MsiExec.exe /uninstall {F201F161-D43B-471A-A9E5-C432E1BA196B} /quiet /norestart
	MsiExec.exe /uninstall {E374CFF5-A81F-4C23-A278-8E19C913C23C} /quiet /norestart
	:: Adobe Flash Player v9r262
	MsiExec.exe /uninstall {35657C68-91B5-42EC-99E6-0BA43106AF8B} /quiet /norestart
	MsiExec.exe /uninstall {9D2AA1D9-65D0-49E9-85A3-B73C9224F1F0} /quiet /norestart
	:: Adobe Flash Player v9.0.277
	MsiExec.exe /uninstall {E09CDDD4-060D-4BF4-AB36-C13AD9AD63A3} /quiet /norestart
	MsiExec.exe /uninstall {AAA3B45B-8FD5-4DD1-86C6-C861EF0BA31C} /quiet /norestart
	:: Adobe Flash Player v9.0.280
	MsiExec.exe /uninstall {22A5BE4F-4A7C-4037-8E30-EAF0E6CB546C} /quiet /norestart
	MsiExec.exe /uninstall {15F93695-7814-43b7-B078-35855A39B63C} /quiet /norestart
	:: Adobe Flash Player v10.0.1.218
	MsiExec.exe /uninstall {3F490EB6-7C6C-4208-93FF-6AC925FA64C8} /quiet /norestart
	MsiExec.exe /uninstall {03DEEAD2-F3B7-45BF-9006-A25D015F00D2} /quiet /norestart
	:: Adobe Flash Player v10.0.12
	MsiExec.exe /uninstall {ECA1A3B6-898F-4DCE-9F04-714CF3BA126B} /quiet /norestart
	MsiExec.exe /uninstall {5D8E406B-D572-4773-BE82-7B4B33F5167F} /quiet /norestart
	:: Adobe Flash Player v10.0.22
	MsiExec.exe /uninstall {64001313-1B41-4457-B884-049984772E6F} /quiet /norestart
	MsiExec.exe /uninstall {4B475346-CE49-402C-991E-3DAF7074E337} /quiet /norestart
	:: Adobe Flash Player v10.0.32
	MsiExec.exe /uninstall {0DFB3DE8-65B9-44FF-AA0A-3BECC5A2BFD1} /quiet /norestart
	MsiExec.exe /uninstall {D6627D6D-E144-49AF-8783-BBEA98B9DC20} /quiet /norestart
	:: Adobe Flash Player v10.0.42
	MsiExec.exe /uninstall {D09E3C22-6573-4723-9962-B3B2ED761754} /quiet /norestart
	MsiExec.exe /uninstall {B67CE1B7-EDD4-4C70-AB8E-6008D029DD03} /quiet /norestart
	:: Adobe Flash Player v10.0.45
	MsiExec.exe /uninstall {AF36CE1D-FD2C-4BA0-93FA-1196785DD610} /quiet /norestart
	MsiExec.exe /uninstall {903BE60B-0336-40A0-9024-6D980D1452C2} /quiet /norestart
	:: Adobe Flash Player v10.1.52
	MsiExec.exe /uninstall {BC41C09D-FAA9-4346-9FE6-1E0017BC551A} /quiet /norestart
	MsiExec.exe /uninstall {359FC4B0-29ED-4CA8-AD66-CF436931F492} /quiet /norestart
	:: Adobe Flash Player v10.1.55
	MsiExec.exe /uninstall {1C5EC8F6-5C5F-421F-85BE-919B5D0CAD4C} /quiet /norestart
	MsiExec.exe /uninstall {14CAE90A-7395-4DF6-93AD-14AF6E52922B} /quiet /norestart
	:: Adobe Flash Player v10.1.82
	MsiExec.exe /uninstall {012CE096-06BA-4f46-8E89-0B4F900E7479} /quiet /norestart
	MsiExec.exe /uninstall {A7FCCC54-F5FB-4610-A47D-BB0B236EC0A0} /quiet /norestart
	:: Adobe Flash Player v10.1.85
	MsiExec.exe /uninstall {343DB62F-891F-45EC-BED3-E2F56CEB1B7C} /quiet /norestart
	MsiExec.exe /uninstall {4ABE9922-AE51-4B1B-9058-9CD3B61CA28B} /quiet /norestart
	:: Adobe Flash Player v10.1.102
	MsiExec.exe /uninstall {35F7D0BF-08AB-42E3-A403-AF9772AC216A} /quiet /norestart
	MsiExec.exe /uninstall {D70FE37C-CDB9-4C87-A60C-9619536A1817} /quiet /norestart
	:: Adobe Flash Player v10.2.152
	MsiExec.exe /uninstall {E6725026-A650-449C-897B-D6B7A5EEA058} /quiet /norestart
	MsiExec.exe /uninstall {EF131455-5740-4A8D-8B58-30895FEA1C41} /quiet /norestart
	:: Adobe Flash Player v10.2.152
	MsiExec.exe /uninstall {FC619975-A025-4B54-873C-FDF000B90261} /quiet /norestart
	MsiExec.exe /uninstall {FAFBF4A2-0CE2-4A80-908D-9C1B007CA821} /quiet /norestart
	:: Adobe Flash Player v10.2.153
	MsiExec.exe /uninstall {9C542173-96F0-435D-A95C-468CAAC75EA0} /quiet /norestart
	MsiExec.exe /uninstall {ABD26AA9-1114-4470-8971-E4AF80177DF1} /quiet /norestart
	:: Adobe Flash Player v10.2.159
	MsiExec.exe /uninstall {F473C85C-1FED-4D0A-8155-E97AC7E43C9D} /quiet /norestart
	MsiExec.exe /uninstall {58083D97-7080-4018-8205-755D57BDCCEE} /quiet /norestart
	:: Adobe Flash Player v10.3.181.14
	MsiExec.exe /uninstall {B7BDAF22-9647-4846-8EA9-6E0A5B785651} /quiet /norestart
	MsiExec.exe /uninstall {EE13B869-5ED6-4304-BDAB-97FCD19196BD} /quiet /norestart
	:: Adobe Flash Player v10.3.181.23
	MsiExec.exe /uninstall {4ED0DB47-769D-4B71-8724-E7A5BFEA1D51} /quiet /norestart
	MsiExec.exe /uninstall {2B30EEBE-80A5-4EC2-80BF-73B68D497A4A} /quiet /norestart
	:: Adobe Flash Player v10.3.181.26
	MsiExec.exe /uninstall {53F29A32-7D03-4635-A8B3-839D921F6F96} /quiet /norestart
	MsiExec.exe /uninstall {E6BF9E13-E356-456B-9FA7-51DB3E0FB4FF} /quiet /norestart
	:: Adobe Flash Player v10.3.181.34
	MsiExec.exe /uninstall {F9D68131-7490-4448-AC45-7BBFB3392F8F} /quiet /norestart
	MsiExec.exe /uninstall {1397D1B4-6341-4D7F-AE9A-4AD5D8569865} /quiet /norestart
	:: Adobe Flash Player v10.3.183.5
	MsiExec.exe /uninstall {8B234375-EFB1-4024-8B53-EA7C745A6687} /quiet /norestart
	MsiExec.exe /uninstall {C0494ABC-1F71-4a95-A31F-C9DE5510253B} /quiet /norestart
	:: Adobe Flash Player v10.3.183.6+
	MsiExec.exe /uninstall {8FC6B896-6F86-4957-AC1A-077A755C4F08} /quiet /norestart
	MsiExec.exe /uninstall {D6CF54D5-35D1-4c14-BF01-682012C4A303} /quiet /norestart
	:: Adobe Flash Player v10.3.183.15
	MsiExec.exe /uninstall {10C35266-87DE-471F-B3C9-9AD0CA0315DE} /quiet /norestart
	MsiExec.exe /uninstall {F9295F4F-A64E-4560-8934-B0B214A79C1B} /quiet /norestart
	:: Adobe Flash Player v10.3.183.x
	MsiExec.exe /uninstall {F9D28ACF-D568-4D4C-9601-2ECEE27479A3} /quiet /norestart
	MsiExec.exe /uninstall {9777D3B0-B104-4337-937F-BD670CA08D3B} /quiet /norestart
	:: Adobe Flash Player v10.3.230
	MsiExec.exe /uninstall {FDBF4291-7DDB-4C5C-B128-332A46CF8FFA} /quiet /norestart
	MsiExec.exe /uninstall {27B80FE1-E9ED-49D9-8EF4-C58635203EBE} /quiet /norestart
	:: Adobe Flash Player v10.3.183.11
	MsiExec.exe /uninstall {1B771BDD-6B21-4C61-A458-226910A9C01B} /quiet /norestart
	MsiExec.exe /uninstall {34C45997-475F-4D02-9F2C-9FFE3880337D} /quiet /norestart
	:: Adobe Flash Player v10.3.183.18
	MsiExec.exe /uninstall {55D873F4-67F0-4BA8-B735-06A5B99AFFE1} /quiet /norestart
	MsiExec.exe /uninstall {91522620-E5A9-4B76-856F-5159D18E2737} /quiet /norestart
	:: Adobe Flash Player v10.3.183.19
	MsiExec.exe /uninstall {1F282E23-66C7-46D3-B23C-70A53342DD4E} /quiet /norestart
	MsiExec.exe /uninstall {ADF9B3BD-14A4-4A34-8382-9FD5757E950F} /quiet /norestart
	:: Adobe Flash Player v10.3.183.20
	MsiExec.exe /uninstall {99BEFA2A-9084-437E-BE21-40F850C1CF47} /quiet /norestart
	MsiExec.exe /uninstall {4C66C92E-56EA-4769-ABD0-FA838A594D53} /quiet /norestart
	:: Adobe Flash Player v10.3.183.23
	MsiExec.exe /uninstall {F78DFF86-B53D-4D6D-AB2B-573C0A7AA856} /quiet /norestart
	MsiExec.exe /uninstall {59CCE106-1DF5-4021-9700-FDFA2878ED41} /quiet /norestart
	:: Adobe Flash Player v10.3.183.x
	MsiExec.exe /uninstall {AB47EA27-9FE1-4775-BEFC-4AAEEE2CB53E} /quiet /norestart
	MsiExec.exe /uninstall {781B0936-390B-4E1B-BC04-6B17D64E6451} /quiet /norestart
	:: Adobe Flash Player v10.3.183.x
	MsiExec.exe /uninstall {95758145-3B5B-4874-B062-597C8E450EA7} /quiet /norestart
	MsiExec.exe /uninstall {73C4CC71-510B-44AD-AAA3-3C373963AED4} /quiet /norestart
	:: Adobe Flash Player v11.0.1
	MsiExec.exe /uninstall {66EE3C89-25FD-4D8F-BC01-B94B25B9D03F} /quiet /norestart
	MsiExec.exe /uninstall {C4E5725D-2758-4FA3-A595-159BBCC5D42C} /quiet /norestart
	MsiExec.exe /uninstall {CA6DA0CF-2852-4407-ADE2-CA6281C8CE9D} /quiet /norestart
	MsiExec.exe /uninstall {C77FD7CE-3E63-4DA2-9EE6-D28F47846DCE} /quiet /norestart
	:: Adobe Flash Player v11.1.102
	MsiExec.exe /uninstall {4ABA8D5B-55F4-4254-905B-ACF8AAFF84EE} /quiet /norestart
	MsiExec.exe /uninstall {605DFBA7-A719-4F7E-A035-84B2CAA7DD4E} /quiet /norestart
	MsiExec.exe /uninstall {063C0043-E954-4850-9AA7-F9BC4E920D38} /quiet /norestart
	MsiExec.exe /uninstall {99798FE8-28DA-421D-9A45-6CFB0C459E5C} /quiet /norestart
	:: Adobe Flash Player v11.1.102.62
	MsiExec.exe /uninstall {35E1B1BF-D8E5-4B7F-9FD6-87D2E5694015} /quiet /norestart
	MsiExec.exe /uninstall {E7051553-A13A-437A-9133-11F8E88F21A8} /quiet /norestart
	MsiExec.exe /uninstall {9243F09B-3319-4A55-8181-9BCEC7391079} /quiet /norestart
	MsiExec.exe /uninstall {E3DB71DB-C4C8-479A-A8C9-C73EF2499B24} /quiet /norestart
	:: Adobe Flash Player v11.1.102.63
	MsiExec.exe /uninstall {F7090575-8BDC-4A14-8D00-C0FB2BC914BD} /quiet /norestart
	MsiExec.exe /uninstall {2239879A-3B8C-4CB8-A98E-5881193A7128} /quiet /norestart
	MsiExec.exe /uninstall {0F2C43BC-2B06-4684-BC2E-C922056DE90C} /quiet /norestart
	MsiExec.exe /uninstall {2187F9AC-D040-4B1C-B636-40A5A8E63C54} /quiet /norestart
	:: Adobe Flash Player v11.1.102.64
	MsiExec.exe /uninstall {E3FB4C86-2BF1-4327-B7D4-60F9A2F0A32F} /quiet /norestart
	MsiExec.exe /uninstall {9EBB117C-1326-400E-95A1-EF538815334B} /quiet /norestart
	MsiExec.exe /uninstall {1E75E46A-D67F-44BC-9344-8EAA358E9FB7} /quiet /norestart
	MsiExec.exe /uninstall {94B0D4F0-F2AC-4FE2-B384-C81507AAAE7C} /quiet /norestart
	:: Adobe Flash Player v11.2.202.228
	MsiExec.exe /uninstall {F1F9D254-FBB7-4634-9481-BEF1312255FE} /quiet /norestart
	MsiExec.exe /uninstall {B87883B7-F397-400F-B700-6934464D2316} /quiet /norestart
	MsiExec.exe /uninstall {12F0097F-68B4-40AB-A968-318D369027EC} /quiet /norestart
	MsiExec.exe /uninstall {9D2F6D68-14FA-44BF-9137-3AE0EE11E609} /quiet /norestart
	:: Adobe Flash Player v11.2.202.233
	MsiExec.exe /uninstall {1E4B6678-A507-4B6A-B6C7-FEE55FC0C14C} /quiet /norestart
	MsiExec.exe /uninstall {9C61F315-7DDF-4481-884C-3AEE83738806} /quiet /norestart
	MsiExec.exe /uninstall {B2883418-71EB-4F63-97AB-222C67E99358} /quiet /norestart
	MsiExec.exe /uninstall {EA5FD27F-D7A5-421A-8424-7DC27F62F7C9} /quiet /norestart
	:: Adobe Flash Player v11.2.202.x
	MsiExec.exe /uninstall {5D8B877C-945B-49F5-AA48-776C81C11B56} /quiet /norestart
	MsiExec.exe /uninstall {6B9F3B5E-D16C-49A6-9DD4-ACFD69A561BC} /quiet /norestart
	MsiExec.exe /uninstall {E648FE50-7E0B-45E2-92ED-AB1FD4493293} /quiet /norestart
	MsiExec.exe /uninstall {7AD8EB38-C7C0-453A-BEC6-D7149EA62EC3} /quiet /norestart
	:: Adobe Flash Player v11.3.300.257
	MsiExec.exe /uninstall {3D3085B0-BC4D-4559-B0AE-F5C879DEFFC4} /quiet /norestart
	MsiExec.exe /uninstall {CF753404-1C40-437F-859E-7EA8BEDABC64} /quiet /norestart
	:: Adobe Flash Player v11.3.300.262
	MsiExec.exe /uninstall {309970D0-D0E2-49AB-B9A2-80F48E22947A} /quiet /norestart
	MsiExec.exe /uninstall {D13D4F0A-6D90-415B-88A9-3E31EE3A5410} /quiet /norestart
	:: Adobe Flash Player v11.3.300.265
	MsiExec.exe /uninstall {417EF49A-B315-449F-9652-85C8CB988042} /quiet /norestart
	MsiExec.exe /uninstall {2BEF1A84-6975-4339-9E06-A70A6EE0CFE8} /quiet /norestart
	:: Adobe Flash Player v11.3.300.268
	MsiExec.exe /uninstall {9BFB1FAB-8FC4-4FAA-9B2D-2B121834B659} /quiet /norestart
	MsiExec.exe /uninstall {DEA37712-5F54-4EF8-AD50-35D1181F79BF} /quiet /norestart
	:: Adobe Flash Player v11.3.300.270
	MsiExec.exe /uninstall {4C85A58E-48BA-4252-90C5-C9CA5E0C83D7} /quiet /norestart
	MsiExec.exe /uninstall {244137C6-0414-48C9-BEFC-EAABDDB910AA} /quiet /norestart
	:: Adobe Flash Player v11.3.300.271
	MsiExec.exe /uninstall {05AADFE6-43D6-4c7c-9433-5F6EF02BF44F} /quiet /norestart
	MsiExec.exe /uninstall {A26798D5-245C-4071-9681-9CE85731A115} /quiet /norestart
	:: Adobe Flash Player v11.3.300.272
	MsiExec.exe /uninstall {395CFBE7-19F1-4494-8ECF-6392D459CE0A} /quiet /norestart
	MsiExec.exe /uninstall {84D0FEC8-D375-448e-9CA6-7A00BD1C4519} /quiet /norestart
	:: Adobe Flash Player v11.4.402.256
	MsiExec.exe /uninstall {97E0DCFB-4CBE-4DA6-955E-B8E4DE37E466} /quiet /norestart
	MsiExec.exe /uninstall {9B560327-156A-46D3-9055-35B3DC5E656F} /quiet /norestart
	:: Adobe Flash Player v11.4.402.278
	MsiExec.exe /uninstall {8C27E4F1-9CE6-4C32-ADBB-D51CD226649E} /quiet /norestart
	MsiExec.exe /uninstall {84B1F33D-5AA3-4669-89BC-CACE194EE877} /quiet /norestart
	:: Adobe Flash Player v11.4.402.287
	MsiExec.exe /uninstall {709D081A-4E86-43F5-9D67-6EAF47EE585E} /quiet /norestart
	MsiExec.exe /uninstall {5E076E3C-9C1C-49C7-B53C-6ECE986F073A} /quiet /norestart
call :log "%CUR_DATE% %TIME%    Done."



call :log "%CUR_DATE% %TIME%   Done."



::::::::::::::::::::::::::::::::
:: FILE AND DIRECTORY CLEANUP ::
::::::::::::::::::::::::::::::::
call :log "%CUR_DATE% %TIME%   Commencing manual purge of leftover files..."

:: JOB: Flash Player update services
call :log "%CUR_DATE% %TIME%    Killing Flash Player Update services..."
	:: Delete the Adobe Acrobat Update Service
	net stop AdobeARMservice >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete AdobeARMservice >> "%LOGPATH%\%LOGFILE%" 2>NUL
	:: Delete the Adobe Acrobat Update Service (older version)
	net stop armsvc >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete armsvc >> "%LOGPATH%\%LOGFILE%" 2>NUL
	:: Delete the Adobe Flash Player Update Service
	net stop AdobeFlashPlayerUpdateSvc >> "%LOGPATH%\%LOGFILE%" 2>NUL
	sc delete AdobeFlashPlayerUpdateSvc >> "%LOGPATH%\%LOGFILE%" 2>NUL
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Task Scheduler jobs
call :log "%CUR_DATE% %TIME%    Killing Flash Player task scheduler jobs..."
	del /F /Q "%SystemDrive%\Windows\tasks\Adobe Flash Player Updater.job" >> "%LOGPATH%\%LOGFILE%" 2>NUL
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Acrotray icon
call :log "%CUR_DATE% %TIME%    Killing Acrotray system tray icon..."
if exist "%ProgramFiles(x86)%\Adobe\Acrobat 7.0\Distillr\acrotray.exe" (
	taskkill /im "acrotray.exe" >> "%LOGPATH%\%LOGFILE%" 2>NUL
	del /f /q "%ProgramFiles(x86)%\Adobe\Acrobat 7.0\Distillr\acrotray.exe" >> "%LOGPATH%\%LOGFILE%" 2>NUL
)
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Stale directories
call :log "%CUR_DATE% %TIME%    Removing stale Flash directories..."
	ATTRIB -H -S -R "%WINDIR%\System32\Macromed\Flash" /s /d >> "%LOGPATH%\%LOGFILE%" 2>NUL
	ATTRIB -H -S -R "%WINDIR%\SysWOW64\Macromed\Flash" /s /d >> "%LOGPATH%\%LOGFILE%" 2>NUL
	if exist "%WINDIR%\System32\Macromed\Flash" rmdir "%WINDIR%\System32\Macromed\Flash" /s /q >> "%LOGPATH%\%LOGFILE%" 2>NUL
	if exist "%WINDIR%\SysWOW64\Macromed\Flash" rmdir "%WINDIR%\SysWOW64\Macromed\Flash" /s /q >> "%LOGPATH%\%LOGFILE%" 2>NUL
	if exist "%SYSTEMDRIVE%\Document and Settings\%USERNAME%\Application Data\Adobe\Flash Player" rmdir "%SYSTEMDRIVE%\Document and Settings\%USERNAME%\Application Data\Adobe\Flash Player" /s /q >> "%LOGPATH%\%LOGFILE%"
	if exist "%SYSTEMDRIVE%\Document and Settings\%USERNAME%\Application Data\Macromedia\Flash" rmdir "%SYSTEMDRIVE%\Document and Settings\%USERNAME%\Application Data\Macromedia\flash" /s /q >> "%LOGPATH%\%LOGFILE%"
	if exist "%SYSTEMDRIVE%\Users\%USERNAME%\AppData\Roaming\Adobe\Flash Player" rmdir "%SYSTEMDRIVE%\Users\%USERNAME%\AppData\Roaming\Adobe\Flash Player" /s /q >> "%LOGPATH%\%LOGFILE%"
	if exist "%SYSTEMDRIVE%\Users\%USERNAME%\AppData\Roaming\Adobe\Flash Player" rmdir "%SYSTEMDRIVE%\Users\%USERNAME%\AppData\Roaming\Macromedia\Flash Player" /s /q >> "%LOGPATH%\%LOGFILE%"
	if exist "%APPDATA%\Adobe\Flash Player" rmdir "%APPDATA%\Adobe\Flash Player" /s /q >> "%LOGPATH%\%LOGFILE%"
	if exist "%APPDATA%\Macromedia\Flash Player" rmdir "%APPDATA%\Macromedia\Flash Player" /s /q >> "%LOGPATH%\%LOGFILE%"
call :log "%CUR_DATE% %TIME%    Done."


:: JOB: Prefetch and cache files
call :log "%CUR_DATE% %TIME%    Removing any existing prefetch and cached files..."
	if exist "%WINDIR%\Prefetch\PLUGIN-CONTAINER*.pf" del "%WINDIR%\Prefetch\PLUGIN-CONTAINER*.pf" >> "%LOGPATH%\%LOGFILE%"
	if exist "%WINDIR%\Prefetch\flashpl*.pf" del "%WINDIR%\Prefetch\flashpl*.pf" >> "%LOGPATH%\%LOGFILE%"
	if exist "%WINDIR%\Prefetch\firefox*.pf" del "%WINDIR%\Prefetch\firefox*.pf" >> "%LOGPATH%\%LOGFILE%"

	:: These items pulled from this official Adobe post: https://forums.adobe.com/thread/928315
	for %%i in (FlashPlayerCPLApp.cpl,FlashPlayerApp.exe,FlashPlayerInstaller.exe) do (
		if exist "%WINDIR%\system32\%%i" del /f /q "%WINDIR%\system32\%%i" >> "%LOGPATH%\%LOGFILE%"
		if exist "%WINDIR%\SysWOW64\%%i" del /f /q "%WINDIR%\SysWOW64\%%i" >> "%LOGPATH%\%LOGFILE%"
	)
call :log "%CUR_DATE% %TIME%    Done."



call :log "%CUR_DATE% %TIME%   Done."

REM Return exit code to SCCM/PDQ Deploy/etc
exit /B %EXIT_CODE%






:::::::::::::::
:: FUNCTIONS ::
:::::::::::::::
:log
echo:%~1 >> "%LOGPATH%\%LOGFILE%"
echo:%~1
goto :eof
