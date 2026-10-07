
# Check dependencies

Write-Host "==> Checking dependencies..."

if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {

    Write-Host ""
    Write-Host "ERROR: OpenSSH client is not installed."
    Write-Host ""
    exit 1
}

Write-Host "==> Checking fzf..."

if (-not (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {

    Write-Host ""
    Write-Host "ERROR: fzf is not installed."
    Write-Host ""

    Write-Host "Install fzf with:"
    Write-Host ""
    Write-Host "  winget install fzf"
    Write-Host ""

    exit 1
}

Write-Host "fzf found."

# Create ~/.config/sshs

$SshsDir = Join-Path $HOME ".config\sshs"

New-Item `
    -ItemType Directory `
    -Path $SshsDir `
    -Force | Out-Null

# Download files

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/sikkancs/sshs/main/sshs-main.ps1" `
    -OutFile (Join-Path $SshsDir "sshs-main.ps1")

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/sikkancs/sshs/main/sshs.cmd" `
    -OutFile (Join-Path $SshsDir "sshs.cmd")

# Add SSHs folder to PATH

$UserPath = [System.Environment]::GetEnvironmentVariable(
    "Path",
    "User"
)

if ($UserPath -notlike "*$SshsDir*") {

    [System.Environment]::SetEnvironmentVariable(
        "Path",
        "$UserPath;$SshsDir",
        "User"
    )

    Write-Host ""
    Write-Host "SSHs added to PATH:"
    Write-Host "  $SshsDir"
}
else {

    Write-Host ""
    Write-Host "SSHs already exists in PATH."
}

Write-Host ""
Write-Host "Installation complete."
Write-Host ""
Write-Host "Open a NEW terminal window and run:"
Write-Host ""
Write-Host "  sshs"
Write-Host ""
Write-Host "IMPORTANT"
Write-Host ""
Write-Host "SSHs relies on native OpenSSH configuration."
Write-Host ""
Write-Host "Make sure the following exist:"
Write-Host ""
Write-Host "  %USERPROFILE%\.ssh\config"
Write-Host "  %USERPROFILE%\.ssh\config.d\"
Write-Host ""
Write-Host "Your SSH config should contain:"
Write-Host ""
Write-Host "  Include ~/.ssh/config.d/*.conf"
Write-Host ""
Write-Host "Place your host definitions into:"
Write-Host ""
Write-Host "  %USERPROFILE%\.ssh\config.d\*.conf"
Write-Host ""
Write-Host "Without this configuration, host aliases"
Write-Host "and native 'ssh host-alias' commands"
Write-Host "will not work correctly."
Write-Host ""
