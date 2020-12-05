<#
 Purpose:       SHOU(Site, Hostname, OU) checker: Moves a workstation to the correct OU based on its site, renames it according to the naming standard, then reboots it
 Requirements:  Domain admin rights
 Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key ID: 0x07d1490f82a211a2
 History:       1.0.0   Initial write
 Usage:         1. Run with Task Scheduler whenever you feel necessary, just be aware the affected machines will be rebooted
                   Run like this:  .\scriptName.ps1 -CheckOU "Name of OU to scan"
 Notes:         If moving from Pima to Ventura, since we don't know which specific OU to place the machine in, we default to dumping it in the Ventura-Area-D OU since that's where most moves happen
#>


#############
# VARIABLES # -- set these to your desired values or supply them from shell
#############
param (
	# Logging information
	[string] $LogPath = $env:systemdrive + "\Logs",
	[string] $LogFile = $env:computername + "_AD_SHOU_checker.log",
	# Credentials to perform the operation
	[string] $DomainUsername = "adrename_robot",
	[string] $DomainPassword = "8I5az5jR66fdxWZKpYdU",
	[string] $CheckOU = $( Read-Host "Enter OU to check" ),  # prompt for this if it wasn't supplied
	
	[string] $FixOU = "no",                                  # Auto-move the host to the correct OU if incorrect
	[string] $FixHostnames = "no"                            # Auto-rename hosts if name is incorrect (note: forces reboot)
)



########
# Prep #
########
$SCRIPT_VERSION="1.0.0"
$SCRIPT_UPDATED="2015-03-10"
$CUR_DATE=get-date -f "yyyy-MM-dd"
$ErrorActionPreference = "SilentlyContinue"


###########
# EXECUTE #
###########
# Log that we started
"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " SHOU checker v$SCRIPT_VERSION initialized, scanning OU `"$CheckOU`"..." >> $LogPath\$LogFile
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n " SHOU checker v$SCRIPT_VERSION initialized, scanning OU `""; write-host -n -f blue "$CheckOU"; write-host "`"..."

# Scan the target OU and populate an array with the current hostnames
$CURRENT_OU_HOSTS=(get-adcomputer -searchbase "OU=$CheckOU,OU=NTI_Workstations,DC=green,DC=nti" -filter 'ObjectClass -eq "Computer"' | select -expand Name)

# FixOU was specified
if ($FixOU -eq "yes") {
	"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " FixOU specified; will automatically fix host OU membership if incorrect" >> $LogPath\$LogFile
	write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " FixOU specified; will automatically fix host OU membership if incorrect"
}

# FixHostnames was specified
if ($FixHostnames -eq "yes") {
	"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " FixHostnames specified; hosts will be automatically renamed and rebooted if their hostname is incorrect" >> $LogPath\$LogFile
	write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " FixHostnames specified; hosts will be automatically renamed and rebooted if their hostname is incorrect"
}

# Neither action was specified
if ($FixHostnames -ne "yes" -And $FixOU -ne "yes") {
	"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " No actions specified, enumerating OU hosts only" >> $LogPath\$LogFile
	write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -b black -f yellow " No actions specified, enumerating OU hosts only"
}


# Iterate through the array and check each system
foreach ($i in $CURRENT_OU_HOSTS) {
	# Temporary exclusion to prevent renaming Lauri's box
	if ($i -ne "G-DGPBZV1") {
		# Log which host we're on
		"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " $i..." >> $LogPath\$LogFile
		write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " $i..."
		
		# Populate current system information (site, hostname, serial number)
		$tempVar = nltest /dsgetsite /server:$i
		$CURRENT_SITE = $tempVar[0]
		$tempVar = Get-ADComputer $i -EA SilentlyContinue
		$CURRENT_OU = $tempVar.DistinguishedName
		$tempVar = wmic /node:$i bios get serialnumber	# get the remote system's serial number
		$tempVar1 = $tempVar[2].trim()					# trim trailing space
		$SERIAL = $tempVar1.replace(' ','')				# trim other spaces
		

		# STEP 1: Check the OU-to-site mapping
		if ($FixOU -eq "yes") {
			if ($CURRENT_SITE -like '*VENTURA*' -And $CURRENT_OU -like '*Ventura*') {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "   OK (OU-site mapping)" >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f green "   OK "; write-host "(OU-site mapping)" -f darkgray
			} elseif ($CURRENT_SITE -like '*PIMA*' -And $CURRENT_OU -like '*Pima*') {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "   OK (OU-site mapping)" >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f green "   OK "; write-host "(OU-site mapping)" -f darkgray
			} else {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " ERROR: $i is in `"$CheckOU`" OU but in site `"$CURRENT_SITE`". Moving to correct OU." >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f red " ERROR"; write-host ": $i is in `"$CheckOU`" OU but in site `"$CURRENT_SITE`". Moving to correct OU."
				if ($CURRENT_SITE -like '*VENTURA*') { Get-ADComputer $i | Move-ADObject -TargetPath "OU=Ventura-Area-D,OU=NTI_Workstations,DC=green,DC=nti" }
				if ($CURRENT_SITE -like '*PIMA*') { Get-ADComputer $i | Move-ADObject -TargetPath "OU=Pima,OU=NTI_Workstations,DC=green,DC=nti" }
			}
		}
		
		# STEP 2: Check the hostname
		if ($FixHostnames -eq "yes") {
			if ($CURRENT_SITE -like '*VENTURA*' -And $i -like '*VENW*') {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "   OK (hostname)" >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f green "   OK "; write-host "(hostname)" -f darkgray
			} elseif ($CURRENT_SITE -like '*PIMA*' -And $i -like '*PIMW*') {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "   OK (hostname)" >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f green "   OK "; write-host "(hostname)" -f darkgray
			} else {
				"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " ERROR: $i does not match naming standard for `"$CURRENT_SITE`"." >> $LogPath\$LogFile
				write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host -n -f red " ERROR"; write-host ": $i does not match naming standard for site `"$CURRENT_SITE`"."
				if ($CURRENT_SITE -like '*VENTURA*') { 
					"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "        Renaming to GVENW$SERIAL and rebooting using account $DomainUsername." >> $LogPath\$LogFile
					write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host "        Renaming to GVENW$SERIAL and rebooting using account $DomainUsername."
					#&netdom renamecomputer $i /newname:GPIMW$SERIAL /ud:$DomainUsername /pd:$DomainPassword /force /reboot:5 
				}
				if ($CURRENT_SITE -like '*PIMA*') { 
					"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + "        Renaming to GPIMW$SERIAL and rebooting using account $DomainUsername." >> $LogPath\$LogFile
					write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host "        Renaming to GPIMW$SERIAL and rebooting using account $DomainUsername."
					#&netdom renamecomputer $i /newname:GVENW$SERIAL /ud:$DomainUsername /pd:$DomainPassword /force /reboot:5 
				}
			}
		}
	}
}


"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " SHOU checker v$SCRIPT_VERSION complete" >> $LogPath\$LogFile
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " SHOU checker v$SCRIPT_VERSION complete"