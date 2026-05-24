#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap a Claude Code dev environment from this template repo.

.DESCRIPTION
    Idempotent. Safe to re-run. Creates junctions/links from ~/.claude/ to this
    repo's claude-config/, memory/, skills/, commands/ so Claude Code reads
    everything from git instead of from a one-off local install.

    Designed to be invoked by Claude Code in auto mode - all parameters are
    flags, no interactive prompts. See AGENTS.md for the autopilot flow.

.PARAMETER Username
    Your GitHub username. Set as git user.name on this repo.

.PARAMETER Email
    Your git commit email. Set as git user.email on this repo.

.PARAMETER SkipCli
    Skip installing the Tier 1 CLI tools (rg, fd, bat, fzf, jq, xh, zoxide).
    Use this if you'll run install-cli.ps1 separately or already have them.

.EXAMPLE
    .\bootstrap.ps1 -Username "alice" -Email "alice@example.com"

.EXAMPLE
    .\bootstrap.ps1 -Username "alice" -Email "alice@example.com" -SkipCli
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Email,

    [switch]$SkipCli
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

# Set execution policy for user scope so wrangler/npm scripts work later.
# If a higher scope already permits (e.g. Bypass), this throws a terminating
# error - swallow it via try/catch since the override means scripts already run.
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
} catch {
    Write-Host "[skip]    execution policy already set by higher scope" -ForegroundColor DarkGray
}

Write-Host "=== Claude Code dev environment bootstrap ===" -ForegroundColor Cyan
Write-Host "Identity: $Username / $Email"
Write-Host ""

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

# Required tooling
Ensure-Winget -Id "Git.Git"       -Name "Git"
Ensure-Winget -Id "GitHub.cli"    -Name "GitHub CLI"
Ensure-Winget -Id "OpenJS.NodeJS" -Name "Node.js"

# Refresh PATH so npm becomes callable after a fresh node install
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

function Ensure-Npm {
    param([string]$Pkg, [string]$Cmd)
    # Check PATH first - more reliable than `npm list -g`, which fails ENOENT
    # if %APPDATA%\npm doesn't exist (common on system-wide Node installs).
    if ($Cmd -and (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "[ok]      $Pkg already installed ($Cmd on PATH)"
        return
    }
    # Ensure npm global dir exists before install
    $npmGlobalDir = "$env:APPDATA\npm"
    if (-not (Test-Path $npmGlobalDir)) {
        New-Item -ItemType Directory -Force -Path $npmGlobalDir | Out-Null
    }
    Write-Host "[install] $Pkg..."
    npm install -g $Pkg
}

Ensure-Npm -Pkg "@anthropic-ai/claude-code" -Cmd "claude"

# Helper for junction creation - idempotent, validates existing link
function Ensure-Junction {
    param([string]$Source, [string]$Target, [string]$Name)
    if (-not (Test-Path $Source)) {
        New-Item -Path $Source -ItemType Directory -Force | Out-Null
    }
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.Attributes -match "ReparsePoint") {
            Write-Host "[ok]      $Name junction already exists"
            return
        }
        Write-Warning "$Target exists and is NOT a junction. Move/rename it manually, then re-run."
        return
    }
    New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
    Write-Host "[ok]      created $Name junction $Target -> $Source"
}

