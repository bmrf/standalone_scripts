<#
Purpose:       Deploys PDQ Packs
Requirements:  1. Expects master copy directory to look like this:
					\job_files
					\repository
					changelog-vX.Y.X-updated-yyyy-mm-dd.txt
					Instructions -- read this.txt
					Roughly what it should look like.png

               2. Expects master changelog file to have accurate "PACK_DATE=yyyy-mm-dd" and "PACK_VERSION=x.y.z" strings because these are parsed and used to name everything correctly

               3. Expects seed server directory structure to look like this:

					\resiliosync\pdq_pack
						
						\pdq_pack
							\job_files
							\repository
							changelog-vX.Y.Z-updated-YYYY-MM-DD.txt
							Instructions -- read this.txt
							Roughly what it should look like.png
						
						\integrity_verification
							checksums.txt
							checksums.txt.asc
							vocatus-public-key.asc


Author:        reddit.com/user/vocatus ( vocatus.gate@gmail.com ) // PGP key: 0x07d1490f82a211a2
Version:       1.0.1 + Add -speed=350 (KB) command to WinSCP FTP upload script because Cox is stupid and auto-kills any FTP upload that goes above a certain rate
                     + add -resume command to WinSCP FTP upload script for the new binary exe only
               1.0.0 . Initial write, fork of deploy_tron.ps1

Behavior/steps:
1. Delete content from seed server
2. Calculate sha256 hashes of all files in \pdq_pack\pdq_pack
3. PGP-sign checksums.txt
3. Make .torrent file, save locally and upload to the autoloader folder
4. Create binary pack
5. PGP-sign the binary pack
6. Background upload the binary pack to the seed server
7. Fetch sha256sums.txt from repo and update it with sha256sum of the new binary pack
8. Delete current version from repo server; upload .exe pack and sha256sums.txt to repo server; cleans up residual temp files; notifies of completion and advises to restart BT Sync
9. Build FTP upload script
10. Upload via FTP
11. Clean up (deletes temp files used)
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
	[string]$logfile = "deploy_pdq_packs.log",

	# Path to 7z.exe
	[string]$SevenZip = "C:\Program Files\7-Zip\7z.exe",

	# Path to WinSCP.com
	[string]$WinSCP = "R:\applications\WinSCP\WinSCP.com",

	# Path to hashdeep.exe
	[string]$HashDeep = "R:\utilities\cli_utils\hashdeep.exe",                  # e.g. "$env:SystemRoot\system32\hashdeep.exe"

	# Path to gpg.exe (for signing)
	[string]$gpg = "${env:ProgramFiles(x86)}\GnuPG\bin\gpg.exe",                # e.g. "$env:ProgramFiles\gpg4win\bin\gpg.exe"

	# Path to mktorrent.exe (for .torrent generation)
	[string]$mktorrent = "R:\applications\mktorrent\mktorrent.exe",             # e.g. "R:\applications\mktorrent\mktorrent.exe"

	# List of torrent trackers to pack into the .torrent
	[string]$TorrentTracker1 = "udp://tracker.coppersurfer.tk:6969/announce",
	[string]$TorrentTracker2 = "udp://tracker.ccc.de:80/announce",
	[string]$TorrentTracker3 = "udp://tracker.publicbt.com:80",
	[string]$TorrentTracker4 = "udp://tracker.istole.it:80",
	[string]$TorrentTracker5 = "http://tracker.openbittorrent.com:80/announce",
	[string]$TorrentTracker6 = "http://tracker.ipv6tracker.org:80/announce",
	[string]$TorrentTracker7 = "http://9.rarbg.com:2710/announce",

	# Master copy. Directory path, not file path. This directory should contain \pdq_pack and \integrity_verification subfolders
	# Cygwin format version is required for mktorrent.exe. This directory should contain \pdq_pack and \integrity_verification subfolders
	[string]$MasterCopy = "R:\utilities\pdq_pack",                               # e.g. "r:\utilities\security\cleanup-repair\pdq_pack"
	[string]$MasterCopyCygwinFormat = "/cygdrive/r/utilities/pdq_pack", # e.g. "/cygdrive/r/utilities/security/cleanup-repair/pdq_pack"

	# .torrent output folder, e.g. where to spit out the generated .torrent file. Supply path
	# in both standard Windows format and in cygwin format. No trailing slash
	[string]$TorrentSaveLocation = "R:\documents\logs\torrents",                # e.g. "R:\documents\logs\torrents"
	[string]$TorrentSaveLocationCygwinFormat = "/cygdrive/r/documents/logs/torrents",  # e.g. "/cygdrive/r/unsorted"

	# Server holding the seed directories
	[string]$SeedServer = "\\thebrain",                                         # e.g. "\\thebrain"

	# Torrent upload directory. e.g. where to copy the .torrent file so it can be loaded by the Bittorrent software
	# Relative path to $SeedServer
	[string]$TorrentAutoloaderLocation = "downloads\torrent_files\autoloader",  # e.g. "downloads\torrent_files\autoloader"

	# Seeding subdirectories containing \repository and \job_files directories (relative paths). No leading or trailing slashes
	# RELEASE seeds
	[string]$SeedFolderRS = "downloads\seeders\resiliosync\pdq_pack",           # e.g. "downloads\seeders\resiliosync\pdq_pack"
	[string]$SeedFolderTorrent = "downloads\seeders\torrent",                   # e.g. "downloads\seeders\torrent"

	# Static pack storage location. RELATIVE path from root on the
	# local deployment server. Where we stash the compiled .exe
	# after uploading to the repo server.
	# No leading or trailing slashes
	[string]$StaticPackStorageLocation = "downloads\seeders\static_packs",      # e.g. "downloads\seeders\static packs"

	# Repository server where we'll fetch sha256sums.txt from
	[string]$Repo_URL = "https://bmrf.org/repos/pdq_packs",                      # e.g. "http://bmrf.org/repos/pdq_packs"

	# FTP information for where we'll upload the final sha256sums.txt and "PDQ Pack vX.Y.Z (yyyy-mm-dd).exe" file to
	[string]$Repo_FTP_Host = "xxx",                                             # e.g. "bmrf.org"
	[string]$Repo_FTP_Username = "xxx",
	[string]$Repo_FTP_Password = "xxx",
	[string]$Repo_FTP_DepositPath = "/public_html/repos/pdq_packs/",            # e.g. "/public_html/repos/pdq_packs/"

	# PGP key authentication information
	[string]$gpgUsername = "xxx",
	[string]$gpgPassphrase = "xxx"
)






