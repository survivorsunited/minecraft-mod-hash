# 00020-zip-content-validation.ps1
# Functional test: Validate ZIP file contents and structure

$ErrorActionPreference = "Stop"

$TestName = "00020-zip-content-validation"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create test mods for ZIP validation
$testModsPath = "$TestOut/test-mods"
if (Test-Path $testModsPath) { Remove-Item -Path $testModsPath -Recurse -Force }
New-Item -ItemType Directory -Path $testModsPath -Force | Out-Null

# Create multiple test mods including expected ones
$testMods = @(
    @{ name = "appleskin-test"; id = "appleskin"; desc = "AppleSkin test mod" },
    @{ name = "balm-test"; id = "balm"; desc = "Balm test mod" },
    @{ name = "fabric-api-test"; id = "fabricapi"; desc = "Fabric API test mod" }
)

foreach ($mod in $testMods) {
    $modPath = "$testModsPath/$($mod.name)-1.0.0.jar"
    $tempDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
    if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $fabricModJson = @{
        schemaVersion = 1
        id = $mod.id
        name = $mod.name
        version = "1.0.0"
        description = $mod.desc
        environment = "client"
    }
    $fabricModJson | ConvertTo-Json | Out-File -FilePath "$tempDir/fabric.mod.json" -Encoding UTF8

    # Create JAR file
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $modPath)
    Remove-Item -Path $tempDir -Recurse -Force
}

# Create versioned directory
$releaseVersion = Get-Date -Format "yyyy.M.d-HHmmss"
$versionedDir = Join-Path $TestOut $releaseVersion
if (-not (Test-Path $versionedDir)) { New-Item -ItemType Directory -Path $versionedDir | Out-Null }

# Run and capture to temp log
$tempLog = "$versionedDir/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
& "../hash.ps1" -CreateZip -ModsPath $testModsPath -OutputPath $versionedDir *>&1 | Tee-Object -FilePath $tempLog

# Assertions
$hashFile = Join-Path $versionedDir "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionedDir "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Find the zip file
$zipFile = Join-Path $versionedDir "modpack.zip"
if (-not (Test-Path $zipFile)) { Write-Error "modpack.zip not found in version directory"; exit 1 }

# Verify signature files exist
if (-not (Test-Path "$zipFile.md5")) { Write-Error "MD5 signature file not found"; exit 1 }
if (-not (Test-Path "$zipFile.sha1")) { Write-Error "SHA1 signature file not found"; exit 1 }
if (-not (Test-Path "$zipFile.sha256")) { Write-Error "SHA256 signature file not found"; exit 1 }
if (-not (Test-Path "$zipFile.sha512")) { Write-Error "SHA512 signature file not found"; exit 1 }

# Extract and validate zip contents
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempExtractDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $tempExtractDir)

try {
    # Verify ZIP contains JAR files
    $jarFiles = Get-ChildItem $tempExtractDir -Filter "*.jar"
    if ($jarFiles.Count -eq 0) { Write-Error "No JAR files found in zip"; exit 1 }

    # Verify ZIP contains README
    $zipReadme = Get-ChildItem $tempExtractDir -Filter "*.md" | Select-Object -First 1
    if (-not $zipReadme) { Write-Error "No README file found in zip"; exit 1 }

    # Validate ZIP README content
    $zipReadmeContent = Get-Content $zipReadme.FullName -Raw
    if ($zipReadmeContent -notmatch "# Minecraft Modpack Package") { Write-Error "ZIP README missing main title"; exit 1 }
    if ($zipReadmeContent -notmatch "## Package Contents") { Write-Error "ZIP README missing package contents section"; exit 1 }
    if ($zipReadmeContent -notmatch "## Installation Instructions") { Write-Error "ZIP README missing installation instructions"; exit 1 }
    if ($zipReadmeContent -notmatch "## Package Verification") { Write-Error "ZIP README missing verification section"; exit 1 }

    # Verify hash values are present in ZIP README (not placeholder)
    if ($zipReadmeContent -match "\[TO BE CALCULATED\]") { Write-Error "ZIP README contains placeholder hash values"; exit 1 }

    # Verify some mandatory mods are present
    $expectedMods = @("appleskin", "balm", "fabric-api")
    foreach ($expectedMod in $expectedMods) {
        $found = $jarFiles | Where-Object { $_.Name -like "*$expectedMod*" }
        if (-not $found) { Write-Error "Expected mod $expectedMod not found in zip"; exit 1 }
    }

} finally {
    # Clean up
    Remove-Item -Path $tempExtractDir -Recurse -Force
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