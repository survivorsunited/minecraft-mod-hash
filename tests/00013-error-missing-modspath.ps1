# 00013-error-missing-modspath.ps1
# Error handling test: Missing mods path

$ErrorActionPreference = "Stop"

$TestName = "00013-error-missing-modspath"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Try to run with non-existent mods path
$result = & "../hash.ps1" -ModsPath "./nonexistent" -OutputPath $TestOut 2>&1
$exitCode = $LASTEXITCODE

# Capture output to log
$result | Out-File -FilePath "$TestOut/test.log" -Encoding UTF8

# Assertions - should fail gracefully
if ($exitCode -eq 0) { Write-Error "Script should have failed with missing mods path"; exit 1 }

# Should produce informative error message
$logContent = Get-Content "$TestOut/test.log" -Raw
if ($logContent -notmatch "mods.*not found|directory.*not exist") { 
    Write-Error "Missing expected error message about mods directory"; exit 1 
}

Write-Host "Test $TestName passed."