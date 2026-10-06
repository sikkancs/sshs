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

# Install fzf if missing

if (-not (Get-Command fzf.exe -ErrorAction SilentlyContinue)) {

    Write-Host "Installing fzf..."

    winget install --id junegunn.fzf -e
}

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
