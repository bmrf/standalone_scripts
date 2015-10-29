<#
Purpose:       Deploys Tron
Requirements:  1. Expects Master Copy directory to contain the following files:
                - \resources
                - tron.bat
                - changelog-vX.Y.X-updated-yyyy-mm-dd.txt
                - Instructions -- YES ACTUALLY READ THEM.txt
               
               2. Expects master tron.bat to have accurate "set VERSION=yyyy-mm-dd" string because this is parsed and used to name everything correctly
               
               3. Expects seed server directory structure to look like this:
                  
                 \tron\btsync
                     \tron
                       - changelog-vX.Y.Z-updated-YYYY-MM-DD.txt
                       - Instructions - YES ACTUALLY READ THEM.txt
                       - Tron.bat
                     \integrity_verification
                       - checksums.txt
                       - checksums.txt.asc
                       - vocatus-public-key.asc

Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
Version:       1.2.7 * Add ability to handle two seed directories (one for BT Sync and one for SyncThing)
                     * Add reporting of the date of the version we're replacing
               1.2.6 / Disable all use of PortablePGP since we're reverting to using gpg4win
               1.2.5 + Add auto-killing of PortablePGP window after checksums.txt signature file appears
               1.2.4 ! Fix binary pack hash calculation by removing ".\" prefix on new binary path, which was breaking the update checker in Tron.bat
               1.2.3 / Suppress 7-Zip output (redirect to log file)
               1.2.2 + Add automatic launching of PortablePGP.exe to signing portion, along with associated $PortablePGP variable
               1.2.1 / Update to account for changed Tron sub-folder and new integrity_verification directory
                     + Add $OldVersion variable and associated code to display the version we replaced
               1.2.0 + Replace built-in Windows FTP client with WinSCP and add associated $WinSCP variable and checks
               1.1.0 * Add calculation of SHA256 sum of the binary pack and upload of respective sha256sums.txt to prepare for moving the Tron update checker away from using MD5 sums
               1.0.0 . Initial write

Behavior/steps:
1. Deletes content from seed server
2. Calculates sha256 hashes of all files in \tron
3. PGP-signs checksums.txt
4. Creates binary pack 
5. PGP-signs the binary pack
6. Background uploads the binary pack to the seed server
7. Fetches sha256sums.txt from repo and updates it with sha256sum of binary pack
8. Deletes current version from repo server; uploads .exe pack and sha256sums.txt to repo server; cleans up residual temp files; notifies of completion and advises to restart BT Sync
9. Builds FTP upload script
#>

# Are you sure?
""
write-host "Did you stop BT Sync?" -f red
""
Write-Host -n 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
""
clear


#############
# VARIABLES # ---------------------- Set these to match your environment ------------------------ #
#############
# Rules for variables:
#  * NO quotes!                    (bad:  "c:\directory\path"       )
#  * NO trailing slashes on paths! (bad:   c:\directory\            )
#  * Spaces are okay               (okay:  c:\my folder\with spaces )
#  * Network paths are okay        (okay:  \\server\share name      )

# Logging information
$logpath = $env:systemdrive + "\Logs"
$logfile = "tron_deployment_script.log"

# Path to 7z.exe
$SevenZip = "C:\Program Files\7-Zip\7z.exe"

# Path to WinSCP.com
$WinSCP = "R:\applications\WinSCP\WinSCP.com"

# Path to hashdeep64.exe
$HashDeep64 = "$env:SystemRoot\syswow64\hashdeep64.exe"             # e.g. "$env:SystemRoot\syswow64\hashdeep64.exe"

# Path to gpg.exe (for signing)
$gpg = "$env:ProgramFiles\gpg4win\bin\gpg.exe"						# e.g. "$env:ProgramFiles\gpg4win\bin\gpg.exe"

# Master copy of Tron. Directory path, not tron.bat
$MasterCopy = "r:\utilities\security\cleanup-repair\tron"           # e.g. "r:\utilities\security\cleanup-repair\tron"

# Server holding the Tron seed directories
$SeedServer = "\\thebrain"                                          # e.g. "\\thebrain"

