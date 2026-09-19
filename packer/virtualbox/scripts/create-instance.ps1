# ============================================================
# Golden Image Factory - VirtualBox
# Windows launcher for create-instance.sh
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================="
Write-Host " Golden Image Factory - Instance Provisioning"
Write-Host "===================================================="
Write-Host ""

# ------------------------------------------------------------
# Locate this scripts directory
# ------------------------------------------------------------

$ScriptDir = $PSScriptRoot

if (-not $ScriptDir) {
    Write-Error "Unable to determine the scripts directory."
    exit 1
}

# ------------------------------------------------------------
# Path to the Bash provisioning script
# ------------------------------------------------------------

$BashScriptWindows = Join-Path $ScriptDir "create-instance.sh"

if (-not (Test-Path $BashScriptWindows)) {
    Write-Error "create-instance.sh was not found:"
    Write-Host "  $BashScriptWindows"
    exit 1
}

# ------------------------------------------------------------
# Convert Windows path to WSL path
#
# Example:
# C:\Users\...\scripts\create-instance.sh
#
# becomes:
# /mnt/c/Users/.../scripts/create-instance.sh
# ------------------------------------------------------------

$BashScriptWSL = wsl.exe wslpath -a "$BashScriptWindows"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to convert the Windows path to a WSL path."
    exit 1
}

$BashScriptWSL = $BashScriptWSL.Trim()

# ------------------------------------------------------------
# Launch the instance creation script inside WSL
# ------------------------------------------------------------

Write-Host "[INFO] Starting create-instance.sh in WSL..."
Write-Host ""

wsl.exe bash "$BashScriptWSL"

# ------------------------------------------------------------
# Check result
# ------------------------------------------------------------

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Error "Instance provisioning failed."
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "[OK] Instance provisioning completed."
Write-Host ""