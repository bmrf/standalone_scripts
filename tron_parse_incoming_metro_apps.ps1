<#
 Purpose:      Parses a list of user-submitted Metro apps against Tron's master lists
               Removes all lines that are already in the master list, then outputs new unique lines to a new file
 Requirements: Specify path to master list files, incoming file to check against, and output file
 Author:       reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
 History:      1.0.1 ! Fix egregious bugs in search syntax
               1.0.0   Initial port from GUID dump parsing script
 Usage:        Make sure paths are specified correctly (variables below) then run the script
#>


#############
# VARIABLES # -- Set these to your desired values or supply from the shell ---------------------- #
#############
# Rules for variables:
#  * Quotes are required              (e.g.:  "c:\directory\path"        )
#  * NO trailing slashes on paths!    (bad:   "c:\directory\"            )
#  * Spaces are okay                  (okay:  "c:\my folder\with spaces" )
#  * Network paths are okay           (okay:  "\\server\share name"      )
#                                     (       "\\172.16.1.5\share name"  )
param (
	# Path to master 3rd party
    [string] $metro3rdPartyListFile = "R:\utilities\security\cleanup-repair\tron\tron\resources\stage_2_de-bloat\metro\metro_3rd_party_modern_apps_to_target_by_name.ps1",

    # Path to master Microsoft list
    [string] $metroMicrosoftListFile = "R:\utilities\security\cleanup-repair\tron\tron\resources\stage_2_de-bloat\metro\metro_Microsoft_modern_apps_to_target_by_name.ps1",

    # Path to Metro app whitelist file
    [string] $metroWhitelistFile = "R:\scripts\blackmesa\tron_metro_whitelist.txt",

    # Path to candidate (new) file
    [string] $candidateListFile = "$env:temp\tron_parse_incoming_metro_apps_candidateListFile.txt",

	# Path to directory containing incoming dump files
    [string] $incomingMetroDirectory = "r:\unsorted",

    # Path to output directory
    [string] $outputFile = "r:\unsorted\metro_parsed_dump.txt"

)





# ----------------------------- Don't edit anything below this line ----------------------------- #




########
# PREP #
########
$SCRIPT_VERSION = "1.0.1"
$SCRIPT_UPDATED = "2018-03-15"


