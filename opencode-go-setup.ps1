# OpenCode Go Setup -- configuration manager (Windows)
#
# Run:
#   powershell -ExecutionPolicy Bypass -File "...\opencode-go-setup.ps1"
#
# Menu:
#   1 = DeepSeek V4 Flash via opencode-go
#   2 = DeepSeek V4 Pro via opencode-go
#   3 = restore the pre-install OpenCode configuration

# This script may be executed via irm | iex inside the user's current session,
# where exit would close the user's terminal window. All aborts therefore go
# through Die -> throw sentinel, swallowed by the dispatcher's try/catch at the
# bottom.

$SCRIPT_VERSION   = '1.0.0'
$FLASH_MODEL      = 'opencode-go/deepseek-v4-flash'
$PRO_MODEL        = 'opencode-go/deepseek-v4-pro'
$PROVIDER         = 'opencode-go'
$BACKUP_DIRNAME   = 'backup-opencode-go'
$ABORT_SENTINEL   = '__OPENCODE_GO_SETUP_ABORT__'

$script:Model = ''   # decided by the menu choice

# ---------------------------------------------------------------- output helpers

function Write-Ok   { param($m) Write-Host '[OK]  ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn { param($m) Write-Host '[!]   ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Head { param($m) Write-Host ''; Write-Host $m -ForegroundColor White }
function Write-Dim  { param($m) Write-Host $m -ForegroundColor DarkGray }
function Die {
    param($m)
    Write-Host ''
    Write-Host "[X] $m" -ForegroundColor Red
    throw $ABORT_SENTINEL
}

# ---------------------------------------------------------------- paths

$ConfigDir = if ($env:OPENCODE_CONFIG_DIR) {
    [System.IO.Path]::GetFullPath($env:OPENCODE_CONFIG_DIR)
} elseif ($env:APPDATA) {
    Join-Path $env:APPDATA 'opencode'
} else {
    Join-Path $HOME 'AppData\Roaming\opencode'
}
$ConfigFile   = Join-Path $ConfigDir 'opencode.json'
$JsoncFile    = Join-Path $ConfigDir 'opencode.jsonc'
$AuthDir      = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'opencode' } else { Join-Path $HOME 'AppData\Local\opencode' }
$AuthFile     = Join-Path $AuthDir 'auth.json'
$BackupDir    = Join-Path $ConfigDir $BACKUP_DIRNAME
$BackupConfig = Join-Path $BackupDir 'opencode.json'
$BackupAuth   = Join-Path $BackupDir 'auth.json'
$Manifest     = Join-Path $BackupDir 'manifest.txt'

# ---------------------------------------------------------------- JSON helpers

function Read-JsonObject {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($null -eq $raw -or $raw.Trim() -eq '') { return [pscustomobject]@{} }
    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse $Path as JSON: $($_.Exception.Message)"
    }
    if ($obj -isnot [System.Management.Automation.PSCustomObject]) {
        throw "$Path must contain a JSON object at the top level."
    }
    return $obj
}

