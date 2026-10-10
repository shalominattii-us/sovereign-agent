<# 
.SYNOPSIS
    Sovereign Governor Service - A2D Protocol Deployment
    Add to Desktop / Auto-start on boot / Deploy as Windows Service

.DESCRIPTION
    Deploys the Governor Autonomous Service with full autonomy:
    - Auto-detect issues
    - Auto-resolve failures  
    - Auto-install updates
    - Auto-pull from repos
    - Auto-push commits
    - Auto-heal system
    Must survive reboots, run as background Windows service.
    GPO-locked execution policy requires IEX-only deployment.

.NOTES
    Author: OV (Omega Victor)
    Standard: SOVEREIGN MAPPING
#>

param(
    [string]$InstallPath = "C:\Sovereign\AE-Hub\Repos\sovereign-agent",
    [string]$ServiceName = "SovereignGovernor",
    [string]$DisplayName = "Sovereign Governor Autonomous Service",
    [string]$Description = "AEGENTIX Sovereign Governor - Fully autonomous system guardian. Auto-heals, auto-updates, auto-commits. Survives reboots.",
    [switch]$ForceReinstall,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch($Level) {
        "ERROR" { "[X] " }
        "WARN"  { "[!] " }
        "OK"    { "[OK] " }
        default { "[*] " }
    }
    $color = switch($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "OK" { "Green" } default { "Cyan" } }
    Write-Host "$prefix [$timestamp] $Message" -ForegroundColor $color
}

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Log "This script requires Administrator privileges. Re-run as Administrator." "ERROR"
    exit 1
}

if ($Uninstall) {
    Write-Log "Uninstalling $ServiceName..."
    if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
        Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $ServiceName | Out-Null
        Write-Log "Service removed." "OK"
    }
    $shortcutPath = "$env:PUBLIC\Desktop\$ServiceName.lnk"
    if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force; Write-Log "Desktop shortcut removed." "OK" }
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$ServiceName.lnk"
    if (Test-Path $startupPath) { Remove-Item $startupPath -Force; Write-Log "Startup shortcut removed." "OK" }
    Write-Log "Uninstall complete." "OK"
    exit 0
}

Write-Log "=== SOVEREIGN GOVERNOR A2D DEPLOYMENT ===" 
Write-Log "Service: $ServiceName"
Write-Log "Install Path: $InstallPath"

# Ensure install directory exists
if (-not (Test-Path $InstallPath)) {
    Write-Log "Creating install directory: $InstallPath"
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Write governor core script directly to file (avoiding here-string variable expansion issues)
$governorScriptPath = Join-Path $InstallPath "governor-core.ps1"
$governorScriptContent = @'
# Sovereign Governor Autonomous Service Core
# Runs as Windows Service, implements A2D protocol

$ErrorActionPreference = "Stop"

function Write-GovLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = "C:\Sovereign\Logs\governor.log"
    $entry = "[$timestamp] [$Level] $Message"
    $entry | Out-File -FilePath $logPath -Encoding UTF8 -Append
    if ($Level -eq "ERROR") { Write-Host "$entry" -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host "$entry" -ForegroundColor Yellow }
    elseif ($Level -eq "OK") { Write-Host "$entry" -ForegroundColor Green }
    else { Write-Host "$entry" -ForegroundColor Cyan }
}

function Test-GovAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-GovIEX {
    param([string]$ScriptBlock)
    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptBlock))
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded
        return $true
    } catch {
        Write-GovLog "IEX execution failed: $_" "ERROR"
        return $false
    }
}

# Auto-heal functions
function Auto-Heal-Service {
    param([string]$ServiceName)
    try {
        $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            Write-GovLog "Service $ServiceName not found, attempting recovery..." "WARN"
            return $false
        }
        if ($svc.Status -ne "Running") {
            Write-GovLog "Service $ServiceName stopped ($($svc.Status)), restarting..." "WARN"
            Start-Service $ServiceName -ErrorAction Stop
            Start-Sleep -Seconds 3
            $svc.Refresh()
            if ($svc.Status -eq "Running") {
                Write-GovLog "Service $ServiceName recovered." "OK"
                return $true
            } else {
                Write-GovLog "Service $ServiceName failed to restart." "ERROR"
                return $false
            }
        }
        return $true
    } catch {
        Write-GovLog "Auto-heal failed for $ServiceName: $_" "ERROR"
        return $false
    }
}

