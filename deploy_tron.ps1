<#
Purpose:       Deploys Tron
Requirements:  1. Expects Master Copy directory to contain the following files:
                - \resources
                - Tron.bat
                - changelog-vX.Y.X-updated-yyyy-mm-dd.txt
                - Instructions -- YES ACTUALLY READ THEM.txt
               
               2. Expects master copy of Tron.bat to have accurate "set VERSION=yyyy-mm-dd" string because this is parsed and used to name everything correctly
               
               3. Expects seed server directory structure to look like this:
                  
                 \tron
                     \tron
                       - changelog-vX.Y.Z-updated-YYYY-MM-DD.txt
                       - Instructions - YES ACTUALLY READ THEM.txt
                       - Tron.bat
                     \integrity_verification
                       - checksums.txt
                       - checksums.txt.sig
                       - vocatus-public-key.asc

Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x07d1490f82a211a2
Version:       1.2.1 / Update to account for changed Tron sub-folder and new integrity_verification directory
                     + Add $OldVersion variable and associated code to display the version we replaced
               1.2.0 + Replace built-in Windows FTP client with WinSCP and add associated $WinSCP variable and checks
               1.1.0 * Add calculation of SHA256 sum of the binary pack and upload of respective sha256sums.txt to prepare for moving the Tron update checker away from using MD5 sums
               1.0.0 . Initial write

Behavior:      Deletes content from seed server; uploads from Master Copy --> seed server; checksums everything, waits for GPG signature, packs files into .exe archive with appropriate version/name; fetches md5sums.txt from repo; checksums .exe pack file; updates md5sums.txt with new hash; deletes current version from repo server; uploads .exe pack and md5sums.txt to repo server; uploads .exe pack to seed server static store; cleans up residual temp files; notifies of completion and advises to restart BT Sync
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

# Path to hashdeep64.exe and md5sum.exe
$HashDeep64 = "$env:SystemRoot\syswow64\hashdeep64.exe"             # e.g. "$env:SystemRoot\syswow64\hashdeep64.exe"
$md5sum = "$env:SystemRoot\syswow64\md5sum.exe"                     # e.g. "$env:SystemRoot\syswow64\md5sum.exe"

# Master copy of Tron. Path to folder, not tron.bat
$MasterCopy = "r:\utilities\security\cleanup-repair\tron"           # e.g. "r:\utilities\security\cleanup-repair\tron"

# Server holding the Tron seed folder
$SeedServer = "\\thebrain"                                          # e.g. "\\thebrain"

# Subfolder containing Tron meta files (changelog, checksums.txt, etc)
# No leading or trailing slashes
$SeedFolder = "downloads\seeders\tron"                              # e.g. "downloads\seeders\Tron"

# Static pack storage location. Relative path on the local
# deployment server. Where we stash the compiled .exe after 
# uploading to the repo server.
# No leading or trailing slashes
$StaticPackStorageLocation = "downloads\seeders\static packs"       # e.g. "downloads\seeders\static packs"

# Repository server where we'll fetch md5sums.txt and sha256sums.txt from
$Repo_URL = "http://bmrf.org/repos/tron"                            # e.g. "http://bmrf.org/repos/tron"


# FTP information for where we'll upload the final md5sums.txt and "Tron vX.Y.Z (yyyy-mm-dd).exe" file to
$RepoFTP_Host = "FTP HOST HERE"
$RepoFTP_Username = "USERNAME HERE"
$RepoFTP_Password = "PASSWORD HERE"
$RepoFTP_DepositPath = "/public_html/repos/tron/"                   # e.g. "/public_html/repos/tron/"





# ----------------------------- Don't edit anything below this line ----------------------------- #





###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION="1.2.1"
$SCRIPT_UPDATED="2015-02-08"
$CUR_DATE=get-date -f "yyyy-MM-dd"

# Extract version number from seed server copy of tron.bat and stash it in $OldVersion
# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)
$OldVersion = gc $SeedServer\$SeedFolder\tron\Tron.bat -ErrorAction SilentlyContinue | Select-String -pattern "set SCRIPT_VERSION"
$OldVersion = "$OldVersion".Split("=")[1]

# Extract version number from master's tron.bat and stash it in $NewVersion, then calculate and store the full .exe name for the new binary we'll be building
# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)
$NewVersion = gc $MasterCopy\tron\Tron.bat -ErrorAction SilentlyContinue | Select-String -pattern "set SCRIPT_VERSION"
$NewVersion = "$NewVersion".Split("=")[1]
$NewBinary = "Tron v$NewVersion ($CUR_DATE).exe"


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

# Test for existence of WinSCP.com
if (!$WinSCP) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find WinSCP.com at the location specified ( $WinSCP )"
	write-host "         Edit this script and change the `$WinSCP variable to point to 7z's location"
	""
	pause
	break
}

# Master Copy: Test for existence of Tron's \resources subfolder
if (!(test-path $MasterCopy\tron\resources)) {
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find Tron's \resources subfolder at $MasterCopy\resources"
	write-host "         Check your paths."
	""
	pause
	break
}

