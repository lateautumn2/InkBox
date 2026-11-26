param(
    [switch]$Release
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$rustDir = Join-Path $repoRoot 'rust_core'
$jniLibs = Join-Path $repoRoot 'app\android\app\src\main\jniLibs'

$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif (Test-Path 'E:\Android\Sdk') { 'E:\Android\Sdk' } else { "$env:LOCALAPPDATA\Android\Sdk" }
$ndkDir = Get-ChildItem (Join-Path $sdkRoot 'ndk') -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $ndkDir) {
    throw "Android NDK not found under $sdkRoot\ndk"
}
$llvmBin = Join-Path $ndkDir.FullName 'toolchains\llvm\prebuilt\windows-x86_64\bin'
Write-Host "Using NDK LLVM toolchain: $llvmBin"

$cargo = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
$profileDir = if ($Release) { 'release' } else { 'debug' }

$targets = @(
    @{ Triple = 'aarch64-linux-android'; Abi = 'arm64-v8a'; Linker = 'aarch64-linux-android24-clang.cmd'; EnvKey = 'CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER' },
    @{ Triple = 'armv7-linux-androideabi'; Abi = 'armeabi-v7a'; Linker = 'armv7a-linux-androideabi24-clang.cmd'; EnvKey = 'CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER' },
    @{ Triple = 'x86_64-linux-android'; Abi = 'x86_64'; Linker = 'x86_64-linux-android24-clang.cmd'; EnvKey = 'CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER' }
)

Push-Location $rustDir
try {
    foreach ($t in $targets) {
        $linkerPath = Join-Path $llvmBin $t.Linker
        Set-Item -Path "Env:$($t.EnvKey)" -Value $linkerPath
        $env:AR = Join-Path $llvmBin 'llvm-ar.exe'
        $args = @('build', '--target', $t.Triple)
        if ($Release) { $args += '--release' }
        Write-Host "Building $($t.Triple) ($profileDir)..."
        & $cargo @args
        if ($LASTEXITCODE -ne 0) { throw "Cargo build failed for $($t.Triple)" }

        $outDir = Join-Path $jniLibs $t.Abi
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        $soSrc = Join-Path $rustDir "target\$($t.Triple)\$profileDir\libinkbox_core.so"
        Copy-Item -Path $soSrc -Destination (Join-Path $outDir 'libinkbox_core.so') -Force
        Write-Host "Copied $soSrc -> $outDir\libinkbox_core.so"
    }
} finally {
    Pop-Location
}
Write-Host "All Android Rust libraries built successfully!"
