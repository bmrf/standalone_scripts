:: Purpose:       Locks down/turns off unnecessary Windows services. Can also undo this lockdown operation.
:: Requirements:  Administrator access. Some services don't exist if a Service Pack is missing; this is okay, they'll just be skipped.
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       2.2.2 Loopified most command blocks, significantly reducing script size
::                2.2.1 Switched to CUR_DATE format to be consistent with all other scripts
::                2.2.0 Added /y switch to a few commands to auto-answer yes instead of prompting
::                2.1.0 Added very minor logging function
::                2.0.0 Massive re-write. New menus, new logic and flow, new services, new
::                      Operating Systems added (Vista/7/XP x64), Windows XP updated to SP3.
::                1.0.0 Original script (Windows XP SP2 only)

:: NOTES
:: ---------------------------------
:: BlackViper.com is due original credit for the four levels of "aggressiveness" for
:: locking down services (he calls his default/safe/tweaked/bare-bones).
:: These profiles are identical to his with the exception of two things:
:: 1. The "moderate" profile deviates from his to suite my tastes, and 2. I retained
:: network functionality in the "aggressive" profiles.

:: MISC
:: ---------------------------------
:: This script uses the "main code block plus add-on code block" method for the profiles to cut
:: down on the size of the script. Behind the scenes, for each OS, there are two "base" profiles
:: and two "add-on" profiles. First, one is run, then (if selected) the other block is run
:: afterwards. Rather than create an entire service configuration script for each profile, I just
:: have the "add-on" profile run as an addendum to the "base" profile. An example are the "Default"
:: and "Minor" profiles. "Default" forms the base for "Minor", since they are so similar. This adds
:: some craziness to the logic...but I managed to solve it by using two variables, basePROFILE and
:: PROFILE. basePROFILE sets our start point and PROFILE sets our overall profile. "If" statements
:: evaluate those two variables at the end of each Profile code block and act accordingly.

:: USER FLOW
:: ---------------------------------
:: The user sees these screens in order:
::     1. Warning/welcome
::     2. Operating System choice menu
::     3. "Profile" choice menu
::     4. "Apply Now or later?" menu
::     5. Confirmation menu
::          - execution
::     6. End screen.

:: CODE INDEX (top-to-bottom layout)
:: ---------------------------------
:: 0. Console prep and variable declaration
:: 1. Welcome/warning screen
:: 2. Operating System menu
:: 3. Windows XP 32-bit, Profile menu
::     - Default
::     - Default    ("apply Now" supplement)
::     - Minor
::     - Minor      ("apply Now" supplement)
::     - Moderate
::     - Moderate   ("apply Now" supplement)
::     - Aggressive
::     - Aggressive ("apply Now" supplement)
:: 4. Windows Vista 32-bit, Profile menu
::     - Default
::     - Default    ("apply Now" supplement)
::     - Minor
::     - Minor      ("apply Now" supplement)
::     - Moderate
::     - Moderate   ("apply Now" supplement)
::     - Aggressive
::     - Aggressive ("apply Now" supplement)
:: 5. Windows 7 32-bit, Profile menu
::     - Default
::     - Default    ("apply Now" supplement)
::     - Minor
::     - Minor      ("apply Now" supplement)
::     - Moderate
::     - Moderate   ("apply Now" supplement)
::     - Aggressive
::     - Aggressive ("apply Now" supplement)
:: 6. Windows XP 64-bit, Profile menu
::     - Default
::     - Default    ("apply Now" supplement)
::     - Minor
::     - Minor      ("apply Now" supplement)
::     - Moderate
::     - Moderate   ("apply Now" supplement)
::     - Aggressive
::     - Aggressive ("apply Now" supplement)
:: 7. End screen
SETLOCAL


:::::::::::::::
:: VARIABLES :: -------------- These are the defaults. Change them if you so desire. --------- ::
:::::::::::::::

:: Log location
set LOGPATH=%systemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_Windows_Services_Lockdown.log

:: This makes sure log file exists
if not exist %LOGPATH% mkdir %LOGPATH%
if not exist %LOGPATH%\%LOGFILE% echo. > %LOGPATH%\%LOGFILE%


:: --------------------------- Don't edit anything below this line --------------------------- ::



:::::::::::::::::::::
:: PREP AND CHECKS ::
:::::::::::::::::::::
@echo off
cls
set SCRIPT_VERSION=2.2.2
set SCRIPT_DATE=2015-08-28
set WIN_VER=--
set namePROFILE=--
set WHEN_TO_APPLY=--

:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%



:::::::::::::
:: EXECUTE ::
:::::::::::::

:: Welcome / Warning screen
:warning
color 0c
title Windows Services Lockdown v%SCRIPT_VERSION%
cls
echo.
echo  ********************************* WARNING *********************************
echo  *                                                                         *
echo  *                    HEY!! Read this! It's important.                     *
echo  *                                                                         *
echo  * This script disables unnecessary Windows services (hidden programs).    *
echo  * This is a good thing - it reduces RAM usage and attack surface. However,*
echo  * sometimes it disables a service that you were using and didn't know     *
echo  * about, causing errors, program crashes, and/or explosions in Italy.     *
echo  *                                                                         *
echo  * GOOD NEWS! This is easy to fix. If you have *ANY* problems after using  *
echo  * this script, just run it again and choose option 1: "defaults" for your *
echo  * operating system. Everything will be restored to the default state.     *
echo  *                                                                         *
echo  * One last thing - you have to run this script as an ADMINISTRATOR.       *
echo  *                                                                         *
echo  * Ready? Press any key to go to the main menu...                          *
echo  *                                                                         *
echo  ***************************************************************************
echo.
pause


