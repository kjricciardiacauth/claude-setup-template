#Requires -Version 5.1
<#
.SYNOPSIS
    Install the Tier 1 + Tier 2 CLI tools used by the Claude Code workflow.

.DESCRIPTION
    Idempotent. Safe to re-run. Uses winget where available, scoop as a relief
    valve for the two tools winget doesn't carry (gron, gh-dash).

    Tier 1 (always recommended): rg fd bat fzf jq xh zoxide
    Tier 2 (install-on-trigger): lazygit gron uv starship gh-dash

    Default: -Tier All installs both. Pass -Tier 1 or -Tier 2 to limit.

.PARAMETER Tier
    Which tier to install. "1" (Tier 1 only), "2" (Tier 2 only), or "All" (default).

.EXAMPLE
    .\install-cli.ps1
    # installs both tiers

.EXAMPLE
    .\install-cli.ps1 -Tier 1
    # only Tier 1
#>

param(
    [ValidateSet("1", "2", "All")]
    [string]$Tier = "All"
)

$ErrorActionPreference = "Continue"

function Ensure-Winget {
    param([string]$Id, [string]$Name)
    $found = winget list --id $Id -e --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id
    if ($found) {
        Write-Host "[ok]      $Name already installed"
    } else {
        Write-Host "[install] $Name..."
        winget install --id $Id -e --accept-source-agreements --accept-package-agreements --silent
    }
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "[ok]      scoop already installed"
        return $true
    }
    Write-Host "[install] scoop (for tools winget does not carry)..."
    try {
        # scoop install requires unrestricted execution for the one-liner
        Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin:`$false"
        return $true
    } catch {
        Write-Warning "scoop install failed: $($_.Exception.Message)"
        Write-Warning "Skipping scoop-only tools (gron, gh-dash)"
        return $false
    }
}

function Ensure-Scoop-Pkg {
    param([string]$Pkg)
    $list = scoop list 2>$null | Out-String
    if ($list -match "(?m)^$Pkg\s") {
        Write-Host "[ok]      $Pkg already installed (scoop)"
    } else {
        Write-Host "[install] $Pkg (scoop)..."
        scoop install $Pkg
    }
}

# Tier 1 - winget only, always available
if ($Tier -in @("1", "All")) {
    Write-Host "=== Tier 1 CLI foundation ===" -ForegroundColor Cyan
    Ensure-Winget -Id "BurntSushi.ripgrep.MSVC" -Name "ripgrep (rg)"
    Ensure-Winget -Id "sharkdp.fd"              -Name "fd"
    Ensure-Winget -Id "sharkdp.bat"             -Name "bat"
    Ensure-Winget -Id "junegunn.fzf"            -Name "fzf"
    Ensure-Winget -Id "jqlang.jq"               -Name "jq"
    Ensure-Winget -Id "ducaale.xh"              -Name "xh"
    Ensure-Winget -Id "ajeetdsouza.zoxide"      -Name "zoxide"
    Write-Host ""
}

# Tier 2 - winget for most, scoop for two
if ($Tier -in @("2", "All")) {
    Write-Host "=== Tier 2 CLI extras ===" -ForegroundColor Cyan
    Ensure-Winget -Id "JesseDuffield.lazygit"   -Name "lazygit"
    Ensure-Winget -Id "astral-sh.uv"            -Name "uv (Python)"
    Ensure-Winget -Id "Starship.Starship"       -Name "starship"

    # gron + gh-dash live in scoop only
    $scoopOk = Ensure-Scoop
    if ($scoopOk) {
        Ensure-Scoop-Pkg "gron"
        Ensure-Scoop-Pkg "gh-dash"
    }
    Write-Host ""
}

# PowerShell profile additions - zoxide init + fzf-friendly history search
# Idempotent: only appends if the marker line isn't already present.
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileMarker = "# --- claude-setup-template CLI foundation ---"
$profileBlock = @"

$profileMarker
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (starship init powershell | Out-String) })
}
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
# --- end claude-setup-template CLI foundation ---
"@
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if (-not (Test-Path $profilePath)) { Set-Content -Path $profilePath -Value "" -Encoding UTF8 }
if (Select-String -Path $profilePath -SimpleMatch $profileMarker -Quiet) {
    Write-Host "[ok]      PowerShell profile already has CLI foundation block"
} else {
    Add-Content -Path $profilePath -Value $profileBlock -Encoding UTF8
    Write-Host "[ok]      appended CLI foundation block to $profilePath"
}

Write-Host ""
Write-Host "=== CLI install complete ===" -ForegroundColor Green
Write-Host "Open a new terminal for PATH + profile changes to take effect."