# Master Copy: Test for existence of tron.bat inside the tron subfolder
if (!(test-path $MasterCopy\tron\tron.bat)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find tron.bat in $MasterCopy\tron.bat"
	write-host "         Check your paths and make sure all the required files exist in the"
	write-host "         appropriate locations."
	""
	pause
	break
}

# Master Copy: Test for existence of the changelog
if (!(test-path $MasterCopy\tron\changelog-v$NewVersion-updated-$CUR_DATE.txt)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the changelog file at $MasterCopy\changelog-v$NewVersion-updated-$CUR_DATE.txt"
	write-host "         Check your paths and make sure all the required files exist in the"
	write-host "         appropriate locations."
	""
	pause
	break
}

# Master Copy:  Test for existence of the Instructions file
if (!(test-path $MasterCopy\tron\Instructions*.txt)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Instructions file in $MasterCopy\"
	write-host "         Check your paths and make sure all the required files exist in the"
	write-host "         appropriate locations."
	""
	pause
	break
}

# Seed Server: Test for existence of top level Tron folder
if (!(test-path $SeedServer\$SeedFolder)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the Tron seed folder at $SeedServer\$SeedFolder"
	write-host "         Check your paths and make sure you can reach the deployment server"
	write-host "         and that you have write-access to the Tron seed folder."
	""
	pause
	break
}

# Seed Server: Test for existence of \tron\integrity_verification sub-folder
if (!(test-path $SeedServer\$SeedFolder\integrity_verification)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the integrity_verification folder at $SeedServer\$SeedFolder\integrity_verification\"
	write-host "         Check your paths and make sure you can reach the deployment server,"
	write-host "         that you have write-access to the Tron seed folder, and that the "
	write-host "         integrity_verification sub-folder exists. "
	""
	pause
	break
}

# Seed Server: Test for existence of the public key
if (!(test-path $SeedServer\$SeedFolder\integrity_verification\vocatus-public-key.asc)) {
	""
	""
	write-host -n " ["; write-host -n "ERROR" -f red; write-host -n "]";
	write-host " Couldn't find the public key at $SeedServer\$SeedFolder\integrity_verification\"
	write-host "         Check your paths and make sure you can reach the deployment server"
	write-host "         and that you have write-access to the Tron seed folder."
	""
	pause
	break
}


###########
# EXECUTE #
###########

# JOB: Clear target area
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Clearing target area on seed server..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Clearing target area on seed server..." -f green
	remove-item $SeedServer\$SeedFolder\tron\* -force -recurse | out-null
	remove-item $SeedServer\$SeedFolder\integrity_verification\*txt* -force -recurse | out-null
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Calculate all hashes
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Calculating hashes, please wait..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Calculating hashes, please wait..." -f green
	pushd $MasterCopy
	del $env:temp\checksum* -force -recurse | out-null
	& $HashDeep64 -s -e -c sha256 -l -r .\ | Out-File $env:temp\checksums.txt -encoding ascii
	mv $env:temp\checksums.txt $MasterCopy\integrity_verification\checksums.txt -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Wait for PGP signature on checksums.txt. Once seen, then proceed to upload entire master directory to seed server
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Waiting for PGP signature of checksums.txt to appear..." -f green
remove-item $MasterCopy\integrity_verification\checksums.txt.sig -force -recurse | out-null
while (1 -eq 1) {
	if (test-path $MasterCopy\integrity_verification\checksums.txt.sig) {
	write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen
	"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
	# file exists so we break out of the loop
	break
	}
	# otherwise sleep for 5 seconds before looking again
	start-sleep -s 3
}


# JOB: Upload from Master Copy to Seed server
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Master Copy is gold. Now copying from Master to seed server..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Master Copy is gold. Now copying from Master to seed server..." -f green
	cp $MasterCopy\* $SeedServer\$SeedFolder\ -recurse -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# Notify that we're done with seed server operations and are starting deployment to the master repo
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Seed server deployment complete. Beginning master repo server update..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Seed server deployment complete. Beginning master repo server update..." -f green


