<#
.SYNOPSIS
    SSHs - Interactive SSH host picker for Windows PowerShell 5.1.

.DESCRIPTION
    Reads explicit Host entries from:
      %USERPROFILE%\.ssh\config
      %USERPROFILE%\.ssh\config.d\*.conf

    Dependencies:
      - Windows OpenSSH client (ssh.exe)
      - fzf.exe
      - Optional: code.cmd for Ctrl+E
#>

[CmdletBinding()]
param(
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------

$ConfigFile = if ($env:SSH_CONFIG) {
    [Environment]::ExpandEnvironmentVariables($env:SSH_CONFIG)
} else {
    Join-Path $HOME '.ssh\config'
}

$ConfigDirectory = if ($env:SSH_CONFIG_DIR) {
    [Environment]::ExpandEnvironmentVariables($env:SSH_CONFIG_DIR)
} else {
    Join-Path $HOME '.ssh\config.d'
}

$SshsDirectory = Join-Path $HOME '.config\sshs'
$RecentFile = Join-Path $SshsDirectory 'recent'
$MaximumRecentHosts = 5
$EditorCommand = if ($env:SSHS_EDITOR) { $env:SSHS_EDITOR } else { 'code.cmd' }
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Show-Usage {
    @"
SSHs - Interactive SSH menu for Windows

Usage:
  sshs
  sshs -Help
  sshs -h

Environment variables:
  SSH_CONFIG       Main SSH config file
                   Default: $HOME\.ssh\config

  SSH_CONFIG_DIR   Directory containing additional *.conf files
                   Default: $HOME\.ssh\config.d

  SSHS_EDITOR      Editor used by Ctrl+E
                   Default: code.cmd

Keys:
  Enter            Connect normally
  Ctrl+V           Connect using ssh.exe -vvvv
  Ctrl+E           Open source config in the configured editor
  ?                Toggle preview
  Esc / Ctrl+C     Exit
"@
}

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Hint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name`r`n$Hint"
    }
}

function Get-ConfigurationFiles {
    $Result = @()

    if (Test-Path -LiteralPath $ConfigFile -PathType Leaf) {
        $ResolvedMainConfig = (Resolve-Path -LiteralPath $ConfigFile).Path
        $Result += New-Object PSObject -Property ([ordered]@{
            Path   = $ResolvedMainConfig
            Source = 'config'
            Order  = 0
        })
    }

    if (Test-Path -LiteralPath $ConfigDirectory -PathType Container) {
        $Order = 1
        $AdditionalFiles = @(Get-ChildItem -LiteralPath $ConfigDirectory -Filter '*.conf' | Where-Object { -not $_.PSIsContainer } | Sort-Object Name)

        foreach ($File in $AdditionalFiles) {
            $Result += New-Object PSObject -Property ([ordered]@{
                Path   = $File.FullName
                Source = $File.Name
                Order  = $Order
            })
            $Order++
        }
    }

    return @($Result)
}

function Save-HostBlock {
    param(
        [string[]]$Aliases,
        [string[]]$BlockLines,
        [hashtable]$Settings,
        [string]$Tags,
        [string]$Source,
        [string]$SourcePath
    )

    $Result = @()

    if ($null -eq $Aliases -or $Aliases.Count -eq 0) {
        return @()
    }

    $HostName = ''
    if ($Settings.ContainsKey('hostname')) {
        $HostName = [string]$Settings['hostname']
    }

    foreach ($Alias in $Aliases) {
        if ([string]::IsNullOrWhiteSpace($Alias)) {
            continue
        }

        if ($Alias.Contains('*') -or $Alias.Contains('?') -or $Alias.StartsWith('!')) {
            continue
        }

        $Result += New-Object PSObject -Property ([ordered]@{
            Host       = $Alias
            HostName   = $HostName
            Tags       = $Tags
            Source     = $Source
            SourcePath = $SourcePath
            Lines      = [string[]]$BlockLines
        })
    }

    return @($Result)
}

