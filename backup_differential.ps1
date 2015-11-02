<#
 Purpose:       Rotating differential backup using 7-Zip for compression.
 Requirements:  - forfiles.exe from Microsoft
                - 7-Zip
 Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
 Version:       0.1.0 + Rebase to PowerShell

 Notes:         My intention for this script was to keep the logic controlling schedules, backup type, etc out of the script and
                let an invoking program handle it (e.g. Task Scheduler). You simply run this script with a flag to perform an action.
                If you want to schedule monthly backups, purge old files, etc, just set up task scheduler jobs for those tasks, 
                where each job calls the script with a different flag.

 Usage:         Run this script without any flags for a list of possible actions. Run it with a flag to perform that action.
                Flags:
                 -f   create full backup
                 -d   create differential backup (full backup must already exist)
                 -r   restore from a backup (extracts to your staging area)
                 -a   archive (close out/rotate) the current backup set. This:
                      1. moves all .7z files in the $destination into a folder named with the current date
                      2. deletes all .7z files from the staging area
                 -p   purge (delete) old backup sets from staging and destination. If you specify a number 
                      of days after the command it will run automatically without any confirmation. Be careful with this!
                 -c   config dump. Show job options (show what the variables are set to)

 Important:     If you want to set this script up in Windows Task Scheduler, be aware that Task Scheduler
                can't use mapped network drives (X:\, Z:\, etc) when it is set to "Run even if user isn't logged on."
                The task will simply fail to do anything (because Scheduler can't see the drives). To work around this use
                UNC paths instead (\\server\backup_folder etc) for your source, destination, and staging areas.

#>

#############
# VARIABLES # ------------------------ Set these to match your environment -------------------------- #
#############
# Rules for variables:
#  * Wrap everything in quotes     ( good:  "c:\directory\path"        )
#  * NO trailing slashes on paths! ( bad:   "c:\directory\"            )
#  * Spaces are okay               ( good:  "c:\my folder\with spaces" )
#  * Network paths are okay        ( good:  "\\server\share name"      )
param (
	# Specify the folder you want to back up here.
	[string]$source = "R:\",

	# Key (password) for archive encryption. If blank, no encryption is used
	[string]$encryption_key = ""
	
	# Work area where everything is stored while compressing. Should be a fast drive or something that can handle a lot of writes
	# Recommend not using a network share unless it's Gigabit or faster.
	[string]$staging = "P:\backup_staging\remote",

	# This is the final, long-term destination for your backup after it is compressed.
	[string]$destination = "\\thebrain\backup",

	# If you want to customize the prefix of the backup files, do so here. Don't use any special characters (like underscores)
	# The script automatically suffixes an underscore to this name. Recommend not changing this unless you really need to.
	#  * Spaces are NOT OKAY to use here!
	[string]$backup_prefix = "backup",

	# OPTIONAL: If you want to exclude some files or folders, you can specify your exclude file here. The exclude file is a list of 
	# files or folders (wildcards in the form of * are allowed and recommended) to exclude
	# If you specify a file here and the script can't find it, it will abort
	# If you leave this variable blank the script will ignore it
	[string]$exclusions_file = "R:\scripts\sysadmin\backup_differential_excludes.txt",

	# Log settings. Max size is how big (in bytes) the log can be before it is archived. 1048576 bytes is one megabyte
	[string]$logpath = $env:systemdrive + "\Logs",
	[string]$logfile = "$env:computername_$backup_prefix_differential.log",
	[string]$log_max_size = "104857600",

	# Location of 7-Zip and forfiles.exe
	[string]$sevenzip = "$env:ProgramFiles\7-Zip\7z.exe",
	[string]$forfiles = "$env:windir\system32\forfiles.exe"
)



# ----------------------------- Don't edit anything below this line ----------------------------- ::




###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "0.1.0"
$SCRIPT_UPDATED = "2015-10-29"
$CUR_DATE=get-date -f "yyyy-MM-dd"

# Preload variables for use later
$JOB_TYPE = $args[0]
$JOB_ERROR = "0"
$DAYS = $Args[1]
$RESTORE_TYPE = "NUL"
$SCRIPT_NAME = "backup_differential.ps1"

# Show help if requested
if ( $args[0] -eq "-h" -or $args[0] -eq "/h" -or $args[0] -eq "--h" -or $args[0] -eq "--help" ) { $JOB_TYPE = "help"
	""
	write-output "  $SCRIPT_NAME v$SCRIPT_VERSION"
	""
	write-output "  Usage: $SCRIPT_NAME < -f | -d | -r | -a | -c [days] >"
	""
	write-output "  Flags:"
	write-output "   -f:  create full backup"
	write-output "   -d:  create differential backup (requires an existing full backup)"
	write-output "   -r:  restore from a backup (extracts to $staging\$backup_prefix_restore)"
	write-output "   -a:  archive current backup set. This will:"
	write-output "         1. move all .7z files located in:"
	write-output "            $destination"
	write-output "            into a dated archive folder."
	write-output "         2. purge (delete) all copies in the staging area ($staging)"
	write-output "   -p:  purge (AKA delete) archived backup sets from staging and long-term storage"
	write-output "        Optionally specify number of days to run automatically. Be careful with this!"
	write-output "        Note that this requires a previously-archived backup set (-a option)"
	write-output "   -c:  config dump (show what parameters the script WOULD execute with)"
	""
	write-output "  Edit this script before running it to specify your source, destination, and work directories."
	exit(0)
}

# Make logfile if it doesn't exist
if (!(test-path $logpath)) { new-item -path $logpath -itemtype directory }


#################
# SANITY CHECKS #
#################
# Test for existence of 7-Zip
if (!$SevenZip) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find 7z.exe at the location specified ( $SevenZip )"
	write-host "         Edit this script and change the `$SevenZip variable to point to 7z's location"
	""
	pause
	break
}