# ----------------------------- Don't edit anything below this line ----------------------------- #






###################
# PREP AND CHECKS #
###################
$SCRIPT_VERSION = "1.0.1"
$SCRIPT_UPDATED = "2017-10-04"
$CUR_DATE=get-date -f "yyyy-MM-dd"

# The "split" command/method is similar to variable cutting in batch (e.g. %myVar:~3,0%)

# Extract version number of current version from the seed server changelog and stash it in $OldVersion
$OldVersion = gc $SeedServer\$SeedFolderRS\pdq_pack\changelog* -ea SilentlyContinue | Select-String -pattern "PACK_VERSION"
$OldVersion = "$OldVersion".Split("=")[1]

# Extract release date of current version from the seed server changelog and stash it in $OldDate
$OldDate = gc $SeedServer\$SeedFolderRS\pdq_pack\changelog* -ea SilentlyContinue | Select-String -pattern "PACK_DATE"
$OldDate = "$OldDate".Split("=")[1]

# Extract version number from master changelog and stash it in $NewVersion, then calculate and store the full .exe name for the binary we'll be building
$NewVersion = gc $MasterCopy\pdq_pack\changelog* -ea SilentlyContinue | Select-String -pattern "PACK_VERSION"
$NewVersion = "$NewVersion".Split("=")[1]
$NewBinary = "PDQ Pack v$NewVersion ($CUR_DATE).exe"



