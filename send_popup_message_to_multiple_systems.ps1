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
$DesktopsOU = "OU=Desktops, DC=mydomain, DC=com"

# OU containing laptops to target
$LaptopsOU = "OU=Laptops, DC=mydomain, DC=com"

# Message to send
$message = "Please save your work and restart your computer ASAP. Thanks."

# Location of psexec (if using the psexec method vs. the Powershell Invoke-Command method)
$psexec = c:\windows\system32\psexec.exe



########
# PREP #
########
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_UPDATED = "2020-02-13"


#############
# EXECUTION #
#############

# Populate the list of computers we're targeting
$DesktopList=(get-adcomputer -searchbase "$DesktopsOU" -filter * | select -expand Name)
$LaptopList=(get-adcomputer -searchbase "$LaptopsOU" -filter * | select -expand Name)

# for testing a single system
#$DesktopList = "computer"
#$LaptopList = "computer2"

# Loop through and send the message
foreach ( $computer in $DesktopList ) {

	# Check to see if the system is online
	if (test-Connection -Cn $computer -quiet) {
		# Using Psexec to connect
		# & $psexec \\$computer -i msg * "$message"
		
		# Using native Powershell to connect
		Invoke-Command -ComputerName $computer -ScriptBlock { msg * "$message" }

	} else {
		"$computer not online, skipping."
	}

}


# Loop through and send the message (laptops)
foreach ( $computer in $LaptopList ) {

	# Check to see if the system is online
	if (test-Connection -Cn $computer -quiet) {
		# Using Psexec to connect
		# & $psexec \\$computer -i msg * "$message"
		
		# Using native Powershell to connect
		Invoke-Command -ComputerName $computer -ScriptBlock { msg * "$message" }

	} else {
		"$computer not online, skipping."
	}

}