:: Welcome screen
:os_menu
::color 17 is white on blue
color 17
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 1/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo                 Select the operating system you are using
echo.
echo    -----------------------------------------------------------------------
echo       Operating System       Architecture       Service Pack
echo    -----------------------------------------------------------------------
echo    1. Windows XP             32-bit                up to SP3
echo    2. Windows XP             64-bit                up to SP2
echo    3. Windows Vista          32-bit/64-bit         up to SP2
echo    4. Windows 7              32-bit/64-bit         up to SP1
echo.
echo    5. Exit
echo.
echo.
:: menu: Setup menu processing
:os_menuChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' goto XP_32_menu_profile
    if '%choice%'=='2' goto XP_64_menu_profile
    if '%choice%'=='3' goto Vista_32_menu_profile
    if '%choice%'=='4' goto 7_32_menu_profile
    if '%choice%'=='5' goto quit
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto os_menuChoice


:XP_32_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WIN_VER=Windows XP 32-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo              Select the lockdown profile to apply to 87 services
echo    -----------------------------------------------------------------------
echo       PROFILE                   Disabled   On-demand     Running    Total
echo    -----------------------------------------------------------------------
echo    1. Windows Defaults                 6          36          39       81
echo    2. Minor                           26          29          26       81
echo    3. Moderate (recommended)          52          19          16       87
echo    4. Aggressive                      72           5          10       87
echo.
echo    5. Go back to Operating System choices
echo.
echo.
:XP_32_menu_profileChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set PROFILE=XP_32_default && set basePROFILE=XP_32_default && set namePROFILE=Default&& goto XP_32_menu_confirm
    if '%choice%'=='2' set PROFILE=XP_32_minor && set basePROFILE=XP_32_default && set namePROFILE=Minor&& goto XP_32_menu_confirm
    if '%choice%'=='3' set PROFILE=XP_32_moderate && set basePROFILE=XP_32_moderate && set namePROFILE=Moderate&& goto XP_32_menu_confirm
    if '%choice%'=='4' set PROFILE=XP_32_aggressive && set basePROFILE=XP_32_moderate && set namePROFILE=Aggressive&& goto XP_32_menu_confirm
    if '%choice%'=='5' set WIN_VER=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_32_menu_profileChoice


:XP_32_menu_confirm
:: Confirm the profile and execute
set WIN_VER=Windows XP 32-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WIN_VER% "%namePROFILE%" CONFIGURATION!
echo.
echo.
echo                                CONFIRM?
echo.
echo    1. Yes - changes take effect immediately
echo    2. Yes - changes take effect after reboot (coward! do it now!)
echo.
echo    3. No  - go back to profile selection
echo.
echo.
:XP_32_menu_confirmChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set WHEN_TO_APPLY=Now && goto %basePROFILE%
    if '%choice%'=='2' set WHEN_TO_APPLY=reboot && goto %basePROFILE%
    if '%choice%'=='3' set namePROFILE=-- && goto XP_32_menu_profile
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_32_menu_confirmChoice


:XP_32_default
:: Operating system defaults. Default also forms the base for the Minor profile.
cls
title Resetting to defaults...
echo.
echo Now resetting all services to the %WIN_VER% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,helpsvc,lanmanserver,lanmanworks,ation,LmHosts,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,Share,Access,ShellHWDetection,Spooler,srservice,Themes,TrkWks,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Only start on demand":
for %%i in (ALG,AppMgmt,BITS,cisvc,COMSysApp,dmadmin,Dot3svc,EapHost,EventSystem,FastUserSwitchingCompatibility,hkmsvc,HTTPFilter,ImapiService,mnmsrvc,MSDTC,MSIServer,napagent,Netlogon,Netman,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RpcLocator,RSVP,SCardSvr,SSDPSRV,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,TlntSvr,upnphost,UPS,V,S,WmdmPmSN,Wmi,WmiApSrv,xmlprov
) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (Alerter,ClipSrv,HidServ,Messenger,NetDDE,NetDDEdsdm,RemoteAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)



if %WHEN_TO_APPLY%==Now goto XP_32_default_Now
if %PROFILE%==XP_32_minor goto XP_32_minor
goto end

