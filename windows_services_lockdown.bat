:: Purpose:       Locks down/turns off unnecessary Windows services. Can also undo this lockdown operation.
:: Requirements:  Administrator access. Some services don't exist if a Service Pack is missing; this is okay, they'll just be skipped.
:: Author:        reddit.com/user/vocatus ( vocatus.gate at gmail ) // PGP key: 0x07d1490f82a211a2
:: Version:       2.2.1 Switched to CUR_DATE format to be consistent with all other scripts
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
::     - Code block - Default
::     - Code block - Default    ("apply Now" supplement)
::     - Code block - Minor
::     - Code block - Minor      ("apply Now" supplement)
::     - Code block - Moderate
::     - Code block - Moderate   ("apply Now" supplement)
::     - Code block - Aggressive
::     - Code block - Aggressive ("apply Now" supplement)
:: 4. Windows Vista 32-bit, Profile menu
::     - Code block - Default
::     - Code block - Default    ("apply Now" supplement)
::     - Code block - Minor
::     - Code block - Minor      ("apply Now" supplement)
::     - Code block - Moderate
::     - Code block - Moderate   ("apply Now" supplement)
::     - Code block - Aggressive
::     - Code block - Aggressive ("apply Now" supplement)
:: 5. Windows 7 32-bit, Profile menu
::     - Code block - Default
::     - Code block - Default    ("apply Now" supplement)
::     - Code block - Minor
::     - Code block - Minor      ("apply Now" supplement)
::     - Code block - Moderate
::     - Code block - Moderate   ("apply Now" supplement)
::     - Code block - Aggressive
::     - Code block - Aggressive ("apply Now" supplement)
:: 6. Windows XP 64-bit, Profile menu
::     - Code block - Default
::     - Code block - Default    ("apply Now" supplement)
::     - Code block - Minor
::     - Code block - Minor      ("apply Now" supplement)
::     - Code block - Moderate
::     - Code block - Moderate   ("apply Now" supplement)
::     - Code block - Aggressive
::     - Code block - Aggressive ("apply Now" supplement)
:: 7. End screen


:: Prep
@echo off
cls

:::::::::::::::
:: VARIABLES ::
:::::::::::::::

:: Log location
set LOGPATH=%systemDrive%\Logs
set LOGFILE=%COMPUTERNAME%_Windows_Services_Lockdown.log

:: This makes sure log file exists
if not exist %LOGPATH% mkdir %LOGPATH%
if not exist %LOGPATH%\%LOGFILE% echo. > %LOGPATH%\%LOGFILE%

:: Don't touch any of these. If you do you will break something
set SCRIPT_VERSION=2.2.1
set WINDOZE=--
set namePROFILE=--
set WHEN_TO_APPLY=--
:: Get the date into ISO 8601 standard date format (yyyy-mm-dd) so we can use it
FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO set DTS=%%a
set CUR_DATE=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%


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
echo    Step 1: Choose OS:            %WINDOZE%
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
set WINDOZE=Windows XP 32-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
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
    if '%choice%'=='5' set WINDOZE=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_32_menu_profileChoice


:XP_32_menu_confirm
:: Confirm the profile and execute
set WINDOZE=Windows XP 32-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WINDOZE% "%namePROFILE%" CONFIGURATION!
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
echo Now resetting all services to the %WINDOZE% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,helpsvc,lanmanserver,lanmanworks,ation,LmHosts,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,Share,Access,ShellHWDetection,Spooler,srservice,Themes,TrkWks,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo %%i...
	sc config %%i start= auto
)

echo Setting the following services to "Only start on demand":
for %%i in (ALG,AppMgmt,BITS,cisvc,COMSysApp,dmadmin,Dot3svc,EapHost,EventSystem,FastUserSwitchingCompatibility,hkmsvc,HTTPFilter,ImapiService,mnmsrvc,MSDTC,MSIServer,napagent,Netlogon,Netman,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RpcLocator,RSVP,SCardSvr,SSDPSRV,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,TlntSvr,upnphost,UPS,V,S,WmdmPmSN,Wmi,WmiApSrv,xmlprov
) do (
	echo %%i...
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (Alerter,ClipSrv,HidServ,Messenger,NetDDE,NetDDEdsdm,RemoteAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)


:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_32_default_Now
if %PROFILE%==XP_32_minor goto XP_32_minor
goto end

:XP_32_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioSrv,Browser,CryptSvc,DcomLaunch,Dhcp,dmserver,Dnscache,ERSvc,Eventlog,FastUserSwitchingCompatibility,h,lpsvc,HidServ,lanmanserver,lanmanworkstation,LmHosts,mnmsrvc,Netlogon,PlugPlay,PolicyAgent,ProtectedStorage,RemoteRegistry,RpcSs,SamSs,Schedule,seclogon,SENS,SharedAccess,ShellHWDetection,Spooler,srservice,SSDPSRV,T,emes,TrkWks,W32Time,WebClient,winmgmt,wscsvc,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i
)

echo Stopping the following services:
for %%i in (Alerter,ALG,AppMgmt,BITS,cisvc,ClipSrv,COMSysApp,dmadmin,Dot3svc,EapHost,hkmsvc,HTTPFilter,ImapiService,Mes,enger,MSDTC,MSIServer,napagent,NetDDE,NetDDEdsdm,Nla,NtLmSsp,NtmsSvc,RasAuto,RasMan,RDSessMgr,RemoteAccess,RpcLocator,RSVP,SCardSvr,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,TlntSvr,upnphost,UPS,VSS,WmdmPmSN,Wmi,Wm,ApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i
)

net	stop EventSystem /y
net	stop Netman	/y


:: testing time!
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
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (cisvc,ERSvc,helpsvc,LmHosts,mnmsrvc,RDSessMgr,RemoteRegistry,RSVP,SCardSvr,seclogon,TlntSvr,UPS,WebClient,WdmPmSN,WmiApSrv,xmlprov) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)

:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_32_minor_Now
goto end


:XP_32_minor_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (cisvc,dmserver,ERSvc,helpsvc,LmHosts,mnmsrvc,RDSessMgr,RemoteRegistry,RSVP,SCardSvr,seclogon,TlntSvr,TrkWks,UPS,W32Time,WebClient,WmdmPmSN,WmiApSrv,xmlprov) do (
	echo Stopping %%i...
	net stop %%i
)

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. whew!
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
	sc config %%i start= auto
)

