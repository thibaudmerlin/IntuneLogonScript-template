#region Config
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = "Intune.Training"
$logPath = "$ENV:ProgramData\$client\Logs"
$logFile = "$logPath\LogonScript.log"
$user = whoami /upn
$errorOccurred = $null
$fileServer = 'fileserver.corp'
$funcUri = 'https://{putURIhere}'
#endregion
#region Functions
function Set-DriveMapping {
    <#
    .SYNOPSIS
        Map a network drive. Also checks for network connectivity before attempting the mapping.
    .PARAMETER driveLetter
        The drive letter to be assigned
    .PARAMETER uncPath
        Full FQDN path of the network share
    .EXAMPLE
        Set-DriveMapping -driveLetter X -uncPath "\\server1.contoso.com\NetworkShareX"
    #>
    [cmdletbinding(SupportsShouldProcess = $True)]
    param (
        [string]$driveLetter,
        [string]$uncPath
    )
    $server = ($uncPath -split "\\")[2]
    $netConn = Test-NetConnection -ComputerName $server | select-object PingSucceeded, NameResolutionSucceeded
    if (($netConn.PingSucceeded) -and ($netConn.NameResolutionSucceeded)) {
        if (Test-Path -Path $uncPath) {
            if (Get-PSDrive | where-object { $_.Name -eq $driveLetter }) {
                if (Get-PSDrive | where-object { ($_.Name -eq $driveLetter) -and ($_.DisplayRoot -eq $uncPath) }) {
                    Write-Host "$($driveLetter): Currently Mapped. No action taken.." -ForegroundColor Green
                }
                else {
                    Write-Host "$($driveLetter): Mapped incorrectly. Might need remapping.." -ForegroundColor Yellow
                    if ($WhatIfPreference) {
                        Write-Host "would remove drive: $driveLetter"
                        Write-Host "would map drive $driveLetter with uncPath $uncPath"
                    }
                    else {
                        Write-Host "Removing drive `"$driveLetter`".."
                        Remove-SmbMapping -LocalPath "$driveLetter`:" -UpdateProfile -Force
                        Start-Sleep -Seconds 2
                        Write-Host "Re-mapping drive `"$driveLetter`" to `"$uncPath`".."
                        New-SmbMapping -LocalPath "$driveLetter`:" -RemotePath $uncPath -Persistent $true
                        #Remove-PSDrive -Name $driveLetter -PSProvider FileSystem -Scope Global -Force -Verbose
                        #New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $uncPath -Scope Global -Persist -Verbose
                    }
                }
            }
            else {
                if ($WhatIfPreference) {
                    Write-Host "would map drive $driveLetter with uncPath $uncPath"
                }
                else {
                    Write-Host "$($driveLetter): not found - mapping to $uncPath" -ForegroundColor Green
                    New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $uncPath -Scope Global -Persist -Verbose
                }
            }
        }
        else {
            Write-Host "Getting a response from $($server) `nCan't access UNC Path: $($uncPath)." -ForegroundColor Red
            if (Get-PSDrive | Where-Object { ($_.Name -eq $driveLetter) -and ($_.DisplayRoot -eq $uncPath) }) {
                if ($WhatIfPreference) {
                    Write-Host "would remove drive: $driveLetter"
                }
                else {
                    #Remove-PSDrive -Name $driveLetter -PSProvider FileSystem -Scope Global -Force -Verbose
                }
            }
        }
    }
    else {
        Write-Host "Could not reach $($uncPath): Going to check if $($driveLetter) is already mapped and remove it" -ForegroundColor Red
        if (Get-PSDrive | Where-Object { ($_.Name -eq $driveLetter) -and ($_.DisplayRoot -eq $uncPath) }) {
            if ($WhatIfPreference) {
                Write-Host "would remove drive: $driveLetter"
            }
            else {
                #Remove-PSDrive -Name $driveLetter -PSProvider FileSystem -Scope Global -Force -Verbose
            }
        }
    }
}
Function Set-LocalPrinters {
    <#
    .SYNOPSIS
        Installs network printer to local machine.
    .PARAMETER Server
        FQDN or IP Address of print server
    .PARAMETER printerName
        Name of printer to be installed
    #>
    param (
        [string]$server,

        [string]$printerName,

        [string]$Default
    )
    $printerPath = $null
    $PrinterPath = "\\$($server)\$($printerName)"
    $netConn = Test-NetConnection -ComputerName $Server | select-object PingSucceeded, NameResolutionSucceeded
    if (($netconn.PingSucceeded) -and ($netConn.NameResolutionSucceeded)) {
        write-host "Installing $printerName.." -ForegroundColor Green
        if (Get-Printer -Name "$printerPath" -ErrorAction SilentlyContinue) {
            Write-Host "Printer $printerPath already installed" -ForegroundColor Green
        }
        else {
            if ($Default -eq "true") {
                Write-Host "Installing $printerPath" -ForegroundColor Green
                & cscript /noLogo C:\windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs -ac -p $printerPath -T
            }
            else {
                Write-Host "Installing $printerPath" -ForegroundColor Green
                & cscript /noLogo C:\windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs -ac -p $printerPath
            }

            if (Get-Printer -Name "$printerPath" -ErrorAction SilentlyContinue) {
                Write-Host "$printerPath successfully installed.."
            }
            else {
                Write-Warning "$printerPath not successfully installed"
            }
        }
    }
    else {
        Write-Host "Print server not pingable. $printerPath will not be installed" -ForegroundColor Red
    }
}
#endregion
#region logging
if (!(Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force
}
Start-Transcript -Path $logFile -Force
#endregion
#region Logon script
try {
    $sw = New-Object System.Diagnostics.Stopwatch
    $sw.Start()
    $timeSpan = New-TimeSpan -Minutes 2
    Write-Host "Hello $user.." -ForegroundColor Green
    Write-Host "Just going to make sure you have access to $client resources before we begin.." -ForegroundColor Green
    Write-Host "Testing connectivity to $fileServer..`ngoing to try for the next few minutes, hold tight.." -ForegroundColor Yellow
    while ((!(Test-Connection -ComputerName $fileServer -Count 2 -Quiet)) -and ($sw.ElapsedMilliseconds -lt $timeSpan.TotalMilliseconds)) {
        start-sleep -Seconds 2
    }
    #region Existing Drive Mapping
    Write-Host "Checking existing drive mappings.."
    $existingDrives = Get-SmbMapping | Where-Object { $_.Status -in @("Unavailable", "Disconnected") } | Select-Object LocalPath, RemotePath
    if ($existingDrives) {
        Write-Host "Found some existing drive mappings that are offline - let's fix that now.."
        foreach ($drive in $existingDrives) {
            try {
                Write-Host "Re-mapping $($drive.LocalPath.Replace(':','')) to $($drive.RemotePath)"
                Set-DriveMapping -driveLetter $($drive.LocalPath.Replace(':', '')) -uncPath $drive.RemotePath
            }
            catch {
                Write-Host "Issue trying to map $($drive.RemotePath) to $($drive.LocalPath).."
                Write-Warning $_.Exception.Message
            }
        }
    }
    else {
        Write-Host "No offline drive mappings found.."
    }
    #endregion
    #region Get group memberships
    $fParams = @{
        Method      = 'Get'
        Uri         = "$funcUri&user=$user"
        ContentType = 'Application/Json'
    }
    $grpMembership = Invoke-RestMethod @fParams
    #endregion
    #region Map drives
    if ($grpMembership.drives) {
        Write-Host "`nMapping network drives.."
        $grpMembership.drives | Format-Table
        foreach ($d in $grpMembership.drives) {
            if ($null -ne $d) {
                Write-Host "Mapping `"$($d.uncPath)`" to $($d.driveLetter):"
                Set-DriveMapping -driveLetter $d.driveLetter -uncPath $d.uncPath
            }
        }
    }
    #endregion
    #region Map printers
    if ($grpMembership.printers) {
        Write-Host "`nMapping network printers.."
        $grpMembership.printers | Format-Table
        foreach ($p in $grpMembership.printers) {
            if ($null -ne $d) {
                Write-Host "Mapping `"$($d.Server)`"/$($p.Printer):"
                Set-LocalPrinters -server $p.Server -printerName $p.Printer -Default $p.Default
            }
        }
    }
    #endregion
}
catch {
    $errorOccurred = $_.Exception.Message
}
finally {
    if ($errorOccurred) {
        Write-Warning "Logon Script completed with errors."
        Stop-Transcript
        Throw $errorOccurred
    }
    else {
        Write-Host "Logon Script completed successfully."
        Stop-Transcript
    }
}
#endregion