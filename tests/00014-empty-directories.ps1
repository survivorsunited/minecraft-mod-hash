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
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }

# Verify empty content
$hashContent = Get-Content $hashFile.FullName -Raw
if ($hashContent -notmatch "# Mandatory Mods") { Write-Error "Missing mandatory mods section"; exit 1 }

Write-Host "Test $TestName passed."