function Read-SshConfigFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $Result = @()
    $Aliases = @()
    $BlockLines = @()
    $Settings = @{}
    $Tags = ''
    $InsideHost = $false

    foreach ($RawLine in [System.IO.File]::ReadAllLines($Path)) {
        $Line = [string]$RawLine
        $Trimmed = $Line.Trim()

        if ($Trimmed -match '^(?i:Host)\s+(.+)$') {
            if ($InsideHost) {
                $Result += @(Save-HostBlock -Aliases $Aliases -BlockLines $BlockLines -Settings $Settings -Tags $Tags -Source $Source -SourcePath $Path)
            }

            $Aliases = @($Matches[1].Trim() -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $BlockLines = @($Line)
            $Settings = @{}
            $Tags = ''
            $InsideHost = $true
            continue
        }

        if ($Trimmed -match '^(?i:Match)(\s+|$)') {
            if ($InsideHost) {
                $Result += @(Save-HostBlock -Aliases $Aliases -BlockLines $BlockLines -Settings $Settings -Tags $Tags -Source $Source -SourcePath $Path)
            }

            $Aliases = @()
            $BlockLines = @()
            $Settings = @{}
            $Tags = ''
            $InsideHost = $false
            continue
        }

        if (-not $InsideHost) {
            continue
        }

        $BlockLines += $Line

        if ($Trimmed -match '^#\s*(?i:Tags)\s+(.+)$') {
            $Tags = $Matches[1].Trim()
            continue
        }

        if ([string]::IsNullOrWhiteSpace($Trimmed) -or $Trimmed.StartsWith('#')) {
            continue
        }

        if ($Trimmed -match '^(\S+)\s+(.+)$') {
            $Key = $Matches[1].ToLowerInvariant()
            $Value = $Matches[2].Trim()

            if ($Value.Length -ge 2) {
                if (($Value.StartsWith('"') -and $Value.EndsWith('"')) -or
                    ($Value.StartsWith("'") -and $Value.EndsWith("'"))) {
                    $Value = $Value.Substring(1, $Value.Length - 2)
                }
            }

            if (-not $Settings.ContainsKey($Key)) {
                $Settings[$Key] = $Value
            }
        }
    }

    if ($InsideHost) {
        $Result += @(Save-HostBlock -Aliases $Aliases -BlockLines $BlockLines -Settings $Settings -Tags $Tags -Source $Source -SourcePath $Path)
    }

    return @($Result)
}

function Get-SshHosts {
    param([object[]]$ConfigurationFiles)

    $Result = @()
    $Seen = @{}

    foreach ($File in @($ConfigurationFiles | Sort-Object Order)) {
        foreach ($Entry in @(Read-SshConfigFile -Path $File.Path -Source $File.Source)) {
            if (-not $Seen.ContainsKey($Entry.Host)) {
                $Seen[$Entry.Host] = $true
                $Result += $Entry
            }
        }
    }

    return @($Result)
}

function Get-RecentHosts {
    if (-not (Test-Path -LiteralPath $RecentFile -PathType Leaf)) {
        return @()
    }

    $Result = @()
    $Seen = @{}

    foreach ($Line in [System.IO.File]::ReadAllLines($RecentFile)) {
        $HostName = $Line.Trim()

        if ([string]::IsNullOrWhiteSpace($HostName)) {
            continue
        }

        if (-not $Seen.ContainsKey($HostName)) {
            $Seen[$HostName] = $true
            $Result += $HostName
        }

        if ($Result.Count -ge $MaximumRecentHosts) {
            break
        }
    }

    return @($Result)
}

function Set-RecentHost {
    param([Parameter(Mandatory = $true)][string]$HostName)

    $Updated = @($HostName)
    $Seen = @{}
    $Seen[$HostName] = $true

    foreach ($ExistingHost in @(Get-RecentHosts)) {
        if (-not $Seen.ContainsKey($ExistingHost)) {
            $Seen[$ExistingHost] = $true
            $Updated += $ExistingHost
        }

        if ($Updated.Count -ge $MaximumRecentHosts) {
            break
        }
    }

    [System.IO.File]::WriteAllLines($RecentFile, [string[]]$Updated, $Utf8NoBom)
}