:XP_32_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,FastUserSwitchingCompatibility,h,lpsvc,HidServ,lanmanserver,lanmanworkstation,LmHosts,mnmsrvc,Netlogon,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,SharedAccess,ShellHWDetection,Spooler,srservice,SSDPSRV,T,emes,TrkWks,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (Alerter,ALG,AppMgmt,BITS,cisvc,ClipSrv,COMSysApp,dmadmin,Dot3svc,EapHost,hkmsvc,HTTPFilter,ImapiService,Mes,enger,MSDTC,MSIServer,napagent,NetDDE,NetDDEdsdm,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RemoteAccess,RpcLocator,RSVP,SCardSvr,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,TlntSvr,upnphost,UPS,VSS,WmdmPmSN,Wmi,Wm,ApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net	stop EventSystem /y
net	stop Netman	/y



if %PROFILE%==XP_32_minor goto XP_32_minor
goto end


:XP_32_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Only start on demand":
for %%i in (dmserver,TrkWks,W32Time) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (cisvc,ERSvc,helpsvc,LmHosts,mnmsrvc,RDSessMgr,RemoteRegistry,RSVP,SCardSvr,seclogon,TlntSvr,UPS,WebClient,WdmPmSN,WmiApSrv,xmlprov) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_32_minor_Now
goto end


:XP_32_minor_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (cisvc,dmserver,ERSvc,helpsvc,LmHosts,mnmsrvc,RDSessMgr,RemoteRegistry,RSVP,SCardSvr,seclogon,TlntSvr,TrkWks,UPS,W32Time,WebClient,WmdmPmSN,WmiApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

 If we executed this block then there's nothing left to do, so we go to the end. whew!
goto end


:XP_32_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioSrv,CryptSvc,DcomLaunch,Dhcp,Eventlog,lanmanserver,lanmanworkstation,PlugPlay,RpcSs,SamSs,SharedAccess,Spooler,winmgmt,wuauserv,WZCSVC) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Only start on demand":
for %%i in (AppMgmt,BITS,Browser,COMSysApp,dmadmin,dmserver,Dnscache,EventSystem,FastUserSwitchingCompatibility,ImapiService,MSIServer,napagent,Netman,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,TapiSrv,TermService,TrkWks,Wmi) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (Alerter,ALG,cisvc,ClipSrv,Dot3svc,EapHost,ERSvc,helpsvc,HidServ,hkmsvc,HTTPFilter,LmHosts,Messenger,mnmsrvc,MSDTC,NetDDE,NetDDEdsdm,Netlogon,NtmsSvc,PolicyAgent,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,RSVP,SENS,srservice,SSDPSRV,stisvc,SwPrv,SysmonLog,Themes,TlntSvr,upnphost,UPS,VSS,W32Time,WebClient,WmdmPmSN,WmiApSrv,wscsvc,xmlprov) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_32_moderate_Now
if %PROFILE%==XP_32_aggressive goto XP_32_aggressive
goto end


:XP_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioSrv,CryptSvc,DcomLaunch,Dhcp,Eventlog,lanmanserver,lanmanworkstation,PlugPlay,RpcSs,SamSs,SharedAccess,Spooler,winmgmt,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (Alerter,ALG,AppMgmt,BITS,Browser,cisvc,ClipSrv,COMSysApp,dmadmin,dmserver,Dnscache,Dot3svc,EapHost,ERSvc,FastUserSwitchingCompatibility,helpsvc,HidServ,hkmsvc,HTTPFilter,ImapiService,LmHosts,Messenger,mnmsrvc,MSDTC,MSIServer,napagent,NetDDE,NetDDEdsdm,Netlogon,Nla,NtLmSsp,NtmsSvc,PolicyAgent,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,RpcLocator,RSVP,SCardSvr,Schedule,seclogon,SENS,ShellHWDetection,srservice,SSDPSRV,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,Themes,TlntSvr,TrkWks,upnphost,UPS,VSS,W32Time,WebClient,WmdmPmSN,Wmi,WmiApSrv,wscsvc,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net stop EventSystem /y
net stop Netman /y


if %PROFILE%==XP_32_aggressive goto XP_32_aggressive
goto end


:XP_32_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile, as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Now applying Aggressive profile...
echo Setting the following services to "Only start on demand":
for %%i in (Spooler,wuauserv) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (AppMgmt,Browser,COMSysApp,CryptSvc,dmadmin,dmserver,Dnscache,EventSystem,FastUserSwitchingCompatibility,ImapiService,lanmanserver,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,TapiSrv,TermService,TrkWks) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_32_aggressive_Now
goto end


:XP_32_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (AppMgmt,Browser,COMSysApp,CryptSvc,dmadmin,dmserver,Dnscache,FastUserSwitchingCompatibility,ImapiService,lanmanserver,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,Spooler,TapiSrv,TermService,TrkWks,wuauserv) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net	stop EventSystem /y


 If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


:Vista_32_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WIN_VER=Windows Vista 32/64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo              Select the lockdown profile to apply to 121 services
echo    -----------------------------------------------------------------------
echo       PROFILE                   Disabled   On-demand     Running    Total
echo    -----------------------------------------------------------------------
echo    1. Windows Defaults                 4          64          53      121
echo    2. Minor                           20          54          47      121
echo    3. Moderate (recommended)          52          35          34      121
echo    4. Aggressive                      72          24          25      121
echo.
echo    5. Go back to Operating System choices
echo.
echo.
:Vista_32_menu_profileChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set PROFILE=Vista_32_default && set basePROFILE=Vista_32_default && set namePROFILE=Default && goto Vista_32_menu_confirm
    if '%choice%'=='2' set PROFILE=Vista_32_minor && set basePROFILE=Vista_32_default && set namePROFILE=Minor && goto Vista_32_menu_confirm
    if '%choice%'=='3' set PROFILE=Vista_32_moderate && set basePROFILE=Vista_32_moderate && set namePROFILE=Moderate && goto Vista_32_menu_confirm
    if '%choice%'=='4' set PROFILE=Vista_32_aggressive && set basePROFILE=Vista_32_moderate && set namePROFILE=Aggressive && goto Vista_32_menu_confirm
    if '%choice%'=='5' set WIN_VER=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto Vista_32_menu_profileChoice


:Vista_32_menu_confirm
:: Confirm the profile and execute
set WIN_VER=Windows Vista 32/64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WIN_VER% "%namePROFILE%" CONFIGURATION!
echo.
echo.
echo                                CONFIRM?
echo.
echo    1. Yes - changes take effect immediately
echo    2. Yes - changes take effect at next reboot
echo.
echo    3. No, go back to profile selection
echo.
echo.
:Vista_32_menu_confirmChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set WHEN_TO_APPLY=Now && goto %basePROFILE%
    if '%choice%'=='2' set WHEN_TO_APPLY=reboot && goto %basePROFILE%
    if '%choice%'=='3' set namePROFILE=-- && goto Vista_32_menu_profile
echo.
echo  "%choice%" is not valid, please try again
echo.
goto Vista_32_menu_confirmChoice


:Vista_32_default
:: Operating system defaults. Default also forms the base for the Minor profile.
cls
title Resetting to defaults...
echo.
echo Now resetting all services to the %WIN_VER% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AeLookupSvc,AudioEndpointBuilder,AudioSrv,BFE,BITS,Browser,CryptSvc,CscService,Dhcp,Dnscache,ehstart,EMDMgmt,Eventlog,EventSystem,FDResPub,IKEEXT,iphlpsvc,KtmRm,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,seclogon,SENS,ShellHWDetection,slsvc,Spooler,SysMain,TabletInputService,TBS,TermService,Themes,upnphost,UxSms,W32Time,WebClient,WerSvc,WinDefend,Winmgmt,Wlansvc,WPDBusEnum,wscsvc,WSearch,wuauserv) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)


