param(
    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# Golden Image Factory - VirtualBox Pre-flight Check
#
# This script NEVER launches "packer build".
#
# Exit codes:
#   0 = Ready to build
#   1 = Blocking errors detected
#
# Usage:
#   .\preflight-check.ps1
#
# Strict mode:
#   .\preflight-check.ps1 -Strict
#
# Strict mode treats warnings as blocking errors.
# ============================================================


# ------------------------------------------------------------
# Counters
# ------------------------------------------------------------

$script:PassCount = 0
$script:WarnCount = 0
$script:FailCount = 0


# ------------------------------------------------------------
# Display functions
# ------------------------------------------------------------

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Pass {
    param([string]$Message)

    $script:PassCount++
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Warn {
    param([string]$Message)

    $script:WarnCount++
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)

    $script:FailCount++
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Test-CommandAvailable {
    param(
        [string]$Command,
        [string]$Label
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Pass "$Label available"
        return $true
    }

    Fail "$Label not found in PATH"
    return $false
}


function Read-TextFile {
    param([string]$Path)

    return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
}


function Get-HclStringValue {
    param(
        [string]$Text,
        [string]$Name
    )

    $pattern =
        '(?m)^\s*' +
        [regex]::Escape($Name) +
        '\s*=\s*"([^"]*)"'

    $match = [regex]::Match($Text, $pattern)

    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}


function Get-YamlScalar {
    param(
        [string]$Text,
        [string]$Name
    )

    $pattern =
        '(?m)^\s*' +
        [regex]::Escape($Name) +
        ':\s*(.+?)\s*$'

    $match = [regex]::Match($Text, $pattern)

    if (-not $match.Success) {
        return $null
    }

    $value = $match.Groups[1].Value

    if ($value.Contains("#")) {
        $value = $value.Split("#")[0]
    }

    return $value.Trim().Trim('"').Trim("'")
}


function Test-RequiredFile {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Pass "$Label exists"
        return $true
    }

    Fail "$Label missing: $Path"
    return $false
}


function Test-Crlf {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = [System.IO.File]::ReadAllText($Path)

    if ($content.Contains("`r`n")) {
        Warn "$(Split-Path $Path -Leaf) uses CRLF line endings"
    }
    else {
        Pass "$(Split-Path $Path -Leaf) uses Unix/LF line endings"
    }
}


function Convert-ToWslPath {
    param([string]$WindowsPath)

    $result = & wsl.exe wslpath -a -u "$WindowsPath" 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $result) {
        return $null
    }

    return ($result | Select-Object -First 1).Trim()
}


function Test-BashSyntax {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $wslPath = Convert-ToWslPath $Path

    if (-not $wslPath) {
        Fail "Could not convert $Label path to WSL"
        return
    }

    & wsl.exe bash -n "$wslPath" 2>$null

    if ($LASTEXITCODE -eq 0) {
        Pass "$Label Bash syntax valid"
    }
    else {
        Fail "$Label contains a Bash syntax error"
    }
}


# ============================================================
# Determine project paths
# ============================================================

Write-Section "PROJECT LOCATION"

$ThisScript = $MyInvocation.MyCommand.Path
$LocalScriptsDir = Split-Path -Parent $ThisScript

# Expected:
#
# project/
# └── packer/
#     └── virtualbox/
#         └── scripts/
#             └── preflight-check.ps1

$VirtualBoxDir = Split-Path -Parent $LocalScriptsDir
$PackerDir     = Split-Path -Parent $VirtualBoxDir
$ProjectRoot   = Split-Path -Parent $PackerDir

Write-Host "Project root : $ProjectRoot"
Write-Host "VirtualBox   : $VirtualBoxDir"

if (Test-Path -LiteralPath $ProjectRoot) {
    Pass "Project root detected"
}
else {
    Fail "Project root cannot be detected"
}


# ============================================================
# Important paths
# ============================================================

$PackerFile = Join-Path $VirtualBoxDir "ubuntu.pkr.hcl"

$UserData = Join-Path $PackerDir "common\http\user-data"
$MetaData = Join-Path $PackerDir "common\http\meta-data"

$AnsibleDir = Join-Path $ProjectRoot "ansible"

$SitePlaybook     = Join-Path $AnsibleDir "site.yml"
$VerifyPlaybook   = Join-Path $AnsibleDir "tests\verify.yml"
$SmokePlaybook    = Join-Path $AnsibleDir "tests\smoke.yml"
$SecurityPlaybook = Join-Path $AnsibleDir "tests\security.yml"

$VirtualBoxVars =
    Join-Path $AnsibleDir "tests\vars\virtualbox.yml"

$GrubDefaults =
    Join-Path $AnsibleDir "roles\grub_hardening\defaults\main.yml"

$GrubTemplate =
    Join-Path $AnsibleDir "roles\grub_hardening\templates\40_custom_hardening.j2"

$NftablesDefaults =
    Join-Path $AnsibleDir "roles\nftables_hardening\defaults\main.yml"

$NftablesTemplate =
    Join-Path $AnsibleDir "roles\nftables_hardening\templates\nftables.conf.j2"