function ConvertTo-FzfField {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ($Value.Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' '))
}

function New-PreviewFile {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][int]$Index
    )

    $PreviewPath = Join-Path $Directory ('{0:D5}.txt' -f $Index)
    $Content = @()
    $Content += "Host:   $($Entry.Host)"
    $Content += "Source: $($Entry.SourcePath)"

    if (-not [string]::IsNullOrWhiteSpace($Entry.Tags)) {
        $Content += "Tags:   $($Entry.Tags)"
    }

    $Content += ''
    $Content += 'Configuration:'
    $Content += ''
    $Content += [string[]]$Entry.Lines

    [System.IO.File]::WriteAllLines($PreviewPath, [string[]]$Content, $Utf8NoBom)
    return $PreviewPath
}

function ConvertTo-FzfLine {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    $Display = (ConvertTo-FzfField $Entry.Display).PadRight(
        $script:DisplayWidth
    )

    $Tags = (ConvertTo-FzfField $Entry.Tags).PadRight(
        $script:TagsWidth
    )

    $Fields = @(
        (ConvertTo-FzfField $Entry.Host),
        $Display,
        $Tags,
        (ConvertTo-FzfField $Entry.Source),
        (ConvertTo-FzfField $Entry.SourcePath),
        (ConvertTo-FzfField $Entry.PreviewPath)
    )

    return ($Fields -join "`t")
}

if ($Help) {
    Show-Usage
    exit 0
}

$PreviewDirectory = $null