echo Setting the following services to "Automatic start (delayed)":
for %%i in (BITS,ehstart,KtmRm,TBS,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)


echo Setting the following services to "Only start on demand":
for %%i in (ALG,Appinfo,AppMgmt,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,DFSR,dot3svc,EapHost,ehRecvr,ehSched,Fax,fdPHost,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IPBusEnum,KeyIso,lltdsvc,MSDTC,MSiSCSI,msiserver,napage,t,Netlogon,Netman,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,SessionEnv,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TapiSrv,THREADORDER,UI0Detect,UmRdpService,vds,VSS,wbengine,wcncsvc,WcsPlugInService,Wecsvc,wercplsupport,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,wudfsvc) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (Mcx2Svc,NetTcpPortSharing,RemoteAccess,SharedAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)




if %WHEN_TO_APPLY%==Now goto Vista_32_default_Now
if %PROFILE%==Vista_32_minor goto Vista_32_minor
goto end


:Vista_32_default_Now
:: This section runs after the Default profile, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AeLookupSvc,AudioEndpointBuilder,AudioSrv,BFE,BITS,Browser,CryptSvc,CscService,Dhcp,Dnscache,ehstart,EMDMgmt,Eventlog,EventSystem,FDResPub,IKEEXT,iphlpsvc,KtmRm,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,Netlogon,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,seclogon,SENS,ShellHWDetection,slsvc,Spooler,SysMain,TabletInputService,TBS,TermService,Themes,upnphost,UxSms,W32Time,WebClient,WerSvc,WinDefend,Winmgmt,Wlansvc,WPDBusEnum,wscsvc,WSearch,wuauserv) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (ALG,Appinfo,AppMgmt,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,DFSR,dot3svc,EapHost,ehRecvr,ehSched,Fax,fdPHost,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IPBusEnum,KeyIso,lltdsvc,Mcx2Svc,MSDTC,MSiSCSI,msiserver,napagent,NetTcpPortSharing,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,SessionEnv,SharedAccess,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TapiSrv,THREADORDER,UI0Detect,UmRdpService,vds,VSS,wbengine,wcncsvc,WcsPlugInService,Wecsvc,wercplsupport,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,wudfsvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net stop netman /y


if %PROFILE%==Vista_32_minor goto Vista_32_minor
goto end


:Vista_32_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Disabled":
for %%i in (CertPropSvc,CscService,Fax,iphlpsvc,MSiSCSI,Netlogon,RemoteRegistry,SCardSvr,SCPolicySvc,SNMPTRAP,TabletInputService,UmRdpService,WebClient,WinHttpAutoProxySvc,WinRM,WSearch) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)

sc config TBS start= demand
sc config TBS start= delayed-auto


if %WHEN_TO_APPLY%==Now goto Vista_32_minor_Now
goto end


:Vista_32_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
echo Stopping the following services:
for %%i in (CertPropSvc,Fax,iphlpsvc,MSiSCSI,Netlogon,CscService,RemoteRegistry,SCardSvr,SCPolicySvc,SNMPTRAP,TabletInputService,UmRdpService,TBS,WebClient,WinRM,WSearch,WinHttpAutoProxySvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

 If we executed this block then there's nothing left to do, so we go to the end. whew!
goto end


:Vista_32_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioEndpointBuilder,AudioSrv,BFE,BITS,CryptSvc,Dhcp,Dnscache,EMDMgmt,Eventlog,EventSystem,KtmRm,LanmanServer,LanmanWorkstation,MMCSS,MpsSvc,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,SENS,ShellHWDetection,slsvc,Spooler,SysMain,W32Time,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Automatic start (delayed)":
for %%i in (BITS,KtmRm,TBS,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)

echo Setting the following services to "Only start on demand":
for %%i in (ALG,Appinfo,AppMgmt,Browser,clr_optimization_v2.0.50727_32,COMSysApp,dot3svc,FontCache3.0.0.0,IKEEXT,KeyIso,msiserver,Netman,pla,ProtectedStorage,RasAuto,RasMan,RpcLocator,SDRSVC,seclogon,SessionEnv,SLUINotify,SSDPSRV,SstpSvc,swprv,TBS,TermService,THREADORDER,UI0Detect,upnphost,VSS,wbengine,WcsPlugInService,Wecsvc,wmiApSrv,wudfsvc) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)


echo Setting the following services to "Disabled":
for %%i in (AeLookupSvc,CertPropSvc,CscService,DFSR,EapHost,ehRecvr,ehSched,ehstart,Fax,fdPHost,FDResPub,hidserv,hkmsvc,idsvc,IPBusEnum,iphlpsvc,lltdsvc,lmhosts,Mcx2Svc,MSDTC,MSiSCSI,napagent,Netlogon,NetTcpPortSharing,p2pimsvc,p2psvc,PNRPAutoReg,PNRPsvc,QWAVE,RemoteAccess,RemoteRegistry,SCardSvr,SCPolicySvc,SharedAccess,SNMPTRAP,stisvc,TabletInputService,TapiSrv,Themes,UmRdpService,UxSms,vds,wcncsvc,WebClient,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,WMPNetworkSvc,WPCSvc,WPDBusEnum,WSearch) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


:: Moderate end
if %WHEN_TO_APPLY%==Now goto Vista_32_moderate_Now
if %PROFILE%==Vista_32_aggressive goto Vista_32_aggressive
goto end