$GlobalScriptsDir =
    Join-Path $ProjectRoot "scripts"

$CleanupScript =
    Join-Path $GlobalScriptsDir "cleanup-image.sh"

$SealScript =
    Join-Path $GlobalScriptsDir "seal-image.sh"

$OpenScapScript =
    Join-Path $ProjectRoot "compliance\openscap\check-compliance.sh"

$OpenScapData =
    Join-Path $ProjectRoot "compliance\openscap\ssg-ubuntu2404-ds.xml"

$LynisScript =
    Join-Path $ProjectRoot "compliance\lynis\check-score.sh"

$ReportsDir =
    Join-Path $VirtualBoxDir "reports"


# ============================================================
# 1. Required tools
# ============================================================

Write-Section "HOST TOOLS"

$PackerAvailable =
    Test-CommandAvailable "packer" "Packer"

$VBoxAvailable =
    Test-CommandAvailable "VBoxManage" "VirtualBox CLI"

$WslAvailable =
    Test-CommandAvailable "wsl.exe" "WSL"

$SshKeygenAvailable =
    Test-CommandAvailable "ssh-keygen" "OpenSSH ssh-keygen"

$GitAvailable =
    Test-CommandAvailable "git" "Git"


if ($PackerAvailable) {
    $packerVersion = & packer version 2>&1 | Select-Object -First 1
    Write-Host "       $packerVersion"
}

if ($VBoxAvailable) {
    $vboxVersion = & VBoxManage --version 2>&1
    Write-Host "       VirtualBox $vboxVersion"
}

if ($WslAvailable) {

    & wsl.exe bash -lc "true" 2>$null

    if ($LASTEXITCODE -eq 0) {
        Pass "WSL Linux environment starts successfully"
    }
    else {
        Fail "WSL exists but Linux environment cannot start"
    }

    & wsl.exe bash -lc "command -v openssl >/dev/null" 2>$null

    if ($LASTEXITCODE -eq 0) {
        Pass "OpenSSL available inside WSL"
    }
    else {
        Warn "OpenSSL not found inside WSL"
    }

    & wsl.exe bash -lc "command -v bash >/dev/null" 2>$null

    if ($LASTEXITCODE -eq 0) {
        Pass "Bash available inside WSL"
    }
    else {
        Fail "Bash unavailable inside WSL"
    }
}


# ============================================================
# 2. Host hardware
# ============================================================

Write-Section "HOST RESOURCES"

try {

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

    if ($cpu.NumberOfLogicalProcessors -ge 4) {
        Pass "CPU has at least 4 logical processors"
    }
    else {
        Warn "Only $($cpu.NumberOfLogicalProcessors) logical processors detected"
    }

    if ($null -ne $cpu.VirtualizationFirmwareEnabled) {

        if ($cpu.VirtualizationFirmwareEnabled) {
            Pass "Hardware virtualization enabled"
        }
        else {
            Warn "Hardware virtualization appears disabled in firmware"
        }
    }
}
catch {
    Warn "Could not determine CPU virtualization status"
}


try {

    $os = Get-CimInstance Win32_OperatingSystem

    $freeRamGB = [math]::Round(
        $os.FreePhysicalMemory / 1MB,
        1
    )

    Write-Host "       Free RAM: $freeRamGB GB"

    if ($freeRamGB -ge 10) {
        Pass "Enough free RAM for an 8 GB build VM"
    }
    elseif ($freeRamGB -ge 8) {
        Warn "RAM is tight for an 8 GB VM: $freeRamGB GB free"
    }
    else {
        Fail "Less than 8 GB RAM currently free"
    }
}
catch {
    Warn "Could not determine free RAM"
}


try {

    $driveRoot = [System.IO.Path]::GetPathRoot($ProjectRoot)
    $driveName = $driveRoot.Substring(0, 1)

    $drive = Get-PSDrive -Name $driveName

    $freeDiskGB = [math]::Round(
        $drive.Free / 1GB,
        1
    )

    Write-Host "       Free disk: $freeDiskGB GB"

    if ($freeDiskGB -ge 30) {
        Pass "Enough disk space for build artifacts"
    }
    elseif ($freeDiskGB -ge 20) {
        Warn "Disk space may be tight: $freeDiskGB GB free"
    }
    else {
        Fail "Less than 20 GB disk space free"
    }
}
catch {
    Warn "Could not determine free disk space"
}


# ============================================================
# 3. Required project files
# ============================================================

Write-Section "PROJECT FILES"

Test-RequiredFile $PackerFile "Packer configuration" | Out-Null

Test-RequiredFile $UserData "Autoinstall user-data" | Out-Null
Test-RequiredFile $MetaData "Autoinstall meta-data" | Out-Null

Test-RequiredFile $SitePlaybook "Ansible site.yml" | Out-Null
Test-RequiredFile $VerifyPlaybook "Ansible verify.yml" | Out-Null
Test-RequiredFile $SmokePlaybook "Ansible smoke.yml" | Out-Null
Test-RequiredFile $SecurityPlaybook "Ansible security.yml" | Out-Null
Test-RequiredFile $VirtualBoxVars "VirtualBox test variables" | Out-Null

