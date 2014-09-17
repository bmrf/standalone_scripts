<#
 Purpose:       Removes built-in default Metro bloatware in Windows 8/8.1/Server 2012 and up
 Requirements:  Administrator rights; Powershell scripts enabled
 Author:        vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
 History:       1.0.0   Initial write

 Usage:         Run the script with admin rights
#>

########
# Prep #
########
$SCRIPT_VERSION="1.0.0"
$SCRIPT_UPDATED="2014-09-17"
$CUR_DATE=get-date -f "yyyy-MM-dd"

#############
# VARIABLES # -- Set these to your desired values
#############
# no user-set variables for this script


#############
# EXECUTION #
#############
# Remove provisioned (in-image) packages
Get-AppXProvisionedPackage -online | Remove-AppxProvisionedPackage -online

# Remove "installed" packages
Get-AppxPackage -AllUsers | Remove-AppxPackage