:Vista_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioEndpointBuilder,AudioSrv,BFE,BITS,CryptSvc,Dhcp,Dnscache,EMDMgmt,Eventlog,EventSystem,KtmRm,LanmanServer,LanmanWorkstation,MMCSS,MpsSvc,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,SENS,ShellHWDetection,slsvc,Spooler,SysMain,W32Time,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (AeLookupSvc,ALG,Appinfo,AppMgmt,Browser,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,CscService,DFSR,dot3svc,EapHost,ehRecvr,ehSched,ehstart,Fax,fdPHost,FDResPub,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IKEEXT,IPBusEnum,iphlpsvc,KeyIso,lltdsvc,lmhosts,Mcx2Svc,MSDTC,MSiSCSI,msiserver,napagent,Netlogon,NetTcpPortSharing,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SessionEnv,SharedAccess,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TabletInputService,TapiSrv,TBS,TermService,Themes,THREADORDER,UI0Detect,UmRdpService,upnphost,UxSms,vds,VSS,wbengine,wcncsvc,WcsPlugInService,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,WPDBusEnum,WSearch,wudfsvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net stop Netman /y


if %PROFILE%==Vista_32_aggressive goto Vista_32_aggressive
goto end


:Vista_32_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Now applying Aggressive profile...

echo Setting the following services to "Only start on demand":
for %%i in (PcaSvc,W32Time) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (ALG,AppMgmt,BFE,clr_optimization_v2.0.50727_32,EMDMgmt,FontCache3.0.0.0,IKEEXT,KeyIso,KtmRm,pla,PolicyAgent,ShellHWDetection,swprv,TermService,UI0Detect,upnphost,wbengine,WcsPlugInService,WinDefend,wscsvc) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)



if %WHEN_TO_APPLY%==Now goto Vista_32_aggressive_Now
goto end


:Vista_32_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (ALG,AppMgmt,BFE,clr_optimization_v2.0.50727_32,EMDMgmt,FontCache3.0.0.0,IKEEXT,KeyIso,KtmRm,PcaSvc,pla,PolicyAgent,ShellHWDetection,swprv,TermService,UI0Detect,upnphost,W32Time,wbengine,WcsPlugInService,WinDefend,wscsvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

 If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end



:7_32_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WIN_VER=Windows 7 32/64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo              Select the lockdown profile to apply to 136 services
echo    -----------------------------------------------------------------------
echo       PROFILE                   Disabled   On-demand     Running    Total
echo    -----------------------------------------------------------------------
echo    1. Windows Defaults                 2          85          36      123
echo    2. Minor                           18          72          34      124
echo    3. Moderate (recommended)          61          42          33      136
echo    4. Aggressive                      82          32          24      138
echo.
echo    5. Go back to Operating System choices
echo.
echo.
:7_32_menu_profileChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set PROFILE=7_32_default && set basePROFILE=7_32_default && set namePROFILE=Default&& goto 7_32_menu_confirm
    if '%choice%'=='2' set PROFILE=7_32_minor && set basePROFILE=7_32_default && set namePROFILE=Minor&& goto 7_32_menu_confirm
    if '%choice%'=='3' set PROFILE=7_32_moderate && set basePROFILE=7_32_moderate && set namePROFILE=Moderate&& goto 7_32_menu_confirm
    if '%choice%'=='4' set PROFILE=7_32_aggressive && set basePROFILE=7_32_moderate && set namePROFILE=Aggressive&& goto 7_32_menu_confirm
    if '%choice%'=='5' set WIN_VER=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto 7_32_menu_choice


:7_32_menu_confirm
:: Confirm the profile and execute
set WIN_VER=Windows 7 32/64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WIN_VER% "%namePROFILE%" CONFIGURATION!
echo.
echo.
echo                                CONFIRM?
echo.
echo    1. Yes - changes take effect immediately
echo    2. Yes - changes take effect at next reboot
echo.
echo    3. No, go back to profile selection
echo.
echo.
:7_32_menu_confirmChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set WHEN_TO_APPLY=Now && goto %basePROFILE%
    if '%choice%'=='2' set WHEN_TO_APPLY=reboot && goto %basePROFILE%
    if '%choice%'=='3' set namePROFILE=-- && goto 7_32_menu_profile
echo.
echo  "%choice%" is not valid, please try again
echo.
goto 7_32_menu_confirmChoice


:7_32_default
:: Operating system defaults. Default also forms the base for the Minor profile.
cls
title Resetting to defaults...
echo.
echo Now resetting all services to the %WIN_VER% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,CryptSvc,CscService,Dhcp,Dnscache,Eventlog,EventSystem,FDResPub,iphlpsvc,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Automatic start (delayed)":
for %%i in (clr_optimization_v2.0.50727_32,sppsvc,WinDefend,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)

echo Setting the following services to "Only start on demand":
for %%i in (AeLookupSvc,ALG,AppIDSvc,Appinfo,AppMgmt,AxInstSV,BITS,Browser,bthserv,CertPropSvc,COMSysApp,defragsvc,dot3svc,EapHost,EFS,fdPHost,FontCache,hidserv,hkmsvc,HomeGroupListener,HomeGroupProvider,IKEEXT,IPBusEnum,KeyIso,KtmRm,lltdsvc,MSDTC,MSiSCSI,msiserver,napagent,Netlogon,Netman,netprofm,p2pimsvc,p2psvc,PcaSvc,PeerDistSvc,pla,PNRPAutoReg,PNRPsvc,PolicyAgent,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SensrSvc,SNMPTRAP,sppuinotify,SSDPSRV,SstpSvc,StiSvc,swprv,TabletInputService,TapiSrv,TBS,TermService,THREADORDER,UI0Detect,UmRdpService,upnphost,VaultSvc,vds,VSS,W32Time,wbengine,WbioSrvc,wcncsvc,WcsPlugInService,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WPCSvc,WPDBusEnum,wudfsvc,WwanSvc
) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (RemoteAccess,SharedAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)



if %WHEN_TO_APPLY%==Now goto 7_32_default_Now
if %PROFILE%==7_32_minor goto 7_32_minor
goto end

:7_32_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,clr_optimization_v2.0.50727_32,CryptSvc,CscService,Dhcp,Dnscache,Eventlog,EventSystem,FDResPub,iphlpsvc,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,Netlogon,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (AeLookupSvc,ALG,AppIDSvc,Appinfo,AppMgmt,AxInstSV,BITS,Browser,bthserv,CertPropSvc,COMSysApp,defragsvc,dot3svc,EapHost,EFS,fdPHost,FontCache,hidserv,hkmsvc,HomeGroupListener,HomeGroupProvider,IKEEXT,IPBusEnum,KeyIso,KtmRm,lltdsvc,MSDTC,MSiSCSI,msiserver,napagent,netprofm,p2pimsvc,p2psvc,PcaSvc,PeerDistSvc,pla,PNRPAutoReg,PNRPsvc,PolicyAgent,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SensrSvc,SharedAccess,SNMPTRAP,sppuinotify,SSDPSRV,SstpSvc,StiSvc,swprv,TabletInputService,TapiSrv,TBS,TermService,THREADORDER,UI0Detect,UmRdpService,upnphost,VaultSvc,vds,VSS,W32Time,wbengine,WbioSrvc,wcncsvc,WcsPlugInService,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WPCSvc,WPDBusEnum,wudfsvc,WwanSvc
) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)