function Auto-Heal-Repo {
    param([string]$RepoPath)
    try {
        if (-not (Test-Path "$RepoPath\.git")) {
            Write-GovLog "Not a git repo: $RepoPath" "WARN"
            return $false
        }
        Set-Location $RepoPath
        $status = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-GovLog "Git status failed for $RepoPath: $status" "ERROR"
            return $false
        }
        if ($status) {
            Write-GovLog "Uncommitted changes in $RepoPath, staging..." "WARN"
            git add -A | Out-Null
            git commit -m "GOV AUTO-COMMIT: Auto-heal checkpoint $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
            Write-GovLog "Auto-committed changes in $RepoPath." "OK"
        }
        git pull --rebase | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-GovLog "Pulled latest for $RepoPath." "OK"
        } else {
            Write-GovLog "Pull failed for $RepoPath, attempting reset..." "WARN"
            git fetch --all | Out-Null
            git reset --hard origin/main | Out-Null
            Write-GovLog "Hard reset to origin/main for $RepoPath." "OK"
        }
        return $true
    } catch {
        Write-GovLog "Auto-heal repo failed for $RepoPath: $_" "ERROR"
        return $false
    }
}

function Auto-Heal-Docker {
    try {
        $containers = docker ps -a --format "{{.Names}} {{.Status}}" 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        $unhealthy = $containers | Where-Object { $_ -match "Exited|Dead|Created|Restarting" }
        if ($unhealthy) {
            Write-GovLog "Unhealthy containers detected: $($unhealthy.Count)" "WARN"
            foreach ($line in $unhealthy) {
                $name = ($line -split ' ')[0]
                Write-GovLog "Restarting container: $name" "WARN"
                docker restart $name | Out-Null
            }
        }
        return $true
    } catch {
        Write-GovLog "Docker auto-heal error: $_" "ERROR"
        return $false
    }
}

function Auto-Heal-DiskSpace {
    try {
        $drive = Get-PSDrive C
        $freePct = ($drive.Free / $drive.Used) * 100
        if ($freePct -lt 10) {
            Write-GovLog "Low disk space: $freePct% free. Cleaning temp..." "WARN"
            Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            docker system prune -f | Out-Null
            Write-GovLog "Disk cleanup complete." "OK"
        }
        return $true
    } catch {
        Write-GovLog "Disk space check failed: $_" "ERROR"
        return $false
    }
}

# Main service loop
Write-GovLog "=== GOVERNOR SERVICE STARTED ==="
Write-GovLog "A2D Protocol Active: Auto-detect, Auto-resolve, Auto-install, Auto-pull, Auto-push, Auto-heal"

$repos = @(
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-agent",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-cybernetics",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-osint",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-installer",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-eoc",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-custody",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-escrow",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-governance",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-eagleshield",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-dashboard",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-dashboard-react",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-agent-mesh",
    "C:\AEGENTIX-WORKSPACE\github-repos\sovereign-recon",
    "C:\AEGENTIX-WORKSPACE\github-repos\SOVEREIGN"
)

# Create log directory
New-Item -ItemType Directory -Path "C:\Sovereign\Logs" -Force | Out-Null

# Initial health check
Write-GovLog "Initializing Governor. Repos to monitor: $($repos.Count)"

# Main autonomous loop
while ($true) {
    try {
        # 1. Auto-heal critical services
        Auto-Heal-Service "docker" | Out-Null
        Auto-Heal-Service "w3svc" | Out-Null  # IIS if present

        # 2. Auto-heal repos (every cycle)
        foreach ($repo in $repos) {
            if (Test-Path $repo) {
                Auto-Heal-Repo $repo | Out-Null
            }
        }

        # 3. Auto-heal docker containers
        Auto-Heal-Docker | Out-Null

        # 4. Auto-heal disk space
        Auto-Heal-DiskSpace | Out-Null

        # 5. Auto-push any local commits (every 5 cycles)
        $global:pushCounter = if ($global:pushCounter) { $global:pushCounter + 1 } else { 1 }
        if ($global:pushCounter % 5 -eq 0) {
            foreach ($repo in $repos) {
                if (Test-Path "$repo\.git") {
                    Set-Location $repo
                    $ahead = git rev-list --count @{u}..HEAD 2>&1
                    if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
                        Write-GovLog "Pushing $ahead commits from $repo..." "WARN"
                        git push | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-GovLog "Auto-pushed $ahead commits from $repo." "OK"
                        } else {
                            Write-GovLog "Auto-push failed for $repo." "ERROR"
                        }
                    }
                }
            }
        }

        # 6. Self-update check (placeholder for future binary updates)
        # Write-GovLog "Governor cycle complete. Sleeping 60s..." "OK"
        
        Start-Sleep -Seconds 60
    } catch {
        Write-GovLog "Governor main loop error: $_" "ERROR"
        Start-Sleep -Seconds 30
    }
}
'@

