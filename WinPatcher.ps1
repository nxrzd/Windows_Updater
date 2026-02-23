#Requires -Version 5.1
param([switch]$Launched)

# =============================
# Relaunch logic (keeps -NoExit and bypass)
# =============================
if (-not $Launched) {
    Start-Process powershell -ArgumentList @(
        "-NoLogo", "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-NoExit",
        "-File", $PSCommandPath,
        "-Launched"
    ) -WindowStyle Normal
    return
}

# =============================
# UI Colors
# =============================
try {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    Clear-Host
}
catch {}

# =============================
# STATIC START SCREEN
# =============================
function Show-Banner {
    Clear-Host
    Write-Host @'
 __      __.__      __________         __         .__                  
/  \    /  \__| ____\______   \_____ _/  |_  ____ |  |__   ___________ 
\   \/\/   /  |/    \|     ___/\__  \\   __\/ ___\|  |  \_/ __ \_  __ \
 \        /|  |   |  \    |     / __ \|  | \  \___|   Y  \  ___/|  | \/
  \__/\  / |__|___|  /____|    (____  /__|  \___  >___|  /\___  >__|   
       \/          \/               \/          \/     \/     \/       
'@
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "          WINGET AUTO UPGRADE + NETWORK LOGGER"
    Write-Host "          Author: Noah Richardson"
    Write-Host "          GitHub: github.com/nxrzd/WinPatcher"
    Write-Host "          Copyright (c) 2026 GPL-3.0 License"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Press ENTER to initiate system sequence..."
    Write-Host ""
}

Show-Banner

# Wait for Enter key
do {
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} until ($key.VirtualKeyCode -eq 13)

Clear-Host

# =============================
# MAIN PROGRAM VARIABLES
# =============================
$ScriptRoot = Split-Path -Parent $PSCommandPath
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Log = Join-Path $ScriptRoot ("Winget-Log_{0}_{1}.txt" -f $TimeStamp, $PID)
$NetFolder = Join-Path $ScriptRoot "NetworkLogs"
if (-not (Test-Path $NetFolder)) {
    New-Item -ItemType Directory -Path $NetFolder | Out-Null
}
$NetLog = Join-Path $NetFolder ("IPConfig_{0}.txt" -f $TimeStamp)

Start-Transcript -Path $Log | Out-Null

# =============================
# Network Logging
# =============================
Write-Host "[+] Capturing Network Configuration..."
$header = @"
============================================================
 NETWORK CONFIGURATION SNAPSHOT
 Date: $(Get-Date)
 Machine: $env:COMPUTERNAME
 User: $env:USERNAME
============================================================

"@
$header | Out-File $NetLog -Encoding UTF8
ipconfig /all | Out-File $NetLog -Append -Encoding UTF8

Add-Content -Path $Log -Value $header
Add-Content -Path $Log -Value (ipconfig /all)

Write-Host "[OK] Network log saved to:"
Write-Host "     $NetLog"
Write-Host ""

# =============================
# Helper Function: Test Command
# =============================
function Test-Command {
    param([string]$Name)
    try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

# =============================
# Windows Version Detection
# =============================
$OSInfo = Get-ComputerInfo -Property "WindowsProductName"
$WindowsVersion = if ($OSInfo.WindowsProductName -like "*Windows 11*") { "11" } else { "10" }

# =============================
# Check System Uptime
# =============================
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeHours = (New-TimeSpan -Start $lastBoot -End (Get-Date)).TotalHours

if ($uptimeHours -gt 12) {
    Write-Host "[INFO] System uptime is over 12 hours ($([math]::Round($uptimeHours,2)) hours)."
    Write-Host "       It is recommended to restart your computer before running upgrades."
    Write-Host "       DISCLAIMER: Skipping restart may cause some issues with package updates."
    Write-Host ""
    
    # Interactive prompt for restart
    $restartChoice = Read-Host "Do you want to restart now before continuing? (Y/N)"
    if ($restartChoice -match '^[Yy]') {
        Write-Host "[INFO] Restarting system..."
        Restart-Computer
        return
    }
    else {
        Write-Host "[INFO] Proceeding without restart..."
        Write-Host ""
    }
}

# =============================
# Ensure Windows App Installer
# =============================
function Test-AppInstaller {
    try {
        Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if (-not (Test-AppInstaller) -and $WindowsVersion -eq "10") {
    Write-Host "[INFO] Windows App Installer not found. Attempting to install via Microsoft Store..."
    try {
        # Try installing via winget
        winget install --id Microsoft.DesktopAppInstaller -e --silent
        Write-Host "[OK] App Installer installed."
    }
    catch {
        Write-Host "[ERROR] Could not install App Installer automatically. Please install from the Microsoft Store:"
        Write-Host "       https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
        Stop-Transcript | Out-Null
        return
    }
}

# =============================
# Ensure Windows Terminal
# =============================
$TerminalInstalled = Test-Command "wt"

if (-not $TerminalInstalled) {
    if ($WindowsVersion -eq "10") {
        Write-Host "[INFO] Installing Windows Terminal for Windows 10..."
        try {
            winget install --id Microsoft.WindowsTerminal -e --silent
        }
        catch {
            Write-Host "[WARNING] Automatic installation failed. Please install manually from the Microsoft Store:"
            Write-Host "       https://www.microsoft.com/store/productId/9N0DX20HK701"
        }
    }
    else {
        Write-Host "[INFO] Windows Terminal not detected. Attempting installation for Windows 11..."
        try {
            winget install --id Microsoft.WindowsTerminal -e --silent
        }
        catch {
            Write-Host "[WARNING] Could not install automatically. Please download from the Microsoft Store:"
            Write-Host "       https://www.microsoft.com/store/productId/9N0DX20HK701"
        }
    }
}
else {
    Write-Host "[OK] Windows Terminal is already installed."
}
Write-Host ""

# =============================
# Winget Upgrade
# =============================
if (Test-Command "winget") {

    Write-Host "[+] Running winget upgrade..."
    $upgradeArgs = @(
        "upgrade", "--all", "--silent", "--include-unknown",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--disable-interactivity"
    )

    & winget @upgradeArgs 2>&1 | Out-Host

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] Upgrade complete."
    }
    else {
        Write-Host ""
        Write-Host "[WARNING] winget exited with code $LASTEXITCODE"
    }
}
else {
    Write-Host "[ERROR] winget not found."
}

# =============================
# Wrap Up
# =============================
Stop-Transcript | Out-Null

Write-Host ""
Write-Host "============================================================"
Write-Host "   OPERATION COMPLETE - PRESS ENTER TO CLOSE"
Write-Host "============================================================"
Read-Host