#############
# EXECUTION #
#############
function main() {

# pre-run cleanup in case there are leftovers from another run
ri "$outputFile" -ea SilentlyContinue
ri "$env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_candidateListFile.txt" -ea silentlycontinue
ri "$env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_temp1.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_temp2.txt" -ea silentlycontinue


# Notify that we're starting
log "   Removing whitelisted and pre-existing Metro apps from candidate list..." white
log "   metro3rdparty:  $metro3rdPartyListFile" darkgray
log "   metroMicrosoft: $metroMicrosoftListFile" darkgray
log "   whitelist:      $metroWhitelistFile" darkgray
log "   output:         $outputFile" darkgray


# STAGE 0/3: Compile incoming lists into a master list and clean it for parsing
dir $incomingMetroDirectory\* -include Metro_app_dump*.txt -rec | gc | out-file $env:temp\tron_parse_incoming_metro_apps_temp1.txt

log "   Compiled new candidate list. Now processing, please wait..."

# Strip out lines containing "IdentifyingNumber"
gc "$env:temp\tron_parse_incoming_metro_apps_temp1.txt" | Where-Object {$_ -notmatch 'Name'} | sc "$env:temp\tron_parse_incoming_metro_apps_temp2.txt"

# Strip out lines containing "----"
gc "$env:temp\tron_parse_incoming_metro_apps_temp2.txt" | Where-Object {$_ -notmatch '----'} | sc "$env:temp\tron_parse_incoming_metro_apps_temp3.txt"

# Remove all whitespace
(gc "$env:temp\tron_parse_incoming_metro_apps_temp3.txt").replace(' ', '') | sc "$env:temp\tron_parse_incoming_metro_apps_temp3.txt"

# Sort remaining contents and remove duplicates
gc "$env:temp\tron_parse_incoming_metro_apps_temp3.txt" | sort | get-unique > $candidateListFile

# Notify how many duplicates were removed
$raw = $(gc "$env:temp\tron_parse_incoming_metro_apps_temp1.txt" -total -1).count
$parsed = $(gc "$candidateListFile" -total -1).count
$duplicatesRemoved = $raw - $parsed
if ( $duplicatesRemoved -gt 0 ) {
    log "   Removed $duplicatesRemoved duplicate lines from candidate list"
} else {
    log "   No duplicate lines found" darkgray
}




# STAGE 1/3: Compare against 3rd party list
$candidateListContents = gc $candidateListFile
$metro3rdPartyListContents = gc $metro3rdPartyListFile
foreach ( $row in $candidateListContents ) {
	$found = $false
	foreach ( $line in $metro3rdPartyListContents ) {
		if ( $row -match $row ) { $firstApp = $MATCHES[0] }
		if ( $line -match "^.*\n" ) { $newApp = $MATCHES[0] }
		if ( $firstApp -eq $newApp ) { $found = $true }
	}

	if ( -not $found ) { echo $row | out-file $env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$candidateListFile" -total -1).count
$parsed = $(gc "$env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt" -total -1).count
$metro3rdPartyRemoved = $raw - $parsed
if ( $metro3rdPartyRemoved -gt 0 ) {
    log "   Matched $metro3rdPartyRemoved lines from 3rd Party list"
} else {
    log "   No matches against 3rd Party list" darkgray
}




# STAGE 2/3: Compare against Microsoft list
$candidateListContents = gc $env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt
$metroMicrosoftListContents = gc $metroMicrosoftListFile
foreach ( $row in $candidateListContents ) {
    $found = $false
	foreach ( $line in $metroMicrosoftListContents ) {
		if ( $row -match $row ) { $firstApp = $MATCHES[0] }
		if ( $line -match "^.*\n" ) { $newApp = $MATCHES[0] }
		if ( $firstApp -eq $newApp ) { $found = $true }
	}
	if ( -not $found ) { echo $row | out-file $env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt" -total -1).count
$parsed = $(gc "$env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt" -total -1).count
$metroMicrosoftRemoved = $raw - $parsed
if ( $metroMicrosoftRemoved -gt 0 ) {
    log "   Matched $metroMicrosoftRemoved lines from Microsoft list"
} else {
    log "   No matches against Microsoft list" darkgray
}




# STAGE 3/3: Compare against whitelist
$candidateListContents = gc $env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt
$whitelistMetroContents = gc $metroWhitelistFile
foreach ( $row in $candidateListContents ) {
    $found = $false
	foreach ( $line in $whitelistMetroContents ) {
		if ( $row -match $row ) { $firstApp = $MATCHES[0] }
		if ( $line -match "^.*\n" ) { $newApp = $MATCHES[0] }
		if ( $firstApp -eq $newApp ) { $found = $true }
	}
    if ( -not $found ) { echo $row | out-file $outputFile -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt" -total -1).count
$parsed = $(gc "$outputFile" -total -1).count
$whitelistedRemoved = $raw - $parsed
if ( $whitelistedRemoved -gt 0 ) {
    log "   Matched $whitelistedRemoved lines from whitelist"
} else {
    log "   No matches against whitelist" darkgray
}



# Clean up after ourselves
ri "$env:temp\tron_parse_incoming_metro_apps_working_file_1_duplicates_removed.txt" -ea silentlycontinue
ri "$env:temp\parse_incoming_metro_apps_working_file_2_microsoft_removed.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_temp1.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_temp2.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_metro_apps_temp3.txt" -ea silentlycontinue
ri "$incomingMetroDirectory\Metro_app_dump_*.txt" -ea silentlycontinue
ri "$incomingMetroDirectory\tron*.log" -ea silentlycontinue

# Currently I'm wiping screenshots since I don't care about them
ri "$incomingMetroDirectory\tron_*.png" -ea silentlycontinue



# Tally up and report
$tally = $duplicatesRemoved + $metro3rdPartyRemoved + $whitelistedRemoved + $metroMicrosoftRemoved
$remaining = (gc $outputFile -total -1).count
if ( $tally -gt 0 ) {
    log "   ------------------------------------------------------"
    log "   $tally duplicate or pre-existing lines removed"
    log "   $remaining lines remain for manual review" green
} else {
    log "   No candidate list entry matches" white
}
log "   Done" darkgray


pause
} # /script





#############
# FUNCTIONS #
#############
function log($message, $color)
{
	if ($color -eq $null) {$color = "gray"}
	write-host (get-date -f "yyyy-MM-dd hh:mm:ss") -n -f darkgray; write-host "$message" -f $color
}


# call the main script
main
