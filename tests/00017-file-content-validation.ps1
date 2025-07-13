# 00017-file-content-validation.ps1
# Functional test: Validate generated file contents

$ErrorActionPreference = "Stop"

$TestName = "00017-file-content-validation"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create test mods for validation
$testModsPath = "$TestOut/test-mods"
if (Test-Path $testModsPath) { Remove-Item -Path $testModsPath -Recurse -Force }
New-Item -ItemType Directory -Path $testModsPath -Force | Out-Null

# Create a test mod with fabric.mod.json
$testModPath = "$testModsPath/validation-test-mod.jar"
$tempDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$fabricModJson = @{
    schemaVersion = 1
    id = "validationmod"
    name = "Validation Test Mod"
    version = "1.0.0"
    description = "A mod for testing validation"
    environment = "client"
}
$fabricModJson | ConvertTo-Json | Out-File -FilePath "$tempDir/fabric.mod.json" -Encoding UTF8

# Create JAR file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $testModPath)
Remove-Item -Path $tempDir -Recurse -Force

& "../hash.ps1" -ModsPath $testModsPath -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }

# Validate hash.txt content structure
$hashContent = Get-Content $hashFile.FullName

# Check for required sections
$mandatorySectionFound = $false
$optionalSectionFound = $false
$blockedSectionFound = $false

foreach ($line in $hashContent) {
    if ($line -eq "# Mandatory Mods") { $mandatorySectionFound = $true }
    if ($line -eq "# Soft-Whitelisted Mods") { $optionalSectionFound = $true }
    if ($line -eq "# Blocked Mods") { $blockedSectionFound = $true }
}

if (-not $mandatorySectionFound) { Write-Error "Mandatory Mods section not found in hash file"; exit 1 }
if (-not $optionalSectionFound) { Write-Error "Soft-Whitelisted Mods section not found in hash file"; exit 1 }
if (-not $blockedSectionFound) { Write-Error "Blocked Mods section not found in hash file"; exit 1 }

# Validate hash format (MD5 hashes should be 32 characters)
$hashLines = $hashContent | Where-Object { $_ -match "^[a-f0-9]{32} " }
if ($hashLines.Count -eq 0) { Write-Error "No valid hash lines found in hash file"; exit 1 }

# Validate README.md content structure
$readmeContent = Get-Content $readmeFile.FullName -Raw

if ($readmeContent -notmatch "# Minecraft Modpack Documentation") { Write-Error "README missing main title"; exit 1 }
if ($readmeContent -notmatch "## Summary") { Write-Error "README missing summary section"; exit 1 }
if ($readmeContent -notmatch "## Mandatory Mods") { Write-Error "README missing mandatory mods section"; exit 1 }
if ($readmeContent -notmatch "\*\*Combined Hash:\*\*") { Write-Error "README missing combined hash"; exit 1 }

# Validate markdown table format
if ($readmeContent -notmatch "\| Name \| ID \| Version \| Description \| License \| Homepage \| Contact \|") { 
    Write-Error "README missing proper table headers"; exit 1 
}

Write-Host "Test $TestName passed."