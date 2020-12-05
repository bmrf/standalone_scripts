<#
 Purpose:       Unlocks Active Directory accounts
 Requirements:  Network admin rights
 Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
 History:       1.1.0 + Added Prep section with standard variables to be consistent with other scripts
                1.0.0   Initial write
				 
 Usage:         Pass account names to be unlocked as arguments, e.g. .\unlock_AD_account.ps1 MyAccountName MySecondAccountName
#>


#############
# VARIABLES # -- Set these to your desired values
#############
# Rules for variables:
#  * Quotes are required              (e.g.:  "c:\directory\path"        )
#  * NO trailing slashes on paths!    (bad:   "c:\directory\"            )
#  * Spaces are okay                  (okay:  "c:\my folder\with spaces" )
#  * Network paths are okay           (okay:  "\\server\share name"      )
#                                     (       "\\172.16.1.5\share name"  )
# Logging information
$LOGPATH=$env:systemdrive + "\Logs"
$LOGFILE=$env:computername + "_AD_unlock_account.log"


########
# Prep #
########
$SCRIPT_VERSION="1.1.0"
$SCRIPT_UPDATED="2014-01-16"
$CUR_DATE=get-date -f "yyyy-MM-dd"



#############
# EXECUTION #
#############
# If no arguments were passed, spit out a message and die.
# AKA if "$args" is false / aka not true, then do this stuff
if (! $args) {
	write-host
	Write-Host "Pass names of accounts to unlock, separated by spaces. e.g. .\unlock_AD_account.ps1 MyAccountName MySecondAccountName" -f white
	write-host
	Break
	}

# Log that the script was triggered
"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " Account unlock script triggered. Executing..." >> $LOGPATH\$LOGFILE

# Do the unlock
foreach ($i in $args) {
	unlock-adaccount $i
	write-host $i unlocked -f green
	"$CUR_DATE "+ $(get-date -f "hh:mm:ss") + " $i unlocked" >> $LOGPATH\$LOGFILE
	#if $LASTEXITCODE -ne "0" write-host $i failed to unlock -f red
}