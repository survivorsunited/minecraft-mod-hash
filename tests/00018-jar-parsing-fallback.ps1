# 00018-jar-parsing-fallback.ps1
# Functional test: JAR file parsing with MANIFEST.MF fallback

$ErrorActionPreference = "Stop"

$TestName = "00018-jar-parsing-fallback"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create test mods directory
$testModsPath = "$TestOut/test-mods"
if (Test-Path $testModsPath) { Remove-Item -Path $testModsPath -Recurse -Force }
New-Item -ItemType Directory -Path $testModsPath -Force | Out-Null

# Create a mock JAR file with only MANIFEST.MF (no fabric.mod.json)
$manifestModPath = "$testModsPath/manifest-only-mod.jar"
$tempDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path "$tempDir/META-INF" -Force | Out-Null

# Create MANIFEST.MF
$manifestContent = @"
Manifest-Version: 1.0
Specification-Title: Manifest Test Mod
Specification-Version: 2.0.0
Implementation-Title: Manifest Test Mod Implementation
Implementation-Version: 2.0.0
"@
$manifestContent | Out-File -FilePath "$tempDir/META-INF/MANIFEST.MF" -Encoding UTF8

# Create JAR file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $manifestModPath)
Remove-Item -Path $tempDir -Recurse -Force

# Create a JAR file with neither fabric.mod.json nor proper MANIFEST.MF
$fallbackModPath = "$testModsPath/fallback-test-mod-1.2.3-fabric.jar"
$tempDir2 = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
New-Item -ItemType Directory -Path $tempDir2 -Force | Out-Null
"dummy content" | Out-File -FilePath "$tempDir2/dummy.txt" -Encoding UTF8
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir2, $fallbackModPath)
Remove-Item -Path $tempDir2 -Recurse -Force

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

# Verify MANIFEST.MF parsing worked
$hashContent = Get-Content $hashFile -Raw
if ($hashContent -notmatch "Manifest Test Mod") { Write-Error "MANIFEST.MF parsed mod name not found"; exit 1 }

# Verify filename fallback worked (should clean up version and fabric suffixes)
if ($hashContent -notmatch "fallback-test-mod") { Write-Error "Filename fallback mod name not found"; exit 1 }
if ($hashContent -match "1.2.3") { Write-Error "Version not cleaned from filename fallback"; exit 1 }
if ($hashContent -match "-fabric") { Write-Error "Fabric suffix not cleaned from filename fallback"; exit 1 }

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