echo Setting the following services to "Only start on demand":
for %%i in (AppMgmt,BITS,Browser,COMSysApp,dmadmin,dmserver,Dnscache,EventSystem,FastUserSwitchingCompatibility,ImapiService,MSIServer,napagent,Netman,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,TapiSrv,TermService,TrkWks,Wmi) do (
	echo %%i...
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (Alerter,ALG,cisvc,ClipSrv,Dot3svc,EapHost,ERSvc,helpsvc,HidServ,hkmsvc,HTTPFilter,LmHosts,Messenger,mnmsrvc,MSDTC,NetDDE,NetDDEdsdm,Netlogon,NtmsSvc,PolicyAgent,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,RSVP,SENS,srservice,SSDPSRV,stisvc,SwPrv,SysmonLog,Themes,TlntSvr,upnphost,UPS,VSS,W32Time,WebClient,WmdmPmSN,WmiApSrv,wscsvc,xmlprov) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)

:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_32_moderate_Now
if %PROFILE%==XP_32_aggressive goto XP_32_aggressive
goto end


:XP_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioSrv,CryptSvc,DcomLaunch,Dhcp,Eventlog,lanmanserver,lanmanworkstation,PlugPlay,RpcSs,SamSs,SharedAccess,Spooler,winmgmt,wuauserv,WZCSVC) do (
	echo Starting %%i...
	net start %%i
)

echo Stopping the following services:
for %%i in (Alerter,ALG,AppMgmt,BITS,Browser,cisvc,ClipSrv,COMSysApp,dmadmin,dmserver,Dnscache,Dot3svc,EapHost,ERSvc,FastUserSwitchingCompatibility,helpsvc,HidServ,hkmsvc,HTTPFilter,ImapiService,LmHosts,Messenger,mnmsrvc,MSDTC,MSIServer,napagent,NetDDE,NetDDEdsdm,Netlogon,Nla,NtLmSsp,NtmsSvc,PolicyAgent,ProtectedStorage,RasAuto,RasMan,RDSessMgr,RemoteAccess,RemoteRegistry,RpcLocator,RSVP,SCardSvr,Schedule,seclogon,SENS,ShellHWDetection,srservice,SSDPSRV,stisvc,SwPrv,SysmonLog,TapiSrv,TermService,Themes,TlntSvr,TrkWks,upnphost,UPS,VSS,W32Time,WebClient,WmdmPmSN,Wmi,WmiApSrv,wscsvc,xmlprov) do (
	echo Stopping %%i...
	net stop %%i
)

net stop EventSystem /y
net stop Netman /y

:: Testing time!
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
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (AppMgmt,Browser,COMSysApp,CryptSvc,dmadmin,dmserver,Dnscache,EventSystem,FastUserSwitchingCompatibility,ImapiService,lanmanserver,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,TapiSrv,TermService,TrkWks) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)

:: Testing time!
if %WHEN_TO_APPLY%==Now goto XP_32_aggressive_Now
goto end


:XP_32_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (AppMgmt,Browser,COMSysApp,CryptSvc,dmadmin,dmserver,Dnscache,FastUserSwitchingCompatibility,ImapiService,lanmanserver,Nla,NtLmSsp,RpcLocator,SCardSvr,Schedule,seclogon,ShellHWDetection,Spooler,TapiSrv,TermService,TrkWks,wuauserv) do (
	echo Stopping %%i...
	net stop %%i
)

net	stop EventSystem /y


:: testing time! If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


:Vista_32_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WINDOZE=Windows Vista 32/64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
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
    if '%choice%'=='5' set WINDOZE=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto Vista_32_menu_profileChoice


:Vista_32_menu_confirm
:: Confirm the profile and execute
set WINDOZE=Windows Vista 32/64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WINDOZE% "%namePROFILE%" CONFIGURATION!
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
echo Now resetting all services to the %WINDOZE% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AeLookupSvc,AudioEndpointBuilder,AudioSrv,BFE,BITS,Browser,CryptSvc,CscService,Dhcp,Dnscache,ehstart,EMDMgmt,Eventlog,EventSystem,FDResPub,IKEEXT,iphlpsvc,KtmRm,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,seclogon,SENS,ShellHWDetection,slsvc,Spooler,SysMain,TabletInputService,TBS,TermService,Themes,upnphost,UxSms,W32Time,WebClient,WerSvc,WinDefend,Winmgmt,Wlansvc,WPDBusEnum,wscsvc,WSearch,wuauserv) do (
	echo %%i...
	sc config %%i start= auto
)


echo Setting the following services to "Automatic start (delayed)":
for %%i in (BITS,ehstart,KtmRm,TBS,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)


echo Setting the following services to "Only start on demand":
for %%i in (ALG,Appinfo,AppMgmt,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,DFSR,dot3svc,EapHost,ehRecvr,ehSched,Fax,fdPHost,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IPBusEnum,KeyIso,lltdsvc,MSDTC,MSiSCSI,msiserver,napage,t,Netlogon,Netman,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,SessionEnv,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TapiSrv,THREADORDER,UI0Detect,UmRdpService,vds,VSS,wbengine,wcncsvc,WcsPlugInService,Wecsvc,wercplsupport,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,wudfsvc) do (
	echo %%i...
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (Mcx2Svc,NetTcpPortSharing,RemoteAccess,SharedAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)



:: testing time!
if %WHEN_TO_APPLY%==Now goto Vista_32_default_Now
if %PROFILE%==Vista_32_minor goto Vista_32_minor
goto end


:Vista_32_default_Now
:: This section runs after the Default profile, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AeLookupSvc,AudioEndpointBuilder,AudioSrv,BFE,BITS,Browser,CryptSvc,CscService,Dhcp,Dnscache,ehstart,EMDMgmt,Eventlog,EventSystem,FDResPub,IKEEXT,iphlpsvc,KtmRm,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,Netlogon,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,seclogon,SENS,ShellHWDetection,slsvc,Spooler,SysMain,TabletInputService,TBS,TermService,Themes,upnphost,UxSms,W32Time,WebClient,WerSvc,WinDefend,Winmgmt,Wlansvc,WPDBusEnum,wscsvc,WSearch,wuauserv) do (
	echo Starting %%i...
	net start %%i
)