net stop Netman /y


if %PROFILE%==7_32_minor goto 7_32_minor
goto end


:7_32_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.

echo Setting the following services to "Disabled":
for %%i in (AppMgmt,bthserv,PeerDistSvc,CertPropSvc,iphlpsvc,MSiSCSI,Netlogon,napagent,CscService,WPCSvc,RpcLocator,RemoteRegistry,SCardSvr,SCPolicySvc,SNMPTRAP,wcncsvc) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


sc config clr_optimization_v2.0.50727_32 start= demand


if %WHEN_TO_APPLY%==Now goto 7_32_minor_Now
goto end


:7_32_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
echo Stopping the following services:
for %%i in (AppMgmt,bthserv,PeerDistSvc,CertPropSvc,iphlpsvc,clr_optimization_v2.0.50727_32,MSiSCSI,Netlogon,napagent,CscService,WPCSvc,RpcLocator,RemoteRegistry,SCardSvr,SCPolicySvc,SNMPTRAP,wcncsvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)
 If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


:7_32_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,CryptSvc,Dhcp,Dnscache,Eventlog,EventSystem,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Automatic start (delayed)":
for %%i in (sppsvc,WinDefend,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)

echo Setting the following services to "Only start on demand":
for %%i in (AeLookupSvc,AppIDSvc,Appinfo,BITS,Browser,clr_optimization_v2.0.50727_32,COMSysApp,defragsvc,dot3svc,EapHost,FontCache,HomeGroupListener,HomeGroupProvider,IKEEXT,KeyIso,KtmRm,MSDTC,msiserver,Netman,netprofm,pla,PolicyAgent,ProtectedStorage,RasAuto,RasMan,SDRSVC,seclogon,sppuinotify,SSDPSRV,SstpSvc,StiSvc,swprv,TapiSrv,THREADORDER,upnphost,vds,VSS,W32Time,wbengine,Wecsvc,wmiApSrv,wudfsvc) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)


echo Setting the following services to "Disabled":
for %%i in (ALG,AppMgmt,AxInstSV,bthserv,CertPropSvc,CscService,Dps,EFS,ehRecvr,ehSched,fdPHost,FDResPub,hidserv,hkmsvc,idsvc,IPBusEnum,iphlp,vc,lltdsvc,MSiSCSI,napagent,Netlogon,p2pimsvc,p2psvc,PcaSvc,PeerDistSvc,PNRPAutoReg,PNRPsvc,QWAVE,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SensrSvc,SessionEnv,SharedAccess,ShellHWDetection,SNMPTRAP,StorSvc,TabletInputService,TBS,TermService,TrkWks,UI0Detect,UmRdpService,VaultSvc,WbioSrvc,wcncsvc,WcsPlugInService,WdiServiceHost,WdiSystemHost,WebClient,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,WPCSvc,WPDBusEnum,WwanSvc,Wsearch,WMPNetworkSvc
) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)

:: Test if we are also applying the Aggressive profile
if %WHEN_TO_APPLY%==Now goto 7_32_moderate_Now
if %PROFILE%==7_32_aggressive goto 7_32_aggressive
goto end


:7_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,clr_optimization_v2.0.50727_32,CryptSvc,Dhcp,Dnscache,Eventlog,EventSystem,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (AeLookupSvc,ALG,AppIDSvc,Appinfo,AppMgmt,AxInstSV,BITS,Browser,bthserv,CertPropSvc,COMSysApp,CscService,defragsvc,dot3svc,DPS,EapHost,EFS,ehRecvr,ehSched,fdPHost,FDResPub,FontCache,hidserv,hkmsvc,HomeGroupListener,HomeGroupProvider,idsvc,IKEEXT,IPBusEnum,iphlpsvc,KeyIso,KtmRm,lltdsvc,MSDTC,MSiSCSI,msiserver,napagent,Netlogon,netprofm,p2pimsvc,p2psvc,PcaSvc,PeerDistSvc,pla,PNRPAutoReg,PNRPsvc,PolicyAgent,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SensrSvc,SessionEnv,SharedAccess,ShellHWDetection,SNMPTRAP,sppuinotify,SSDPSRV,SstpSvc,StiSvc,StorSvc,swprv,TabletInputService,TapiSrv,TBS,TermService,THREADORDER,TrkWks,UI0Detect,UmRdpService,upnphost,VaultSvc,vds,VSS,W32Time,wbengine,WbioSrvc,wcncsvc,WcsPlugInService,WdiServiceHost,WdiSystemHost,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,WPDBusEnum,WSearch,wudfsvc,WwanSvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net stop Netman /y

if %PROFILE%==7_32_aggressive goto 7_32_aggressive
goto end


:7_32_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Disabled":
for %%i in (BITS,BFE,BDESVC,wbengine,KeyIso,UxSms,Dnscache,EapHost,HomeGroupListener,HomeGroupProvider,PolicyAgent,SstpSvc,wscsvc,lmhosts,TapiSrv,Themes,WinDefend,W32Time,dot3svc) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)

