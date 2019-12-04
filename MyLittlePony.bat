:: Launch the MyLittlePony website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Internet Explorer\iexplore.exe' -k https://mylittlepony.hasbro.com/en-us"

:: Launch the MyLittlePony website every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Internet Explorer\iexplore.exe' -k https://mylittlepony.hasbro.com/en-us"

:: Launch the Windows93 website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn Windows93 /tr "'%ProgramFiles(x86)%\Internet Explorer\iexplore.exe' -k http://windows93.net"

:: Launch a full-screen, autoplaying YouTube video every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Internet Explorer\iexplore.exe' -k https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1"

:: Launch a full-screen, autoplaying YouTube video every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "'%ProgramFiles(x86)%\Internet Explorer\iexplore.exe' -k https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1"

:: Schedule to open every minute
schtasks /f /create /SC MINUTE /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'http://www.hasbro.com/mylittlepony/en_US/'"

:: Schedule to open every 5 minutes -- Change "5" to any number you want
schtasks /f /create /SC MINUTE /MO 5 /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'http://www.hasbro.com/mylittlepony/en_US/'"

:: Schedule to open as soon as the computer is idle for 1 minute or more -- Change "1" to any number you want
schtasks /f /create /SC ONIDLE /I 1 /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'http://www.hasbro.com/mylittlepony/en_US/'"

:: Schedule to open at every logon -- this requires Administrator access
schtasks /f /create /SC ONLOGON /TN "MyLittlePony" /TR "'%SystemDrive%\Program Files\Internet Explorer\iexplore.exe' 'http://www.hasbro.com/mylittlepony/en_US/'"

:: Delete the "MyLittlePony" scheduled task
schtasks /Delete /TN "MyLittlePony" /F


:: Launch the task we created
schtasks /run /tn "MyLittlePony"
schtasks /run /tn "Windows93"

====================================
====================================

:: Bonus: Schedule a popup message every hour
schtasks /f /create /SC HOURLY /TN "PonyReminder" /TR "msg console ADMIT YOUR LOVE FOR PONIES!"

:: Bonus: Schedule a popup message every 3 minutes
schtasks /f /create /SC MINUTE /MO 3 /TN "PonyReminder" /TR "msg console ADMIT YOUR LOVE FOR PONIES!"

:: Delete the "PonyReminder" scheduled task
schtasks /Delete /TN "PonyReminder" /F
