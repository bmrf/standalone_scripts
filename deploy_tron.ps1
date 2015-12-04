<#
Purpose:       Deploys Tron
Requirements:  1. Expects Master Copy directory to look like this:
					\resources
					tron.bat
					changelog-vX.Y.X-updated-yyyy-mm-dd.txt
					Instructions -- YES ACTUALLY READ THEM.txt
               
               2. Expects master copy tron.bat to have accurate "set SCRIPT_DATE=yyyy-mm-dd" and "set SCRIPT_VERSION=x.y.z" strings because these are parsed and used to name everything correctly
               
               3. Expects seed server directory structure to look like this:
                  
					\btsync\tron
						\tron
							- changelog-vX.Y.Z-updated-YYYY-MM-DD.txt
							- Instructions -- YES ACTUALLY READ THEM.txt
							- Tron.bat
						\integrity_verification
							- checksums.txt
							- checksums.txt.asc
							- vocatus-public-key.asc
					
					\syncthing\tron
						\tron
							- changelog-vX.Y.Z-updated-YYYY-MM-DD.txt
							- Instructions -- YES ACTUALLY READ THEM.txt
							- Tron.bat
						\integrity_verification
							- checksums.txt
							- checksums.txt.asc
							- vocatus-public-key.asc

Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
Version:       1.3.1 / Move "Are you sure?" dialog to after sanity checks; this way when we see the dialog we know all sanity checks passed
               1.3.0 ! Fix bug where we appended .UPLOADING to the new binary pack too soon
                     + Add automatic PGP signature verification of new Tron binary pack
               1.2.9 + Add additional checks to look for Tron's stage-specific sub-scripts (Tron modularization project)
               1.2.8 * Add automatic PGP signature verification of Tron's internal checksums.txt
               1.2.7 * Add ability to handle two seed directories (one for BT Sync and one for SyncThing)
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
7. Fetches sha256sums.txt from repo and updates it with sha256sum of the new binary pack
8. Deletes current version from repo server; uploads .exe pack and sha256sums.txt to repo server; cleans up residual temp files; notifies of completion and advises to restart BT Sync
9. Builds FTP upload script
10. Uploads via FTP
11. Cleans up (deletes temp files used)
#>



#############
# VARIABLES # ---------------------- Set these to match your environment ------------------------ #
#############
# Rules for variables:
#  * NO quotes!                    (bad:  "c:\directory\path"       )
#  * NO trailing slashes on paths! (bad:   c:\directory\            )
#  * Spaces are okay               (okay:  c:\my folder\with spaces )
#  * Network paths are okay        (okay:  \\server\share name      )
param (
	# Logging information
	[string]$logpath = "$env:systemdrive\Logs",
	[string]$logfile = "tron_deployment_script.log",

	# Path to 7z.exe
	[string]$SevenZip = "C:\Program Files\7-Zip\7z.exe",

	# Path to WinSCP.com
	[string]$WinSCP = "R:\applications\WinSCP\WinSCP.com",

	# Path to hashdeep64.exe
	[string]$HashDeep64 = "$env:SystemRoot\syswow64\hashdeep64.exe",            # e.g. "$env:SystemRoot\syswow64\hashdeep64.exe"

	# Path to gpg.exe (for signing)
	[string]$gpg = "${env:ProgramFiles(x86)}\GNU\GnuPG\pub\gpg.exe",            # e.g. "$env:ProgramFiles\gpg4win\bin\gpg.exe"

	# Master copy of Tron. Directory path, not tron.bat
	[string]$MasterCopy = "r:\utilities\security\cleanup-repair\tron",          # e.g. "r:\utilities\security\cleanup-repair\tron"

	# Server holding the Tron seed directories
	[string]$SeedServer = "\\thebrain",                                         # e.g. "\\thebrain"

	# Seeding subdirectories containing \tron and \integrity_verification directories
	# No leading or trailing slashes
	[string]$SeedFolderBTS = "downloads\seeders\btsync\tron",                   # e.g. "downloads\seeders\tron\btsync"
	[string]$SeedFolderST = "downloads\seeders\syncthing\tron",                 # e.g. "downloads\seeders\tron\syncthing"

	# Static pack storage location. RELATIVE path from root on the
	# local deployment server. Where we stash the compiled .exe
	# after uploading to the repo server.
	# No leading or trailing slashes
	[string]$StaticPackStorageLocation = "downloads\seeders\static_packs",      # e.g. "downloads\seeders\static packs"

	# Repository server where we'll fetch sha256sums.txt from
	[string]$Repo_URL = "http://bmrf.org/repos/tron",                           # e.g. "http://bmrf.org/repos/tron"

	# FTP information for where we'll upload the final sha256sums.txt and "Tron vX.Y.Z (yyyy-mm-dd).exe" file to
	[string]$Repo_FTP_Host = "bmrf.org",                                        # e.g. "bmrf.org"
	[string]$Repo_FTP_Username = "zzzz",
	[string]$Repo_FTP_Password = "zzzz",
	[string]$Repo_FTP_DepositPath = "/public_html/repos/tron/",                 # e.g. "/public_html/repos/tron/"

	# PGP key authentication information
	[string]$gpgPassphrase = "zzzz",
	[string]$gpgUsername = "zzzz"
)