sc config wuauserv start= demand

:: These services were missing from the config tool and manually added by me
sc config NetTcpPortSharing start= disabled 2>NUL
sc config RpcLocator start= disabled 2>NUL

:: This is another service from our lovely Media Center edition. Goodbye.
REM Windows Presentation Foundation Font
sc config FontCache3.0.0.0 start= disabled 2>NUL


if %WHEN_TO_APPLY%==Now goto 7_32_aggressive_Now
goto end


:7_32_aggressive_Now
echo Stopping the following services:
for %%i in (BITS,BFE,BDESVC,wbengine,KeyIso,UxSms,Dnscache,EapHost,HomeGroupListener,HomeGroupProvider,PolicyAgent,SstpSvc,wscsvc,lmhosts,TapiSrv,Themes,WinDefend,W32Time,wuauserv,dot3svc,NetTcpPortSharing,RpcLocator,FontCache3.0.0.0) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

::If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


::::::::::::::::::::::::::::::::::
::                              ::
:: Beginning of 64-bit Sections ::
::                              ::
::::::::::::::::::::::::::::::::::


:XP_64_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WIN_VER=Windows XP 64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo              Select the lockdown profile to apply to 87 services
echo    -----------------------------------------------------------------------
echo       PROFILE                   Disabled   On-demand     Running    Total
echo    -----------------------------------------------------------------------
echo    1. Windows Defaults                 6          36          39       81
echo    2. Minor                           26          29          26       81
echo    3. Moderate (recommended)          52          19          16       87
echo    4. Aggressive                      72           5          10       87
echo.
echo    5. Go back to Operating System choices
echo.
echo.
:XP_64_menu_profileChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set PROFILE=XP_64_default && set basePROFILE=XP_64_default && set namePROFILE=Default&& goto XP_64_menu_confirm
    if '%choice%'=='2' set PROFILE=XP_64_minor && set basePROFILE=XP_64_default && set namePROFILE=Minor&& goto XP_64_menu_confirm
    if '%choice%'=='3' set PROFILE=XP_64_moderate && set basePROFILE=XP_64_moderate && set namePROFILE=Moderate&& goto XP_64_menu_confirm
    if '%choice%'=='4' set PROFILE=XP_64_aggressive && set basePROFILE=XP_64_moderate && set namePROFILE=Aggressive&& goto XP_64_menu_confirm
    if '%choice%'=='5' set WIN_VER=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_64_menu_profileChoice


:XP_64_menu_confirm
:: Confirm the profile and execute
set WIN_VER=Windows XP 64-bit
title Services Lockdown - %WIN_VER%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WIN_VER%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WIN_VER% "%namePROFILE%" CONFIGURATION!
echo.
echo.
echo                                CONFIRM?
echo.
echo    1. Yes - changes take effect immediately
echo    2. Yes - changes take effect at next reboot
echo.
echo    3. No, go back to profile selection
echo.
echo.
:XP_64_menu_confirmChoice
set /p choice=Choice:
if not '%choice%'=='' set choice=%Choice:~0,1%
    if '%choice%'=='1' set WHEN_TO_APPLY=Now && goto %basePROFILE%
    if '%choice%'=='2' set WHEN_TO_APPLY=reboot && goto %basePROFILE%
    if '%choice%'=='3' set namePROFILE=-- && goto XP_64_menu_profile
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_64_menu_confirmChoice


:XP_64_default
:: Operating system defaults. Default also forms the base for the Minor profile.
cls
title Resetting to defaults...
echo.
echo Now resetting all services to the %WIN_VER% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AeLookupSvc,AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,EventSystem,helpsvc,lanmanserver,lanmanworkstation,LmHosts,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,SharedAccess,ShellHWDetection,Spooler,srservice,stisvc,SysmonLog,Themes,TrkWks,upnphost,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Only start on demand":
for %%i in (ALG,AppMgmt,BITS,ClipSrv,COMSysApp,dmadmin,HTTPFilter,IASJet,ImapiService,mnmsrvc,MSDTC,MSIServer,NetDDE,NetDDEdsdm,Netlogon,Netman,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RpcLocator,SCardSvr,SSDPSRV,TapiSrv,TermService,UMWdf,UPS,vds,VSS,WinHttpAutoProxySvc,WmdmPmSN,Wmi,WmiApSrv,xmlprov) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (Alerter,cisvc,HidServ,Messenger,RemoteAccess,TlntSvr) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_64_default_Now
if %PROFILE%==XP_64_minor goto XP_64_minor
goto end

:XP_64_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AeLookupSvc,AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,EventSystem,helpsvc,lanmanserver,lanmanworkstation,LmHosts,Netlogon,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,SharedAccess,ShellHWDetection,Spooler,srservice,stisvc,SysmonLog,Themes,TrkWks,upnphost,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (Alerter,ALG,AppMgmt,BITS,cisvc,ClipSrv,COMSysApp,dmadmin,HidServ,HTTPFilter,IASJet,ImapiService,Messenger,mnmsrvc,MSDTC,MSIServer,NetDDE,NetDDEdsdm,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RemoteAccess,RpcLocator,SCardSvr,SSDPSRV,TapiSrv,TermService,TlntSvr,UMWdf,UPS,vds,VSS,WinHttpAutoProxySvc,WmdmPmSN,Wmi,WmiApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)


net stop Netman /y

if %PROFILE%==XP_64_minor goto XP_64_minor
goto end


:XP_64_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Only start on demand":
for %%i in (dmserver,EventSystem,helpsvc,seclogon,stisvc,SysmonLog,TrkWks,upnphost) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (ClipSrv,ERSvc,IASJet,LmHosts,mnmsrvc,NetDDE,NetDDEdsdm,Netlogon,RDSessMgr,RemoteRegistry,SCardSvr,UPS,vds,W32Time,WebClient,WinHttpAutoProxySvc,WmdmPmSN,WmiApSrv,xmlprov
) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_64_minor_Now
goto end


