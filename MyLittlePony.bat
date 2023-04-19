:: Launch a full-screen, autoplaying YouTube video every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe' --kiosk https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1" --edge-kiosk-type=fullscreen

:: Launch a full-screen, autoplaying YouTube video every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe' --kiosk https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1" --edge-kiosk-type=fullscreen

:: Alternate version of above command if Task Scheduler execution of IE is blocked
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "%windir%\explorer.exe \"https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1\"" --edge-kiosk-type=fullscreen

:: Alternate version of above command using Microsoft Word, loads the MyLittlePony website in Word every 5 minutes
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "'%ProgramFiles(x86)\Microsoft Office\Office15\winword.exe' /q /h https://mylittlepony.hasbro.com/en-us" --edge-kiosk-type=fullscreen

:: Launch the MyLittlePony website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe' --kiosk https://mylittlepony.hasbro.com/en-us" --edge-kiosk-type=fullscreen

:: Launch the MyLittlePony website every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe' --kiosk https://mylittlepony.hasbro.com/en-us" --edge-kiosk-type=fullscreen

:: Alternate version of above command if Task Scheduler execution of IE is blocked
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "%windir%\explorer.exe \"https://mylittlepony.hasbro.com/en-us\""

:: Launch the Windows93 website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn Windows93 /tr "'%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe' --kiosk http://windows93.net"

:: Schedule to open every minute
schtasks /f /create /SC MINUTE /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'https://mylittlepony.hasbro.com/en-us'" --edge-kiosk-type=fullscreen

:: Schedule to open as soon as the computer is idle for 1 minute or more -- Change "1" to any number you want
schtasks /f /create /SC ONIDLE /I 1 /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'https://mylittlepony.hasbro.com/en-us'" --edge-kiosk-type=fullscreen

:: Schedule to open at every logon -- this requires Administrator access
schtasks /f /create /SC ONLOGON /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'https://mylittlepony.hasbro.com/en-us'" --edge-kiosk-type=fullscreen

:: Delete the "MyLittlePony" scheduled task
schtasks /Delete /TN "MyLittlePony" /F


:: Launch the task we created
schtasks /run /tn "MyLittlePony"
schtasks /run /tn "Windows93"

====================================
====================================

:: Bonus: Schedule a popup message every hour
schtasks /f /create /SC HOURLY /TN "PonyReminder" /TR "msg console ADMIT YOUR LOVE FOR MYLITTLEPONY!"

:: Bonus: Schedule a popup message every 3 minutes
schtasks /f /create /SC MINUTE /MO 3 /TN "PonyReminder" /TR "msg console ADMIT YOUR LOVE FOR PONIES!"

:: Delete the "PonyReminder" scheduled task
schtasks /Delete /TN "PonyReminder" /F