# Memory junction - the path Claude Code reads from is derived from USERPROFILE
$memoryTarget = Join-Path $repoRoot "memory"
$claudeProjectName = $env:USERPROFILE.Replace(':', '-').Replace('\', '-')
$memoryLink = "$env:USERPROFILE\.claude\projects\$claudeProjectName\memory"
$memoryParent = Split-Path $memoryLink -Parent
if (-not (Test-Path $memoryParent)) {
    New-Item -Path $memoryParent -ItemType Directory -Force | Out-Null
}
Ensure-Junction -Source $memoryTarget -Target $memoryLink -Name "memory"

# Commands, skills, rules, hooks junctions
Ensure-Junction -Source (Join-Path $repoRoot "commands")            -Target "$env:USERPROFILE\.claude\commands" -Name "commands"
Ensure-Junction -Source (Join-Path $repoRoot "skills")              -Target "$env:USERPROFILE\.claude\skills"   -Name "skills"
Ensure-Junction -Source (Join-Path $repoRoot "claude-config\rules") -Target "$env:USERPROFILE\.claude\rules"    -Name "rules"
Ensure-Junction -Source (Join-Path $repoRoot "claude-config\hooks") -Target "$env:USERPROFILE\.claude\hooks"    -Name "hooks"

# User-scope CLAUDE.md - imports core rules from this repo
$claudeMdPath = "$env:USERPROFILE\.claude\CLAUDE.md"
$coreRulesPath = (Join-Path $repoRoot "memory\core-rules.md").Replace('\', '/')
$claudeMdContent = "@$coreRulesPath`n"
if (-not (Test-Path $claudeMdPath)) {
    Set-Content -Path $claudeMdPath -Value $claudeMdContent -Encoding UTF8
    Write-Host "[ok]      created ~/.claude/CLAUDE.md -> core-rules.md"
} else {
    Write-Host "[ok]      ~/.claude/CLAUDE.md already exists (not overwritten)"
}

# Settings link - canonical claude-config/settings.json -> ~/.claude/settings.json
# Prefer symlink (Developer Mode), fall back to hard link.
$settingsSource = Join-Path $repoRoot "claude-config\settings.windows.json"
$settingsTarget = "$env:USERPROFILE\.claude\settings.json"
if (-not (Test-Path $settingsSource)) {
    Write-Warning "claude-config/settings.json missing in repo - skipping settings link (run 'git pull' first)"
} else {
    $linkNeeded = $true
    if (Test-Path $settingsTarget) {
        $item = Get-Item $settingsTarget -Force
        if ($item.LinkType -in @("SymbolicLink", "HardLink")) {
            Write-Host "[ok]      settings.json link already exists ($($item.LinkType))"
            $linkNeeded = $false
        } else {
            $backup = "$settingsTarget.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item $settingsTarget $backup
            Write-Host "[backup]  existing settings.json -> $backup"
        }
    }
    if ($linkNeeded) {
        try {
            New-Item -ItemType SymbolicLink -Path $settingsTarget -Target $settingsSource -ErrorAction Stop | Out-Null
            Write-Host "[ok]      created settings.json symlink (Developer Mode active)"
        } catch {
            cmd /c mklink /H $settingsTarget $settingsSource | Out-Null
            if (Test-Path $settingsTarget) {
                Write-Host "[ok]      created settings.json hard link (enable Developer Mode for symlink - more robust)"
            } else {
                Write-Warning "Failed to link settings.json - copy manually: Copy-Item '$settingsSource' '$settingsTarget'"
            }
        }
    }
}

# Per-repo git identity (commits to this repo use the values you passed in)
$currentEmail = git -C $repoRoot config user.email 2>$null
if ($currentEmail -ne $Email) {
    git -C $repoRoot config user.name $Username
    git -C $repoRoot config user.email $Email
    Write-Host "[ok]      set repo identity: $Username / $Email"
} else {
    Write-Host "[ok]      repo identity already configured ($Email)"
}

# Tier 1 CLI tools - skip if -SkipCli or run install-cli.ps1 if available
if (-not $SkipCli) {
    $cliInstaller = Join-Path $repoRoot "install-cli.ps1"
    if (Test-Path $cliInstaller) {
        Write-Host ""
        Write-Host "=== CLI tools ===" -ForegroundColor Cyan
        & $cliInstaller -Tier All
    } else {
        Write-Host "[skip]    install-cli.ps1 not found - skipping CLI tools"
    }
}

# Verification - confirm everything is in place
Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
$checks = @(
    @{Name="memory junction";       Test={ Test-Path "$memoryLink\MEMORY.md" -ErrorAction SilentlyContinue }},
    @{Name="commands junction";     Test={ (Get-Item "$env:USERPROFILE\.claude\commands" -Force -EA SilentlyContinue).Attributes -match "ReparsePoint" }},
    @{Name="skills junction";       Test={ (Get-Item "$env:USERPROFILE\.claude\skills" -Force -EA SilentlyContinue).Attributes -match "ReparsePoint" }},
    @{Name="rules junction";        Test={ (Get-Item "$env:USERPROFILE\.claude\rules" -Force -EA SilentlyContinue).Attributes -match "ReparsePoint" }},
    @{Name="hooks junction";        Test={ (Get-Item "$env:USERPROFILE\.claude\hooks" -Force -EA SilentlyContinue).Attributes -match "ReparsePoint" }},
    @{Name="settings link";         Test={ $i=Get-Item $settingsTarget -Force -EA SilentlyContinue; $i.LinkType -in @("SymbolicLink","HardLink") }},
    @{Name="~/.claude/CLAUDE.md";   Test={ Test-Path $claudeMdPath }},
    @{Name="claude CLI installed";  Test={ (Get-Command claude -EA SilentlyContinue) -ne $null }},
    @{Name="git identity set";      Test={ (git -C $repoRoot config user.email) -eq $Email }}
)
$failed = 0
foreach ($c in $checks) {
    $ok = & $c.Test
    if ($ok -is [array]) { $ok = $ok[-1] }
    if ($ok) { Write-Host "[PASS]    $($c.Name)" } else { Write-Host "[FAIL]    $($c.Name)" -ForegroundColor Red; $failed++ }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "=== Bootstrap complete - all checks passed ===" -ForegroundColor Green
} else {
    Write-Host "=== Bootstrap complete with $failed failed check(s) ===" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:"
$ghStatus = gh auth status 2>&1 | Out-String
if ($ghStatus -notmatch "Logged in to github\.com") {
    Write-Host "  1. gh auth login                       (authenticate as $Username)"
}
Write-Host "  2. Customize claude-config/hooks/*.template files - rename to .ps1 and fill in your rules"
Write-Host "  3. Customize memory/MEMORY.md.template and memory/core-rules.md.template - rename to .md and fill in your project context"
Write-Host "  4. Recommended: enable Windows Developer Mode (Settings -> For developers)"
Write-Host "     Then re-run this script to upgrade settings.json hard link -> symlink (survives atomic-rename)"
Write-Host "  5. Open a new terminal so PATH refreshes, then run: claude"