:XP_64_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
echo Stopping the following services:
for %%i in (ClipSrv,dmserver,ERSvc,helpsvc,IASJet,LmHosts,mnmsrvc,NetDDE,NetDDEdsdm,Netlogon,RDSessMgr,RemoteRegistry,SCardSvr,seclogon,SSDPSRV,stisvc,SysmonLog,TrkWks,upnphost,UPS,vds,W32Time,WebClient,WinHttpAutoProxySvc,WmdmPmSN,WmiApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)


net stop EventSystem /y
:: If we executed this block then there's nothing left to do, so we go to the end. whew!
goto end


:XP_64_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,Eventlog,lanmanserver,lanmanworkstation,PlugPlay,RpcSs,SamSs,SharedAccess,Spooler,winmgmt,wuauserv,WZCSVC) do (
	echo %%i...
	sc config %%i start= auto 2>NUL
)

echo Setting the following services to "Only start on demand":
for %%i in (BITS,dmadmin,dmserver,Dnscache,HTTPFilter,ImapiService,MSIServer,Netman,Nla,NtLmSsp,PolicyAgent,PNRPSvc,p2psvc,p2pgasvc,p2pimsvc,RpcLocator,TermService,Wmi,WmiApSrv) do (
	echo %%i...
	sc config %%i start= demand 2>NUL
)

echo Setting the following services to "Disabled":
for %%i in (6to4,AeLookupSvc,Alerter,ALG,AppMgmt,cisvc,ClipSrv,COMSysApp,ERSvc,EventSystem,helpsvc,HidServ,IASJet,LmHosts,Messenger,mnmsrvc,MSDTC,NetDDE,NetDDEdsdm,Netlogon,NtmsSvc,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,SCardSvr,Schedule,seclogon,SENS,ShellHWDetection,srservice,SSDPSRV,stisvc,SysmonLog,TapiSrv,Themes,TlntSvr,TrkWks,UMWdf,upnphost,UPS,vds,VSS,w3svc,W32Time,WebClient,WinHttpAutoProxySvc,WmdmPmSN,wscsvc,xmlprov
) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)



if %WHEN_TO_APPLY%==Now goto XP_64_moderate_Now
if %PROFILE%==XP_64_aggressive goto XP_64_aggressive
goto end


:XP_64_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,Eventlog,lanmanserver,lanmanworkstation,PlugPlay,RpcSs,SamSs,SharedAccess,Spooler,winmgmt,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i 2>NUL
)

echo Stopping the following services:
for %%i in (6to4,AeLookupSvc,Alerter,ALG,AppMgmt,BITS,cisvc,ClipSrv,COMSysApp,dmadmin,dmserver,Dnscache,ERSvc,helpsvc,HidServ,HTTPFilter,IASJet,ImapiService,LmHosts,Messenger,mnmsrvc,MSDTC,MSIServer,NetDDE,NetDDEdsdm,Netlogon,Nla,NtLmSsp,NtmsSvc,p2pgasvc,p2pimsvc,p2psvc,PNRPSvc,PolicyAgent,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,Schedule,seclogon,SENS,ShellHWDetection,srservice,SSDPSRV,stisvc,SysmonLog,TapiSrv,TermService,Themes,TlntSvr,TrkWks,UMWdf,upnphost,UPS,vds,VSS,W32Time,w3svc,WebClient,WinHttpAutoProxySvc,WmdmPmSN,Wmi,WmiApSrv,wscsvc,xmlprov) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

net stop Netman /y
net stop EventSystem /y

if %PROFILE%==XP_64_aggressive goto XP_64_aggressive
goto end


:XP_64_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
echo Setting the following services to "Disabled":
for %%i in (BITS,Browser,CryptSvc,dmadmin,dmserver,Dnscache,ImapiService,lanmanserver,Nla,NtLmSsp,PNRPSvc,p2psvc,p2pgasvc,p2pimsvc,RpcLocator,Spooler,TermService,Wmi,wuauserv,WZCSVC) do (
	echo Disabling %%i...
	sc config %%i start= disabled 2>NUL
)


if %WHEN_TO_APPLY%==Now goto XP_64_aggressive_Now
goto end


:XP_64_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (BITS,Browser,CryptSvc,dmadmin,dmserver,Dnscache,ImapiService,lanmanserver,Nla,NtLmSsp,RpcLocator,Spooler,TermService,Wmi,wuauserv,WZCSVC,PNRPSvc,p2psvc,p2pgasvc,p2pimsvc) do (
	echo Stopping %%i...
	net stop %%i 2>NUL
)

:: If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


:end
:: Save to the log what we just did. Maybe someday I'll add more advanced logging functions
if %WHEN_TO_APPLY%==reboot (
	echo %CUR_DATE% %TIME% [%COMPUTERNAME%]: Service lockdown profile "%namePROFILE%" applied by %USERDOMAIN%\%USERNAME%. Settings take effect at next reboot. >> %LOGPATH%\%LOGFILE%
	) ELSE (
	echo %CUR_DATE% %TIME% [%COMPUTERNAME%]: Service lockdown profile "%namePROFILE%" applied by %USERDOMAIN%\%USERNAME%. Settings took effect immediately. >> %LOGPATH%\%LOGFILE%
	)


:: Inform the user that we're done
title Lockdown Complete
echo.
echo.
echo                      LOCKDOWN COMPLETE
echo.
echo.
echo    The following configuration was applied:
echo.
echo.
echo    Operating System:  %WIN_VER%
echo    Profile:           %PROFILE%
echo    Changes Effective: %WHEN_TO_APPLY%
echo.
echo    Log file saved at: %LOGPATH%\%LOGFILE%
echo.
echo.
echo    Press any key to quit...
echo.
pause