echo Stopping the following services:
for %%i in (ALG,Appinfo,AppMgmt,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,DFSR,dot3svc,EapHost,ehRecvr,ehSched,Fax,fdPHost,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IPBusEnum,KeyIso,lltdsvc,Mcx2Svc,MSDTC,MSiSCSI,msiserver,napagent,NetTcpPortSharing,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,SessionEnv,SharedAccess,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TapiSrv,THREADORDER,UI0Detect,UmRdpService,vds,VSS,wbengine,wcncsvc,WcsPlugInService,Wecsvc,wercplsupport,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,wudfsvc) do (
	echo Stopping %%i...
	net stop %%i
)

net stop netman /y

:: testing time!
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
	sc config %%i start= disabled
)

sc config TBS start= demand
sc config TBS start= delayed-auto

:: testing time!
if %WHEN_TO_APPLY%==Now goto Vista_32_minor_Now
goto end


:Vista_32_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
echo Stopping the following services:
for %%i in (CertPropSvc,Fax,iphlpsvc,MSiSCSI,Netlogon,CscService,RemoteRegistry,SCardSvr,SCPolicySvc,SNMPTRAP,TabletInputService,UmRdpService,TBS,WebClient,WinRM,WSearch,WinHttpAutoProxySvc) do (
	echo Stopping %%i...
	net stop %%i
)

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. whew!
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
	sc config %%i start= auto
)

echo Setting the following services to "Automatic start (delayed)":
for %%i in (BITS,KtmRm,TBS,wscsvc,wuauserv) do (
	echo Disabling %%i...
	sc config %%i start= delayed-auto
)

echo Setting the following services to "Only start on demand":
for %%i in (ALG,Appinfo,AppMgmt,Browser,clr_optimization_v2.0.50727_32,COMSysApp,dot3svc,FontCache3.0.0.0,IKEEXT,KeyIso,msiserver,Netman,pla,ProtectedStorage,RasAuto,RasMan,RpcLocator,SDRSVC,seclogon,SessionEnv,SLUINotify,SSDPSRV,SstpSvc,swprv,TBS,TermService,THREADORDER,UI0Detect,upnphost,VSS,wbengine,WcsPlugInService,Wecsvc,wmiApSrv,wudfsvc) do (
	echo %%i...
	sc config %%i start= demand
)


echo Setting the following services to "Disabled":
for %%i in (AeLookupSvc,CertPropSvc,CscService,DFSR,EapHost,ehRecvr,ehSched,ehstart,Fax,fdPHost,FDResPub,hidserv,hkmsvc,idsvc,IPBusEnum,iphlpsvc,lltdsvc,lmhosts,Mcx2Svc,MSDTC,MSiSCSI,napagent,Netlogon,NetTcpPortSharing,p2pimsvc,p2psvc,PNRPAutoReg,PNRPsvc,QWAVE,RemoteAccess,RemoteRegistry,SCardSvr,SCPolicySvc,SharedAccess,SNMPTRAP,stisvc,TabletInputService,TapiSrv,Themes,UmRdpService,UxSms,vds,wcncsvc,WebClient,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,WMPNetworkSvc,WPCSvc,WPDBusEnum,WSearch) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)


:: Moderate end
:: testing time!
if %WHEN_TO_APPLY%==Now goto Vista_32_moderate_Now
if %PROFILE%==Vista_32_aggressive goto Vista_32_aggressive
goto end


:Vista_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioEndpointBuilder,AudioSrv,BFE,BITS,CryptSvc,Dhcp,Dnscache,EMDMgmt,Eventlog,EventSystem,KtmRm,LanmanServer,LanmanWorkstation,MMCSS,MpsSvc,netprofm,NlaSvc,nsi,PcaSvc,PlugPlay,PolicyAgent,ProfSvc,Schedule,SENS,ShellHWDetection,slsvc,Spooler,SysMain,W32Time,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo Starting %%i...
	net start %%i
)

echo Stopping the following services:
for %%i in (AeLookupSvc,ALG,Appinfo,AppMgmt,Browser,CertPropSvc,clr_optimization_v2.0.50727_32,COMSysApp,CscService,DFSR,dot3svc,EapHost,ehRecvr,ehSched,ehstart,Fax,fdPHost,FDResPub,FontCache3.0.0.0,hidserv,hkmsvc,idsvc,IKEEXT,IPBusEnum,iphlpsvc,KeyIso,lltdsvc,lmhosts,Mcx2Svc,MSDTC,MSiSCSI,msiserver,napagent,Netlogon,NetTcpPortSharing,p2pimsvc,p2psvc,pla,PNRPAutoReg,PNRPsvc,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SessionEnv,SharedAccess,SLUINotify,SNMPTRAP,SSDPSRV,SstpSvc,stisvc,swprv,TabletInputService,TapiSrv,TBS,TermService,Themes,THREADORDER,UI0Detect,UmRdpService,upnphost,UxSms,vds,VSS,wbengine,wcncsvc,WcsPlugInService,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WMPNetworkSvc,WPCSvc,WPDBusEnum,WSearch,wudfsvc) do (
	echo Stopping %%i...
	net stop %%i
)

net stop Netman /y

:: testing time!
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
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (ALG,AppMgmt,BFE,clr_optimization_v2.0.50727_32,EMDMgmt,FontCache3.0.0.0,IKEEXT,KeyIso,KtmRm,pla,PolicyAgent,ShellHWDetection,swprv,TermService,UI0Detect,upnphost,wbengine,WcsPlugInService,WinDefend,wscsvc) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)


:: testing time!
if %WHEN_TO_APPLY%==Now goto Vista_32_aggressive_Now
goto end


:Vista_32_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Stopping the following services:
for %%i in (ALG,AppMgmt,BFE,clr_optimization_v2.0.50727_32,EMDMgmt,FontCache3.0.0.0,IKEEXT,KeyIso,KtmRm,PcaSvc,pla,PolicyAgent,ShellHWDetection,swprv,TermService,UI0Detect,upnphost,W32Time,wbengine,WcsPlugInService,WinDefend,wscsvc) do (
	echo Stopping %%i...
	net stop %%i
)

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end