Test-RequiredFile $CleanupScript "cleanup-image.sh" | Out-Null
Test-RequiredFile $SealScript "seal-image.sh" | Out-Null

Test-RequiredFile $OpenScapScript "OpenSCAP validation script" | Out-Null
Test-RequiredFile $OpenScapData "OpenSCAP Ubuntu 24.04 datastream" | Out-Null
Test-RequiredFile $LynisScript "Lynis validation script" | Out-Null


# Stop advanced checks if main HCL does not exist.

if (-not (Test-Path $PackerFile)) {
    Write-Section "FINAL RESULT"
    Fail "Cannot continue without ubuntu.pkr.hcl"
    exit 1
}


$PackerText = Read-TextFile $PackerFile


# ============================================================
# 4. Find Packer variables file
# ============================================================

Write-Section "PACKER VARIABLES"

$VarCandidates =
    Get-ChildItem `
        -LiteralPath $VirtualBoxDir `
        -Filter "*.pkrvars.hcl" `
        -File `
        -ErrorAction SilentlyContinue

$VarFile = $null

foreach ($candidate in $VarCandidates) {

    $candidateText = Read-TextFile $candidate.FullName

    if (
        $candidateText -match '(?m)^\s*iso_url\s*=' -and
        $candidateText -match '(?m)^\s*ssh_username\s*='
    ) {
        $VarFile = $candidate.FullName
        break
    }
}

if ($null -eq $VarFile) {
    Fail "No usable *.pkrvars.hcl file found"
}
else {
    Pass "Packer variables file found: $(Split-Path $VarFile -Leaf)"
}

if ($null -ne $VarFile) {
    $VarsText = Read-TextFile $VarFile
}
else {
    $VarsText = ""
}


# ============================================================
# 5. ISO + checksum
# ============================================================

Write-Section "UBUNTU ISO"

$IsoUrl =
    Get-HclStringValue $VarsText "iso_url"

$IsoChecksum =
    Get-HclStringValue $VarsText "iso_checksum"

