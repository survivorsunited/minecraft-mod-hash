# 00014-empty-directories.ps1
# Functional test: Handle empty mod directories

$ErrorActionPreference = "Stop"

$TestName = "00014-empty-directories"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create empty mods directory structure
$emptyModsPath = "$TestOut/empty-mods"
New-Item -ItemType Directory -Path $emptyModsPath -Force | Out-Null
New-Item -ItemType Directory -Path "$emptyModsPath/optional" -Force | Out-Null
New-Item -ItemType Directory -Path "$emptyModsPath/block" -Force | Out-Null

& "../hash.ps1" -ModsPath $emptyModsPath -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Verify empty content
$hashContent = Get-Content $hashFile -Raw
if ($hashContent -notmatch "# Mandatory Mods") { Write-Error "Missing mandatory mods section"; exit 1 }

Write-Host "Test $TestName passed."