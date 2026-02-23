# WinPatcher

## Overview
This PowerShell script is designed to automate **system package upgrades** using `winget` and capture a **network configuration snapshot** for logging purposes. It provides a clean interface for monitoring progress and saving logs.

> **Note:** This script requires **Windows PowerShell 5.1 or higher** and that `winget` is installed on your system.

---

## Features
- **Automatic Script Relaunch:** Ensures the script runs with `-NoExit` and `Bypass` execution policy.
- **Network Logging:** Captures a full `ipconfig /all` snapshot and saves it under `NetworkLogs` with a timestamped filename.
- **Winget Auto Upgrade:**  
  - Upgrades all installed packages
  - Runs silently with acceptance of package and source agreements
  - Includes unknown sources
- **Comprehensive Logging:** Creates a full transcript log of all operations in the script folder.
- **Safe and Organized:** All logs are timestamped and stored in structured directories for easy reference.

---

## Usage
1. Ensure **Windows PowerShell 5.1+** is installed.
2. Ensure `winget` is installed and accessible from PowerShell.
3. Place the script in a folder where you want logs to be saved.
4. Run the script:
   ```powershell
   .\WinPatcher.ps1
