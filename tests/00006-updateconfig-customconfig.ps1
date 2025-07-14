# 00006-updateconfig-customconfig.ps1
# Functional test: Update IAC config with custom config path

$ErrorActionPreference = "Stop"

$TestName = "00006-updateconfig-customconfig"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

$customConfigPath = "$TestOut/custom-config/InertiaAntiCheat.toml"
if (-not (Test-Path "$TestOut/custom-config")) { New-Item -ItemType Directory -Path "$TestOut/custom-config" | Out-Null }
if (-not (Test-Path $customConfigPath)) { "[validation.group]`nhash = []`nsoftWhitelist = []" | Out-File -FilePath $customConfigPath -Encoding UTF8 }

& "../hash.ps1" -UpdateConfig -ConfigPath $customConfigPath -ModsPath "../mods" -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }
if (-not (Test-Path $customConfigPath)) { Write-Error "Custom IAC config not found"; exit 1 }
Write-Host "Test $TestName passed." 