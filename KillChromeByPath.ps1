Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$thresholdMB = 10  # Set RAM threshold in MB
$logDir = "C:\Logs"
$scriptLog = "$logDir\ScriptExecution.log"
$killLog = "$logDir\ProcessKill.log"

# Ensure the log directory exists
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Log script start time
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Script started." | Out-File -Append -FilePath $scriptLog
a
# Get dynamic Chrome paths (including user-specific installations)
$chromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) + (Get-ChildItem "C:\Users" -Directory | ForEach-Object {
    "C:\Users\$($_.Name)\AppData\Local\Google\Chrome\Application\chrome.exe"
})

while ($true) {
    # Get all Chrome processes from all users
    $chromeProcesses = Get-CimInstance Win32_Process | Where-Object { 
        $_.Name -eq "chrome.exe" -and $_.WorkingSetSize -gt ($thresholdMB * 1MB) 
    }

    # Filter processes based on allowed Chrome paths
    $chromeProcesses = $chromeProcesses | Where-Object { 
        $_.ExecutablePath -and ($chromePaths -contains $_.ExecutablePath) 
    }

    # Loop through and terminate each high-memory Chrome process
    foreach ($process in $chromeProcesses) {
        try {
            # Get process owner (user)
            $owner = $process | Invoke-CimMethod -MethodName GetOwner
            $username = "$($owner.Domain)\$($owner.User)"
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $ramUsageMB = [math]::Round($process.WorkingSetSize / 1MB, 2)

            # Log process termination
            $logEntry = "[$timestamp] Killed Chrome process: PID $($process.ProcessId), User: $username, Path: $($process.ExecutablePath), RAM Usage: ${ramUsageMB}MB"
            Write-Host $logEntry -ForegroundColor Red
            $logEntry | Out-File -Append -FilePath $killLog

            # Kill the process
            Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to kill Chrome process: PID $($process.ProcessId) - $_" -ForegroundColor Yellow
        }
    }

    Write-Host "Next check in 15 minutes..." -ForegroundColor Cyan
    Start-Sleep -Seconds 9  # Wait for 15 minutes before running again
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy $originalPolicy -Force

