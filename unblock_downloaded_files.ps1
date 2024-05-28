<#
Purpose:       Recursively removes the "this file was downloaded from the Internet" flag from all files
Requirements:  Place script in the directory you want to start from
Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
Version:       1.0.0
#>



#############
# VARIABLES # ---------------------- Set these to match your environment ------------------------ #
#############
# Rules for variables:
#  * NO trailing slashes on paths! (bad:   c:\directory\            )
#  * Spaces are okay               (okay:  c:\my folder\with spaces )
#  * Network paths are okay        (okay:  \\server\share name      )
param (
	# Logging information (currently unused, the unblock-file command doesn't output any text
	[string]$logpath = "c:\logs",
	[string]$logfile = "unblock_downloaded_files.log"
)






# ----------------------------- Don't edit anything below this line ----------------------------- #






###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_UPDATED = "2024-05-28"
$CUR_DATE=get-date -f "yyyy-MM-dd"




###########
# EXECUTE #
###########
dir "." -recurse | unblock-file