#################
# SANITY CHECKS #
#################
# List of items to make sure they exist before running the script
$pathsToCheck = @(

    # Local machine: 7z.exe
    "$SevenZip",

    # Local machine: WinSCP.com
    "$WinSCP",

    # Local machine: hashdeep
    "$HashDeep",

    # Master copy: \job_files subfolder
    "$MasterCopy\pdq_pack\job_files",

    # Master copy: \repository
    "$MasterCopy\pdq_pack\repository",

    # Master copy: changelog
    "$MasterCopy\pdq_pack\changelog-v$NewVersion-updated-$CUR_DATE.txt",

    # Master copy: the Instructions file
    "$MasterCopy\pdq_pack\Instructions -- read this.txt",

    # Seed server: top level folder (Resilio Sync)
    "$SeedServer\$SeedFolderRS",

    # Seed server: \pdq_pack\integrity_verification sub-folder (Resilio Sync)
    "$SeedServer\$SeedFolderRS\integrity_verification",

    # Seed server: the public key (BT Sync)
    "$SeedServer\$SeedFolderRS\integrity_verification\vocatus-public-key.asc"
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



# Are you sure?
""
write-host " Build passed sanity checks." -f green
""
write-host " About to replace PDQ Pack v$OldVersion ($OldDate) with v$NewVersion ($CUR_DATE)"
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
# The rest of the script is wrapped in the "main" function. This is literally just so we can put the logging function at the bottom of the script instead of at the top
function main() {
""
log " PDQ Pack deployment script v$SCRIPT_VERSION" blue
""
log "   Replacing v$OldVersion ($OldDate) with v$NewVersion ($CUR_DATE)" green


# JOB: Clear target area
log "   Clearing RELEASE targets on local seed server..." green
	remove-item $SeedServer\$SeedFolderRS\pdq_pack\* -force -recurse -ea SilentlyContinue | out-null
	remove-item $SeedServer\$SeedFolderRS\integrity_verification\*txt* -force -recurse -ea SilentlyContinue | out-null
log "   Done" darkgreen


# JOB: Calculate hashes of every file in the directory structure
log "   Calculating individual hashes of all included files, please wait..." green
	pushd $MasterCopy
	del $env:temp\checksum* -force -recurse | out-null
	& $HashDeep -s -e -c sha256 -l -r .\ | Out-File $env:temp\checksums.txt -encoding ascii
	mv $env:temp\checksums.txt $MasterCopy\integrity_verification\checksums.txt -force
log "   Done" darkgreen


# JOB: PGP sign the resulting checksums.txt then upload the signature file to the seed locations
log "   PGP signing checksums.txt..." green
""
remove-item $MasterCopy\integrity_verification\checksums.txt.asc -force -recurse -ea SilentlyContinue | out-null
& $gpg --batch --yes --local-user $gpgUsername --passphrase $gpgPassphrase --armor --verbose --detach-sign $MasterCopy\integrity_verification\checksums.txt
while (1 -eq 1) {
	if (test-path $MasterCopy\integrity_verification\checksums.txt.asc) {
		""
		log "   Done" darkgreen
		break
	}
	# sleep before looking again
	start-sleep -s 2
}


# JOB: Verify PGP signature before FTP upload
log "   Verifying PGP signature of checksums.txt..." green
""
& $gpg --batch --yes --verbose --verify $MasterCopy\integrity_verification\checksums.txt.asc $MasterCopy\integrity_verification\checksums.txt
if ($? -eq "True") {
	""
	log "   Done" darkgreen
} else {
	log " ! There was a problem verifying the signature!" red
	pause
}


# JOB: Create .torrent file for the release
log "   Generating .torrent file and saving to $TorrentSaveLocationCygwinFormat..." green
	& $mktorrent -n "PDQ Pack v$NewVersion ($CUR_DATE)" -c "Instructions at https://www.reddit.com/r/sysadmin" -a $TorrentTracker1,$TorrentTracker2,$TorrentTracker3,$TorrentTracker4,$TorrentTracker5,$TorrentTracker6,$TorrentTracker7 -o "$TorrentSaveLocationCygwinFormat/PDQ Pack v$NewVersion ($CUR_DATE).torrent" $MasterCopyCygwinFormat/pdq_pack
if ($? -eq "True") { log "   Done" darkgreen } else { log " ! There was a problem creating the .torrent" red }


# JOB: Upload from master copy to seed server directories
log "   Master copy is stamped and good to go. Copying from master to local seeds..." green
	
	
	log "   Loading Resilio Sync seed..." green
		cp $MasterCopy\* $SeedServer\$SeedFolderRS\ -recurse -force
	log "   Done" darkgreen
	
	
	log "   Loading Torrent seed..." green
		mkdir "$SeedServer\$SeedFolderTorrent\PDQ Pack v$NewVersion ($CUR_DATE)" -ea silentlycontinue | out-null
		cp $MasterCopy\pdq_pack\* "$SeedServer\$SeedFolderTorrent\PDQ Pack v$NewVersion ($CUR_DATE)" -recurse -force
	log "   Done" darkgreen
	
	
	log "   Uploading .torrent file to $TorrentAutoloaderLocation..." green
		cp "$TorrentSaveLocation\PDQ Pack v$NewVersion ($CUR_DATE).torrent" $SeedServer\$TorrentAutoloaderLocation
	if ($? -eq "True") {
		log "   Done" darkgreen
	} else {
		log " ! There was a problem copying the .torrent to the autoloader folder" red
	}

log "   Done, seed server loaded." darkgreen


# Notify that we're done loading the seed server and are starting deployment to the master repo
log "   Updating master repo (remote)..." green


# JOB: Pack into a binary pack (.exe archive) using 7z and stash it in the TEMP directory.
# Create the file name using the new version number extracted from the changelog and exclude any
# files with "sync" in the title (these are Resilio Sync hidden files, we don't need to pack them)
log "   Building binary pack, please wait..." green
	& "$SevenZip" a -sfx "$env:temp\$NewBinary" ".\*" -x!*sync* -x!*ini* >> $LOGPATH\$LOGFILE
log "   Done" darkgreen


# JOB: Background upload the binary pack to the static pack folder on the local seed server
log "   Background uploading $NewBinary to $SeedServer\$StaticPackStorageLocation..." green
start-job -name pdq_pack_copy_to_seed_server -scriptblock {cp "$env:temp\$($args[0])" "$($args[1])\$($args[2])" -force} -ArgumentList $NewBinary, $SeedServer, $StaticPackStorageLocation
""


# JOB: Fetch sha256sums.txt from the repo for updating
log "   Fetching repo copy of sha256sums.txt to update..." green
	Invoke-WebRequest $Repo_URL/sha256sums.txt -outfile $env:temp\sha256sums.txt
log "   Done" darkgreen


# JOB: Calculate SHA256 hash of newly-created binary pack and append it to sha256sums.txt
log "   Calculating SHA256 hash for binary pack and appending it to sha256sums.txt..." green
	pushd $env:temp
	# First hash the file
	& $HashDeep -s -e -l -c sha256 "PDQ Pack v$NewVersion ($CUR_DATE).exe" | Out-File .\sha256sums_TEMP.txt -Encoding utf8
	# Strip out the annoying hashdeep header
	gc .\sha256sums_TEMP.txt | Where-Object {$_ -notmatch '#'} | where-object {$_ -notmatch '%'} | sc .\sha256sums_TEMP2.txt
	# Strip out blank lines and trailing spaces (not needed?)
	#(gc .\sha256sums_TEMP2.txt) | ? {$_.trim() -ne "" } | sc .\sha256sums_TEMP2.txt
	# Append the result to the sha256sums.txt we pulled from the repo
	gc .\sha256sums_TEMP2.txt | out-file .\sha256sums.txt -encoding utf8 -append
	# Sleep for a few seconds to make sure the pack has had time to finish uploading to the local seed server static pack location
	start-sleep -s 10
	# Rename the file to prepare it for uploading
	ren "$env:temp\$NewBinary" "$env:temp\UPLOADING"
	popd
log "   Done" darkgreen


# JOB: PGP sign sha256sums.txt
log "   PGP signing sha256sums.txt..." green
""
remove-item $env:temp\sha256sums.txt.asc -force -recurse -ea SilentlyContinue | out-null
& $gpg --batch --yes --local-user $gpgUsername --passphrase $gpgPassphrase --armor --verbose --detach-sign $env:temp\sha256sums.txt
while (1 -eq 1) {
	if (test-path $env:temp\sha256sums.txt.asc) {
		""
		log "   Done" darkgreen
		break
	}
	# sleep before looking again
	start-sleep -s 2
}


# JOB: Verify PGP signature of sha256sums.txt
log "   Verifying PGP signature of sha256sums.txt..." green
& $gpg --batch --yes --verbose --verify $env:temp\sha256sums.txt.asc $env:temp\sha256sums.txt
if ($? -eq "True") {
	log "   Done" darkgreen
} else {
	log " ! There was a problem verifying the signature!" red
}


# JOB: Build FTP upload script
# PDQ Pack exe will have "UPLOADING" appended to its name until upload is complete
log "   Building FTP deployment script..." green
	"option batch abort" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -encoding ascii
	"option confirm off" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"open ftp://$Repo_FTP_Username`:$Repo_FTP_Password@$Repo_FTP_Host" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"cd $Repo_FTP_DepositPath" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"rm *.exe" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"rm *.torrent" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"rm sha256sums*" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	add-content -path $env:temp\deploy_pdq_pack_ftp_script.txt -value "put -transfer=binary `"$TorrentSaveLocation\PDQ Pack v$NewVersion ($CUR_DATE).torrent`""
	add-content -path $env:temp\deploy_pdq_pack_ftp_script.txt -value "put -transfer=binary -speed=350 -resume `"$env:temp\UPLOADING`""
	add-content -path $env:temp\deploy_pdq_pack_ftp_script.txt -value "mv `"UPLOADING`" `"$NewBinary`""
	add-content -path $env:temp\deploy_pdq_pack_ftp_script.txt -value "put -transfer=binary `"$env:temp\sha256sums.txt`""
	add-content -path $env:temp\deploy_pdq_pack_ftp_script.txt -value "put -transfer=ascii `"$env:temp\sha256sums.txt.asc`""
	#write-output "mv "UPLOADING_$NewBinary" "$NewBinary"" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
	"exit" | Out-File $env:temp\deploy_pdq_pack_ftp_script.txt -append -encoding ascii
log "   Done" darkgreen


# JOB: Upload binary pack and hash files to FTP repo server
# Get in TEMP directory and call WinSCP to run the script we just created
log "   Uploading $NewBinary to $Repo_FTP_Host..." green
	""
	pushd $env:temp
	& $WinSCP /script=.\deploy_pdq_pack_ftp_script.txt
	popd
	""
log "   Done" darkgreen


# JOB: Clean up after ourselves
log "   Cleaning up..." green
	remove-item $env:temp\sha256sums* -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\$NewBinary* -force -recurse -ea SilentlyContinue | out-null
	remove-item $env:temp\deploy_pdq_pack_ftp_script.txt -force -recurse -ea SilentlyContinue | out-null
	# Remove our background upload job from the job list
	get-job | remove-job
log "   Done" darkgreen



############
# Finished #
############
log "   Deployment done " green
log "   Version deployed:                  v$NewVersion ($CUR_DATE)"
log "   Version replaced:                  v$OldVersion ($OldDate)"
log "   Local seed server:                 $SeedServer"
log "   Local seed directories:"
log "             Resilio Sync (RELEASE):  $SeedFolderRS"
log "   Local torrent autoloader location: $TorrentAutoloaderLocation"
log "   Local torrent save location:       $TorrentSaveLocation"
log "   Local static pack storage:         $StaticPackStorageLocation"
log "   Remote repo host:                  $Repo_FTP_Host"
log "   Remote repo upload path:           $Repo_FTP_Host/$Repo_FTP_DepositPath"
log "   Log file:                          $LOGPATH\$LOGFILE"
log "                                      Start the .torrent file" blue
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
	write-host (get-date -f "yyyy-MM-dd hh:mm:ss") -n -f darkgray; write-host "$message" -f $color
	#log
	#(get-date -f "yyyy-mm-dd hh:mm:ss") +"$message" | out-file -Filepath "$logpath\$logfile" -append
	(get-date -f "yyyy-MM-dd hh:mm:ss") +"$message" | out-file -Filepath "C:\logs\deploy_pdq_packs.log" -append
}


# call the main script
main