:7_32_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WINDOZE=Windows 7 32/64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
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
    if '%choice%'=='5' set WINDOZE=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto 7_32_menu_choice


:7_32_menu_confirm
:: Confirm the profile and execute
set WINDOZE=Windows 7 32/64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WINDOZE% "%namePROFILE%" CONFIGURATION!
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
echo Now resetting all services to the %WINDOZE% defaults, please wait...
echo.
echo Setting the following services to "Automatically start":
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,CryptSvc,CscService,Dhcp,Dnscache,Eventlog,EventSystem,FDResPub,iphlpsvc,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo %%i...
	sc config %%i start= auto
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
	sc config %%i start= demand
)

echo Setting the following services to "Disabled":
for %%i in (RemoteAccess,SharedAccess) do (
	echo Disabling %%i...
	sc config %%i start= disabled
)


:: testing time!
if %WHEN_TO_APPLY%==Now goto 7_32_default_Now
if %PROFILE%==7_32_minor goto 7_32_minor
goto end

:7_32_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
echo Starting the following services:
for %%i in (AudioEndpointBuilder,AudioSrv,BDESVC,BFE,clr_optimization_v2.0.50727_32,CryptSvc,CscService,Dhcp,Dnscache,Eventlog,EventSystem,FDResPub,iphlpsvc,LanmanServer,LanmanWorkstation,lmhosts,MMCSS,MpsSvc,Netlogon,NlaSvc,nsi,PlugPlay,Power,ProfSvc,RpcEptMapper,Schedule,SENS,ShellHWDetection,Spooler,sppsvc,SysMain,Themes,UxSms,WinDefend,Winmgmt,Wlansvc,wscsvc,wuauserv) do (
	echo Starting %%i...
	net start %%i
)

echo Stopping the following services:
for %%i in (AeLookupSvc,ALG,AppIDSvc,Appinfo,AppMgmt,AxInstSV,BITS,Browser,bthserv,CertPropSvc,COMSysApp,defragsvc,dot3svc,EapHost,EFS,fdPHost,FontCache,hidserv,hkmsvc,HomeGroupListener,HomeGroupProvider,IKEEXT,IPBusEnum,KeyIso,KtmRm,lltdsvc,MSDTC,MSiSCSI,msiserver,napagent,netprofm,p2pimsvc,p2psvc,PcaSvc,PeerDistSvc,pla,PNRPAutoReg,PNRPsvc,PolicyAgent,ProtectedStorage,QWAVE,RasAuto,RasMan,RemoteAccess,RemoteRegistry,RpcLocator,SCardSvr,SCPolicySvc,SDRSVC,seclogon,SensrSvc,SharedAccess,SNMPTRAP,sppuinotify,SSDPSRV,SstpSvc,StiSvc,swprv,TabletInputService,TapiSrv,TBS,TermService,THREADORDER,UI0Detect,UmRdpService,upnphost,VaultSvc,vds,VSS,W32Time,wbengine,WbioSrvc,wcncsvc,WcsPlugInService,WebClient,Wecsvc,wercplsupport,WerSvc,WinHttpAutoProxySvc,WinRM,wmiApSrv,WPCSvc,WPDBusEnum,wudfsvc,WwanSvc
) do (
	echo Stopping %%i...
	net stop %%i
)


net stop Netman /y

:: testing time!
if %PROFILE%==7_32_minor goto 7_32_minor
goto end


:7_32_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config AppMgmt start= disabled
sc config bthserv start= disabled
sc config PeerDistSvc start= disabled
sc config CertPropSvc start= disabled
sc config iphlpsvc start= disabled
sc config clr_optimization_v2.0.50727_32 start= demand
sc config MSiSCSI start= disabled
sc config Netlogon start= disabled
sc config napagent start= disabled
sc config CscService start= disabled
sc config WPCSvc start= disabled
sc config RpcLocator start= disabled
sc config RemoteRegistry start= disabled
sc config SCardSvr start= disabled
sc config SCPolicySvc start= disabled
sc config SNMPTRAP start= disabled
sc config wcncsvc start= disabled

:: testing time!
if %WHEN_TO_APPLY%==Now goto 7_32_minor_Now
goto end


:7_32_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
net stop AppMgmt
net stop bthserv
net stop PeerDistSvc
net stop CertPropSvc
net stop iphlpsvc
net stop clr_optimization_v2.0.50727_32
net stop MSiSCSI
net stop Netlogon
net stop napagent
net stop CscService
net stop WPCSvc
net stop RpcLocator
net stop RemoteRegistry
net stop SCardSvr
net stop SCPolicySvc
net stop SNMPTRAP
net stop wcncsvc
:: testing time! If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