try {
    Assert-Command -Name 'ssh.exe' -Hint 'Install the Windows OpenSSH Client optional feature.'
    Assert-Command -Name 'fzf.exe' -Hint 'Install fzf with: winget install --id junegunn.fzf -e'

    if (-not (Test-Path -LiteralPath $SshsDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $SshsDirectory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $RecentFile -PathType Leaf)) {
        [System.IO.File]::WriteAllText($RecentFile, '', $Utf8NoBom)
    }

    $ConfigurationFiles = @(Get-ConfigurationFiles)

    if ($ConfigurationFiles.Count -eq 0) {
        throw "No SSH configuration files found.`r`nMain config: $ConfigFile`r`nConfig directory: $ConfigDirectory"
    }

    $Hosts = @(Get-SshHosts -ConfigurationFiles $ConfigurationFiles)

    if ($Hosts.Count -eq 0) {
        throw 'No explicit SSH Host aliases found. Wildcard, question-mark and negated patterns are hidden.'
    }

    $PreviewDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('sshs-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $PreviewDirectory -Force | Out-Null

    $PreparedHosts = @()
    $Index = 0

    foreach ($Entry in $Hosts) {
        $Display = $Entry.Host

        if (-not [string]::IsNullOrWhiteSpace($Entry.HostName)) {
            $Display = "$($Entry.Host) ($($Entry.HostName))"
        }

        $PreparedHosts += New-Object PSObject -Property ([ordered]@{
            Host        = $Entry.Host
            Display     = $Display
            Tags        = $Entry.Tags
            Source      = $Entry.Source
            SourcePath  = $Entry.SourcePath
            PreviewPath = New-PreviewFile -Entry $Entry -Directory $PreviewDirectory -Index $Index
        })

        $Index++
    }
    # Calculate fixed column widths after all host records are prepared.
    $script:DisplayWidth = 'Host (Hostname)'.Length
    $script:TagsWidth = 'Tags'.Length

    foreach ($PreparedEntry in $PreparedHosts) {
        $CurrentDisplayLength = (
            ConvertTo-FzfField $PreparedEntry.Display
        ).Length

        $CurrentTagsLength = (
            ConvertTo-FzfField $PreparedEntry.Tags
        ).Length

        if ($CurrentDisplayLength -gt $script:DisplayWidth) {
            $script:DisplayWidth = $CurrentDisplayLength
        }

        if ($CurrentTagsLength -gt $script:TagsWidth) {
            $script:TagsWidth = $CurrentTagsLength
        }
    }
    $HostsByName = @{}
    foreach ($Entry in $PreparedHosts) {
        $HostsByName[$Entry.Host] = $Entry
    }

    $RecentEntries = @()
    $RecentSet = @{}

    foreach ($RecentHost in @(Get-RecentHosts)) {
        if ($HostsByName.ContainsKey($RecentHost)) {
            $RecentEntries += $HostsByName[$RecentHost]
            $RecentSet[$RecentHost] = $true
        }
    }

    $NormalEntries = @()
    foreach ($Entry in $PreparedHosts) {
        if (-not $RecentSet.ContainsKey($Entry.Host)) {
            $NormalEntries += $Entry
        }
    }

    $DisplayLines = @()

    $DisplayHeader = 'Host (Hostname)'.PadRight(
        $script:DisplayWidth
    )

    $TagsHeader = 'Tags'.PadRight(
        $script:TagsWidth
    )

    $DisplayLines += (
    @(
        '__header__'
        $DisplayHeader
        $TagsHeader
        'Source'
        ''
        ''
    ) -join "`t"
)

    foreach ($Entry in $RecentEntries) {
        $DisplayLines += ConvertTo-FzfLine $Entry
    }

    if ($RecentEntries.Count -gt 0 -and $NormalEntries.Count -gt 0) {
$DisplayLines += (
@(
'__separator__'
'────────── All Hosts ──────────'
''
''
''
''
) -join "`t"
)    }

    foreach ($Entry in $NormalEntries) {
        $DisplayLines += ConvertTo-FzfLine $Entry
    }

    $EditorAvailable = [bool](Get-Command $EditorCommand -ErrorAction SilentlyContinue)

    $FzfArguments = @(
        '--height=60%',
        '--reverse',
        '--exact',
        '--tiebreak=begin,length',
        "--delimiter=`t",
        '--with-nth=2,3,4',
        '--nth=1,2,3,4',
        '--preview=cmd.exe /d /c type "{6}"',
        '--preview-window=down:50%:wrap:hidden',
        '--bind=?:toggle-preview',
        '--bind=ctrl-v:execute(ssh.exe -vvvv "{1}")+abort',
        '--prompt=[Recent 5 hosts at top] Search: ',
        '--info=right',
        '--header-lines=1',
        '--border=rounded',
        '--border-label= SSHs | Enter=Connect | Ctrl-V=Verbose | Ctrl-E=Edit | ?=Details ',
        '--ellipsis=...'
    )

    if ($EditorAvailable) {
        $FzfArguments += ('--bind=ctrl-e:execute-silent({0} "{{5}}")' -f $EditorCommand)
    }

    $PreviousConsoleEncoding = [Console]::OutputEncoding
    $PreviousPipelineEncoding = $OutputEncoding

    try {
        [Console]::OutputEncoding = $Utf8NoBom
        $OutputEncoding = $Utf8NoBom
        $SelectedEntry = $DisplayLines | & fzf.exe @FzfArguments
        $FzfExitCode = $LASTEXITCODE
    }
    finally {
        [Console]::OutputEncoding = $PreviousConsoleEncoding
        $OutputEncoding = $PreviousPipelineEncoding
    }

    if ($FzfExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($SelectedEntry)) {
        exit 0
    }

    $SelectedFields = $SelectedEntry -split "`t", 6
    $SelectedHost = $SelectedFields[0]

    if ($SelectedHost -eq '__header__' -or $SelectedHost -eq '__separator__') {
        exit 0
    }

    Set-RecentHost -HostName $SelectedHost
    & ssh.exe $SelectedHost
    exit $LASTEXITCODE
}
catch {
    Write-Host '----- SSHs ERROR -----' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($_.ScriptStackTrace)) {
        Write-Host ''
        Write-Host $_.ScriptStackTrace
    }

    exit 1
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($PreviewDirectory)) {
        if (Test-Path -LiteralPath $PreviewDirectory) {
            Remove-Item -LiteralPath $PreviewDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
