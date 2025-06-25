# ================================
# Chrome RAM Watchdog Script
# ================================

# --- Save current execution policy and bypass for this session ---
$originalPolicy = Get-ExecutionPolicy -Scope Process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# --- Configuration ---
$thresholdMB = 10  # Set RAM threshold in MB
$logDir      = "C:\Libeteks_InstantSupport\000\Logs"
$scriptLog   = "$logDir\ScriptExecution.log"
$killLog     = "$logDir\ProcessKill.log"
$checkDelay  = 9  # Time between checks in seconds (use 900 for 15 minutes)

# --- Ensure log directory exists ---
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# --- Log script start ---
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Script started." | Out-File -Append -FilePath $scriptLog

# --- Get valid Chrome paths (user and system) ---
$chromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) + (Get-ChildItem "C:\Users" -Directory | ForEach-Object {
    "C:\Users\$($_.Name)\AppData\Local\Google\Chrome\Application\chrome.exe"
})

# --- Main monitoring loop ---
while ($true) {
    # Get running Chrome PIDs for verification
    $runningPIDs = (Get-Process -Name chrome -ErrorAction SilentlyContinue).Id

    # Get all Chrome processes above memory threshold and filter out zombies
    $chromeProcesses = Get-WmiObject Win32_Process |
        Where-Object {
            $_.Name -eq "chrome.exe" -and
            $_.WorkingSetSize -gt ($thresholdMB * 1MB) -and
            $_.ExecutablePath -and
            ($chromePaths -contains $_.ExecutablePath) -and
            ($runningPIDs -contains $_.ProcessId)
        } |
        Sort-Object ProcessId -Descending  # Process with highest PID first

    foreach ($proc in $chromeProcesses) {
        try {
            # Try to get owner
            try {
                $ownerInfo = $proc.GetOwner()
                $username = "$($ownerInfo.Domain)\$($ownerInfo.User)"
            } catch {
                $username = "Unknown"
            }

            $ramMB     = [math]::Round($proc.WorkingSetSize / 1MB, 2)
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

            $entry = "[$timestamp] Killed Chrome process: PID $($proc.ProcessId), User: $username, Path: $($proc.ExecutablePath), RAM Usage: ${ramMB}MB"

            # Verify process still running before attempting to kill
            if (Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue) {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                Write-Host $entry -ForegroundColor Red
                $entry | Out-File -Append -FilePath $killLog
            } else {
                $msg = "[$timestamp] Skipped: PID $($proc.ProcessId) already exited."
                Write-Warning $msg
                $msg | Out-File -Append -FilePath $killLog
            }
        }
        catch {
            Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] Failed to kill PID=$($proc.ProcessId): $_"
        }
    }

    Write-Host "Next check in 15 minutes..." -ForegroundColor Cyan
    Start-Sleep -Seconds $checkDelay
}

# --- Restore original execution policy (won’t run unless loop is exited manually) ---
#Set-ExecutionPolicy -Scope Process -ExecutionPolicy $originalPolicy -Force
