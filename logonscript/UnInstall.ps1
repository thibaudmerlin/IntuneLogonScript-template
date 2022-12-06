#region Config
$client = "Company"
$scriptsPath = "$env:ProgramData\$client\Scripts\LogonScript\"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\LogonScript-UnInstall.log"
$buildId = "9d984414-ae86-43a3-8a84-8e497bc7eef4"
#endregion
#region Logging
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region Scheduled Task
try {
    Write-Verbose "Deletting scheduled task"
    if ((Get-ScheduledTask -TaskName "$client`_Logonscript" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName "$client`_Logonscript" -Confirm:$false
        Write-Verbose "Scheduled task deleted successfully"
        if (Test-Path "$scriptsPath") {
            Remove-Item -Path "$scriptsPath" -Force -Recurse
            Write-Verbose "Scripts deleted successfully"
        }
    }
    else {
        Write-Verbose "Scheduled task already deleted."
    }
}
catch {
    $errMsg = $_.Exception.Message
}
finally {
    if ($errMsg) {
        Write-Warning $errMsg
        Stop-Transcript
        throw $errMsg
    }
    else {
        Write-Host "script completed successfully.."
        "done." | Out-File "$env:temp\$buildId`.txt" -Encoding ASCII -force
        Stop-Transcript
    }
}
#endregion