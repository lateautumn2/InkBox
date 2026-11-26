param(
    [switch]$Release
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$rustDir = Join-Path $repoRoot 'rust_core'
$cargo = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$profileDir = if ($Release) { 'release' } else { 'debug' }

Push-Location $rustDir
try {
    $args = @('build')
    if ($Release) { $args += '--release' }
    & $cargo @args
    if ($LASTEXITCODE -ne 0) { throw "Cargo Windows build failed" }
    $dll = Join-Path $rustDir "target\$profileDir\inkbox_core.dll"
    Write-Host "Built Windows Rust DLL: $dll"
} finally {
    Pop-Location
}
