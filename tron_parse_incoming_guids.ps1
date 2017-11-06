<#
 Purpose:      Parses a list of user-submitted GUIDs against Tron's master list.
               Removes all lines that are already in the master list, then outputs new unique lines to a new file
 Requirements: Specify path to master GUID file, incoming file to check against, and output file
 Author:       reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
 History:      1.0.1 * Add auto compilation and cleanup of incoming GUID lists
               1.0.0   Initial write
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
	# Path to master file
    [string] $byGUIDListFile = "R:\utilities\security\cleanup-repair\tron\tron\resources\stage_2_de-bloat\oem\programs_to_target_by_GUID.txt",

    # Path to toolbar/BHO file
    [string] $toolbarBHOListFile = "R:\utilities\security\cleanup-repair\tron\tron\resources\stage_2_de-bloat\oem\toolbars_BHOs_to_target_by_GUID.txt",

    # Path to GUID whitelist file
    [string] $whitelistGUIDPath = "R:\documents\misc\tron_guid_whitelist.txt",

    # Path to candidate (new) file
    [string] $candidateListFile = "$env:temp\tron_parse_incoming_guids_candidateListFile.txt",

	# Path to directory containing incoming GUID dump files
    [string] $incomingGUIDDirectory = "r:\unsorted",

    # Path to output directory
    [string] $outputFile = "r:\unsorted\guid_parsed_dump.txt"

)





# ----------------------------- Don't edit anything below this line ----------------------------- #




########
# PREP #
########
$SCRIPT_VERSION = "1.0.1"
$SCRIPT_UPDATED = "2017-09-08"


#############
# EXECUTION #
#############
function main() {

# pre-run cleanup in case there are leftovers from another run
ri "$outputFile" -ea SilentlyContinue
ri "$env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt" -ea silentlycontinue
ri "$env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_guids_temp1.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_guids_temp2.txt" -ea silentlycontinue


# Notify that we're starting
log "   Removing whitelisted and pre-existing GUIDs from candidate list..." white
log "   master:      $byGUIDListFile" darkgray
log "   toolbar_bho: $toolbarBHOListFile" darkgray
log "   whitelist:   $whitelistGUIDPath" darkgray
log "   output:      $outputFile" darkgray


# STAGE 0/4: Compile incoming GUID lists into a master list and clean it for parsing
dir $incomingGUIDDirectory\* -include GUID_dump*.txt -rec | gc | out-file $env:temp\tron_parse_incoming_guids_temp1.txt

log "   Compiled new candidate list. Now processing, please wait..."

# Strip out lines containing "IdentifyingNumber"
gc "$env:temp\tron_parse_incoming_guids_temp1.txt" | Where-Object {$_ -notmatch 'IdentifyingNumber'} | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"

# Condense whitespace (replace multiple spaces with one)
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"
(gc "$env:temp\tron_parse_incoming_guids_temp2.txt").replace('  ', ' ') | sc "$env:temp\tron_parse_incoming_guids_temp2.txt"

# Sort remaining contents and remove duplicates
gc "$env:temp\tron_parse_incoming_guids_temp2.txt" | sort | get-unique > $candidateListFile

# Notify how many duplicates were removed
$raw = $(gc "$env:temp\tron_parse_incoming_guids_temp1.txt" -total -1).count
$parsed = $(gc "$candidateListFile" -total -1).count
$duplicatesRemoved = $raw - $parsed
if ( $duplicatesRemoved -gt 0 ) {
    log "   Removed $duplicatesRemoved duplicate lines from candidate list"
} else {
    log "   No duplicate lines found" darkgray
}




# STAGE 1/4: Compare against by_GUID list
$candidateListContents = gc $candidateListFile
$masterListContents = gc $byGUIDListFile
foreach ( $row in $candidateListContents ) {
    $found = $false
    # Do a regex match to find GUIDs, since they always follow this format. Note: will not work if the hyphens have been removed
	if ( $row -match "........\-....\-....\-....\-............" ) { $firstGUID = $MATCHES[0]
        foreach ( $line in $masterListContents ) {
            if ( $line -match "........\-....\-....\-....\-............" ) { $newGUID = $MATCHES[0] }
            if ( $firstGUID -eq $newGUID ) { $found = $true }
        }
    }
    if ( -not $found ) { echo $row | out-file $env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$candidateListFile" -total -1).count
$parsed = $(gc "$env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt" -total -1).count
$byGUIDRemoved = $raw - $parsed
if ( $byGUIDRemoved -gt 0 ) {
    log "   Matched $byGUIDRemoved lines from master list"
} else {
    log "   No matches against master list" darkgray
}




# STAGE 2/4: Compare against toolbar/BHO list
$candidateListContents = gc $env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt
$toolbarBHOListContents = gc $toolbarBHOListFile
foreach ( $row in $candidateListContents ) {
    $found = $false
	# Do a regex match to find GUIDs, since they always follow this format. Note: will not work if the hyphens have been removed
    if ( $row -match "........\-....\-....\-....\-............" ) { $firstGUID = $MATCHES[0]
        foreach ( $line in $toolbarBHOListContents ) {
            if ( $line -match "........\-....\-....\-....\-............" ) { $newGUID = $MATCHES[0] }
            if ( $firstGUID -eq $newGUID ) { $found = $true }
        }
    }
    if ( -not $found ) { echo $row | out-file $env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt" -total -1).count
$parsed = $(gc "$env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt" -total -1).count
$toolbarBHORemoved = $raw - $parsed
if ( $toolbarBHORemoved -gt 0 ) {
    log "   Matched $toolbarBHORemoved lines from toolbar/BHO list"
} else {
    log "   No matches against toolbar/BHO list" darkgray
}




# STAGE 3/4: Compare against white list
$candidateListContents = gc $env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt
$whitelistGUIDContents = gc $whitelistGUIDPath
foreach ( $row in $candidateListContents ) {
    $found = $false
	# Do a regex match to find GUIDs, since they always follow this format. Note: will not work if the hyphens have been removed
    if ( $row -match "........\-....\-....\-....\-............" ) { $firstGUID = $MATCHES[0]
        foreach ( $line in $whitelistGUIDContents ) {
            if ( $line -match "........\-....\-....\-....\-............" ) { $newGUID = $MATCHES[0] }
            if ( $firstGUID -eq $newGUID ) { $found = $true }
        }
    }
    if ( -not $found ) { echo $row | out-file $outputFile -append -encoding default }
}

# Tell us how many items were removed
$raw = $(gc "$env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt" -total -1).count
$parsed = $(gc "$outputFile" -total -1).count
$whitelistedRemoved = $raw - $parsed
if ( $whitelistedRemoved -gt 0 ) {
    log "   Matched $whitelistedRemoved lines from white list"
} else {
    log "   No matches against whitelist" darkgray
}





# Clean up after ourselves
ri "$env:temp\tron_parse_incoming_guids_working_file_1_duplicates_removed.txt" -ea silentlycontinue
ri "$env:temp\parse_incoming_guids_working_file_2_toolbar_bho_removed.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_guids_temp1.txt" -ea silentlycontinue
ri "$env:temp\tron_parse_incoming_guids_temp2.txt" -ea silentlycontinue
ri "GUID_dump_*.txt" -ea silentlycontinue
ri "tron*.log" -ea silentlycontinue

# Tally up and report
$tally = $duplicatesRemoved + $byGUIDRemoved + $whitelistedRemoved + $toolbarBHORemoved
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