# ----------------------------- Don't edit anything below this line ----------------------------- #






###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "1.3.1"
$SCRIPT_UPDATED = "2015-12-04"
$CUR_DATE=get-date -f "yyyy-MM-dd"

# Extract current release version number from seed server copy of tron.bat and stash it in $OldVersion
# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)
$OldVersion = gc $SeedServer\$SeedFolderBTS\tron\tron.bat -ea SilentlyContinue | Select-String -pattern "set SCRIPT_VERSION"
$OldVersion = "$OldVersion".Split("=")[1]

# Extract release date of current version from seed server copy of tron.bat and stash it in $OldDate
$OldDate = gc $SeedServer\$SeedFolderBTS\tron\tron.bat -ea SilentlyContinue | Select-String -pattern "set SCRIPT_DATE"
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

# Master copy: Test for existence of stage_0_prep.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_0_prep\stage_0_prep.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_0_prep.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_0_prep\stage_0_prep.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_1_tempclean.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_1_tempclean\stage_1_tempclean.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_1_tempclean.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_1_tempclean\stage_1_tempclean.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_2_de-bloat.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_2_de-bloat\stage_2_de-bloat.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_2_de-bloat.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_2_de-bloat\stage_2_de-bloat.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_3_disinfect.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_3_disinfect\stage_3_disinfect.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_3_disinfect.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_3_disinfect\stage_3_disinfect.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_4_repair.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_4_repair\stage_4_repair.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_4_repair.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_4_repair\stage_4_repair.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_5_patch.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_5_patch\stage_5_patch.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_5_patch.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_5_patch\stage_5_patch.bat"
	""
	write-host "         Check your paths and make sure all the required files"
	write-host "         exist in the appropriate locations."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Master copy: Test for existence of stage_6_optimize.bat inside the resources subfolder
