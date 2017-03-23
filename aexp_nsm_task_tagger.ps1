<#
Purpose:       Pulls TASK numbers out of log files and adds them to the log file name
Requirements:  Specify your log file directory in the implementationLogs variable
               Script searches the change.log's in the directory, extracts the TASK number, and renames the before/change/after log set based on that. If no task #, then no rename occurs.
Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
Version:       1.0.0 . Initial write
#>



#############
# VARIABLES # ---------------------- Set these to match your environment ------------------------ #
#############
# Rules for variables:
#  * NO trailing slashes on paths! (bad:   c:\directory\            )
#  * Spaces are okay               (okay:  c:\my folder\with spaces )
#  * Network paths are okay        (okay:  \\server\share name      )
param (
	# Logging information
	#[string]$logpath = "$env:userprofile\root\documents\misc\logs",
	[string]$logpath = "c:\logs",
	[string]$logfile = "add_task_number_to_log_names.log",

	# Path to 7z.exe
	[string]$SevenZip = "C:\Program Files\7-Zip\7z.exe",

	# Implementation logs directory that we're scanning
	[string]$implementationLogs = "$env:userprofile\root\documents\implementation_logs"
	#[string]$implementationLogs = "$env:userprofile\implementation_logs"
)






# ----------------------------- Don't edit anything below this line ----------------------------- #






###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "1.0.0"
$SCRIPT_UPDATED = "2017-03-23"
$CUR_DATE=get-date -f "yyyy-MM-dd"
# Get in our directory. We'll be here for the rest of the script
pushd $implementationLogs
# Preload our different arrays for later
# Extract bare file names, then convert to those filenames to strings and store full path of each file
$logsChange = ls $implementationLogs\*change.log -name
$logsBefore = ls $implementationLogs\*before.log -name
$logsAfter = ls $implementationLogs\*after.log -name
$logsChange = ls $logsChange | % { $_.FullName }
$logsBefore = ls $logsBefore | % { $_.FullName }
$logsAfter = ls $logsAfter | % { $_.FullName }




#################
# SANITY CHECKS #
#################
# List of items to make sure they exist before running the script
$pathsToCheck = @(
    # Local machine: 7z.exe
    "$SevenZip",
    # Local machine: Implementation logs
    "$implementationLogs"
)

# Run the check
foreach ($i in $pathstoCheck) {
    if ( -not (test-path -LiteralPath $i)) {
        ""
        write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
        write-host " Couldn't find the following required item:"
        ""
        write-host "            $i"
        ""
        write-host "         Check paths and permissions and make sure it exists"
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
		return
    }
}





###########
# EXECUTE #
###########

