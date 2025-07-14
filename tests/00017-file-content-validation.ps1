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

# Create versioned directory
$releaseVersion = Get-Date -Format "yyyy.M.d-HHmmss"
$versionedDir = Join-Path $TestOut $releaseVersion
if (-not (Test-Path $versionedDir)) { New-Item -ItemType Directory -Path $versionedDir | Out-Null }

# Run and capture to temp log
$tempLog = "$versionedDir/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
& "../hash.ps1" -ModsPath $testModsPath -OutputPath $versionedDir *>&1 | Tee-Object -FilePath $tempLog

# Assertions
$hashFile = Join-Path $versionedDir "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionedDir "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Validate hash.txt content structure
$hashContent = Get-Content $hashFile

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
$readmeContent = Get-Content $readmeFile -Raw

if ($readmeContent -notmatch "# Minecraft Modpack Documentation") { Write-Error "README missing main title"; exit 1 }
if ($readmeContent -notmatch "## Summary") { Write-Error "README missing summary section"; exit 1 }
if ($readmeContent -notmatch "## Mandatory Mods") { Write-Error "README missing mandatory mods section"; exit 1 }
if ($readmeContent -notmatch "\*\*Combined Hash:\*\*") { Write-Error "README missing combined hash"; exit 1 }

# Validate markdown table format
if ($readmeContent -notmatch "\| Name \| ID \| Version \| Description \| License \| Homepage \| Contact \|") { 
    Write-Error "README missing proper table headers"; exit 1 
}

# Copy log to version folder if temp log exists
Write-Host "Checking for temp log: $tempLog"
if (Test-Path $tempLog) {
    Write-Host "Temp log exists, copying to version directory"
    $finalLog = Join-Path $versionedDir "test.log"
    Copy-Item -Path $tempLog -Destination $finalLog -Force
    Write-Host "Copied temp log to version directory"
    Remove-Item -Path $tempLog -Force
} else {
    Write-Host "Warning: Temp log not found: $tempLog"
}

Write-Host "Test $TestName passed."