:7_32_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config AxInstSV start= disabled
sc config SensrSvc start= disabled
sc config AeLookupSvc start= demand
sc config AppIDSvc start= demand
sc config Appinfo start= demand
sc config ALG start= disabled
sc config AppMgmt start= disabled
sc config BITS start= demand
sc config BFE start= auto
sc config BDESVC start= auto
sc config wbengine start= demand
sc config bthserv start= disabled
sc config PeerDistSvc start= disabled
sc config CertPropSvc start= disabled
sc config KeyIso start= demand
sc config EventSystem start= auto
sc config COMSysApp start= demand
sc config Browser start= demand
sc config VaultSvc start= disabled
sc config CryptSvc start= auto
sc config UxSms start= auto
sc config Dhcp start= auto
sc config defragsvc start= demand
sc config MSDTC start= demand
sc config Dnscache start= auto
sc config EFS start= disabled
sc config EapHost start= demand
sc config fdPHost start= disabled
sc config FDResPub start= disabled
sc config hkmsvc start= disabled
sc config HomeGroupListener start= demand
sc config HomeGroupProvider start= demand
sc config hidserv start= disabled
sc config IKEEXT start= demand
sc config UI0Detect start= disabled
sc config SharedAccess start= disabled
sc config iphlpsvc start= disabled
sc config PolicyAgent start= demand
sc config KtmRm start= demand
sc config lltdsvc start= disabled
sc config clr_optimization_v2.0.50727_32 start= demand
::sc config clr_optimization_v2.0.50727_32 start= delayed-auto
sc config MSiSCSI start= disabled
sc config swprv start= demand
sc config MMCSS start= auto
sc config Netlogon start= disabled
sc config napagent start= disabled
sc config Netman start= demand
sc config netprofm start= demand
sc config NlaSvc start= auto
sc config nsi start= auto
sc config CscService start= disabled
sc config WPCSvc start= disabled
sc config PNRPsvc start= disabled
sc config p2psvc start= disabled
sc config p2pimsvc start= disabled
sc config pla start= demand
sc config PlugPlay start= auto
sc config IPBusEnum start= disabled
sc config PNRPAutoReg start= disabled
sc config WPDBusEnum start= disabled
sc config Power start= auto
sc config Spooler start= auto
sc config wercplsupport start= disabled
sc config PcaSvc start= disabled
sc config ProtectedStorage start= demand
sc config QWAVE start= disabled
sc config RasAuto start= demand
sc config RasMan start= demand
sc config TermService start= disabled
sc config UmRdpService start= disabled
sc config RpcLocator start= disabled
sc config RemoteRegistry start= disabled
sc config RemoteAccess start= disabled
sc config RpcEptMapper start= auto
sc config seclogon start= demand
sc config SstpSvc start= demand
sc config wscsvc start= auto
sc config wscsvc start= delayed-auto
sc config LanmanServer start= auto
sc config ShellHWDetection start= auto
sc config SCardSvr start= disabled
sc config SCPolicySvc start= disabled
sc config SNMPTRAP start= disabled
sc config sppsvc start= auto
sc config sppsvc start= delayed-auto
sc config sppuinotify start= demand
sc config SSDPSRV start= demand
sc config SysMain start= auto
sc config SENS start= auto
sc config TabletInputService start= disabled
sc config Schedule start= auto
sc config lmhosts start= auto
sc config TapiSrv start= demand
sc config Themes start= auto
sc config THREADORDER start= demand
sc config TBS start= disabled
sc config upnphost start= demand
sc config ProfSvc start= auto
sc config vds start= demand
sc config VSS start= demand
sc config WebClient start= disabled
sc config AudioSrv start= auto
sc config AudioEndpointBuilder start= auto
sc config SDRSVC start= demand
sc config WbioSrvc start= disabled
sc config WcsPlugInService start= disabled
sc config wcncsvc start= disabled
sc config WinDefend start= auto
sc config WinDefend start= delayed-auto
sc config wudfsvc start= demand
sc config WerSvc start= disabled
sc config Wecsvc start= demand
sc config Eventlog start= auto
sc config MpsSvc start= auto
sc config FontCache start= demand
sc config StiSvc start= demand
sc config msiserver start= demand
sc config Winmgmt start= auto
sc config WinRM start= disabled
sc config W32Time start= demand
sc config wuauserv start= auto
sc config wuauserv start= delayed-auto
sc config WinHttpAutoProxySvc start= disabled
sc config dot3svc start= demand
sc config Wlansvc start= auto
sc config wmiApSrv start= demand
sc config LanmanWorkstation start= auto
sc config WwanSvc start= disabled

:: These services were missing from the config tool and manually added by me
sc config DPS start= disabled
sc config WdiServiceHost start= disabled
sc config WdiSystemHost start= disabled
sc config TrkWks start= disabled
sc config SessionEnv start= disabled
sc config StorSvc start= disabled

:: This is a major annoyance to me but potentially wanted by people. Shell Hardware Detection
:: does auto-insert notification and detection of the type of DVD/CD drive that is installed.
:: This does not affect actual functionality, only Windows' ability to detect its features. Meh.
sc config ShellHWDetection start= disabled

::These are services added by Windows Live Essentials
REM Windows Card Service & Windows Search
sc config idsvc start= disabled
sc config WSearch start= disabled

:: These are services added by Windows Media Center
sc config ehRecvr start= disabled
sc config ehSched start= disabled
sc config WMPNetworkSvc start= disabled

:: Test if we are also applying the Aggressive profile
:: testing time!
if %WHEN_TO_APPLY%==Now goto 7_32_moderate_Now
if %PROFILE%==7_32_aggressive goto 7_32_aggressive
goto end


:7_32_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
net stop AxInstSV
net stop SensrSvc
net stop AeLookupSvc
net stop AppIDSvc
net stop Appinfo
net stop ALG
net stop AppMgmt
net stop BITS
net start BFE
net start BDESVC
net stop wbengine
net stop bthserv
net stop PeerDistSvc
net stop CertPropSvc
net stop KeyIso
net start EventSystem
net stop COMSysApp
net stop Browser
net stop VaultSvc
net start CryptSvc
net start UxSms
net start Dhcp
net stop defragsvc
net stop MSDTC
net start Dnscache
net stop EFS
net stop EapHost
net stop fdPHost
net stop FDResPub
net stop hkmsvc
net stop HomeGroupListener
net stop HomeGroupProvider
net stop hidserv
net stop IKEEXT
net stop UI0Detect
net stop SharedAccess
net stop iphlpsvc
net stop PolicyAgent
net stop KtmRm
net stop lltdsvc
net start clr_optimization_v2.0.50727_32
net stop MSiSCSI
net stop swprv
net start MMCSS
net stop Netlogon
net stop napagent
net stop Netman /y
net stop netprofm
net start NlaSvc
net start nsi
net stop CscService
net stop WPCSvc
net stop PNRPsvc
net stop p2psvc
net stop p2pimsvc
net stop pla
net start PlugPlay
net stop IPBusEnum
net stop PNRPAutoReg
net stop WPDBusEnum
net start Power
net start Spooler
net stop wercplsupport
net stop PcaSvc
net stop ProtectedStorage
net stop QWAVE
net stop RasAuto
net stop RasMan
net stop TermService
net stop UmRdpService
net stop RpcLocator
net stop RemoteRegistry
net stop RemoteAccess
net start RpcEptMapper
net stop seclogon
net stop SstpSvc
net start wscsvc
net start LanmanServer
net start ShellHWDetection
net stop SCardSvr
net stop SCPolicySvc
net stop SNMPTRAP
net start sppsvc
net stop sppuinotify
net stop SSDPSRV
net start SysMain
net start SENS
net stop TabletInputService
net start Schedule
net start lmhosts
net stop TapiSrv
net start Themes
net stop THREADORDER
net stop TBS
net stop upnphost
net start ProfSvc
net stop vds
net stop VSS
net stop WebClient
net start AudioSrv
net start AudioEndpointBuilder
net stop SDRSVC
net stop WbioSrvc
net stop WcsPlugInService
net stop wcncsvc
net start WinDefend
net stop wudfsvc
net stop WerSvc
net stop Wecsvc
net start Eventlog
net start MpsSvc
net stop FontCache
net stop StiSvc
net stop msiserver
net start Winmgmt
net stop WinRM
net stop W32Time
net start wuauserv
net stop WinHttpAutoProxySvc
net stop dot3svc
net start Wlansvc
net stop wmiApSrv
net start LanmanWorkstation
net stop WwanSvc
net stop DPS
net stop WdiServiceHost
net stop WdiSystemHost
net stop TrkWks
net stop SessionEnv
net stop StorSvc
net stop ShellHWDetection
net stop idsvc
net stop WSearch
net stop ehRecvr
net stop ehSched
net stop WMPNetworkSvc
:: testing time!
if %PROFILE%==7_32_aggressive goto 7_32_aggressive
goto end