# Write governor core script to file using UTF8 encoding
[IO.File]::WriteAllText($governorScriptPath, $governorScriptContent, [Text.Encoding]::UTF8)
Write-Log "Governor core script written to: $governorScriptPath" "OK"

# Create the service using sc.exe
$serviceExe = "powershell.exe"
$serviceArgs = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$governorScriptPath`""

Write-Log "Creating Windows service: $ServiceName"
try {
    if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
        if ($ForceReinstall) {
            Write-Log "Service exists, removing for reinstall..." "WARN"
            Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServiceName | Out-Null
        } else {
            Write-Log "Service already exists. Use -ForceReinstall to replace." "WARN"
            exit 1
        }
    }
    
    # Create service using sc.exe
    sc.exe create $ServiceName binPath= "`"$serviceExe`" $serviceArgs" DisplayName= "$DisplayName" start= auto obj= "LocalSystem" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "sc.exe create failed. Trying alternative method..." "WARN"
        New-Service -Name $ServiceName -BinaryPathName "`"$serviceExe`" $serviceArgs" -DisplayName $DisplayName -StartupType Automatic -Description $Description | Out-Null
    }
    Write-Log "Service created successfully." "OK"
} catch {
    Write-Log "Service creation failed: $_" "ERROR"
    exit 1
}

# Configure service recovery (restart on failure)
sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
Write-Log "Service recovery configured (restart on failure)." "OK"

# Set service description
sc.exe description $ServiceName "$Description" | Out-Null

# A2D: Add to Desktop (All Users)
$desktopPath = "$env:PUBLIC\Desktop\$ServiceName.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($desktopPath)
$shortcut.TargetPath = $serviceExe
$shortcut.Arguments = $serviceArgs
$shortcut.WorkingDirectory = $InstallPath
$shortcut.Description = "Start Sovereign Governor Service"
$shortcut.IconLocation = "C:\Windows\System32\shell32.dll,137"
$shortcut.Save()
Write-Log "Desktop shortcut created: $desktopPath" "OK"

# A2D: Auto-start on boot (Startup folder for current user)
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$ServiceName.lnk"
$shortcut2 = $shell.CreateShortcut($startupPath)
$shortcut2.TargetPath = $serviceExe
$shortcut2.Arguments = $serviceArgs
$shortcut2.WorkingDirectory = $InstallPath
$shortcut2.Description = "Auto-start Sovereign Governor on login"
$shortcut2.Save()
Write-Log "Startup shortcut created: $startupPath" "OK"

# Start the service
Write-Log "Starting $ServiceName..."
Start-Service $ServiceName -ErrorAction Stop
Start-Sleep -Seconds 3
$svc = Get-Service $ServiceName
if ($svc.Status -eq "Running") {
    Write-Log "SERVICE RUNNING: $ServiceName" "OK"
} else {
    Write-Log "Service may be starting... Status: $($svc.Status)" "WARN"
}

# Verify service is set to auto-start
$svcConfig = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"
Write-Log "Service StartMode: $($svcConfig.StartMode)" "OK"

Write-Log "=== A2D DEPLOYMENT COMPLETE ===" "OK"
Write-Log "Governor Autonomous Service deployed with:"
Write-Log "  [OK] Windows Service (auto-start, LocalSystem)"
Write-Log "  [OK] Desktop shortcut (All Users)"
Write-Log "  [OK] Startup shortcut (Auto-start on boot)"
Write-Log "  [OK] Auto-recovery on failure"
Write-Log "  [OK] IEX-compatible core script"
Write-Log ""
Write-Log "The Governor will now:"
Write-Log "  * Auto-detect issues every 60s"
Write-Log "  * Auto-heal services, repos, docker, disk"
Write-Log "  * Auto-pull/push git repos"
Write-Log "  * Survive reboots via Windows Service + Startup shortcut"
Write-Log ""
Write-Log "To manage: services.msc or 'sc query $ServiceName'"
Write-Log "Logs: C:\Sovereign\Logs\governor.log"