# Seeding subdirectories containing \tron and \integrity_verification directories
# No leading or trailing slashes
$SeedFolderBTS = "downloads\seeders\tron\btsync"                    # e.g. "downloads\seeders\tron\btsync"
$SeedFolderST = "downloads\seeders\tron\syncthing"                  # e.g. "downloads\seeders\tron\syncthing"

# Static pack storage location. RELATIVE path from root on the
# local deployment server. Where we stash the compiled .exe
# after uploading to the repo server.
# No leading or trailing slashes
$StaticPackStorageLocation = "downloads\seeders\static packs"       # e.g. "downloads\seeders\static packs"

# Repository server where we'll fetch sha256sums.txt from
$Repo_URL = "http://bmrf.org/repos/tron"                            # e.g. "http://bmrf.org/repos/tron"

# FTP information for where we'll upload the final sha256sums.txt and "Tron vX.Y.Z (yyyy-mm-dd).exe" file to
$Repo_FTP_Host = "webserver-address-here"                            # e.g. "bmrf.org"
$Repo_FTP_Username = "username-here"
$Repo_FTP_Password = "password-here"
$Repo_FTP_DepositPath = "/path/to/public_html/"                      # e.g. "/public_html/repos/tron/"





# ----------------------------- Don't edit anything below this line ----------------------------- #





###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "1.2.7"
$SCRIPT_UPDATED = "2015-10-29"
$CUR_DATE=get-date -f "yyyy-MM-dd"

# Extract current release version number from seed server copy of tron.bat and stash it in $OldVersion
# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)
$OldVersion = gc $SeedServer\$SeedFolderBTS\tron.bat -ea SilentlyContinue | Select-String -pattern "set SCRIPT_VERSION"
$OldVersion = "$OldVersion".Split("=")[1]

# Extract release date of current version from seed server copy of tron.bat and stash it in $OldDate
$OldDate = gc $SeedServer\$SeedFolderBTS\tron.bat -ea SilentlyContinue | Select-String -pattern "set SCRIPT_DATE"
$OldDate = "$OldDate".Split("=")[1]

# Extract version number from master's tron.bat and stash it in $NewVersion, then calculate and store the full .exe name for the new binary we'll be building
# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)
$NewVersion = gc $MasterCopy\tron\Tron.bat -ea SilentlyContinue | Select-String -pattern "set SCRIPT_VERSION"
$NewVersion = "$NewVersion".Split("=")[1]
$NewBinary = "Tron v$NewVersion ($CUR_DATE).exe"


