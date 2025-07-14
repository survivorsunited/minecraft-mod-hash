# 00001-basic.ps1
# Functional test: Generate hash.txt and README-MOD.md only

$ErrorActionPreference = "Stop"

$TestName = "00001-basic"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Run and capture to temp log
$tempLog = "$TestOut/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
& "../hash.ps1" -ModsPath "./mods" -OutputPath $TestOut | Tee-Object -FilePath $tempLog

# Assertions  
# Find the LATEST version directory (sort by name since format is sortable)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Sort-Object Name -Descending | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Copy log to version folder if temp log exists
if (Test-Path $tempLog) {
    Write-Host "Copying temp log to version directory"
    $finalLog = Join-Path $versionDir.FullName "test.log"
    Copy-Item -Path $tempLog -Destination $finalLog -Force
    Write-Host "Copied temp log to version directory"
    Remove-Item -Path $tempLog -Force
}

Write-Host "Test $TestName passed." 