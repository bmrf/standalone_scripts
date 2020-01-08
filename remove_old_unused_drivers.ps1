# Removes old versions of drivers from the Windows driver store
# I did not write this script, but found it somewhere online. Spacing/tabbing is messed up but I've tested the script and it works as of 2020-01-08

$dismOut = dism /online /get-drivers
$Lines = $dismOut | select -Skip 10

$Operation = "theName"
$Drivers = @()


foreach ( $Line in $Lines ) {
    $tmp = $Line
    $txt = $($tmp.Split( ':' ))[1]
    switch ($Operation) {

        'theName' { $Name = $txt
                     $Operation = 'theFileName'
                     break
                   }

        'theFileName' { $FileName = $txt.Trim()
                         $Operation = 'theEntr'
                         break
                       }
        'theEntr' { $Entr = $txt.Trim()
                     $Operation = 'theClassName'
                     break
                   }

        'theClassName' { $ClassName = $txt.Trim()

                          $Operation = 'theVendor'

                          break

                        }

        'theVendor' { $Vendor = $txt.Trim()
                       $Operation = 'theDate'
                       break
                     }

        'theDate' { # change the date format for easy sorting
                     $tmp = $txt.split( '.' )
                     $txt = "$($tmp[2]).$($tmp[1]).$($tmp[0].Trim())"
                     $Date = $txt
                     $Operation = 'theVersion'
                     break
                   }


        'theVersion' { $Version = $txt.Trim()

                        $Operation = 'theNull'
                        $params = [ordered]@{ 'FileName' = $FileName
                                              'Vendor' = $Vendor
                                              'Date' = $Date
                                              'Name' = $Name
                                              'ClassName' = $ClassName
                                              'Version' = $Version
                                              'Entr' = $Entr
                                            }


                        $obj = New-Object -TypeName PSObject -Property $params
                        $Drivers += $obj


                        break

                      }
         'theNull' { $Operation = 'theName'
                      break
                     }
    }
}


Write-Host "All installed third-party drivers"

$Drivers | sort Filename | ft

Write-Host "Different versions"

$last = ''
$NotUnique = @()


foreach ( $Dr in $($Drivers | sort Filename) ) {
    if ($Dr.FileName -eq $last  ) {  $NotUnique += $Dr  }
    $last = $Dr.FileName
}

$NotUnique | sort FileName | ft

Write-Host "Outdated drivers"

$list = $NotUnique | select -ExpandProperty FileName -Unique

$ToDel = @()

foreach ( $Dr in $list ) {
    Write-Host "duplicate found" -ForegroundColor Yellow
    $sel = $Drivers | where { $_.FileName -eq $Dr } | sort date -Descending | select -Skip 1
    $sel | ft
    $ToDel += $sel
}


Write-Host "Drivers to remove" -ForegroundColor Red

$ToDel | ft

# removing old drivers
foreach ( $item in $ToDel ) {
    $Name = $($item.Name).Trim()
    Write-Host "deleting $Name" -ForegroundColor Yellow
    Write-Host "pnputil.exe -d $Name" -ForegroundColor Yellow
    Invoke-Expression -Command "pnputil.exe -d $Name"
}