if (-not $IsoUrl) {
    Fail "iso_url is missing"
}
else {

    Pass "iso_url defined"

    if ($IsoUrl -match '^file:///') {

        $isoRawPath =
            $IsoUrl -replace '^file:///', ''

        $isoRawPath =
            [System.Uri]::UnescapeDataString($isoRawPath)

        $IsoPath =
            $isoRawPath.Replace("/", "\")

        if (Test-Path -LiteralPath $IsoPath) {

            Pass "Ubuntu ISO exists"
            Write-Host "       $IsoPath"

            if ($IsoChecksum -match '^sha256:(.+)$') {

                $ExpectedHash =
                    $Matches[1].ToLowerInvariant()

                Write-Host "       Calculating SHA256..."

                $ActualHash =
                    (Get-FileHash `
                        -LiteralPath $IsoPath `
                        -Algorithm SHA256
                    ).Hash.ToLowerInvariant()

                if ($ActualHash -eq $ExpectedHash) {
                    Pass "Ubuntu ISO SHA256 matches configuration"
                }
                else {
                    Fail "Ubuntu ISO SHA256 DOES NOT MATCH"
                    Write-Host "       Expected: $ExpectedHash"
                    Write-Host "       Actual  : $ActualHash"
                }
            }
            else {
                Fail "iso_checksum is missing or not SHA256"
            }
        }
        else {
            Fail "Ubuntu ISO not found: $IsoPath"
        }
    }
    else {
        Warn "ISO is not using a local file:/// URL"
    }
}


# ============================================================
# 6. Build account
# ============================================================

Write-Section "PACKER BUILD ACCOUNT"

$SshUsername =
    Get-HclStringValue $VarsText "ssh_username"

$SshPassword =
    Get-HclStringValue $VarsText "ssh_password"

$PrivateKeyConfigured =
    Get-HclStringValue $VarsText "ssh_private_key_file"


if ($SshUsername -eq "packer") {
    Pass "Build SSH username is packer"
}
else {
    Fail "Build SSH username must be packer; found '$SshUsername'"
}


if ($SshPassword) {

    Pass "Build sudo password is defined"

    if (
        $SshPassword.Length -lt 10 -or
        $SshPassword -eq "123"
    ) {
        Warn "Build password is weak/test-only"
    }

    if ($SshPassword.Contains("'")) {
        Fail "ssh_password contains a single quote and will break current shell execute_command quoting"
    }
}
else {
    Fail "ssh_password is missing"
}


# ============================================================
# 7. Autoinstall user-data
# ============================================================

Write-Section "AUTOINSTALL USER-DATA"

if (Test-Path $UserData) {

    $UserDataText = Read-TextFile $UserData

    $AutoinstallUsername =
        Get-YamlScalar $UserDataText "username"

    if ($AutoinstallUsername -eq "packer") {
        Pass "Autoinstall creates packer build account"
    }
    else {
        Fail "Autoinstall username is '$AutoinstallUsername', expected 'packer'"
    }


    # --------------------------------------------------------
    # Check separate filesystems expected by smoke tests
    # --------------------------------------------------------

    foreach ($mount in @("/tmp", "/var", "/home")) {

        if ($UserDataText.Contains($mount)) {
            Pass "Autoinstall references required mount $mount"
        }
        else {
            Warn "Could not find required mount $mount in user-data"
        }
    }
}


# ============================================================
# 8. Build SSH key
# ============================================================

Write-Section "BUILD SSH KEY"

if (-not $PrivateKeyConfigured) {
    Fail "ssh_private_key_file is missing"
}
else {

    $PrivateKeyPath =
        $PrivateKeyConfigured.Replace("/", "\")

    if (-not [System.IO.Path]::IsPathRooted($PrivateKeyPath)) {
        $PrivateKeyPath =
            Join-Path $VirtualBoxDir $PrivateKeyPath
    }

    if (Test-Path -LiteralPath $PrivateKeyPath) {

        Pass "Build SSH private key exists"

        if ($SshKeygenAvailable) {

            $derivedKey =
                & ssh-keygen -y -f "$PrivateKeyPath" 2>$null

            if ($LASTEXITCODE -eq 0 -and $derivedKey) {

                $derivedParts =
                    ($derivedKey.Trim() -split '\s+')

                $derivedComparable =
                    "$($derivedParts[0]) $($derivedParts[1])"


                $keyMatches =
                    [regex]::Matches(
                        $UserDataText,
                        'ssh-(?:ed25519|rsa|ecdsa-[^\s]+)\s+[A-Za-z0-9+/=]+'
                    )

                $foundMatchingKey = $false

                foreach ($keyMatch in $keyMatches) {

                    if ($keyMatch.Value -eq $derivedComparable) {
                        $foundMatchingKey = $true
                        break
                    }
                }

                if ($foundMatchingKey) {
                    Pass "Private build key matches authorized key in user-data"
                }
                else {
                    Fail "Build private key does NOT match any public key in user-data"
                }
            }
            else {
                Fail "ssh-keygen cannot read build private key"
            }
        }
    }
    else {
        Fail "Build SSH private key not found: $PrivateKeyPath"
    }
}


# ============================================================
# 9. Verify Linux password hash
# ============================================================

Write-Section "BUILD PASSWORD HASH"

if (
    $WslAvailable -and
    $SshPassword -and
    (Test-Path $UserData)
) {

    $hashMatch =
        [regex]::Match(
            $UserDataText,
            '\$6\$[^\s"'']+'
        )

    if ($hashMatch.Success) {

        $StoredPasswordHash =
            $hashMatch.Value

        Pass "SHA-512 password hash found in user-data"

        $hashParts =
            $StoredPasswordHash -split '\$'

        if ($hashParts.Count -eq 4) {

            $salt =
                $hashParts[2]

            $passwordBytes =
                [System.Text.Encoding]::UTF8.GetBytes(
                    $SshPassword
                )

            $passwordBase64 =
                [Convert]::ToBase64String(
                    $passwordBytes
                )

            $linuxCommand =
                "printf '%s' '$passwordBase64' | base64 -d | openssl passwd -6 -salt '$salt' -stdin"

            $generatedHash =
                & wsl.exe bash -lc "$linuxCommand" 2>$null

            if ($LASTEXITCODE -eq 0) {

                $generatedHash =
                    ($generatedHash | Select-Object -Last 1).Trim()

                if ($generatedHash -eq $StoredPasswordHash) {
                    Pass "ssh_password matches autoinstall password hash"
                }
                else {
                    Fail "ssh_password does NOT match password hash in user-data"
                }
            }
            else {
                Warn "Could not verify password hash using WSL/OpenSSL"
            }
        }
        else {
            Warn "Password hash uses a non-standard rounds format; automatic comparison skipped"
        }
    }
    else {
        Fail "No SHA-512 crypt password hash found in user-data"
    }
}


# ============================================================
# 10. GRUB build configuration
# ============================================================

Write-Section "GRUB CONFIGURATION"

$GrubHash =
    Get-HclStringValue $VarsText "grub_password_hash"


if (-not $GrubHash) {
    Fail "grub_password_hash is missing"
}
elseif (
    $GrubHash -match '^grub\.pbkdf2\.sha512\.\d+\.[A-Za-z0-9]+\.[A-Za-z0-9]+$' -and
    $GrubHash.Length -gt 100
) {
    Pass "GRUB PBKDF2 hash format looks valid"
}
else {
    Fail "grub_password_hash does not look like a valid GRUB PBKDF2 hash"
}


if ($PackerText.Contains(
    'grub_password_hash=${var.grub_password_hash}'
)) {
    Pass "Packer passes GRUB password hash to Ansible"
}
else {
    Fail "Packer does not pass grub_password_hash to Ansible"
}


if ($PackerText.Contains(
    'grub_password_enabled=true'
)) {
    Pass "GRUB password hardening enabled for build"
}
else {
    Fail "grub_password_enabled=true not found"
}


if (Test-Path $GrubDefaults) {

    $grubDefaultsText =
        Read-TextFile $GrubDefaults

    $grubSuperuser =
        Get-YamlScalar $grubDefaultsText "grub_superuser"

    if ($grubSuperuser -eq "admin") {
        Pass "Default GRUB superuser is admin"
    }
    else {
        Warn "Default GRUB superuser is '$grubSuperuser'"
    }
}


if (Test-Path $GrubTemplate) {

    $grubTemplateText =
        Read-TextFile $GrubTemplate

    if (
        $grubTemplateText -match 'set superusers=' -and
        $grubTemplateText -match 'password_pbkdf2'
    ) {
        Pass "GRUB template contains superuser and PBKDF2 configuration"
    }
    else {
        Fail "GRUB template appears incomplete"
    }
}


# ============================================================
# 11. Packer structure
# ============================================================

Write-Section "PACKER PIPELINE"

$AnsibleLocalCount =
    [regex]::Matches(
        $PackerText,
        'provisioner\s+"ansible-local"'
    ).Count

$RemoteAnsibleCount =
    [regex]::Matches(
        $PackerText,
        'provisioner\s+"ansible"\s*\{'
    ).Count


if ($AnsibleLocalCount -eq 2) {
    Pass "Two ansible-local provisioners configured"
}
else {
    Fail "Expected 2 ansible-local provisioners; found $AnsibleLocalCount"
}


if ($RemoteAnsibleCount -eq 0) {
    Pass "No native remote ansible provisioner remains"
}
else {
    Fail "Remote ansible provisioner still present"
}


if (
    $PackerText -match 'github\.com/hashicorp/ansible'
) {
    Pass "HashiCorp Ansible plugin declared"
}
else {
    Fail "HashiCorp Ansible plugin missing"
}


$InstallAnsibleIndex =
    $PackerText.IndexOf(
        "apt-get install -y ansible"
    )

$FirstAnsibleLocalIndex =
    $PackerText.IndexOf(
        'provisioner "ansible-local"'
    )

if (
    $InstallAnsibleIndex -ge 0 -and
    $FirstAnsibleLocalIndex -ge 0 -and
    $InstallAnsibleIndex -lt $FirstAnsibleLocalIndex
) {
    Pass "Ansible is installed before ansible-local runs"
}
else {
    Fail "Ansible installation is missing or occurs after ansible-local"
}


if ($PackerText -match 'disable_shutdown\s*=\s*true') {
    Pass "Packer automatic shutdown disabled"
}
else {
    Fail "disable_shutdown = true missing"
}


if ($PackerText -match 'shutdown_timeout\s*=\s*"5m"') {
    Pass "Shutdown timeout configured"
}
else {
    Warn "Expected shutdown_timeout = `"5m`""
}


# ============================================================
# 12. Provisioner ordering
# ============================================================

Write-Section "PROVISIONER ORDER"

$CleanupIndex =
    $PackerText.IndexOf("cleanup-image.sh")

$SealIndex =
    $PackerText.IndexOf("seal-image.sh")

$ReportDownloadIndex =
    $PackerText.IndexOf(
        'direction = "download"'
    )


if (
    $ReportDownloadIndex -ge 0 -and
    $CleanupIndex -gt $ReportDownloadIndex
) {
    Pass "Reports downloaded before cleanup"
}
else {
    Fail "Reports must be downloaded before cleanup"
}


if (
    $CleanupIndex -ge 0 -and
    $SealIndex -gt $CleanupIndex
) {
    Pass "cleanup-image.sh runs before seal-image.sh"
}
else {
    Fail "cleanup/sealing order is incorrect"
}


if ($PackerText.Contains("seal-image-test.sh")) {
    Fail "Old seal-image-test.sh reference still exists"
}
else {
    Pass "No old seal-image-test.sh reference"
}


$ProvisionerMatches =
    [regex]::Matches(
        $PackerText,
        'provisioner\s+"[^"]+"'
    )

if ($ProvisionerMatches.Count -gt 0) {

    $LastProvisioner =
        $ProvisionerMatches[
            $ProvisionerMatches.Count - 1
        ]

    $LastProvisionerText =
        $PackerText.Substring(
            $LastProvisioner.Index
        )

    if ($LastProvisionerText.Contains("seal-image.sh")) {
        Pass "seal-image.sh is the final provisioner"
    }
    else {
        Fail "seal-image.sh is NOT the final provisioner"
    }
}


if (
    $SealIndex -ge 0 -and
    $PackerText.Substring($SealIndex) -match 'expect_disconnect\s*=\s*true'
) {
    Pass "Sealing provisioner expects SSH disconnect"
}
else {
    Fail "seal-image.sh provisioner must use expect_disconnect = true"
}


# ============================================================
# 13. Ansible main playbook
# ============================================================

Write-Section "ANSIBLE HARDENING"

if (Test-Path $SitePlaybook) {

    $SiteText =
        Read-TextFile $SitePlaybook

    if ($SiteText -match '(?m)^\s*hosts:\s*servers\s*$') {
        Pass "site.yml targets servers group"
    }
    else {
        Fail "site.yml does not target servers"
    }


    $roleMatches =
        [regex]::Matches(
            $SiteText,
            '(?m)^\s{4}-\s+([A-Za-z0-9_.-]+)\s*$'
        )

    foreach ($roleMatch in $roleMatches) {

        $roleName =
            $roleMatch.Groups[1].Value

        $rolePath =
            Join-Path $AnsibleDir "roles\$roleName"

        if (Test-Path $rolePath -PathType Container) {
            Pass "Ansible role exists: $roleName"
        }
        else {
            Fail "Missing Ansible role directory: $roleName"
        }
    }
}


# ============================================================
# 14. Verification playbook
# ============================================================

Write-Section "ANSIBLE TEST SUITE"

if (Test-Path $VerifyPlaybook) {

    $VerifyText =
        Read-TextFile $VerifyPlaybook

    if ($VerifyText.Contains("smoke.yml")) {
        Pass "verify.yml imports smoke.yml"
    }
    else {
        Fail "verify.yml does not import smoke.yml"
    }

    if ($VerifyText.Contains("security.yml")) {
        Pass "verify.yml imports security.yml"
    }
    else {
        Fail "verify.yml does not import security.yml"
    }
}


# ============================================================
# 15. VirtualBox test variables
# ============================================================

if (Test-Path $VirtualBoxVars) {

    $VBoxVarsText =
        Read-TextFile $VirtualBoxVars

    $ExpectedLinuxUser =
        Get-YamlScalar `
            $VBoxVarsText `
            "platform_expected_admin_user"

    $ExpectedGrubUser =
        Get-YamlScalar `
            $VBoxVarsText `
            "platform_expected_grub_superuser"


    if ($ExpectedLinuxUser -eq "packer") {
        Pass "Tests expect Linux build user packer"
    }
    else {
        Fail "platform_expected_admin_user must be packer"
    }


    if ($ExpectedGrubUser -eq "admin") {
        Pass "Tests expect default GRUB superuser admin"
    }
    else {
        Fail "platform_expected_grub_superuser must currently be admin"
    }
}


# ============================================================
# 16. security.yml checks
# ============================================================

if (Test-Path $SecurityPlaybook) {

    $SecurityText =
        Read-TextFile $SecurityPlaybook


    if ($SecurityText.Contains(
        "expected_grub_superuser"
    )) {
        Pass "security.yml separates GRUB account from Linux account"
    }
    else {
        Fail "security.yml missing expected_grub_superuser"
    }


    if (
        $SecurityText -match 'set superusers=.*expected_admin_user'
    ) {
        Fail "security.yml still uses expected_admin_user for GRUB"
    }
    else {
        Pass "security.yml no longer uses Linux account for GRUB superuser"
    }


    if (
        $SecurityText -match 'password_pbkdf2.*expected_admin_user'
    ) {
        Fail "security.yml still uses expected_admin_user for GRUB password"
    }
    else {
        Pass "security.yml uses separate GRUB account for password test"
    }
}


# ============================================================
# 17. smoke.yml checks
# ============================================================

if (Test-Path $SmokePlaybook) {

    $SmokeText =
        Read-TextFile $SmokePlaybook


    if ($SmokeText.Contains(
        "expected_grub_superuser"
    )) {
        Pass "smoke.yml separates GRUB account"
    }
    else {
        Fail "smoke.yml missing expected_grub_superuser"
    }


    if ($SmokeText -match 'sudo\s+-n\s+id\s+-u') {
        Fail "Old sudo -n test still exists"
    }
    else {
        Pass "Old sudo -n test removed"
    }


    if (
        $SmokeText -match '(?s)Verify administrator can escalate privileges.*?become:\s*true'
    ) {
        Pass "Smoke test uses Ansible become for privilege escalation"
    }
    else {
        Warn "Could not confirm become:true in sudo smoke test"
    }
}


# ============================================================
# 18. Connection-breaking Ansible tasks
# ============================================================

Write-Section "BUILD CONNECTION SAFETY"

$RolesDir =
    Join-Path $AnsibleDir "roles"

if (Test-Path $RolesDir) {

    $DangerPatterns = @(
        'userdel\s+.*packer',
        'passwd\s+-l\s+.*packer',
        'usermod.*packer.*nologin',
        '/home/packer/\.ssh/authorized_keys'
    )

    $dangerFound = $false

    $roleFiles =
        Get-ChildItem `
            $RolesDir `
            -Recurse `
            -File `
            -Include *.yml,*.yaml,*.j2,*.sh

    foreach ($roleFile in $roleFiles) {

        $roleContent =
            Read-TextFile $roleFile.FullName

        foreach ($dangerPattern in $DangerPatterns) {

            if ($roleContent -match $dangerPattern) {

                Fail "Potential build connection killer in $($roleFile.FullName): $dangerPattern"
                $dangerFound = $true
            }
        }
    }

    if (-not $dangerFound) {
        Pass "Ansible roles do not disable/delete packer account early"
    }
}


# ============================================================
# 19. SSH hardening
# ============================================================

$SshDefaults =
    Join-Path $AnsibleDir "roles\ssh_hardening\defaults\main.yml"

if (Test-Path $SshDefaults) {

    $SshHardeningText =
        Read-TextFile $SshDefaults

    if (
        $SshHardeningText -match
        'ssh_password_authentication:\s*"no"'
    ) {
        Pass "SSH password authentication disabled by hardening"
    }
    else {
        Warn "Could not confirm PasswordAuthentication=no"
    }
}


# ============================================================
# 20. nftables / SSH access
# ============================================================

Write-Section "FIREWALL"

if (
    (Test-Path $NftablesDefaults) -and
    (Test-Path $NftablesTemplate)
) {

    $NftDefaultsText =
        Read-TextFile $NftablesDefaults

    $NftTemplateText =
        Read-TextFile $NftablesTemplate


    if ($NftDefaultsText -match 'nftables_ssh_port:\s*22') {
        Pass "nftables SSH port configured as 22"
    }
    else {
        Fail "nftables SSH port 22 not confirmed"
    }


    if (
        $NftTemplateText -match
        'tcp dport \{\{\s*nftables_ssh_port'
    ) {
        Pass "nftables template allows configured SSH port"
    }
    else {
        Fail "nftables template does not appear to allow SSH"
    }


    $sshRateMatch =
        [regex]::Match(
            $NftDefaultsText,
            'nftables_ssh_rate:\s*"([^"]+)"'
        )

    if ($sshRateMatch.Success) {

        $rate =
            $sshRateMatch.Groups[1].Value

        Write-Host "       SSH new-connection rate: $rate"

        if ($rate -eq "10/minute") {
            Warn "10/minute SSH rate limit may be tight during a Packer build"
        }
    }
}


# ============================================================
# 21. Cleanup script responsibilities
# ============================================================

Write-Section "CLEANUP / SEALING SEPARATION"

if (Test-Path $CleanupScript) {

    $CleanupText =
        Read-TextFile $CleanupScript

    $cleanupForbidden =
        @(
            'cloud-init clean',
            '/etc/machine-id',
            'ssh_host_',
            'passwd -l',
            'usermod .*nologin',
            'shutdown -P'
        )

    $cleanupProblem = $false

    foreach ($pattern in $cleanupForbidden) {

        if ($CleanupText -match $pattern) {
            Fail "cleanup-image.sh still performs sealing operation: $pattern"
            $cleanupProblem = $true
        }
    }


    if ($CleanupText -match 'rm\s+-rf\s+/tmp/\*') {
        Fail "cleanup-image.sh must not wipe all /tmp"
        $cleanupProblem = $true
    }


    if (-not $cleanupProblem) {
        Pass "cleanup-image.sh contains only build cleanup responsibilities"
    }


    foreach ($expected in @(
        "lynis",
        "openscap-scanner",
        "ansible",
        "autoremove",
        "apt-get clean"
    )) {

        if ($CleanupText.Contains($expected)) {
            Pass "cleanup-image.sh handles: $expected"
        }
        else {
            Warn "cleanup-image.sh does not mention: $expected"
        }
    }
}


# ============================================================
# 22. Sealing script
# ============================================================

if (Test-Path $SealScript) {

    $SealText =
        Read-TextFile $SealScript

    $sealRequired =
        @(
            'BUILD_USER="packer"',
            'authorized_keys',
            'passwd -l',
            'nologin',
            'cloud-init clean',
            '/etc/machine-id',
            'ssh_host_',
            'random-seed',
            'CURRENT_SCRIPT',
            'shutdown -P now'
        )

    foreach ($required in $sealRequired) {

        if ($SealText.Contains($required)) {
            Pass "seal-image.sh contains: $required"
        }
        else {
            Fail "seal-image.sh missing required operation: $required"
        }
    }


    if (
        $SealText.Contains(
            'CURRENT_SCRIPT="$(readlink -f "$0")"'
        )
    ) {
        Pass "Sealing protects currently running script"
    }
    else {
        Warn "Verify CURRENT_SCRIPT uses readlink -f `"`$0`" exactly"
    }


    if (
        $SealText.Contains(
            '! -path "${CURRENT_SCRIPT}"'
        )
    ) {
        Pass "Temporary cleanup excludes running seal script"
    }
    else {
        Fail "seal-image.sh /tmp cleanup does not exclude current script"
    }
}


# ============================================================
# 23. Bash syntax
# ============================================================

Write-Section "BASH SCRIPT SYNTAX"

if ($WslAvailable) {

    foreach ($script in @(
        @{
            Path  = $CleanupScript
            Label = "cleanup-image.sh"
        },
        @{
            Path  = $SealScript
            Label = "seal-image.sh"
        },
        @{
            Path  = $OpenScapScript
            Label = "OpenSCAP script"
        },
        @{
            Path  = $LynisScript
            Label = "Lynis script"
        }
    )) {

        Test-Crlf $script.Path
        Test-BashSyntax $script.Path $script.Label
    }
}


# ============================================================
# 24. Reports directory
# ============================================================

Write-Section "REPORTS"

if (-not (Test-Path $ReportsDir)) {

    try {
        New-Item `
            -ItemType Directory `
            -Path $ReportsDir `
            -Force |
            Out-Null

        Pass "Created reports directory"
    }
    catch {
        Fail "Unable to create reports directory"
    }
}
else {
    Pass "Reports directory exists"
}


try {

    $testFile =
        Join-Path $ReportsDir ".preflight-write-test"

    Set-Content `
        -LiteralPath $testFile `
        -Value "test"

    Remove-Item `
        -LiteralPath $testFile `
        -Force

    Pass "Reports directory is writable"
}
catch {
    Fail "Reports directory is not writable"
}


# ============================================================
# 25. Existing VirtualBox VM
# ============================================================

Write-Section "VIRTUALBOX STATE"

$VmName =
    Get-HclStringValue $VarsText "vm_name"

if ($VBoxAvailable -and $VmName) {

    $allVms =
        & VBoxManage list vms 2>$null

    $vmExists = $false

    foreach ($vmLine in $allVms) {

        if ($vmLine -match '^"([^"]+)"') {

            if ($Matches[1] -eq $VmName) {
                $vmExists = $true
                break
            }
        }
    }

    if ($vmExists) {
        Fail "VirtualBox VM '$VmName' already exists"
    }
    else {
        Pass "No existing VirtualBox VM named '$VmName'"
    }


    $runningVms =
        & VBoxManage list runningvms 2>$null

    if ($runningVms) {
        Warn "Other VirtualBox VM(s) currently running"
        $runningVms | ForEach-Object {
            Write-Host "       $_"
        }
    }
    else {
        Pass "No other VirtualBox VMs currently running"
    }
}


# ============================================================
# 26. Existing Packer output
# ============================================================

Write-Section "PACKER OUTPUT"

$DefaultOutput =
    Join-Path $VirtualBoxDir "output-ubuntu"

if (Test-Path $DefaultOutput) {

    $existingArtifacts =
        Get-ChildItem `
            -LiteralPath $DefaultOutput `
            -Force `
            -ErrorAction SilentlyContinue

    if ($existingArtifacts.Count -gt 0) {
        Fail "output-ubuntu already contains artifacts; rename/delete it before build"
    }
    else {
        Warn "output-ubuntu exists but is empty"
    }
}
else {
    Pass "No previous output-ubuntu directory"
}


# ============================================================
# 28. Packer formatting
# ============================================================

Write-Section "PACKER STATIC VALIDATION"

if ($PackerAvailable) {

    Push-Location $VirtualBoxDir

    try {

        & packer fmt -check "ubuntu.pkr.hcl" 2>&1 |
            Out-Null

        if ($LASTEXITCODE -eq 0) {
            Pass "ubuntu.pkr.hcl formatting valid"
        }
        else {
            Fail "Run: packer fmt ubuntu.pkr.hcl"
        }


        Write-Host ""
        Write-Host "Running packer init..." -ForegroundColor Cyan

        $initOutput =
            & packer init . 2>&1

        if ($LASTEXITCODE -eq 0) {
            Pass "packer init successful"
        }
        else {
            Fail "packer init failed"

            $initOutput |
                ForEach-Object {
                    Write-Host "       $_"
                }
        }


        Write-Host ""
        Write-Host "Running packer validate..." -ForegroundColor Cyan

        $validateOutput =
            & packer validate . 2>&1

        if ($LASTEXITCODE -eq 0) {

            Pass "packer validate successful"

            foreach ($line in $validateOutput) {

                if (
                    $line -match
                    'shutdown_command was not specified'
                ) {
                    Write-Host ""
                    Write-Host "       Expected warning: shutdown is handled by seal-image.sh" -ForegroundColor DarkYellow
                }
            }
        }
        else {

            Fail "packer validate failed"

            Write-Host ""

            $validateOutput |
                ForEach-Object {
                    Write-Host "       $_"
                }
        }

    }
    finally {
        Pop-Location
    }
}


# ============================================================
# FINAL RESULT
# ============================================================

Write-Section "PRE-FLIGHT RESULT"

Write-Host ""
Write-Host "PASS : $script:PassCount" -ForegroundColor Green
Write-Host "WARN : $script:WarnCount" -ForegroundColor Yellow
Write-Host "FAIL : $script:FailCount" -ForegroundColor Red
Write-Host ""


if ($script:FailCount -gt 0) {

    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " BUILD NOT READY" -ForegroundColor Red
    Write-Host " Fix all FAIL items before running packer build." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red

    exit 1
}


if ($Strict -and $script:WarnCount -gt 0) {

    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host " BUILD NOT READY IN STRICT MODE" -ForegroundColor Yellow
    Write-Host " Resolve warnings before continuing." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow

    exit 1
}


Write-Host "============================================================" -ForegroundColor Green
Write-Host " PRE-FLIGHT PASSED" -ForegroundColor Green
Write-Host ""
Write-Host " Configuration is ready for the first complete build." -ForegroundColor Green
Write-Host ""
Write-Host " This script did NOT launch packer build." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

exit 0