function Get-JsonProperty {
    param($Object, [string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Set-JsonProperty {
    param($Object, [string]$Name, $Value)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { $prop.Value = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Write-JsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 100
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}

function Test-OpenCodeGoAuth {
    param($AuthObject)
    $entry = Get-JsonProperty $AuthObject $PROVIDER
    if ($null -eq $entry) { return $false }
    if ($entry -isnot [System.Management.Automation.PSCustomObject]) { return $false }
    if ((Get-JsonProperty $entry 'type') -ne 'api') { return $false }
    $key = Get-JsonProperty $entry 'key'
    if ($null -eq $key -or $key -isnot [string] -or $key.Trim() -eq '') { return $false }
    return $true
}

# ---------------------------------------------------------------- restore (menu 3)

function Invoke-OpenCodeGoRestore {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head 'Restore the pre-install OpenCode configuration'
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        Die "Backup directory not found:`n  $BackupDir`nNothing to restore -- the script may never have been installed, or was already restored."
    }
    if (-not (Test-Path -LiteralPath $Manifest)) {
        Die "Backup is corrupted: missing $Manifest"
    }

    $manifestRaw = Get-Content -LiteralPath $Manifest -Raw
    $hadConfig = $manifestRaw -match 'original_config_existed=1'
    $hadAuth   = $manifestRaw -match 'original_auth_existed=1'

    $n = 1
    Write-Host ''
    Write-Host 'The following actions will be performed:'
    if ($hadConfig) {
        if (-not (Test-Path -LiteralPath $BackupConfig)) { Die "Backup is corrupted: missing $BackupConfig" }
        Write-Host "  $n. Delete the current $ConfigFile"; $n++
        Write-Host '     (any changes made to this file since installation will be lost)' -ForegroundColor Yellow
        Write-Host "  $n. Restore opencode.json from the backup"; $n++
    } else {
        Write-Host "  $n. Delete $ConfigFile"; $n++
        Write-Dim  '     (this file did not exist before installation)'
    }
    if ($hadAuth) {
        if (-not (Test-Path -LiteralPath $BackupAuth)) { Die "Backup is corrupted: missing $BackupAuth" }
        Write-Host "  $n. Delete the current $AuthFile"; $n++
        Write-Host '     (any changes made to this file since installation will be lost)' -ForegroundColor Yellow
        Write-Host "  $n. Restore auth.json from the backup"; $n++
    } else {
        Write-Host "  $n. Delete $AuthFile"; $n++
        Write-Dim  '     (this file did not exist before installation)'
    }
    Write-Host "  $n. Delete the backup directory $BackupDir"
    Write-Host ''

    try {
        $ans = Read-Host 'Restore now? Type y to continue, anything else to cancel'
    } catch {
        Die 'Cannot read input (non-interactive environment); exiting (no files were modified).'
    }
    if ($ans -notin @('y','Y','yes','YES')) {
        Write-Host 'Cancelled; nothing was modified.'
        return
    }

    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AuthDir -Force | Out-Null

    if ($hadConfig) {
        if (Test-Path -LiteralPath $ConfigFile) { Remove-Item -LiteralPath $ConfigFile -Force }
        Copy-Item -LiteralPath $BackupConfig -Destination $ConfigFile -Force
        Write-Ok 'opencode.json restored'
    } else {
        if (Test-Path -LiteralPath $ConfigFile) { Remove-Item -LiteralPath $ConfigFile -Force }
        Write-Ok 'opencode.json deleted (it did not exist before installation)'
    }

    if ($hadAuth) {
        if (Test-Path -LiteralPath $AuthFile) { Remove-Item -LiteralPath $AuthFile -Force }
        Copy-Item -LiteralPath $BackupAuth -Destination $AuthFile -Force
        Write-Ok 'auth.json restored'
    } else {
        if (Test-Path -LiteralPath $AuthFile) { Remove-Item -LiteralPath $AuthFile -Force }
        Write-Ok 'auth.json deleted (it did not exist before installation)'
    }

    Remove-Item -LiteralPath $BackupDir -Recurse -Force
    Write-Ok 'Backup directory cleaned up'
    Write-Host ''
    Write-Ok 'Restore complete; the OpenCode configuration is back to its pre-install state.'
}

# ---------------------------------------------------------------- switch model (fast path)

function Invoke-OpenCodeGoSwitchModel {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "Switching default model -> $($script:Model)"
    Write-Dim  'Backup from this script detected; only the model field in opencode.json will be updated.'

    $config = $null
    $auth   = $null
    try {
        $config = Read-JsonObject $ConfigFile
        $auth   = Read-JsonObject $AuthFile
    } catch {
        Die "Current configuration could not be parsed; no files were modified.`n$($_.Exception.Message)`nRun this script again and pick 3 to restore, or fix the file manually."
    }
    if ($null -eq $config) {
        Die "Missing $ConfigFile; no files were modified. Run this script again and pick 3 to restore, or reinstall."
    }
    if ($null -eq $auth) {
        Die "Missing $AuthFile; no files were modified. Run this script again and pick 3 to restore, or reinstall."
    }
    if (-not (Test-OpenCodeGoAuth $auth)) {
        Die "The $PROVIDER entry in $AuthFile is missing or invalid; no files were modified. Run this script again and pick 3 to restore, then reinstall."
    }

    Set-JsonProperty $config 'model' $script:Model
    Write-JsonFile $ConfigFile $config

    Write-Ok "opencode.json updated: model = `"$($script:Model)`""
    Write-Host ''
    Write-Dim 'Run this script again to switch models (pick 1/2) or restore the default config (pick 3).'
}

# ---------------------------------------------------------------- first install

function Invoke-OpenCodeGoInstall {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "First-time install (target model: $($script:Model))"

    $ApiKey = $env:OPENCODE_API_KEY
    if ($ApiKey) {
        $ApiKey = $ApiKey.Trim()
        if ($ApiKey -eq '') {
            $ApiKey = ''
        } elseif ($ApiKey -match '"') {
            Die 'The OPENCODE_API_KEY environment variable must not contain double quotes.'
        } else {
            Write-Host ''
            Write-Ok 'Using the API key from the OPENCODE_API_KEY environment variable; skipping the prompt.'
        }
    }

    if (-not $ApiKey) {
        Write-Host ''
        Write-Dim "Don't have an API key yet? Get one at https://opencode.ai/zen/go"
        $attempt = 0
        while (-not $ApiKey) {
            try {
                $ApiKey = (Read-Host 'Enter your OpenCode Go API key').Trim()
            } catch {
                Die 'Cannot read input (non-interactive environment); exiting (no files were modified).'
            }
            if (-not $ApiKey) {
                $attempt++
                if ($attempt -ge 3) {
                    Die 'Failed to get an API key; exiting (no files were modified).'
                }
                Write-Warn 'The API key must not be empty.'
            }
        }
        if ($ApiKey -match '"') {
            Die 'The API key must not contain double quotes.'
        }
    }

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $OrigConfigExisted = Test-Path -LiteralPath $ConfigFile
    $OrigAuthExisted   = Test-Path -LiteralPath $AuthFile

    if ($OrigConfigExisted) {
        Copy-Item -LiteralPath $ConfigFile -Destination $BackupConfig -Force
        Write-Ok "Backed up opencode.json -> $BackupConfig"
    } else {
        Write-Warn 'opencode.json not found; a new file will be created'
    }
    if ($OrigAuthExisted) {
        Copy-Item -LiteralPath $AuthFile -Destination $BackupAuth -Force
        Write-Ok "Backed up auth.json -> $BackupAuth"
    } else {
        Write-Warn 'auth.json not found; a new file will be created'
    }

    $config = $null
    $auth   = $null
    try {
        $config = Read-JsonObject $ConfigFile
        $auth   = Read-JsonObject $AuthFile
    } catch {
        Remove-Item -LiteralPath $BackupDir -Recurse -Force
        Die "Existing configuration could not be parsed; aborted (the original files were not modified).`n$($_.Exception.Message)"
    }
    if ($null -eq $config) { $config = [pscustomobject]@{} }
    if ($null -eq $auth)   { $auth   = [pscustomobject]@{} }

    Set-JsonProperty $config 'model' $script:Model
    Set-JsonProperty $auth $PROVIDER ([pscustomobject]@{ type = 'api'; key = $ApiKey })

    New-Item -ItemType Directory -Path $AuthDir -Force | Out-Null

    $tmpConfig = Join-Path $ConfigDir 'opencode.json.opencode-go-tmp'
    $tmpAuth   = Join-Path $AuthDir 'auth.json.opencode-go-tmp'
    try {
        Write-JsonFile $tmpConfig $config
        Write-JsonFile $tmpAuth $auth
        Move-Item -LiteralPath $tmpConfig -Destination $ConfigFile -Force
        Move-Item -LiteralPath $tmpAuth -Destination $AuthFile -Force
    } catch {
        Remove-Item -LiteralPath $tmpConfig, $tmpAuth -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $BackupDir -Recurse -Force
        Die "Failed to write the new configuration; aborted (the original files were not modified).`n$($_.Exception.Message)"
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $manifestLines = @(
        "script_version=$SCRIPT_VERSION"
        "installed_at=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "original_config_existed=$(if ($OrigConfigExisted) { 1 } else { 0 })"
        "original_auth_existed=$(if ($OrigAuthExisted) { 1 } else { 0 })"
        "model=$($script:Model)"
    )
    [System.IO.File]::WriteAllText($Manifest, (($manifestLines -join "`n") + "`n"), $utf8)

    Write-Head 'Configuration written'
    Write-Host "  model  = `"$($script:Model)`""
    Write-Host "  auth   = $PROVIDER (api key stored in $AuthFile)"
    Write-Host ''
    Write-Ok 'Installation complete.'
    Write-Host ''
    Write-Host 'How to verify it took effect:'
    Write-Host '  - Start OpenCode and check that the model selector shows the model above'
    Write-Host '  - Run "opencode auth list" and confirm opencode-go is present'
    Write-Host ''
    Write-Dim 'Run this script again to switch models (pick 1/2) or restore the default config (pick 3).'
}

# ---------------------------------------------------------------- menu + pre-flight state check

function Invoke-OpenCodeGoMain {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "OpenCode Go Setup v$SCRIPT_VERSION"
    Write-Dim  "Config directory: $ConfigDir"

    $opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
    if ($null -eq $opencodeCmd) {
        Write-Warn 'The opencode CLI was not found on PATH; the config files below will still be written.'
        Write-Dim 'Install OpenCode first, then run this script again: https://opencode.ai/docs/'
    } else {
        Write-Ok "Detected opencode CLI: $($opencodeCmd.Source)"
    }

    if (Test-Path -LiteralPath $JsoncFile) {
        Write-Warn "Found $JsoncFile; OpenCode loads opencode.jsonc after opencode.json, so a model set there would override this script's setting. This script only writes opencode.json."
    }

    Write-Host ''
    Write-Host 'Choose an action:'
    Write-Host "  1. Configure OpenCode to use $FLASH_MODEL"
    Write-Host "  2. Configure OpenCode to use $PRO_MODEL"
    Write-Host '  3. Restore the pre-install OpenCode configuration'
    Write-Host ''

    $choice = ''
    $attempt = 0
    while ($true) {
        try {
            $choice = Read-Host 'Enter 1 / 2 / 3'
        } catch {
            Die 'Cannot read input (non-interactive environment); exiting (no files were modified).'
        }
        if ($choice -in @('1','2','3')) { break }
        $attempt++
        if ($attempt -ge 3) { Die 'Invalid choice; exiting (no files were modified).' }
        Write-Warn 'Invalid input; please enter 1, 2 or 3.'
    }

    switch ($choice) {
        '1' { $script:Model = $FLASH_MODEL }
        '2' { $script:Model = $PRO_MODEL }
        '3' { Invoke-OpenCodeGoRestore; return }
    }

    if (Test-Path -LiteralPath $BackupDir) {
        # A backup exists -> this script presumably installed before. Verify the
        # files still match expectations, then take the fast path; any mismatch
        # aborts without touching anything.
        $config = $null
        $auth   = $null
        $problems = @()
        try {
            $config = Read-JsonObject $ConfigFile
            $auth   = Read-JsonObject $AuthFile
        } catch {
            $problems += "  - Current configuration could not be parsed: $($_.Exception.Message)"
        }
        if ($null -eq $config) { $problems += "  - Missing $ConfigFile" }
        if ($null -eq $auth)   { $problems += "  - Missing $AuthFile" }
        if ($null -ne $auth -and -not (Test-OpenCodeGoAuth $auth)) {
            $problems += "  - The $PROVIDER entry in $AuthFile is missing or invalid"
        }

        if ($problems.Count -gt 0) {
            Die @"
The backup directory $BackupDir exists,
but the current configuration does not match what this script expects:
$($problems -join "`n")

To avoid damaging your existing files or that backup, this run has been aborted
and no files were modified.

Suggested fixes (pick one):
  a) Run this script again, pick 3 to restore the pre-install configuration
     first, then run it again and pick 1/2 to install;
  b) Inspect and delete the unexpected files listed above yourself (if you are
     sure the backup directory is no longer valuable, delete $BackupDir too),
     then run this script again.
"@
        }

        Invoke-OpenCodeGoSwitchModel
        return
    }

    Invoke-OpenCodeGoInstall
}

# ---------------------------------------------------------------- entry point

try {
    Invoke-OpenCodeGoMain
} catch {
    if ("$_" -ne $ABORT_SENTINEL) { throw }
    # Die already printed the error; keep a non-zero exit code when run as a file
    # (must not exit in the irm | iex scenario)
    if ($PSCommandPath) { exit 1 }
}