# JOB: Pack Tron to into an .exe archive using 7z and stash it in the Temp directory. 
# Create the file name using the new version number extracted from tron.bat and exclude any 
# files with "Sync" in the title (these are BT Sync hidden files, we don't need to pack them
# TODO: Delete existing files first
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Building binary pack, please wait..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Building binary pack, please wait..." -f green
	& "$SevenZip" a -sfx "$env:temp\$NewBinary" ".\*" -x!*Sync* -x!*ini*
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Fetch sha256sums.txt and md5sums.txt from the repo for updating
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Fetching repo copy of sha256sums.txt to update..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Fetching repo copy of sha256sums.txt to update..." -f green
	Invoke-WebRequest $Repo_URL/md5sums.txt -outfile $env:temp\md5sums.txt
	Invoke-WebRequest $Repo_URL/sha256sums.txt -outfile $env:temp\sha256sums.txt
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Calculate MD5 hash of Tron .exe and append it to md5sums file // LEGACY, this will be removed after a few versions due to the switch to SHA256 for checksumming
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Calculating MD5 hash for binary pack and appending it to md5sums.txt..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Calculating MD5 hash for binary pack and appending it to md5sums.txt..." -f green
	pushd $env:temp
	& $md5sum ".\Tron v$NewVersion ($CUR_DATE).exe" | out-file .\md5sums.txt -Encoding utf8 -append
	popd
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Calculate SHA256 hash of Tron .exe and append it to sha256 file
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." -f green
	pushd $env:temp
	# First hash the file
	& $HashDeep64 -s -e -l -c sha256 ".\Tron v$NewVersion ($CUR_DATE).exe" | Out-File .\sha256sums_TEMP.txt -Encoding utf8
	# Strip out the annoying hashdeep header
	gc .\sha256sums_TEMP.txt | Where-Object {$_ -notmatch '#'} | where-object {$_ -notmatch '%'} | sc .\sha256sums_TEMP2.txt
	# Strip out blank lines and trailing spaces (not needed?) testing removal
	#(gc .\sha256sums_TEMP2.txt) | ? {$_.trim() -ne "" } | sc .\sha256sums_TEMP2.txt
	# Append the result to the sha256sums.txt we pulled from the repo
	gc .\sha256sums_TEMP2.txt | out-file .\sha256sums.txt -encoding utf8 -append
	popd
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Build the FTP upload script
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Building FTP deployment script..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Building FTP deployment script..." -f green
"option batch abort" | Out-File $env:temp\deploy_tron_ftp_script.txt -encoding ascii
"option confirm off" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"open ftp://$RepoFTP_Username`:$RepoFTP_Password@$RepoFTP_Host" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"cd $RepoFTP_DepositPath" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm *.exe" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"rm *.txt" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=binary `"$env:temp\$NewBinary`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=ascii `"$env:temp\md5sums.txt`""
add-content -path $env:temp\deploy_tron_ftp_script.txt -value "put -transfer=ascii `"$env:temp\sha256sums.txt`""
"exit" | Out-File $env:temp\deploy_tron_ftp_script.txt -append -encoding ascii
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Upload binary pack and the hash files to the repo server
# Now get in the TEMP directory and call the Windows built-in FTP command to do the heavy lifting
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Uploading $NewBinary to $RepoFTP_Host..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Uploading $NewBinary to $RepoFTP_Host..." -f green
	pushd $env:temp
	& $WinSCP /script=.\deploy_tron_ftp_script.txt
	popd
	Write-Host ""
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Save the packed binary to the static pack folder on the local seed server
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Saving $NewBinary to $SeedServer\$StaticPackStorageLocation..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Saving $NewBinary to $SeedServer\$StaticPackStorageLocation..." -f green
	mv $env:temp\$NewBinary $SeedServer\$StaticPackStorageLocation -force
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen


# JOB: Clean up after ourselves
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Cleaning up..." >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Cleaning up..." -f green
	remove-item $env:temp\md5sums.txt -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\sha256sum*.txt -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\$NewBinary -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\deploy_tron_ftp_script.txt -force -recurse -ea SilentlyContinue | out-null
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done" >> $LOGPATH\$LOGFILE
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done" -f darkgreen



############
# Finished #
############
# Logfile
"$CUR_DATE "+ $(get-date -f hh:mm:ss) + " Done Make sure to re-enable BT Sync and post release to Reddit." >> $LOGPATH\$LOGFILE
echo "                    Version deployed:          v$NewVersion ($CUR_DATE)" >> $LOGPATH\$LOGFILE
echo "                    Version replaced:          v$OldVersion" >> $LOGPATH\$LOGFILE
echo "                    Local deployment server:   $SeedServer" >> $LOGPATH\$LOGFILE
echo "                    Local seed folder          $SeedFolder" >> $LOGPATH\$LOGFILE
echo "                    Local static pack storage: $StaticPackStorageLocation" >> $LOGPATH\$LOGFILE
echo "                    Remote repo host:          $RepoFTP_Host" >> $LOGPATH\$LOGFILE
echo "                    Remote repo upload path:   $RepoFTP_Host/$RepoFTP_DepositPath" >> $LOGPATH\$LOGFILE
echo "                    Log file:                  $LOGPATH\$LOGFILE" >> $LOGPATH\$LOGFILE

# Console
write-host $CUR_DATE (get-date -f hh:mm:ss) -n -f darkgray; write-host " Done " -f green
write-host "                    Version deployed:          v$NewVersion ($CUR_DATE)" -f darkgray
write-host "                    Version replaced:          v$OldVersion" -f darkgray
write-host "                    Local deployment server:   $SeedServer" -f darkgray
write-host "                    Local seed folder          $SeedFolder" -f darkgray
write-host "                    Local static pack storage: $StaticPackStorageLocation" -f darkgray
write-host "                    Remote repo host:          $RepoFTP_Host" -f darkgray
write-host "                    Remote repo upload path:   $RepoFTP_Host/$RepoFTP_DepositPath" -f darkgray
write-host "                    Log file:                  $LOGPATH\$LOGFILE" -f darkgray
write-host "                                               Re-enable BT Sync and post release to Reddit" -f blue

pause
