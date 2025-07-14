# 00013-error-missing-modspath.ps1
# Error handling test: Missing mods path

$ErrorActionPreference = "Stop"

$TestName = "00013-error-missing-modspath"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create versioned directory
$releaseVersion = Get-Date -Format "yyyy.M.d-HHmmss"
$versionedDir = Join-Path $TestOut $releaseVersion
if (-not (Test-Path $versionedDir)) { New-Item -ItemType Directory -Path $versionedDir | Out-Null }

# Run and capture to temp log
$tempLog = "$versionedDir/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
# Try to run with non-existent mods path
$result = & "../hash.ps1" -ModsPath "./nonexistent" -OutputPath $versionedDir 2>&1
$exitCode = $LASTEXITCODE

# Capture output to temp log
$result | Out-File -FilePath $tempLog -Encoding UTF8

# Assertions - should fail gracefully
if ($exitCode -eq 0) { Write-Error "Script should have failed with missing mods path"; exit 1 }

# Should produce informative error message
$logContent = Get-Content $tempLog -Raw
if ($logContent -notmatch "mods.*not found|directory.*not exist") { 
    Write-Error "Missing expected error message about mods directory"; exit 1 
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