# Script is wrapped in a function so we can stick the log function at the bottom
function main() {
log "AEXP NSM log file TASK tagging script v$SCRIPT_VERSION" cyan
log "Executing as $env:userdomain\$env:username" darkgray

# Loop through the logs and rename them, using the Change log as the "anchor" since it' contains the TASK number
foreach ($logfileChange in $logsChange) {
	
	# Extract the task number from the log and into a variable
	$taskNumber = ""												# blank it out each loop
	$step1 = gc $logfileChange | sls -pattern TASK\d\d\d\d\d\d\d	# extract whole line
	$step2 = ("$step1" -split "\*\*\*\*\s")[1]						# strip leading asterisks
	$taskNumber = $step2 -replace "\s\*\*\*\*",""					# strip trailing asterisks
	$taskNumber = $taskNumber.trim()								# strip before and after whitespace

	# If we were able to get a task number go ahead and perform the rename operations
	# If we weren't able to extract a TASK number then all the following is skipped and we go on to the next file
	# (length being greater than 5 is a somewhat arbitrary check but whatever)
	if ($taskNumber.Length -gt 5) {

		# Rename the CHANGE log
		if ($logfileChange -match "$taskNumber") {
			log "SKIP $taskNumber change.log (already tagged)"
		} else {
			log "TAG  $taskNumber change.log" green
			# Build our new file name then do the rename
			$logfileChangeNewName = $logfileChange -replace "TASKxxxxxxx","$taskNumber"
			Rename-Item $logfileChange $logfileChangeNewName -force
		}
	

		# Rename the BEFORE log
		# Loop through ALL Before logs and compare them to the working Change log to find a match
		foreach ($logfileBefore in $logsBefore) {
			# This is really ugly but here's the explanation:
			# We're basically doing an AND comparison on the date/time stamp (down to the hour) and the IP address/hostname in the "before" log file names
			# If BOTH match, then we assume we've found a matching log set and rename accordingly
			# The use of the split function is to strip out the path and leave only the file name
			# The use of the substring function is to extract the IP address/hostname for comparison
			if ($logfileBefore.split("\\")[-1].substring(0,14) -eq $logfileChange.split("\\")[-1].substring(0,14) -and $logfileBefore.split("-")[-2] -eq $logfileChange.split("-")[-2]) {

				# Rename the Before log
				if ($logfileBefore -match "$taskNumber") {
					log "SKIP $taskNumber before.log (already tagged)"
				} else {
					log "TAG  $taskNumber before.log" green

					# Make some variables to use in the log messages
					$logfileChangeMatch = $logfileChange.split("\\")[-1]
					$logfileBeforeMatch = $logfileBefore.split("\\")[-1]

					# Log the match
					logNoDateTimeStamp "$logfileChangeMatch"
					logNoDateTimeStamp "$logfileBeforeMatch"

					# Build our new file name then do the rename
					$logfileBeforeNewName = $logfileBefore -replace "TASKxxxxxxx","$taskNumber"
					Rename-Item $logfileBefore $logfileBeforeNewName -force
				}
			}
		}
		
		
		# Rename the AFTER log
		# Loop through ALL After logs and compare them to the working Change log to find a match
		foreach ($logfileAfter in $logsAfter) {
			# This is really ugly but here's the explanation:
			# We're basically doing an AND comparison on the date/time stamp (down to the hour) and the IP address/hostname in the "After" log file names
			# If BOTH match, then we assume we've found a matching log set and rename accordingly
			# The use of the split function is to strip out the path and leave only the file name
			# The use of the substring function is to extract the IP address/hostname for comparison
			if ($logfileAfter.split("\\")[-1].substring(0,14) -eq $logfileChange.split("\\")[-1].substring(0,14) -and $logfileAfter.split("-")[-2] -eq $logfileChange.split("-")[-2]) {

				# Rename the After log
				if ($logfileAfter -match "$taskNumber") {
					log "SKIP $taskNumber after.log  (already tagged)"
				} else {
					log "TAG  $taskNumber after.log" green

					# Make some variables to use in the log messages
					$logfileChangeMatch = $logfileChange.split("\\")[-1]
					$logfileAfterMatch = $logfileAfter.split("\\")[-1]

					# Log the match
					logNoDateTimeStamp "$logfileChangeMatch"
					logNoDateTimeStamp "$logfileAfterMatch"

					# Build our new file name then do the rename
					$logfileAfterNewName = $logfileAfter -replace "TASKxxxxxxx","$taskNumber"
					Rename-Item $logfileAfter $logfileAfterNewName -force
				}
			}
		}


		
		
	} else {
		$x = $logfileChange.split("\\")[-1] #hacky workaround so the log function doesn't blow up
		log "PASS (no task #): $x" 
	}

} # End rename loop



# Finished
log "COMPLETE" cyan
popd
pause
} # End main function





#############
# FUNCTIONS #
#############
function log($message, $color)
{
	if ($color -eq $null) {$color = "gray"}

	write-host (get-date -f "yyyy-MM-dd hh:mm:ss") -n -f darkgray; write-host " $message" -f $color
	(get-date -f "yyyy-MM-dd hh:mm:ss") +" $message" | out-file -Filepath "c:\logs\add_task_number_to_log_names.log" -append
	#(get-date -f "yyyy-mm-dd hh:mm:ss") +"$message" | out-file -Filepath "$logpath\$logfile" -append
}

function logNoDateTimeStamp($message, $color)
{
	if ($color -eq $null) {$color = "gray"}

	write-host "                    $message" -f $color
	"                    $message" | out-file -Filepath "c:\logs\add_task_number_to_log_names.log" -append
}




# call the main script
main