# Test for existence of exclusions file if it was specified
if ( !(test-path -path $exclusions_file) -and ($exclusions_file -ne "") ) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " An exclusions file was specified but couldn't be found."
	write-host "         $exclusions_file"
	""
	pause
	break
}


# Dump config if requested
if ( $JOB_TYPE -eq "config_dump" ) {
	""
	write-output  Current configuration:
	""
	write-output  Script version:       $SCRIPT_VERSION
	write-output  Script updated:       $SCRIPT_UPDATED
	write-output  Source:               $source
	write-output  Destination:          $destination
	write-output  Staging area:         $staging
	write-output  Exclusions file:      $exclusions_file
	write-output  Backup prefix:        $backup_prefix
	write-output  Restores unpacked to: $staging\$backup_prefix_restore
	write-output  Log file:             $logpath\$logfile
	""
	write-output Edit this script with a text editor to customize these options.
	"" 
}


###########
# EXECUTE #
###########
# wrap entire script in main function so we can put the logging function at the bottom of the script
function main {

# Parse CLI args
foreach ( $thing in $args ) {
	if ( $thing -eq "-f" ) { $JOB_TYPE = "full" }
	if ( $thing -eq "-d" ) { $JOB_TYPE = "differential" }
	if ( $thing -eq "-r" ) { $JOB_TYPE = "restore" }
	if ( $thing -eq "-a" ) { $JOB_TYPE = "archive_backup_set" }
	if ( $thing -eq "-p" ) { $JOB_TYPE = "purge_archives" }
	if ( $thing -eq "-c" ) { $JOB_TYPE = "config_dump" }
}

# Welcome banner
logliteral ""
logliteral "---------------------------------------------------------------------------------------------------"
logliteral "  Differential Backup Script v$SCRIPT_VERSION - initialized (get-date -f "yyyy-mm-dd hh:mm:ss") at by $env:userdomain\$env:username" green
logliteral ""
logliteral "  Script location:  $pwd\$SCRIPT_NAME"
logliteral ""
logliteral " Job Options"
logliteral "  Job type:        Full backup"
logliteral "  Source:          $source"
logliteral "  Destination:     $destination"
logliteral "  Staging area:    $staging"
logliteral "  Exclusions file: $exclusions_file"
logliteral "  Backup prefix:   $backup_prefix"
logliteral "  Log location:    $logpath\$logfile"
logliteral "---------------------------------------------------------------------------------------------------"
logliteral ""


# // FULL BACKUP: begin
if ( $JOB_TYPE -eq "full" ) { 
	logliteral ""
	log "   Building full archive in staging area $staging..."
	logliteral ""
	log "------- [ Beginning of 7zip output ] -------" blue
		if ( $exclusions_file -ne "" ) { & $sevenzip a "$staging\$backup_prefix_full.7z" "$source" -xr@$exclusions_file  }
		if ( $exclusions_file -eq "" ) { & $sevenzip a "$staging\$backup_prefix_full.7z" "$source"  }
	logliteral ""
	log "------- [ End of 7zip output ] -------" blue
	logliteral ""

	# Report on the build
	if ( $? -eq "True" ) {
		log "   Archive built successfully."
	} else {
		$JOB_ERROR = "1"
		log " ! Archive built with errors." yellow
	}

	# Upload to destination
	logliteral ""
	log "   Uploading $backup_prefix_full.7z to $destination..."
	logliteral ""
	xcopy "$staging\$backup_prefix_full.7z" "$destination\" /Q /J /Y /Z 
	logliteral ""

	# Report on the upload
	if ( $? -eq "True" ) {
		log "   Uploaded full backup to $destination successfully."
	} else {
		$JOB_ERROR = "1"
		log " ! Upload of full backup to $destination failed." yellow
	}

} # // FULL BACKUP: end



# // DIFFERENTIAL BACKUP: begin
if ( $JOB_TYPE -eq "full" ) { 

	# Check for full backup existence
	if (!"$staging\$backup_prefix_full.7z") {
		$JOB_ERROR = "1"
		log " ! ERROR: Couldn't find full backup file ($backup_prefix_full.7z). You must create a full backup before a differential can be created." yellow
		break
	} else {
		# Backup existed, so go ahead
		log "   Performing differential backup of $source..." green
	}


	# Build archive
	log "   Building archive in staging area $staging..."
	logliteral ""
	log "------- [ Beginning of 7zip output ] -------"
	# Run if we're using an exclusions file
	if ( $exclusions_file -ne "" ) { & $sevenzip u "$staging\$backup_prefix_full.7z" "$source" -ms=off -mx=9 -xr@$exclusions_file -t7z -u- -up0q3r2x2y2z0w2!"$staging\$backup_prefix_differential_$CUR_DATE.7z"  }
	
	# Run if we're NOT using an exclusions file
	if ( $exclusions_file -eq "" ) { & $sevenzip u "$staging\$backup_prefix_full.7z" "$source" -ms=off -mx=9 -t7z -u- -up0q3r2x2y2z0w2!"$staging\$backup_prefix_differential_$CUR_DATE.7z"  }
	write-output "------- [ End of 7zip output ] -------" 
	logliteral ""

	# Report on the build
	if ( $? -eq "True" ) {
		log "   Archive built successfully."
	} else {
		$JOB_ERROR = "1"
		log " ! Archive built with errors." yellow
	}

	# Upload to destination
	log "   Uploading $backup_prefix_differential_$CUR_DATE.7z to $destination..."
	xcopy "$staging\$backup_prefix_differential_$CUR_DATE.7z" "$destination\" /Q /J /Y /Z 

	# Report on the upload
	if ( $? -eq "True" ) {
		log "   Uploaded differential file successfully."
	} else {
		$JOB_ERROR = "1"
		log " ! Upload of differential file failed." yellow
	}
} # DIFFERENTIAL BACKUP: end



# // RESTORE FROM BACKUP: begin
	#
	# ! ----------------------------------------------------  LOTS OF BROKEN STUFF BELOW HERE
	#
if ( $JOB_TYPE -eq "restore" ) { 
	logliteral " Restoring from a backup set"
	logliteral " These backups are available:"
	logliteral ""
	cmd /c dir /b /a:-d "$staging"
	logliteral ""
	logliteral " Enter the filename to restore from exactly as it appears above."
	logliteral " (Note: archived backup sets are not shown)"
	logliteral ""


	$BACKUP_FILE = ""
	set /p BACKUP_FILE=Filename: 
	if ($BACKUP_FILE -eq "exit") {break}

	logliteral ""
	# Make sure user didn't fat-finger the file name
	if (test-path -literalpath "$staging\$BACKUP_FILE") {
		logliteral "  ! ERROR: That file wasn't found. Check your typing and try again." red
		goto restore_menu
	}

	$CHOICE = "y"
	logliteral "  ! Selected file '$BACKUP_FILE'"
	logliteral ""
	set /p CHOICE=Is this correct [y]?: 
		if not %CHOICE%==y echo  Going back to menu... && goto restore_menu
	""
	echo  Great. Press any key to get started.
	pause >NUL
	echo  ! Starting restoration at %TIME% on $CUR_DATE
	write-output   This might take a while, be patient...

	# Test if we're doing a full or differential restore.
	if ($BACKUP_FILE -eq "$backup_prefix_full.7z") {$RESTORE_TYPE = "full"}
	if (!($BACKUP_FILE -eq "$backup_prefix_full.7z")) {$RESTORE_TYPE = "differential"}

	# Detect our backup type and inform the user
	if ($RESTORE_TYPE -eq "differential") {
		log " Restoring from differential backup. Will unpack full backup then differential."
	}
	if ($RESTORE_TYPE -eq "full") {
		log "   Restoring from full backup."
		log "   Unpacking full backup..."
	}

	
	# Unpack full backup
	logliteral ""
	logliteral " ------- [ Beginning of 7zip output ] ------- " blue
		& $sevenzip x "$staging\$backup_prefix_full.7z" -y -o"$staging\$backup_prefix_restore\" >> $LOGPATH\$LOGFILE
	logliteral " ------- [    End of 7zip output    ] ------- " blue

	# Report on the unpack
	if ($? -eq "True") {
		log "   Full backup unpacked successfully."
	} else { 
		$JOB_ERROR = "1"
		log " ! Full backup unpacked with errors." yellow
	}

	# Unpack differential file if requested
	if ($RESTORE_TYPE - eq "differential") {
		logliteral ""
		log "   Unpacking differential file $BACKUP_FILE..."
		logliteral ""
		logliteral " ------- [ Beginning of 7zip output ] ------- " blue
			& $sevenzip x "$staging\$BACKUP_FILE" -aoa -y -o"$staging\$backup_prefix_restore\" >> $LOGPATH\$LOGFILE
		logliteral " ------- [    End of 7zip output    ] ------- " blue
		logliteral ""

		# Report on the unpack
		if ($? -eq "True") {			log "   Differential backup unpacked successfully."
			} else {
			$JOB_ERROR = "1"
			log " ! Differential backup unpacked with errors." yellow
		}
	}
} # // RESTORE FROM BACKUP: end


# // ARCHIVE BACKUPS: begin
if ( $JOB_TYPE -eq "archive" ) { 
	log "   Archiving current backup set to $destination\$CUR_DATE_$backup_prefix_set."

	# Final destination: Make directory, move files
	pushd "$destination"
	mkdir $CUR_DATE_$backup_prefix_set 
	move /Y *.* $CUR_DATE_$backup_prefix_set 
	popd
	log "   Deleting all copies in the staging area..."
	# Staging area: Delete old files
	del /Q /F "$staging\*.7z"
	logliteral ""

	# Report
	logliteral ""
	log "   Backup set archived. All unarchived files in staging area were deleted."
	logliteral ""
} # // ARCHIVE BACKUPS: end


# // PURGE BACKUPS: begin
if ( $JOB_TYPE -eq "purge" ) {

	logliteral " CURRENT BACKUP SETS:"
	""
	logliteral " IN STAGING          : ($staging)"
	logliteral " ---------------------"
	dir /B /A:D "$staging"
	""
	""
	logliteral " IN LONG-TERM STORAGE: ($destination)"
	logliteral " ---------------------"
	dir /B /A:D "$destination"
	""
	set DAYS=180
	logliteral " Delete backup sets older than how many days? (you will be prompted for confirmation)
	set /p DAYS=[%DAYS%]?: 
	if %DAYS%==exit goto end
	""
	# Tell user what will happen
	logliteral " THESE BACKUP SETS WILL BE DELETED:"
	logliteral " ----------------------------------"
	# List files that would match. 
	# We have to use PushD to get around forfiles.exe not using UNC paths. pushd automatically assigns the next free drive letter
	logliteral " From staging:"
	pushd "$staging"
	FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 2>NUL
	popd
	""
	logliteral " From long-term storage:"
	pushd "$destination"
	FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 2>NUL
	popd
	""
	set HMMM=n
	set /p HMMM=Is this okay [%HMMM%]?: 
	if /i %HMMM%==n "" && echo Canceled. Returning to menu. && goto cleanup_archives_list2
	if %DAYS%==exit goto end
	""
	set CHOICE=n
	set /p CHOICE=Are you absolutely sure [%CHOICE%]?: 
	if not %CHOICE%==y "" && echo Canceled. Returning to menu. && goto cleanup_archives_list2

	log "   Deleting backup sets that are older than %DAYS% days..."

	# This cleans out the staging area.
	# First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
	pushd "$staging"
	FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 
	FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
	popd

	# This cleans out the destination / long-term storage area.
	# First FORFILES command tells the logfile what will get deleted. Second command actually deletes.
	pushd "$destination"
	FORFILES /D -%DAYS% /C "cmd /c IF @isdir == TRUE echo @path" 
	FORFILES /S /D -%DAYS% /C "cmd /c IF @isdir == TRUE rmdir /S /Q @path"
	popd

	# Report results
	if ( $? -eq "True" ) {
		log "   Cleanup completed successfully."
	} else {
		$JOB_ERROR = "1"
		log " ! Cleanup completed with errors." yellow
	}
	
} # // PURGE BACKUPS: done






#####################
# COMPLETION REPORT #
#####################
# One of these displays if the operation was a restore operation
if ($RESTORE_TYPE -eq "full"){ log "   Restored full backup to $staging\$backup_prefix" }
if ($RESTORE_TYPE -eq "differential"){ log "   Restored full and differential backup to $staging\$backup_prefix" }

log "$SCRIPT_NAME complete." green
if ($JOB_ERROR -eq "1") { log " ! Note: Script exited with errors. Maybe check the log." yellow }

# Clean up our temp exclude file
if exist %TEMP%\DEATH_BY_HAMSTERS.txt del /F /Q %TEMP%\DEATH_BY_HAMSTERS.txt

# Close the main() function. End of the script
}




#############
# FUNCTIONS #
#############
function log($message, $color)
{
	if ($color -eq $null) {$color = "gray"}
	#console
	write-host (get-date -f "yyyy-mm-dd hh:mm:ss") -n -f darkgray; write-host "$message" -f $color
	#log
	(get-date -f "yyyy-mm-dd hh:mm:ss") +"$message" | out-file -Filepath $logfile -append
}

# Literal log (no date/time prefix)
function logliteral($message, $color)
{
	if ($color -eq $null) {$color = "gray"}
	#console
	write-host "$message" -f $color
	#log
	"$message" | out-file -Filepath $logfile -append
}


# call the main script
main