#################
# SANITY CHECKS #
#################
# Local machine: Test for existence of 7-Zip
if (!(test-path -literalpath $SevenZip)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find 7z.exe at:"
	""
	write-host "         $SevenZip"
	""
	write-host "         Edit this script and change the `$SevenZip variable to"
	write-host "         the correct location."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Local machine: Test for existence of WinSCP.com
if (!(test-path -literalpath $WinSCP)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find WinSCP.com at:"
	""
	write-host "         $WinSCP"
	""
	write-host "         Edit this script and change the `$WinSCP variable to point"
	write-host "         to the correct location."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of Tron's \resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find Tron's \resources subfolder at:"
	""
	write-host "         $MasterCopy\resources"
	""
	write-host "         Check your paths."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of tron.bat inside the tron subfolder
if (!(test-path -literalpath $MasterCopy\tron\tron.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find tron.bat at:"
	""
	write-host "         $MasterCopy\tron.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of the changelog
if (!(test-path -literalpath $MasterCopy\tron\changelog-v$NewVersion-updated-$CUR_DATE.txt)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the changelog at:"
	""
	write-host "         $MasterCopy\changelog-v$NewVersion-updated-$CUR_DATE.txt"
	""
	write-host "         Check your paths and make sure all the required files exist in the"
	write-host "         appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy:  Test for existence of the Instructions file
if (!(test-path $MasterCopy\tron\Instructions*.txt)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Instructions file at:"
	""
	write-host "         $MasterCopy\Instructions*.txt"
	""
	write-host "         Check your paths and make sure all the required files exist in the"
	write-host "         appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of top level Tron folder
if (!(test-path -literalpath $SeedServer\$SeedFolder)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Tron seed folder at:"
	""
	write-host "         $SeedServer\$SeedFolder"
	""
	write-host "         Check your paths and make sure the deployment server is"
	write-host "         accessible and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of \tron\integrity_verification sub-folder
if (!(test-path -literalpath $SeedServer\$SeedFolder\integrity_verification)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the integrity_verification folder at:"
	""
	write-host "         $SeedServer\$SeedFolder\integrity_verification\"
	""
	write-host "         Check your paths and make sure you can reach the deployment server,"
	write-host "         you have write-access to the Tron seed folder, and that the"
	write-host "         \integrity_verification sub-folder exists. "
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of the public key
if (!(test-path -literalpath $SeedServer\$SeedFolder\integrity_verification\vocatus-public-key.asc)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the public key at:"
	""
	write-host "         $SeedServer\$SeedFolder\integrity_verification\vocatus-public-key.asc"
	""
	write-host "         Check your paths and make sure you can reach the deployment server"
	write-host "         and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}


###########
# EXECUTE #
###########
# The rest of the script is wrapped in the "main" function. This is just so we can put the logging function at the bottom of the script instead of at the top
function main() {
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Tron deployment script v$SCRIPT_VERSION" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Tron deployment script v$SCRIPT_VERSION" -f green

# JOB: Clear target area
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Clearing target area on seed server..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Clearing target area on seed server..." -f green
	remove-item $SeedServer\$SeedFolder\tron\* -force -recurse | out-null
	remove-item $SeedServer\$SeedFolder\integrity_verification\*txt* -force -recurse | out-null
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: Calculate hashes of every single file included in the \tron directory
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Calculating hashes, please wait..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Calculating hashes, please wait..." -f green
	pushd $MasterCopy
	del $env:temp\checksum* -force -recurse | out-null
	& $HashDeep64 -s -e -c sha256 -l -r .\ | Out-File $env:temp\checksums.txt -encoding ascii
	mv $env:temp\checksums.txt $MasterCopy\integrity_verification\checksums.txt -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: PGP sign the resulting checksums.txt then upload master directory to seed locations
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " PGP signing checksums.txt..." -f green
remove-item $MasterCopy\integrity_verification\checksums.txt.asc -force -recurse -ea SilentlyContinue | out-null

#& $gpg --local-user vocatus.gate --armor --detach-sign $MasterCopy\integrity_verification\checksums.txt

while (1 -eq 1) {
	if (test-path $MasterCopy\integrity_verification\checksums.txt.asc) {
		write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen
		"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
		break
	}
	# sleep for 3 seconds before looking again
	start-sleep -s 3
}


# JOB: Upload from master copy to seed server directories
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Master copy is gold. Copying from master to seed locations..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Master copy is gold. Copying from master to seed locations..." -f green
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Loading BT Sync seed..." -f green
	cp $MasterCopy\* $SeedServer\$SeedFolderBTS\ -recurse -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Loading SyncThing seed..." -f green
	cp $MasterCopy\* $SeedServer\$SeedFolderST\ -recurse -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# Notify that we're done loading the seed server and are starting deployment to the master repo
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Seed server loaded. Updating master repo..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host "  Seed server loaded. Updating master repo..." -f green


# JOB: Pack Tron to into a binary pack (.exe archive) using 7z and stash it in the TEMP directory. 
# Create the file name using the new version number extracted from tron.bat and exclude any 
# files with "sync" in the title (these are BT Sync hidden files, we don't need to pack them
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Building binary pack, please wait..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Building binary pack, please wait..." -f green
	& "$SevenZip" a -sfx "$env:temp\$NewBinary" ".\*" -x!*sync* -x!*ini* >> $LOGPATH\$LOGFILE
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: Background upload the binary pack to the static pack folder on the local seed server
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Background uploading $NewBinary to $SeedServer\$StaticPackStorageLocation..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Background uploading $NewBinary to $SeedServer\$StaticPackStorageLocation..." -f green
start-job -name tron_move_pack_to_seed_server -scriptblock {mv $env:temp\$NewBinary $SeedServer\$StaticPackStorageLocation -force}

	
# JOB: Fetch sha256sums.txt from the repo for updating
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Fetching repo copy of sha256sums.txt to update..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Fetching repo copy of sha256sums.txt to update..." -f green
	Invoke-WebRequest $Repo_URL/sha256sums.txt -outfile $env:temp\sha256sums.txt
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: Calculate SHA256 hash of newly-created binary pack and append it to sha256sums.txt
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." -f green
	pushd $env:temp
	# First hash the file
	& $HashDeep64 -s -e -l -c sha256 "Tron v$NewVersion ($CUR_DATE).exe" | Out-File .\sha256sums_TEMP.txt -Encoding utf8
	# Strip out the annoying hashdeep header
	gc .\sha256sums_TEMP.txt | Where-Object {$_ -notmatch '#'} | where-object {$_ -notmatch '%'} | sc .\sha256sums_TEMP2.txt
	# Strip out blank lines and trailing spaces (not needed?)
	#(gc .\sha256sums_TEMP2.txt) | ? {$_.trim() -ne "" } | sc .\sha256sums_TEMP2.txt
	# Append the result to the sha256sums.txt we pulled from the repo
	gc .\sha256sums_TEMP2.txt | out-file .\sha256sums.txt -encoding utf8 -append
	popd
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: PGP sign sha256sums.txt before FTP upload
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " PGP signing sha256sums.txt..." -f green
remove-item $env:temp\sha256sums.txt.asc -force -recurse -ea SilentlyContinue | out-null
#& $gpg --local-user vocatus.gate --armor --detach-sign $env:temp\sha256sums.txt
while (1 -eq 1) {
	if (test-path $env:temp\sha256sums.txt.asc) {
		write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen
		"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
		break
	}
	# otherwise sleep for 5 seconds before looking again
	start-sleep -s 5
}


# JOB: Build FTP upload script
# Tron exe will have "UPLOADING" appended to its name until upload is complete
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Building FTP deployment script..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Building FTP deployment script..." -f green
"option batch abort" | Out-File $env:temp\deploy_tron_ftp_script.txt -encoding ascii
"option confirm off" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"open ftp://$Repo_FTP_Username`:$Repo_FTP_Password@$Repo_FTP_Host" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"cd $Repo_FTP_DepositPath" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm *.exe" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm sha256sums*" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=binary `"$env:temp\$NewBinary.UPLOADING`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=ascii `"$env:temp\sha256sums.txt`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=ascii `"$env:temp\sha256sums.txt.asc`""
"mv $NewBinary.UPLOADING $NewBinary" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"exit" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: Upload binary pack and hash files to FTP repo server
# Get in TEMP directory and call WinSCP to run the script we just created
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Uploading $NewBinary to $Repo_FTP_Host..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Uploading $NewBinary to $Repo_FTP_Host..." -f green
	pushd $env:temp
	& $WinSCP /script=.\deploy_tron_ftp_script.txt
	popd
	Write-Host ""
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen


# JOB: Clean up after ourselves
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Cleaning up..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Cleaning up..." -f green
	remove-item $env:temp\sha256sums* -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\$NewBinary -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\deploy_tron_ftp_script.txt -force -recurse -ea SilentlyContinue | out-null
	# Remove our background upload job from the job list
	get-job | remove-job
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n; write-host " Done" -f darkgreen



############
# Finished #
############
log " Done " -f green
log "                    Version deployed:                  v$NewVersion ($CUR_DATE)"
log "                    Version replaced:                  v$OldVersion ($OldDate)"
log "                    Local seed server:                 $SeedServer"
log "                    Local seed directory (BT Sync):    $SeedFolderBTS"
log "                    Local seed directory (SyncThing):  $SeedFolderST"
log "                    Local static pack storage:         $StaticPackStorageLocation"
log "                    Remote repo host:                  $Repo_FTP_Host"
log "                    Remote repo upload path:           $Repo_FTP_Host/$Repo_FTP_DepositPath"
log "                    Log file:                          $LOGPATH\$LOGFILE"
log "                                                       Notify mirror ops and post release to Reddit" -f blue

write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null

# Close the main() function. End of the script
}






#############
# FUNCTIONS #
#############
function log($message, $color)
{
	if ($Color -eq $null) {$color = "gray"}
	#console
	write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host "$message" -f $color
	#log
	"$CUR_DATE "+ $(get-date -f hh:mm:ss) + "$message" | out-file -Filepath $logfile -append
}


# call the main script
main
