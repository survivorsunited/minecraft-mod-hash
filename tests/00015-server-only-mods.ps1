# 00015-server-only-mods.ps1
# Functional test: Handle server-only mods (environment: "server")

$ErrorActionPreference = "Stop"

$TestName = "00015-server-only-mods"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create test mods directory with server-only mod
$testModsPath = "$TestOut/test-mods"
if (Test-Path $testModsPath) { Remove-Item -Path $testModsPath -Recurse -Force }
New-Item -ItemType Directory -Path $testModsPath -Force | Out-Null

# Create a mock server-only mod JAR file with fabric.mod.json
$serverModPath = "$testModsPath/server-only-mod.jar"
$tempDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create fabric.mod.json with server environment
$fabricModJson = @{
    schemaVersion = 1
    id = "servermod"
    name = "Server Only Mod"
    version = "1.0.0"
    description = "A server-only mod"
    environment = "server"
}
$fabricModJson | ConvertTo-Json | Out-File -FilePath "$tempDir/fabric.mod.json" -Encoding UTF8

# Create JAR file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $serverModPath)
Remove-Item -Path $tempDir -Recurse -Force

# Create a regular client mod for comparison
$clientModPath = "$testModsPath/client-test-mod.jar"
$tempDir2 = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
New-Item -ItemType Directory -Path $tempDir2 -Force | Out-Null

# Create fabric.mod.json with client environment
$clientFabricModJson = @{
    schemaVersion = 1
    id = "clientmod"
    name = "Client Test Mod"
    version = "1.0.0"
    description = "A client mod for testing"
    environment = "client"
}
$clientFabricModJson | ConvertTo-Json | Out-File -FilePath "$tempDir2/fabric.mod.json" -Encoding UTF8

# Create JAR file
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir2, $clientModPath)
Remove-Item -Path $tempDir2 -Recurse -Force

& "../hash.ps1" -ModsPath $testModsPath -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Verify server-only mod is excluded from hash file
$hashContent = Get-Content $hashFile -Raw
if ($hashContent -match "Server Only Mod") { Write-Error "Server-only mod found in hash file"; exit 1 }

# Verify log shows server-only mod was ignored
$logContent = Get-Content "$TestOut/test.log" -Raw
if ($logContent -notmatch "Server-only mods.*ignored for hashing") { Write-Error "Server-only mod warning not found in log"; exit 1 }

Write-Host "Test $TestName passed."