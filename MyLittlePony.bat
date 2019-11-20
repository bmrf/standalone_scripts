:: Launch the MyLittlePony website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /create /sc hourly /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://mylittlepony.hasbro.com/en-us"

:: Launch the MyLittlePony website every 5 minutes in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /create /sc minute /MO 5 /tn MyLittlePony /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k https://mylittlepony.hasbro.com/en-us"

:: Launch the Windows93 website every hour in Kiosk mode (full-screen, all controls except alt-f4 disabled)
schtasks /create /sc hourly /tn Windows93 /tr "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe -k http://windows93.net"