:7_32_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config BITS start= disabled
sc config BFE start= disabled
sc config BDESVC start= disabled
sc config wbengine start= disabled
sc config KeyIso start= disabled
sc config UxSms start= disabled
sc config Dnscache start= disabled
sc config EapHost start= disabled
sc config HomeGroupListener start= disabled
sc config HomeGroupProvider start= disabled
sc config PolicyAgent start= disabled
sc config SstpSvc start= disabled
sc config wscsvc start= disabled
sc config lmhosts start= disabled
sc config TapiSrv start= disabled
sc config Themes start= disabled
sc config WinDefend start= disabled
sc config W32Time start= disabled
sc config wuauserv start= demand
sc config dot3svc start= disabled

:: These services were missing from the config tool and manually added by me
sc config NetTcpPortSharing start= disabled
sc config RpcLocator start= disabled

:: This is another service from our lovely Media Center edition. Goodbye.
REM Windows Presentation Foundation Font
sc config FontCache3.0.0.0 start= disabled

:: testing time!
if %WHEN_TO_APPLY%==Now goto 7_32_aggressive_Now
goto end


:7_32_aggressive_Now
net stop BITS
net stop BFE
net stop BDESVC
net stop wbengine
net stop KeyIso
net stop UxSms
net stop Dnscache
net stop EapHost
net stop HomeGroupListener
net stop HomeGroupProvider
net stop PolicyAgent
net stop SstpSvc
net stop wscsvc
net stop lmhosts
net stop TapiSrv
net stop Themes
net stop WinDefend
net stop W32Time
net stop wuauserv
net stop dot3svc
net stop NetTcpPortSharing
net stop RpcLocator
net stop FontCache3.0.0.0

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
goto end


::::::::::::::::::::::::::::::::::
::                              ::
:: Beginning of 64-bit Sections ::
::                              ::
::::::::::::::::::::::::::::::::::


:XP_64_menu_profile
:: This is where the user selects the lockdown profile to use. Pretty self-explanatory.
set WINDOZE=Windows XP 64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                       WINDOWS SERVICES LOCKDOWN - STEP 2/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
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
    if '%choice%'=='5' set WINDOZE=-- && echo. && cls && goto os_menu
:: Else, go back and re-draw the menu
echo.
echo  "%choice%" is not valid, please try again
echo.
goto XP_64_menu_profileChoice


:XP_64_menu_confirm
:: Confirm the profile and execute
set WINDOZE=Windows XP 64-bit
title Services Lockdown - %WINDOZE%
cls
echo.
echo                      WINDOWS SERVICES LOCKDOWN - STEP 3/3
echo.
echo    Step 1: Choose OS:            %WINDOZE%
echo    Step 2: Choose Profile:       %namePROFILE%
echo    Step 3: Confirm
echo.
echo.
echo    ABOUT TO APPLY THE %WINDOZE% "%namePROFILE%" CONFIGURATION!
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
echo Now resetting all services to the %WINDOZE% defaults, please wait...
echo.
sc config Alerter start= disabled
sc config AeLookupSvc start= auto
sc config ALG start= demand
sc config AppMgmt start= demand
sc config AudioSrv start= auto
sc config BITS start= demand
sc config Browser start= auto
sc config cisvc start= disabled
sc config ClipSrv start= demand
sc config COMSysApp start= demand
sc config CryptSvc start= auto
sc config DcomLaunch start= auto
sc config Dhcp start= auto
sc config dmadmin start= demand
sc config dmserver start= auto
sc config Dnscache start= auto
sc config ERSvc start= auto
sc config Eventlog start= auto
sc config EventSystem start= auto
sc config helpsvc start= auto
sc config HidServ start= disabled
sc config HTTPFilter start= demand
sc config IASJet start= demand
sc config ImapiService start= demand
sc config lanmanserver start= auto
sc config lanmanworkstation start= auto
sc config LmHosts start= auto
sc config Messenger start= disabled
sc config mnmsrvc start= demand
sc config MSDTC start= demand
sc config MSIServer start= demand
sc config NetDDE start= demand
sc config NetDDEdsdm start= demand
sc config Netlogon start= demand
sc config Netman start= demand
sc config Nla start= demand
sc config NtLmSsp start= demand
sc config NtmsSvc start= demand
sc config PlugPlay start= auto
sc config PolicyAgent start= auto
sc config ProtectedStorage start= auto
sc config RasAuto start= demand
sc config RasMan start= demand
sc config RDSessMgr start= demand
sc config RemoteAccess start= disabled
sc config RemoteRegistry start= auto
sc config RpcLocator start= demand
sc config RpcSs start= auto
sc config SamSs start= auto
sc config SCardSvr start= demand
sc config Schedule start= auto
sc config seclogon start= auto
sc config SENS start= auto
sc config SharedAccess start= auto
sc config ShellHWDetection start= auto
sc config Spooler start= auto
sc config srservice start= auto
sc config SSDPSRV start= demand
sc config stisvc start= auto
sc config SysmonLog start= auto
sc config TapiSrv start= demand
sc config TermService start= demand
sc config Themes start= auto
sc config TlntSvr start= disabled
sc config TrkWks start= auto
sc config UMWdf start= demand
sc config upnphost start= auto
sc config UPS start= demand
sc config vds start= demand
sc config VSS start= demand
sc config W32Time start= auto
sc config WebClient start= auto
sc config WinHttpAutoProxySvc start= demand
sc config winmgmt start= auto
sc config WmdmPmSN start= demand
sc config Wmi start= demand
sc config WmiApSrv start= demand
sc config wscsvc start= auto
sc config wuauserv start= auto
sc config WZCSVC start= auto
sc config xmlprov start= demand

:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_64_default_Now
if %PROFILE%==XP_64_minor goto XP_64_minor
goto end

:XP_64_default_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
net stop Alerter
net start AeLookupSvc
net stop ALG
net stop AppMgmt
net start AudioSrv
net stop BITS
net start Browser
net stop cisvc
net stop ClipSrv
net stop COMSysApp
net start CryptSvc
net start DcomLaunch
net start Dhcp
net stop dmadmin
net start dmserver
net start Dnscache
net start ERSvc
net start Eventlog
net start EventSystem
net start helpsvc
net stop HidServ
net stop HTTPFilter
net stop IASJet
net stop ImapiService
net start lanmanserver
net start lanmanworkstation
net start LmHosts
net stop Messenger
net stop mnmsrvc
net stop MSDTC
net stop MSIServer
net stop NetDDE
net stop NetDDEdsdm
net start Netlogon
net stop Netman /y
net stop Nla
net stop NtLmSsp
net stop NtmsSvc
net start PlugPlay
net start PolicyAgent
net start ProtectedStorage
net stop RasAuto
net stop RasMan
net stop RDSessMgr
net stop RemoteAccess
net start RemoteRegistry
net stop RpcLocator
net start RpcSs
net start SamSs
net stop SCardSvr
net start Schedule
net start seclogon
net start SENS
net start SharedAccess
net start ShellHWDetection
net start Spooler
net start srservice
net stop SSDPSRV
net start stisvc
net start SysmonLog
net stop TapiSrv
net stop TermService
net start Themes
net stop TlntSvr
net start TrkWks
net stop UMWdf
net start upnphost
net stop UPS
net stop vds
net stop VSS
net start W32Time
net start WebClient
net stop WinHttpAutoProxySvc
net start winmgmt
net stop WmdmPmSN
net stop Wmi
net stop WmiApSrv
net start wscsvc
net start wuauserv
net start WZCSVC
net stop xmlprov

:: testing time!
if %PROFILE%==XP_64_minor goto XP_64_minor
goto end


:XP_64_minor
:: If it was selected, the Minor profile runs after Default as addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config ClipSrv start= disabled
sc config dmserver start= demand
sc config ERSvc start= disabled
sc config EventSystem start= demand
sc config helpsvc start= demand
sc config IASJet start= disabled
sc config LmHosts start= disabled
sc config mnmsrvc start= disabled
sc config NetDDE start= disabled
sc config NetDDEdsdm start= disabled
sc config Netlogon start= disabled
sc config RDSessMgr start= disabled
sc config RemoteRegistry start= disabled
sc config SCardSvr start= disabled
sc config seclogon start= demand
sc config stisvc start= demand
sc config SysmonLog start= demand
sc config TrkWks start= demand
sc config upnphost start= demand
sc config UPS start= disabled
sc config vds start= disabled
sc config W32Time start= disabled
sc config WebClient start= disabled
sc config WinHttpAutoProxySvc start= disabled
sc config WmdmPmSN start= disabled
sc config WmiApSrv start= disabled
sc config xmlprov start= disabled

:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_64_minor_Now
goto end


:XP_64_minor_Now
:: If it was selected, this section runs after the profile above. It applies changes immediately.
net stop ClipSrv
net stop dmserver
net stop ERSvc
net stop EventSystem /y
net stop helpsvc
net stop IASJet
net stop LmHosts
net stop mnmsrvc
net stop NetDDE
net stop NetDDEdsdm
net stop Netlogon
net stop RDSessMgr
net stop RemoteRegistry
net stop SCardSvr
net stop seclogon
net stop SSDPSRV
net stop stisvc
net stop SysmonLog
net stop TrkWks
net stop upnphost
net stop UPS
net stop vds
net stop W32Time
net stop WebClient
net stop WinHttpAutoProxySvc
net stop WmdmPmSN
net stop WmiApSrv
net stop xmlprov

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. whew!
goto end


:XP_64_moderate
:: The Moderate profile forms the base for the Aggressive profile
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config Alerter start= disabled
sc config AeLookupSvc start= disabled
sc config ALG start= disabled
sc config AppMgmt start= disabled
sc config AudioSrv start= auto
sc config BITS start= demand
sc config Browser start= auto
sc config cisvc start= disabled
sc config ClipSrv start= disabled
sc config COMSysApp start= disabled
sc config CryptSvc start= auto
sc config DcomLaunch start= auto
sc config Dhcp start= auto
sc config dmadmin start= demand
sc config dmserver start= demand
sc config Dnscache start= demand
sc config ERSvc start= disabled
sc config Eventlog start= auto
sc config EventSystem start= disabled
sc config helpsvc start= disabled
sc config HidServ start= disabled
sc config HTTPFilter start= demand
sc config IASJet start= disabled
sc config ImapiService start= demand
sc config lanmanserver start= auto
sc config lanmanworkstation start= auto
sc config LmHosts start= disabled
sc config Messenger start= disabled
sc config mnmsrvc start= disabled
sc config MSDTC start= disabled
sc config MSIServer start= demand
sc config NetDDE start= disabled
sc config NetDDEdsdm start= disabled
sc config Netlogon start= disabled
sc config Netman start= demand
sc config Nla start= demand
sc config NtLmSsp start= demand
sc config NtmsSvc start= disabled
sc config PlugPlay start= auto
sc config PolicyAgent start= demand
sc config ProtectedStorage start= disabled
sc config RasAuto start= disabled
sc config RasMan start= disabled
sc config RDSessMgr start= disabled
sc config RemoteAccess start= disabled
sc config RemoteRegistry start= disabled
sc config RpcLocator start= demand
sc config RpcSs start= auto
sc config SamSs start= auto
sc config SCardSvr start= disabled
sc config Schedule start= disabled
sc config seclogon start= disabled
sc config SENS start= disabled
sc config SharedAccess start= auto
sc config ShellHWDetection start= disabled
sc config Spooler start= auto
sc config srservice start= disabled
sc config SSDPSRV start= disabled
sc config stisvc start= disabled
sc config SysmonLog start= disabled
sc config TapiSrv start= disabled
sc config TermService start= demand
sc config Themes start= disabled
sc config TlntSvr start= disabled
sc config TrkWks start= disabled
sc config UMWdf start= disabled
sc config upnphost start= disabled
sc config UPS start= disabled
sc config vds start= disabled
sc config VSS start= disabled
sc config W32Time start= disabled
sc config WebClient start= disabled
sc config WinHttpAutoProxySvc start= disabled
sc config winmgmt start= auto
sc config WmdmPmSN start= disabled
sc config Wmi start= demand
sc config WmiApSrv start= demand
sc config wscsvc start= disabled
sc config wuauserv start= auto
sc config WZCSVC start= auto
sc config xmlprov start= disabled

