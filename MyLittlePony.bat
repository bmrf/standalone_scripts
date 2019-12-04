:: Launch the MyLittlePony website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://mylittlepony.hasbro.com/en-us"

:: Launch the MyLittlePony website every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://mylittlepony.hasbro.com/en-us"

:: Launch the Windows93 website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn Windows93 /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k http://windows93.net"

:: Launch a full-screen, autoplaying YouTube video every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc hourly /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1"

:: Launch a full-screen, autoplaying YouTube video every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /f /create /sc minute /MO 5 /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://www.youtube.com/embed/dUoiwSQdnoc?autoplay=1"
