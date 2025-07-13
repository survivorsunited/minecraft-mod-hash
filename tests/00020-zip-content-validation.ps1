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

& "../hash.ps1" -CreateZip -ModsPath $testModsPath -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }

# Find the zip file
$zipFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*.zip" | Select-Object -First 1
if (-not $zipFile) { Write-Error "mods zip file not found"; exit 1 }

# Verify signature files exist
if (-not (Test-Path "$TestOut/$($zipFile.Name).md5")) { Write-Error "MD5 signature file not found"; exit 1 }
if (-not (Test-Path "$TestOut/$($zipFile.Name).sha1")) { Write-Error "SHA1 signature file not found"; exit 1 }
if (-not (Test-Path "$TestOut/$($zipFile.Name).sha256")) { Write-Error "SHA256 signature file not found"; exit 1 }
if (-not (Test-Path "$TestOut/$($zipFile.Name).sha512")) { Write-Error "SHA512 signature file not found"; exit 1 }

# Extract and validate zip contents
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempExtractDir = Join-Path "./temp" ([System.Guid]::NewGuid().ToString())
if (-not (Test-Path "./temp")) { New-Item -ItemType Directory -Path "./temp" -Force | Out-Null }
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $tempExtractDir)

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

Write-Host "Test $TestName passed."