if (!(test-path -literalpath $MasterCopy\tron\resources\stage_6_optimize\stage_6_optimize.bat)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find stage_6_optimize.bat at:"
	""
	write-host "         $MasterCopy\resources\stage_6_optimize\stage_6_optimize.bat"
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

# Master copy: Test for existence of the Instructions file
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

# Seed server: Test for existence of top level Tron folder (BT Sync)
if (!(test-path -literalpath $SeedServer\$SeedFolderBTS)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Tron BT Sync seed folder at:"
	""
	write-host "         $SeedServer\$SeedFolderBTS"
	""
	write-host "         Check your paths and make sure the deployment server is"
	write-host "         accessible and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of top level Tron folder (SyncThing)
if (!(test-path -literalpath $SeedServer\$SeedFolderST)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Tron SyncThing seed folder at:"
	""
	write-host "         $SeedServer\$SeedFolderST"
	""
	write-host "         Check your paths and make sure the deployment server is"
	write-host "         accessible and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of \tron\integrity_verification sub-folder (BT Sync)
if (!(test-path -literalpath $SeedServer\$SeedFolderBTS\integrity_verification)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the BT Sync integrity_verification folder at:"
	""
	write-host "         $SeedServer\$SeedFolderBTS\integrity_verification\"
	""
	write-host "         Check your paths and make sure you can reach the deployment server,"
	write-host "         you have write-access to the Tron seed folder, and that the"
	write-host "         \integrity_verification sub-folder exists. "
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of \tron\integrity_verification sub-folder (SyncThing)
if (!(test-path -literalpath $SeedServer\$SeedFolderST\integrity_verification)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the SyncThing integrity_verification folder at:"
	""
	write-host "         $SeedServer\$SeedFolderST\integrity_verification\"
	""
	write-host "         Check your paths and make sure you can reach the deployment server,"
	write-host "         you have write-access to the Tron seed folder, and that the"
	write-host "         \integrity_verification sub-folder exists. "
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of the public key (BT Sync)
if (!(test-path -literalpath $SeedServer\$SeedFolderBTS\integrity_verification\vocatus-public-key.asc)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the public key at:"
	""
	write-host "         $SeedServer\$SeedFolderBTS\integrity_verification\vocatus-public-key.asc"
	""
	write-host "         Check your paths and make sure you can reach the deployment server"
	write-host "         and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}

# Seed server: Test for existence of the public key (SyncThing)
if (!(test-path -literalpath $SeedServer\$SeedFolderST\integrity_verification\vocatus-public-key.asc)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the public key at:"
	""
	write-host "         $SeedServer\$SeedFolderST\integrity_verification\vocatus-public-key.asc"
	""
	write-host "         Check your paths and make sure you can reach the deployment server"
	write-host "         and that you have write-access to the Tron seed folder."
	""
	write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	break
}



# Are you sure?
""
write-host " About to replace Tron $OldVersion ($OldDate) with $NewVersion ($CUR_DATE)"
""
write-host " Are you sure?" -f red
""
Write-Host -n 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
""
clear




###########
# EXECUTE #
###########
# The rest of the script is wrapped in the "main" function. This is just so we can put the logging function at the bottom of the script instead of at the top
function main() {
log " Tron deployment script v$SCRIPT_VERSION" green


# JOB: Clear target area
log " Clearing target areas on local seed server..." green
	remove-item $SeedServer\$SeedFolderBTS\tron\* -force -recurse | out-null
	remove-item $SeedServer\$SeedFolderBTS\integrity_verification\*txt* -force -recurse | out-null
	remove-item $SeedServer\$SeedFolderST\tron\* -force -recurse | out-null
	remove-item $SeedServer\$SeedFolderST\integrity_verification\*txt* -force -recurse | out-null
log " Done" darkgreen


# JOB: Calculate hashes of every single file included in the \tron directory
log " Calculating hashes, please wait..." green
	pushd $MasterCopy
	del $env:temp\checksum* -force -recurse | out-null
	& $HashDeep64 -s -e -c sha256 -l -r .\ | Out-File $env:temp\checksums.txt -encoding ascii
	mv $env:temp\checksums.txt $MasterCopy\integrity_verification\checksums.txt -force
log " Done" darkgreen


# JOB: PGP sign the resulting checksums.txt then upload master directory to seed locations
log " PGP signing checksums.txt..." green
remove-item $MasterCopy\integrity_verification\checksums.txt.asc -force -recurse -ea SilentlyContinue | out-null
& $gpg --batch --yes --local-user $gpgUsername --passphrase $gpgPassphrase --armor --verbose --detach-sign $MasterCopy\integrity_verification\checksums.txt
while (1 -eq 1) {
	if (test-path $MasterCopy\integrity_verification\checksums.txt.asc) {
		log " Done" darkgreen
		break
	}
	# sleep before looking again
	start-sleep -s 2
}


# JOB: Verify PGP signature before FTP upload
log "   Verifying PGP signature of checksums.txt..." green
& $gpg --batch --yes --verbose --verify $MasterCopy\integrity_verification\checksums.txt.asc $MasterCopy\integrity_verification\checksums.txt
if ($? -eq "True") { 
	log "   Done" darkgreen
} else {
	log " ! There was a problem verifying the signature!" red
}


# JOB: Upload from master copy to seed server directories
log "   Master copy is gold. Copying from master to local seed locations..." green
log "   Loading BT Sync seed..." green
	cp $MasterCopy\* $SeedServer\$SeedFolderBTS\ -recurse -force
log "   Done" darkgreen
log "   Loading SyncThing seed..." green
	cp $MasterCopy\* $SeedServer\$SeedFolderST\ -recurse -force
log "   Done" darkgreen
log "   Done, seed server loaded." darkgreen


# Notify that we're done loading the seed server and are starting deployment to the master repo
log "   Updating master repo (remote)..." green


# JOB: Pack Tron to into a binary pack (.exe archive) using 7z and stash it in the TEMP directory. 
# Create the file name using the new version number extracted from tron.bat and exclude any 
# files with "sync" in the title (these are BT Sync hidden files, we don't need to pack them
log "   Building binary pack, please wait..." green
	& "$SevenZip" a -sfx "$env:temp\$NewBinary" ".\*" -x!*sync* -x!*ini* >> $LOGPATH\$LOGFILE
log "   Done" darkgreen


# JOB: Background upload the binary pack to the static pack folder on the local seed server
log "   Starting background upload of $NewBinary to $SeedServer\$StaticPackStorageLocation..." green
start-job -name tron_copy_pack_to_seed_server -scriptblock {cp "$env:temp\$($args[0])" "$($args[1])\$($args[2])" -force} -ArgumentList $NewBinary, $SeedServer, $StaticPackStorageLocation

	
# JOB: Fetch sha256sums.txt from the repo for updating
log "   Fetching repo copy of sha256sums.txt to update..." green
	Invoke-WebRequest $Repo_URL/sha256sums.txt -outfile $env:temp\sha256sums.txt
log "   Done" darkgreen


# JOB: Calculate SHA256 hash of newly-created binary pack and append it to sha256sums.txt
log "   Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." green
	pushd $env:temp
	# First hash the file
	& $HashDeep64 -s -e -l -c sha256 "Tron v$NewVersion ($CUR_DATE).exe" | Out-File .\sha256sums_TEMP.txt -Encoding utf8
	# Strip out the annoying hashdeep header
	gc .\sha256sums_TEMP.txt | Where-Object {$_ -notmatch '#'} | where-object {$_ -notmatch '%'} | sc .\sha256sums_TEMP2.txt
	# Strip out blank lines and trailing spaces (not needed?)
	#(gc .\sha256sums_TEMP2.txt) | ? {$_.trim() -ne "" } | sc .\sha256sums_TEMP2.txt
	# Append the result to the sha256sums.txt we pulled from the repo
	gc .\sha256sums_TEMP2.txt | out-file .\sha256sums.txt -encoding utf8 -append
	# Rename the file to prepare it for uploading
	ren "$env:temp\$NewBinary" "$env:temp\$NewBinary.UPLOADING"
	popd
log "   Done" darkgreen


# JOB: PGP sign sha256sums.txt
log "   PGP signing sha256sums.txt..." green
remove-item $env:temp\sha256sums.txt.asc -force -recurse -ea SilentlyContinue | out-null
& $gpg --batch --yes --local-user $gpgUsername --passphrase $gpgPassphrase --armor --verbose --detach-sign $env:temp\sha256sums.txt
while (1 -eq 1) {
	if (test-path $env:temp\sha256sums.txt.asc) {
		log "   Done" darkgreen
		break
	}
	# sleep before looking again
	start-sleep -s 2
}


# JOB: Verify PGP signature before FTP upload
log "   Verifying PGP signature of sha256sums.txt..." green
& $gpg --batch --yes --verbose --verify $env:temp\sha256sums.txt.asc $env:temp\sha256sums.txt
if ($? -eq "True") { 
	log "   Done" darkgreen
} else {
	log " ! There was a problem verifying the signature!" red
}


# JOB: Build FTP upload script
# Tron exe will have "UPLOADING" appended to its name until upload is complete
log "   Building FTP deployment script..." green

"option batch abort" | Out-File $env:temp\deploy_tron_ftp_script.txt -encoding ascii
"option confirm off" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"open ftp://$Repo_FTP_Username`:$Repo_FTP_Password@$Repo_FTP_Host" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"cd $Repo_FTP_DepositPath" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm *.exe" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm sha256sums*" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=binary `"$env:temp\$NewBinary.UPLOADING`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=binary `"$env:temp\sha256sums.txt`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=ascii `"$env:temp\sha256sums.txt.asc`""
write-output "rename "$NewBinary.UPLOADING" "$NewBinary"" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"exit" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii

log "   Done" darkgreen


# JOB: Upload binary pack and hash files to FTP repo server
# Get in TEMP directory and call WinSCP to run the script we just created
log "   Uploading $NewBinary to $Repo_FTP_Host..." green
	pushd $env:temp
	& $WinSCP /script=.\deploy_tron_ftp_script.txt
	popd
	Write-Host ""
log "   Done" darkgreen


# JOB: Clean up after ourselves
log "   Cleaning up..." green
	remove-item $env:temp\sha256sums* -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\$NewBinary* -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\deploy_tron_ftp_script.txt -force -recurse -ea SilentlyContinue | out-null
	# Rename the file we uploaded to the static pack storage location earlier
	mv $SeedServer\$StaticPackStorageLocation\$NewBinary.UPLOADING $SeedServer\$StaticPackStorageLocation\$NewBinary -force
	# Remove our background upload job from the job list
	get-job | remove-job
log "   Done" darkgreen



############
# Finished #
############
log "   Done " green
log "                    Version deployed:                  v$NewVersion ($CUR_DATE)"
log "                    Version replaced:                  v$OldVersion ($OldDate)"
log "                    Local seed server:                 $SeedServer"
log "                    Local seed directory (BT Sync):    $SeedFolderBTS"
log "                    Local seed directory (SyncThing):  $SeedFolderST"
log "                    Local static pack storage:         $StaticPackStorageLocation"
log "                    Remote repo host:                  $Repo_FTP_Host"
log "                    Remote repo upload path:           $Repo_FTP_Host/$Repo_FTP_DepositPath"
log "                    Log file:                          $LOGPATH\$LOGFILE"
log "                                                       Notify mirror ops and post release to Reddit" blue

write-output "Press any key to continue..."; $HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null

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
	#(get-date -f "yyyy-mm-dd hh:mm:ss") +"$message" | out-file -Filepath "$logpath\$logfile" -append
	(get-date -f "yyyy-mm-dd hh:mm:ss") +"$message" | out-file -Filepath "C:\logs\tron_deployment_script.log" -append
}


# call the main script
main
