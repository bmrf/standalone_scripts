<#
 Purpose:       Trigger a pop-up message window on a list of systems
 Requirements:  Admin rights on the target machines
 Author:        S-6
 History:       1.0.0   Initial write
 Usage:         Edit the variables below to target the OU you want, and specify where psexec is
#>



#############
# VARIABLES # (set these to your values)
#############

# OU containing desktops to target
$DesktopOU = "OU=MB,OU=Desktops,DC=com"

# OU containing laptops to target
$LaptopOU = "OU=MB,OU=Laptops,DC=com"

# Message to send
#$message = "Please save your work and restart your computer ASAP. Thanks, S-6."
$MessageToSend = "This is a test of the S-6 notification system, please disregard this message."

# Location of psexec (if using the psexec method vs. the Powershell Invoke-Command method) $psexec = c:\windows\system32\psexec.exe




########
# PREP #
########
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_UPDATED = "2020-02-20"




###########
# EXECUTE #
###########
# The wrest of the script is wrapped in the "main" function, just so we can put the logging function at the bottom
function main() {

# Pull in the list of computers we're targeting
$DesktopList=(get-adcomputer -searchbase "$DesktopOU" -filter * | select -expand Name)
$LaptopList=(get-adcomputer -searchbase "$LaptopOU" -filter * | select -expand Name)

# for testing against specific systems
#$DesktopList = 'BLISW6CLAAWKPT2',
#'BLISWKMAD1HQ604',
#'BLISWkmad1hq602'

#$LaptopList = 'BLISW6CLAAWKPT2',
#'BLISWKMAD1HQ604',
#'BLISWkmad1hq602'


# Count how many in each OU
$DesktopCount = $DesktopList.Count
$LaptopCount = $LaptopList.Count
$TotalCount = $DesktopCount + $LaptopCount



# Notify what we're doing
log "   Message sending script v$SCRIPT_VERSION ($SCRIPT_UPDATED)" green
log "   Message to send: '$MessageToSend'" white
log "   Desktop OU: ($DesktopCount hosts) '$DesktopOU'"
log "   Laptop OU:  ($LaptopCount hosts) '$LaptopOU'"


# Prompt to launch
""
write-host "   Message will be sent to a total of $TotalCount hosts." -f white
""
write-host "   Are you sure?" -f red
""
pause
""


# Loop through and send the message (Desktop OU)
log "   Sending to Desktop OU..." green

foreach ( $computer in $DesktopList ) {

    # Check to see if the system is online before sending
    if (test-Connection -Cn $computer -quiet) {

        # Using Psexec to connect
        # & $psexec \\$computer -i msg * "$MessageToSend"
       
        # Using Powershell to connect
        Invoke-Command -ComputerName $computer -ScriptBlock { msg * "$using:MessageToSend" } -ea SilentlyContinue # the "$using:" method only works on PS v3 and up
        log "   $computer sent."

    } else {
        log " ! $computer not online, skipping." yellow
    }

}
log "   Done." darkgreen




# Loop through and send the message (Laptop OU)
log "   Sending to Laptop OU..." green

foreach ( $computer in $LaptopList ) {
    # Check to see if the system is online before sending
    if (test-Connection -Cn $computer -quiet) {

        # Using Psexec to connect
        # & $psexec \\$computer -i msg * "$MessageToSend"
       
        # Using Powershell to connect
        Invoke-Command -ComputerName $computer -ScriptBlock { msg * "$using:MessageToSend" } -ea SilentlyContinue # the "$using:" method only works on PS v3 and up
        log "   $computer sent."

    } else {
        log " ! $computer not online, skipping." yellow
    }

}
log "   Done." darkgreen

} # Close out the main function. End of script




#############
# FUNCTIONS #
#############
function log($message, $color)
{
	if ($color -eq $null) {$color = "gray"}
	# log to console
	write-host (get-date -f "yyyy-MM-dd hh:mm:ss") -n -f darkgray; write-host "$message" -f $color
}



# Call the main function (script). Script won't function without this line
main