:: These services were not in the config tool and were added by me
sc config 6to4 start= disabled

::Peer Name Resolution Protocol, Peer Networking, Peer Networking Group Authentication, and Peer Networking Identity Manager, respectively.
sc config PNRPSvc start= demand
sc config p2psvc start= demand
sc config p2pgasvc start= demand
sc config p2pimsvc start= demand

:: World Wide Web Publishing...whatever...nuke it.
sc config w3svc start= disabled

:: testing time!
if %WHEN_TO_APPLY%==Now goto XP_64_moderate_Now
if %PROFILE%==XP_64_aggressive goto XP_64_aggressive
goto end


:XP_64_moderate_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
net stop Alerter
net stop AeLookupSvc
net stop ALG
net stop AppMgmt
net start AudioSrv
net stop BITS
net start Browser
net stop cisvc
net stop ClipSrv
net stop COMSysApp
net start CryptSvc
net start DcomLaunch
net start Dhcp
net stop dmadmin
net stop dmserver
net stop Dnscache
net stop ERSvc
net start Eventlog
net stop EventSystem /y
net stop helpsvc
net stop HidServ
net stop HTTPFilter
net stop IASJet
net stop ImapiService
net start lanmanserver
net start lanmanworkstation
net stop LmHosts
net stop Messenger
net stop mnmsrvc
net stop MSDTC
net stop MSIServer
net stop NetDDE
net stop NetDDEdsdm
net stop Netlogon
net stop Netman /y
net stop Nla
net stop NtLmSsp
net stop NtmsSvc
net start PlugPlay
net stop PolicyAgent
net stop ProtectedStorage
net stop RasAuto
net stop RasMan
net stop RDSessMgr
net stop RemoteAccess
net stop RemoteRegistry
net stop RpcLocator
net start RpcSs
net start SamSs
net stop SCardSvr
net stop Schedule
net stop seclogon
net stop SENS
net start SharedAccess
net stop ShellHWDetection
net start Spooler
net stop srservice
net stop SSDPSRV
net stop stisvc
net stop SysmonLog
net stop TapiSrv
net stop TermService
net stop Themes
net stop TlntSvr
net stop TrkWks
net stop UMWdf
net stop upnphost
net stop UPS
net stop vds
net stop VSS
net stop W32Time
net stop WebClient
net stop WinHttpAutoProxySvc
net start winmgmt
net stop WmdmPmSN
net stop Wmi
net stop WmiApSrv
net stop wscsvc
net start wuauserv
net start WZCSVC
net stop xmlprov
net stop 6to4
net stop PNRPSvc
net stop p2psvc
net stop p2pgasvc
net stop p2pimsvc
net stop w3svc
:: Testing time!
if %PROFILE%==XP_64_aggressive goto XP_64_aggressive
goto end


:XP_64_aggressive
:: If it was selected, the Aggressive profile runs after the Moderate profile as an addendum.
cls
title Applying %PROFILE% settings...
echo.
echo Now applying %PROFILE% settings, please wait...
echo.
sc config BITS start= disabled
sc config Browser start= disabled
sc config CryptSvc start= disabled
sc config dmadmin start= disabled
sc config dmserver start= disabled
sc config Dnscache start= disabled
sc config ImapiService start= disabled
sc config lanmanserver start= disabled
sc config Nla start= disabled
sc config NtLmSsp start= disabled
sc config RpcLocator start= disabled
sc config Spooler start= disabled
sc config TermService start= disabled
sc config Wmi start= disabled
sc config wuauserv start= disabled
sc config WZCSVC start= disabled

::Peer Name Resolution Protocol, Peer Networking, Peer Networking Group Authentication, and Peer Networking Identity Manager, respectively.
sc config PNRPSvc start= disabled
sc config p2psvc start= disabled
sc config p2pgasvc start= disabled
sc config p2pimsvc start= disabled

:: Testing time!
if %WHEN_TO_APPLY%==Now goto XP_64_aggressive_Now
goto end


:XP_64_aggressive_Now
:: This section runs after the profile above, if selected. It applies changes immediately.
net stop BITS
net stop Browser
net stop CryptSvc
net stop dmadmin
net stop dmserver
net stop Dnscache
net stop ImapiService
net stop lanmanserver
net stop Nla
net stop NtLmSsp
net stop RpcLocator
net stop Spooler
net stop TermService
net stop Wmi
net stop wuauserv
net stop WZCSVC
net stop PNRPSvc
net stop p2psvc
net stop p2pgasvc
net stop p2pimsvc

:: testing time! If we executed this block then there's nothing left to do, so we go to the end. Yahtzee!
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
echo    Operating System:  %WINDOZE%
echo    Profile:           %PROFILE%
echo    Changes Effective: %WHEN_TO_APPLY%
echo.
echo    Log file saved at: %LOGPATH%\%LOGFILE%
echo.
echo.
echo    Press any key to quit...
echo.
pause
