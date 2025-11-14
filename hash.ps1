# PowerShell script to generate hash.txt with mandatory and soft-whitelisted mods
# Designed to run from .minecraft folder
# Mandatory mods: all .jar files in mods/ directory
# Soft-whitelisted mods: all .jar files in mods/optional/ directory

param(
    [switch]$UpdateConfig,
    [switch]$CreateZip,
    [string]$ConfigPath = "config\InertiaAntiCheat\InertiaAntiCheat.toml",
    [string]$MotdMessage = "Whitelisted mods:",
    [string]$ModpackMessage = "Requires modpack: ",
    [string]$BannedModsMessage = "Banned mods: ",
    [string]$ModsPath = "mods",
    [string]$OutputPath = "output",
    [string]$ModListPath = "modlist.csv"
)

# Ensure parent directory for config exists
$configDir = Split-Path $ConfigPath -Parent
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Function to calculate MD5 hash of a file
function Get-FileMD5 {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm MD5
    return $hash.Hash.ToLower()
}

# Function to calculate MD5 hash of a string
function Get-StringMD5 {
    param([string]$InputString)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hashBytes = $md5.ComputeHash($inputBytes)
    $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    $md5.Dispose()
    return $hash
}

# Function to get mod name from fabric.mod.json, META-INF/MANIFEST.MF, or fallback to filename
function Get-ModName {
    param([string]$FilePath)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        # 1. Try fabric.mod.json first
        $fabricEntry = $zip.Entries | Where-Object { $_.Name -eq "fabric.mod.json" }
        if ($fabricEntry) {
            $reader = New-Object System.IO.StreamReader($fabricEntry.Open())
            $jsonContent = $reader.ReadToEnd()
            $reader.Close()
            $json = $jsonContent | ConvertFrom-Json
            if ($json.name) {
                $zip.Dispose()
                return $json.name.Trim()
            }
        }
        # 2. Try META-INF/MANIFEST.MF
        $manifestEntry = $zip.Entries | Where-Object { $_.FullName -eq "META-INF/MANIFEST.MF" }
        if ($manifestEntry) {
            $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
            $manifestContent = $reader.ReadToEnd()
            $reader.Close()
            # Look for Specification-Title or Implementation-Title
            $specTitle = ($manifestContent -split "`n") | Where-Object { $_ -match "^Specification-Title:" } | ForEach-Object { $_.Split(":")[1].Trim() }
            if ($specTitle -and $specTitle -ne "") {
                $zip.Dispose()
                return $specTitle
            }
            $implTitle = ($manifestContent -split "`n") | Where-Object { $_ -match "^Implementation-Title:" } | ForEach-Object { $_.Split(":")[1].Trim() }
            if ($implTitle -and $implTitle -ne "") {
                $zip.Dispose()
                return $implTitle
            }
        }
        $zip.Dispose()
    } catch {
        Write-Host "  Warning: Could not read fabric.mod.json or manifest from $([System.IO.Path]::GetFileName($FilePath))" -ForegroundColor Yellow
    }
    # 3. Fallback: clean up filename
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $name = $fileName -replace '\.jar$', ''
    $name = $name -replace '[-+][0-9]+\.[0-9]+\.[0-9]+.*$', ''
    $name = $name -replace '-fabric.*$', ''
    $name = $name -replace '-mc.*$', ''
    $name = $name -replace '[-+][0-9]+\.[0-9]+.*$', ''
    return $name
}

# Function to update InertiaAntiCheat config
function Update-IACConfig {
    param(
        [string]$ConfigPath,
        [string]$CombinedHash,
        [array]$SoftWhitelist,
        [array]$AllModNames,
        [array]$RequiredModNames,
        [array]$OptionalModNames,
        [array]$BlockedMods,
        [array]$BlockedModNames,
        [string]$MotdMessage,
        [string]$ModpackMessage,
        [string]$BannedModsMessage
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: IAC config file not found: $ConfigPath" -ForegroundColor Red
        Write-Host "Please ensure InertiaAntiCheat is installed and has generated its config file." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Reading existing IAC config: $ConfigPath" -ForegroundColor Yellow
    
    # Read existing config as array of lines
    $configLines = Get-Content $ConfigPath
    
    # Find section boundaries
    $validationGroupStart = -1
    $validationGroupEnd = -1
    $validationIndividualStart = -1
    $validationIndividualEnd = -1
    $motdStart = -1
    $motdEnd = -1
    
    for ($i = 0; $i -lt $configLines.Count; $i++) {
        $line = $configLines[$i].Trim()
        
        if ($line -eq "[validation.group]") {
            $validationGroupStart = $i
        } elseif ($line -eq "[validation.individual]") {
            $validationIndividualStart = $i
        } elseif ($line -eq "[motd]") {
            $motdStart = $i
        } elseif ($validationGroupStart -ne -1 -and $validationGroupEnd -eq -1 -and $line.StartsWith("[") -and $line -ne "[validation.group]") {
            $validationGroupEnd = $i - 1
        } elseif ($validationIndividualStart -ne -1 -and $validationIndividualEnd -eq -1 -and $line.StartsWith("[") -and $line -ne "[validation.individual]") {
            $validationIndividualEnd = $i - 1
        } elseif ($motdStart -ne -1 -and $motdEnd -eq -1 -and $line.StartsWith("[") -and $line -ne "[motd]") {
            $motdEnd = $i - 1
        }
    }
    
    # Set end boundaries if sections extend to end of file
    if ($validationGroupStart -ne -1 -and $validationGroupEnd -eq -1) {
        $validationGroupEnd = $configLines.Count - 1
    }
    if ($validationIndividualStart -ne -1 -and $validationIndividualEnd -eq -1) {
        $validationIndividualEnd = $configLines.Count - 1
    }
    if ($motdStart -ne -1 -and $motdEnd -eq -1) {
        $motdEnd = $configLines.Count - 1
    }
    
    # Track updates
    $hashUpdated = $false
    $softWhitelistUpdated = $false
    $blacklistUpdated = $false
    $whitelistUpdated = $false
    $motdBlacklistUpdated = $false
    $modpackHashUpdated = $false
    
    # Update validation.group section
    if ($validationGroupStart -ne -1) {
        Write-Host "Updating [validation.group] section..." -ForegroundColor Yellow
        
        # Only look within the validation.group section
        for ($i = $validationGroupStart + 1; $i -le $validationGroupEnd; $i++) {
            $line = $configLines[$i]
            $trimmedLine = $line.Trim()
            
            if ($trimmedLine.StartsWith("hash") -and $trimmedLine.Contains("=") -and -not $hashUpdated) {
                $configLines[$i] = ('hash = ["{0}"]' -f $CombinedHash)
                Write-Host "  Updated hash line" -ForegroundColor Yellow
                $hashUpdated = $true
            } elseif ($trimmedLine.StartsWith("softWhitelist") -and $trimmedLine.Contains("=") -and -not $softWhitelistUpdated) {
                $configLines[$i] = "softWhitelist = [$(($SoftWhitelist | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
                Write-Host "  Updated softWhitelist line" -ForegroundColor Yellow
                $softWhitelistUpdated = $true
            }
        }
    } else {
        Write-Host "Adding [validation.group] section..." -ForegroundColor Yellow
        $configLines += ""
        $configLines += "[validation.group]"
        $configLines += ('hash = ["{0}"]' -f $CombinedHash)
        $configLines += "softWhitelist = [$(($SoftWhitelist | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
    }
    
    # Update validation.individual section
    if ($validationIndividualStart -ne -1) {
        Write-Host "Updating [validation.individual] section..." -ForegroundColor Yellow
        
        # Only look within the validation.individual section
        for ($i = $validationIndividualStart + 1; $i -le $validationIndividualEnd; $i++) {
            $line = $configLines[$i]
            $trimmedLine = $line.Trim()
            
            if ($trimmedLine.StartsWith("blacklist") -and $trimmedLine.Contains("=") -and -not $blacklistUpdated) {
                $blockedHashes = $BlockedMods | ForEach-Object { $_.Hash }
                $configLines[$i] = "blacklist = [$(($blockedHashes | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
                Write-Host "  Updated blacklist line" -ForegroundColor Yellow
                $blacklistUpdated = $true
            }
        }
    } else {
        Write-Host "Adding [validation.individual] section..." -ForegroundColor Yellow
        $configLines += ""
        $configLines += "[validation.individual]"
        $blockedHashes = $BlockedMods | ForEach-Object { $_.Hash }
        $configLines += "blacklist = [$(($blockedHashes | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
    }
    
    # Update motd section
    if ($motdStart -ne -1) {
        Write-Host "Updating [motd] section..." -ForegroundColor Yellow
        
        # Only look within the motd section
        for ($i = $motdStart + 1; $i -le $motdEnd; $i++) {
            $line = $configLines[$i]
            $trimmedLine = $line.Trim()
            
            if ($trimmedLine.StartsWith("whitelist") -and $trimmedLine.Contains("=") -and -not $whitelistUpdated) {
                $configLines[$i] = "whitelist = [$(($OptionalModNames | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
                Write-Host "  Updated whitelist line" -ForegroundColor Yellow
                $whitelistUpdated = $true
            } elseif ($trimmedLine.StartsWith("blacklist") -and $trimmedLine.Contains("=") -and -not $motdBlacklistUpdated) {
                $configLines[$i] = "blacklist = [$(($BlockedModNames | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
                Write-Host "  Updated blacklist line" -ForegroundColor Yellow
                $motdBlacklistUpdated = $true
            }
        }
    } else {
        Write-Host "Adding [motd] section..." -ForegroundColor Yellow
        $configLines += ""
        $configLines += "[motd]"
        $configLines += "whitelist = [$(($OptionalModNames | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
        $configLines += "blacklist = [$(($BlockedModNames | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
    }
    
    # Update modpack hash line (outside any section)
    for ($i = 0; $i -lt $configLines.Count; $i++) {
        $line = $configLines[$i]
        $trimmedLine = $line.Trim()
        
        # Look for the modpack hash line that contains the default modpack message
        if ($trimmedLine.StartsWith("hash") -and $trimmedLine.Contains("=") -and $trimmedLine.Contains("Requires modpack") -and -not $modpackHashUpdated) {
            $configLines[$i] = "hash = [$(($RequiredModNames | ForEach-Object { '"' + $_ + '"' }) -join ", ")]"
            Write-Host "  Updated modpack hash line" -ForegroundColor Yellow
            $modpackHashUpdated = $true
        }
    }
    
    # Remove existing auto-update comments and add new one at the top
    $configLines = $configLines | Where-Object { -not $_.Trim().StartsWith("# Auto-Updated by hash.ps1") }
    $configLines = @("# Auto-Updated by hash.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")") + $configLines
    
    $configLines | Out-File -FilePath $ConfigPath -Encoding UTF8
    Write-Host "IAC config updated: $ConfigPath" -ForegroundColor Green
}

# Function to extract mod information from JAR file
function Extract-ModInfo {
    param(
        [string]$JarPath
    )
    
    $modInfo = @{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($JarPath)
        Hash = ""
        Id = ""
        Description = ""
        Version = ""
        Contact = ""
        Homepage = ""
        License = ""
        Category = ""
        JarFileName = [System.IO.Path]::GetFileName($JarPath)
        Environment = ""
    }
    
    try {
        # Calculate MD5 hash first
        $modInfo.Hash = (Get-FileHash -Path $JarPath -Algorithm MD5).Hash.ToLower()
        
        # Create a temporary directory for extraction (within project)
        $tempBase = "./tests/temp"
        if (-not (Test-Path $tempBase)) { New-Item -ItemType Directory -Path $tempBase -Force | Out-Null }
        $tempDir = Join-Path $tempBase ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Extract fabric.mod.json using PowerShell's built-in ZIP functionality
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
        
        $fabricModJsonEntry = $zip.GetEntry("fabric.mod.json")
        if ($fabricModJsonEntry) {
            $fabricModJson = Join-Path $tempDir "fabric.mod.json"
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($fabricModJsonEntry, $fabricModJson, $true)
            
            if (Test-Path $fabricModJson) {
                $jsonContent = Get-Content $fabricModJson -Raw | ConvertFrom-Json
                
                # Extract basic info
                if ($jsonContent.name) {
                    $modInfo.Name = $jsonContent.name
                }
                if ($jsonContent.id) {
                    $modInfo.Id = $jsonContent.id
                }
                if ($jsonContent.description) {
                    $modInfo.Description = $jsonContent.description
                }
                if ($jsonContent.version) {
                    $modInfo.Version = $jsonContent.version
                }
                
                # Extract contact/homepage info
                if ($jsonContent.contact) {
                    if ($jsonContent.contact.homepage) {
                        $modInfo.Homepage = $jsonContent.contact.homepage
                    }
                    if ($jsonContent.contact.issues) {
                        $modInfo.Contact = $jsonContent.contact.issues
                    }
                }
                
                # Extract license
                if ($jsonContent.license) {
                    $modInfo.License = $jsonContent.license
                }
                # Extract environment
                if ($jsonContent.environment) {
                    $modInfo.Environment = $jsonContent.environment
                }
            }
        } else {
            # Fallback to MANIFEST.MF
            $manifestEntry = $zip.GetEntry("META-INF/MANIFEST.MF")
            if ($manifestEntry) {
                $manifestPath = Join-Path $tempDir "MANIFEST.MF"
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($manifestEntry, $manifestPath, $true)
                
                if (Test-Path $manifestPath) {
                    $manifestContent = Get-Content $manifestPath -Raw
                    $lines = $manifestContent -split "`r?`n"
                    
                    foreach ($line in $lines) {
                        if ($line -match "Specification-Title:\s*(.+)") {
                            $modInfo.Name = $matches[1].Trim()
                        } elseif ($line -match "Implementation-Title:\s*(.+)") {
                            if (-not $modInfo.Name) {
                                $modInfo.Name = $matches[1].Trim()
                            }
                        }
                    }
                }
            }
        }
        
        $zip.Dispose()
        
    } catch {
        Write-Warning "Could not read fabric.mod.json or manifest from $([System.IO.Path]::GetFileName($JarPath))"
    } finally {
        # Clean up temporary directory
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    # If name is still the raw filename (no fabric.mod.json or MANIFEST.MF provided a clean name),
    # use Get-ModName for filename-based cleaning
    $rawFileName = [System.IO.Path]::GetFileNameWithoutExtension($JarPath)
    if ($modInfo.Name -eq $rawFileName) {
        $modInfo.Name = Get-ModName -FilePath $JarPath
    }
    
    return $modInfo
}

# Function to look up Category from modlist.csv
function Get-ModCategory {
    param(
        [hashtable]$ModInfo,
        [string]$ModListPath
    )
    
    if (-not (Test-Path $ModListPath)) {
        return ""
    }
    
    try {
        $modList = Import-Csv -Path $ModListPath
        if ($modList) {
            # Try to match by ID first (most reliable)
            if ($ModInfo.Id) {
                $match = $modList | Where-Object { $_.ID -eq $ModInfo.Id }
                if ($match -and $match.Category) {
                    return $match.Category
                }
            }
            
            # Fallback: try to match by Name
            if ($ModInfo.Name) {
                $match = $modList | Where-Object { $_.Name -eq $ModInfo.Name }
                if ($match -and $match.Category) {
                    return $match.Category
                }
            }
            
            # Fallback: try to match by Jar filename
            if ($ModInfo.JarFileName) {
                $match = $modList | Where-Object { $_.Jar -eq $ModInfo.JarFileName }
                if ($match -and $match.Category) {
                    return $match.Category
                }
            }
        }
    } catch {
        # Silently fail if modlist.csv can't be read
    }
    
    return ""
}

# Function to create signature files for a file
function Create-SignatureFiles {
    param([string]$FilePath)
    
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileDir = [System.IO.Path]::GetDirectoryName($FilePath)
    
    Write-Host "  Creating signature files for $fileName..." -ForegroundColor Gray
    
    # Create MD5 signature
    $md5Hash = Get-FileHash -Path $FilePath -Algorithm MD5
    $md5Content = "$($md5Hash.Hash.ToLower()) *$fileName"
    $md5Path = Join-Path $fileDir "$fileName.md5"
    $md5Content | Out-File -FilePath $md5Path -Encoding UTF8
    Write-Host "    Created: $([System.IO.Path]::GetFileName($md5Path))" -ForegroundColor Gray
    
    # Create SHA1 signature
    $sha1Hash = Get-FileHash -Path $FilePath -Algorithm SHA1
    $sha1Content = "$($sha1Hash.Hash.ToLower()) *$fileName"
    $sha1Path = Join-Path $fileDir "$fileName.sha1"
    $sha1Content | Out-File -FilePath $sha1Path -Encoding UTF8
    Write-Host "    Created: $([System.IO.Path]::GetFileName($sha1Path))" -ForegroundColor Gray
    
    # Create SHA256 signature
    $sha256Hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    $sha256Content = "$($sha256Hash.Hash.ToLower()) *$fileName"
    $sha256Path = Join-Path $fileDir "$fileName.sha256"
    $sha256Content | Out-File -FilePath $sha256Path -Encoding UTF8
    Write-Host "    Created: $([System.IO.Path]::GetFileName($sha256Path))" -ForegroundColor Gray
    
    # Create SHA512 signature
    $sha512Hash = Get-FileHash -Path $FilePath -Algorithm SHA512
    $sha512Content = "$($sha512Hash.Hash.ToLower()) *$fileName"
    $sha512Path = Join-Path $fileDir "$fileName.sha512"
    $sha512Content | Out-File -FilePath $sha512Path -Encoding UTF8
    Write-Host "    Created: $([System.IO.Path]::GetFileName($sha512Path))" -ForegroundColor Gray
    
    return @{
        MD5 = $md5Hash.Hash.ToLower()
        SHA1 = $sha1Hash.Hash.ToLower()
        SHA256 = $sha256Hash.Hash.ToLower()
        SHA512 = $sha512Hash.Hash.ToLower()
    }
}

# Function to create zip file with all mods
function Create-ModsZip {
    param(
        [array]$MandatoryMods,
        [array]$SoftWhitelistedMods,
        [string]$CombinedHash,
        [string]$OutputPath
    )
    
    $zipFileName = "modpack.zip"
    
    Write-Host "Creating mods zip file: $zipFileName" -ForegroundColor Yellow
    
    try {
        # Load the ZIP assembly
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Create the zip file (use absolute path for reliability)
        $resolvedOutput = try { (Resolve-Path $OutputPath).ProviderPath } catch { $OutputPath }
        $zipPath = Join-Path $resolvedOutput $zipFileName
        
        # Create a temporary directory to organize files
        $tempBase = "./tests/temp"
        if (-not (Test-Path $tempBase)) { New-Item -ItemType Directory -Path $tempBase -Force | Out-Null }
        $tempDir = Join-Path $tempBase ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Build folder structure: mods/, mods/optional/, mods/server/, shaderpacks/, datapacks/, install/, config/InertiaAntiCheat/
        $tempModsDir = Join-Path $tempDir 'mods'
        $tempModsOptionalDir = Join-Path $tempModsDir 'optional'
        $tempModsServerDir = Join-Path $tempModsDir 'server'
        $tempShaderpacksDir = Join-Path $tempDir 'shaderpacks'
        $tempDatapacksDir = Join-Path $tempDir 'datapacks'
        $tempInstallDir = Join-Path $tempDir 'install'
        $tempIacConfigDir = Join-Path $tempDir 'config\InertiaAntiCheat'
        New-Item -ItemType Directory -Path $tempModsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempModsOptionalDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempModsServerDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempShaderpacksDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempDatapacksDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempInstallDir -Force | Out-Null
        New-Item -ItemType Directory -Path $tempIacConfigDir -Force | Out-Null

        # Copy all mandatory mods under mods/
        Write-Host "  Adding mandatory mods..." -ForegroundColor Gray
        foreach ($mod in $MandatoryMods) {
            $sourcePath = Join-Path $ModsPath $mod.JarFileName
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath $tempModsDir
                Write-Host "    Added: $($mod.Name)" -ForegroundColor Gray
            } else {
                Write-Host "    Warning: Could not find JAR file: $($mod.JarFileName) for $($mod.Name)" -ForegroundColor Yellow
            }
        }

        # Copy all optional mods under mods/optional/
        if ($SoftWhitelistedMods.Count -gt 0) {
            Write-Host "  Adding optional mods..." -ForegroundColor Gray
            foreach ($mod in $SoftWhitelistedMods) {
                $sourcePath = Join-Path $ModsPath\optional $mod.JarFileName
                if (Test-Path $sourcePath) {
                    Copy-Item $sourcePath $tempModsOptionalDir
                    Write-Host "    Added: $($mod.Name)" -ForegroundColor Gray
                } else {
                    Write-Host "    Warning: Could not find JAR file: $($mod.JarFileName) for $($mod.Name)" -ForegroundColor Yellow
                }
            }
        }

        # Copy server-only mods under mods/server/
        $modsServerPath = Join-Path $ModsPath 'server'
        if (Test-Path $modsServerPath) {
            Write-Host "  Adding server-only mods..." -ForegroundColor Gray
            $serverJars = Get-ChildItem -Path $modsServerPath -Filter '*.jar' -File -ErrorAction SilentlyContinue
            foreach ($sj in $serverJars) {
                Copy-Item -Path $sj.FullName -Destination (Join-Path $tempModsServerDir $sj.Name)
                Write-Host "    Added: $($sj.Name)" -ForegroundColor Gray
            }
        }

        # Copy shaderpacks (if a sibling shaderpacks/ exists next to ModsPath)
        $modsParent = Split-Path -Parent $ModsPath
        $shaderpacksPath = Join-Path $modsParent 'shaderpacks'
        if (Test-Path $shaderpacksPath) {
            Write-Host "  Adding shaderpacks..." -ForegroundColor Gray
            $shaderFiles = Get-ChildItem -Path $shaderpacksPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip','.jar') }
            foreach ($sp in $shaderFiles) {
                Copy-Item $sp.FullName -Destination (Join-Path $tempShaderpacksDir $sp.Name)
                Write-Host "    Added: $($sp.Name)" -ForegroundColor Gray
            }
        }

        # Copy datapacks (if a sibling datapacks/ exists next to ModsPath)
        $datapacksPath = Join-Path $modsParent 'datapacks'
        if (Test-Path $datapacksPath) {
            Write-Host "  Adding datapacks..." -ForegroundColor Gray
            # Only include ZIP datapacks here; JAR datapacks are placed into mods during release build
            $dpFiles = Get-ChildItem -Path $datapacksPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip') }
            foreach ($dp in $dpFiles) {
                Copy-Item $dp.FullName -Destination (Join-Path $tempDatapacksDir $dp.Name)
                Write-Host "    Added: $($dp.Name)" -ForegroundColor Gray
            }
        }

        # copy install files (if a sibling install/ exists next to ModsPath)
        $installPath = Join-Path $modsParent 'install'
        if (Test-Path $installPath) {
            Write-Host "  Adding install files..." -ForegroundColor Gray
            $installFiles = Get-ChildItem -Path $installPath -File -ErrorAction SilentlyContinue
            foreach ($inst in $installFiles) {
                Copy-Item $inst.FullName -Destination (Join-Path $tempInstallDir $inst.Name)
                Write-Host "    Added: $($inst.Name)" -ForegroundColor Gray
            }
        }

        # Copy server jars to ZIP root (if present alongside ModsPath)
        $minecraftServerJar = Get-ChildItem -Path $modsParent -Filter 'minecraft_server*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($minecraftServerJar) {
            Copy-Item -Path $minecraftServerJar.FullName -Destination (Join-Path $tempDir $minecraftServerJar.Name)
            Write-Host "  Added server jar at root: $($minecraftServerJar.Name)" -ForegroundColor Gray
        }
        $fabricServerJar = Get-ChildItem -Path $modsParent -Filter 'fabric-server*.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($fabricServerJar) {
            Copy-Item -Path $fabricServerJar.FullName -Destination (Join-Path $tempDir $fabricServerJar.Name)
            Write-Host "  Added fabric server launcher at root: $($fabricServerJar.Name)" -ForegroundColor Gray
        }

        # Include InertiaAntiCheat config inside config/InertiaAntiCheat/ if present next to ModsPath
        $iacConfig = Join-Path $modsParent 'config\InertiaAntiCheat\InertiaAntiCheat.toml'
        if (Test-Path $iacConfig) {
            Copy-Item -Path $iacConfig -Destination (Join-Path $tempIacConfigDir 'InertiaAntiCheat.toml') -Force
            Write-Host "  Added: config/InertiaAntiCheat/InertiaAntiCheat.toml" -ForegroundColor Gray
        }

        # Warn if any ZIPs are present under mods/ (likely misclassification)
        $modsZips = @()
        $modsZips += (Get-ChildItem -Path $ModsPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.zip' })
        $modsOptionalPath = Join-Path $ModsPath 'optional'
        if (Test-Path $modsOptionalPath) {
            $modsZips += (Get-ChildItem -Path $modsOptionalPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.zip' })
        }
        foreach ($z in $modsZips) {
            Write-Host "  Warning: ZIP under mods detected (expected JAR) -> $($z.Name)" -ForegroundColor Yellow
        }
        
        # Create README.md for the zip package
        $zipReadmeContent = @()
        $zipReadmeContent += "# Minecraft Modpack Package"
        $zipReadmeContent += ""
        $zipReadmeContent += "**Package:** $zipFileName"
        $zipReadmeContent += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $zipReadmeContent += "**Combined Hash:** $CombinedHash"
        $zipReadmeContent += ""
        $zipReadmeContent += "## Package Contents"
        $zipReadmeContent += ""
    $zipReadmeContent += "This package contains the modpack with expected folder structure (mods/, mods/server/, mods/optional/, shaderpacks/, datapacks/, install/)."
        $zipReadmeContent += "If available, the Minecraft server jar and Fabric server launcher are included at the ZIP root."
        $zipReadmeContent += ""
        $zipReadmeContent += "### Mandatory Mods ($($MandatoryMods.Count))"
        foreach ($mod in $MandatoryMods) {
            $zipReadmeContent += "- **$($mod.Name)** v$($mod.Version) - $($mod.Description)"
        }
        
        if ($SoftWhitelistedMods.Count -gt 0) {
            $zipReadmeContent += ""
            $zipReadmeContent += "### Optional Mods ($($SoftWhitelistedMods.Count))"
            foreach ($mod in $SoftWhitelistedMods) {
                $zipReadmeContent += "- **$($mod.Name)** v$($mod.Version) - $($mod.Description)"
            }
        }

        if ($blockedMods.Count -gt 0) {
            $zipReadmeContent += ""
            $zipReadmeContent += "### Blocked Mods ($($blockedMods.Count))"
            foreach ($mod in $blockedMods) {
                $zipReadmeContent += "- **$($mod.Name)** v$($mod.Version) - $($mod.Description)"
            }
        }

        # List server-only mods if present
        if (Test-Path $modsServerPath) {
            $srvList = Get-ChildItem -Path $modsServerPath -Filter '*.jar' -File -ErrorAction SilentlyContinue
            if ($srvList.Count -gt 0) {
                $zipReadmeContent += ""
                $zipReadmeContent += "### Server-only Mods ($($srvList.Count))"
                foreach ($f in $srvList) { $zipReadmeContent += "- $($f.Name)" }
            }
        }
        
        $zipReadmeContent += ""
        $zipReadmeContent += "## Installation Instructions"
        $zipReadmeContent += ""
        $zipReadmeContent += "1. Extract the contents of this zip."
        $zipReadmeContent += "2. Copy the 'mods' folder into your `.minecraft/` folder (preserving the 'optional' subfolder)."
        $zipReadmeContent += "3. If you use shaders, copy the 'shaderpacks' folder into your `.minecraft/` folder."
        $zipReadmeContent += "4. If your server/client uses datapacks, copy the 'datapacks' folder into the world folder (or as per your server setup)."
        $zipReadmeContent += "5. (Optional) Run the installer found under 'install/' to install the required loader (e.g., Fabric)."
        $zipReadmeContent += "6. Ensure you have the correct loader installed (e.g., Fabric) for your Minecraft version."
        $zipReadmeContent += "7. Start Minecraft and join the server."
        $zipReadmeContent += ""
        $zipReadmeContent += "## Package Verification"
        $zipReadmeContent += ""
        $zipReadmeContent += "``````powershell"
        $zipReadmeContent += "# Windows PowerShell"
        $zipReadmeContent += "Get-FileHash -Path `"$zipFileName`" -Algorithm MD5"
        $zipReadmeContent += "Get-FileHash -Path `"$zipFileName`" -Algorithm SHA1"
        $zipReadmeContent += "Get-FileHash -Path `"$zipFileName`" -Algorithm SHA256"
        $zipReadmeContent += "Get-FileHash -Path `"$zipFileName`" -Algorithm SHA512"
        $zipReadmeContent += "``````"
        $zipReadmeContent += ""
        $zipReadmeContent += "``````bash"
        $zipReadmeContent += "# Linux/macOS"
        $zipReadmeContent += "md5sum `"$zipFileName`""
        $zipReadmeContent += "sha1sum `"$zipFileName`""
        $zipReadmeContent += "sha256sum `"$zipFileName`""
        $zipReadmeContent += "sha512sum `"$zipFileName`""
        $zipReadmeContent += "``````"
        $zipReadmeContent += ""
        $zipReadmeContent += "## Support"
        $zipReadmeContent += ""
        $zipReadmeContent += "If you encounter issues with this modpack, please contact the server administrator."
        $zipReadmeContent += ""
        $zipReadmeContent += "---"
        $zipReadmeContent += "*This package was automatically generated by hash.ps1*"
        
        # Write README.md to temp directory
        $zipReadmeFileName = "README.md"
        $zipReadmePath = Join-Path $tempDir $zipReadmeFileName
        $zipReadmeContent | Out-File -FilePath $zipReadmePath -Encoding UTF8
        Write-Host "  Added: $zipReadmeFileName" -ForegroundColor Gray
        
        # Create the zip file from the temp directory
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
        
        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force
        
        # Create signature files for the zip
        $signatures = Create-SignatureFiles -FilePath $zipPath
        
        # Update the README.md inside the zip with actual hash values
        $updatedZipReadmeContent = $zipReadmeContent -replace "\[TO BE CALCULATED\]", $signatures.MD5
        $updatedZipReadmeContent = $updatedZipReadmeContent -replace "\[TO BE CALCULATED\]", $signatures.SHA1
        $updatedZipReadmeContent = $updatedZipReadmeContent -replace "\[TO BE CALCULATED\]", $signatures.SHA256
        $updatedZipReadmeContent = $updatedZipReadmeContent -replace "\[TO BE CALCULATED\]", $signatures.SHA512
        
        # Create a new temp directory for the updated README
        $tempBase2 = "./tests/temp"
        if (-not (Test-Path $tempBase2)) { New-Item -ItemType Directory -Path $tempBase2 -Force | Out-Null }
        $tempDir2 = Join-Path $tempBase2 ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir2 -Force | Out-Null
        
        # Copy all files from the zip to temp directory
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir2)
        
        # Update the README.md with actual hash values
        $updatedZipReadmePath = Join-Path $tempDir2 $zipReadmeFileName
        $updatedZipReadmeContent | Out-File -FilePath $updatedZipReadmePath -Encoding UTF8
        
        # Recreate the zip with updated README
        Remove-Item -Path $zipPath -Force
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir2, $zipPath)
        
        # Clean up second temp directory
        Remove-Item -Path $tempDir2 -Recurse -Force
        
        Write-Host "  Zip file created successfully: $zipFileName" -ForegroundColor Green
        return @{
            Path = $zipPath
            Signatures = $signatures
        }
        
    } catch {
        Write-Host "  Error creating zip file: $($_.Exception.Message)" -ForegroundColor Red
        # Clean up temp directories if they exist
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
        if ($tempDir2 -and (Test-Path $tempDir2)) {
            Remove-Item -Path $tempDir2 -Recurse -Force
        }
        return $null
    }
}

Write-Host "Generating hash.txt with mandatory and soft-whitelisted mods..." -ForegroundColor Green

# Validate input paths
if (-not (Test-Path $ModsPath)) {
    Write-Host "Error: Mods path not found: $ModsPath" -ForegroundColor Red
    Write-Host "Please ensure the mods directory exists or specify a valid path with -ModsPath" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $OutputPath)) {
    Write-Host "Creating output directory: $OutputPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Process mandatory mods
Write-Host "Processing mandatory mods from $ModsPath..." -ForegroundColor Yellow
$mandatoryMods = @()
$serverOnlyMandatoryMods = @()
$mandatoryJars = Get-ChildItem -Path $ModsPath -Filter "*.jar" | Sort-Object Name
foreach ($jar in $mandatoryJars) {
    $modInfo = Extract-ModInfo -JarPath $jar.FullName
    # Look up Category from modlist.csv
    $modInfo.Category = Get-ModCategory -ModInfo $modInfo -ModListPath $ModListPath
    if ($modInfo.Environment -eq "server") {
        $serverOnlyMandatoryMods += $modInfo
    } else {
        $mandatoryMods += $modInfo
        Write-Host "  $($jar.Name) -> $($modInfo.Hash) ($($modInfo.Name))" -ForegroundColor Gray
    }
}
if ($serverOnlyMandatoryMods.Count -gt 0) {
    Write-Host "Server-only mods (ignored for hashing) from ${ModsPath}:" -ForegroundColor DarkYellow
    foreach ($mod in $serverOnlyMandatoryMods) {
        Write-Host "  $($mod.JarFileName) ($($mod.Name))" -ForegroundColor DarkYellow
    }
}
# Filter mandatory mods by environment
$mandatoryMods = $mandatoryMods | Where-Object { $_.Environment -eq "" -or $_.Environment -eq "*" -or $_.Environment -eq "client" }

# Process soft-whitelisted mods
Write-Host "Processing soft-whitelisted mods from $ModsPath\optional..." -ForegroundColor Yellow
$softWhitelistedMods = @()
$serverOnlyOptionalMods = @()
$optionalModsPath = Join-Path $ModsPath "optional"
if (Test-Path $optionalModsPath) {
    $optionalJars = Get-ChildItem -Path $optionalModsPath -Filter "*.jar" | Sort-Object Name
    foreach ($jar in $optionalJars) {
        $modInfo = Extract-ModInfo -JarPath $jar.FullName
        # Look up Category from modlist.csv
        $modInfo.Category = Get-ModCategory -ModInfo $modInfo -ModListPath $ModListPath
        if ($modInfo.Environment -eq "server") {
            $serverOnlyOptionalMods += $modInfo
        } else {
            $softWhitelistedMods += $modInfo
            Write-Host "  $($jar.Name) -> $($modInfo.Hash) ($($modInfo.Name))" -ForegroundColor Gray
        }
    }
    if ($serverOnlyOptionalMods.Count -gt 0) {
        Write-Host "Server-only mods (ignored for hashing) from ${optionalModsPath}:" -ForegroundColor DarkYellow
        foreach ($mod in $serverOnlyOptionalMods) {
            Write-Host "  $($mod.JarFileName) ($($mod.Name))" -ForegroundColor DarkYellow
        }
    }
}
# Filter optional mods by environment
$softWhitelistedMods = $softWhitelistedMods | Where-Object { $_.Environment -eq "" -or $_.Environment -eq "*" -or $_.Environment -eq "client" }

# Process blocked mods
Write-Host "Processing blocked mods from $ModsPath\block..." -ForegroundColor Yellow
$blockedMods = @()
$serverOnlyBlockedMods = @()
$blockModsPath = Join-Path $ModsPath "block"
if (Test-Path $blockModsPath) {
    $blockJars = Get-ChildItem -Path $blockModsPath -Filter "*.jar" | Sort-Object Name
    foreach ($jar in $blockJars) {
        $modInfo = Extract-ModInfo -JarPath $jar.FullName
        # Look up Category from modlist.csv
        $modInfo.Category = Get-ModCategory -ModInfo $modInfo -ModListPath $ModListPath
        if ($modInfo.Environment -eq "server") {
            $serverOnlyBlockedMods += $modInfo
        } else {
            $blockedMods += $modInfo
            Write-Host "  $($jar.Name) -> $($modInfo.Hash) ($($modInfo.Name))" -ForegroundColor Red
        }
    }
    if ($serverOnlyBlockedMods.Count -gt 0) {
        Write-Host "Server-only mods (ignored for hashing) from ${blockModsPath}:" -ForegroundColor DarkYellow
        foreach ($mod in $serverOnlyBlockedMods) {
            Write-Host "  $($mod.JarFileName) ($($mod.Name))" -ForegroundColor DarkYellow
        }
    }
}
# Filter blocked mods by environment
$blockedMods = $blockedMods | Where-Object { $_.Environment -eq "" -or $_.Environment -eq "*" -or $_.Environment -eq "client" }

# Calculate combined hash from mandatory + optional mods (optional are required on client)
$requiredForHash = @()
$requiredForHash += $mandatoryMods
$requiredForHash += $softWhitelistedMods
$mandatoryHashes = $requiredForHash | ForEach-Object { $_.Hash } | Sort-Object
$combinedHashString = $mandatoryHashes -join "|"

# Debug information
Write-Host "Debug: Number of mandatory mods: $($mandatoryMods.Count)" -ForegroundColor Magenta
Write-Host "Debug: Number of optional mods (treated as required): $($softWhitelistedMods.Count)" -ForegroundColor Magenta
Write-Host "Debug: Number of hashes collected: $($mandatoryHashes.Count)" -ForegroundColor Magenta
Write-Host "Debug: Combined string length: $($combinedHashString.Length)" -ForegroundColor Magenta
if ($mandatoryHashes.Count -ge 3) {
    Write-Host "Debug: First few hashes: $($mandatoryHashes[0..2] -join ', ')" -ForegroundColor Magenta
} elseif ($mandatoryHashes.Count -gt 0) {
    Write-Host "Debug: First few hashes: $($mandatoryHashes -join ', ')" -ForegroundColor Magenta
} else {
    Write-Host "Debug: First few hashes: (none)" -ForegroundColor Magenta
}
# Output server-only mod summary
$totalServerOnly = $serverOnlyMandatoryMods.Count + $serverOnlyOptionalMods.Count + $serverOnlyBlockedMods.Count
Write-Host "Debug: Number of server-only mods: $($totalServerOnly)" -ForegroundColor Magenta

$md5 = [System.Security.Cryptography.MD5]::Create()
$combinedHashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combinedHashString))
$combinedHash = [System.BitConverter]::ToString($combinedHashBytes).Replace("-", "").ToLower()
$md5.Dispose()

# Use the provided output path directly
$actualOutputPath = $OutputPath
Write-Host "Writing files to output directory" -ForegroundColor Green

Write-Host "Combined hash (from mandatory + optional mods): $combinedHash" -ForegroundColor Cyan

# Generate hash.txt
$hashContent = @()
$hashContent += "# Mandatory Mods"
foreach ($mod in $mandatoryMods) {
    $hashContent += "$($mod.Hash) $($mod.Name)"
}
$hashContent += ""
$hashContent += "# Soft-Whitelisted Mods"
foreach ($mod in $softWhitelistedMods) {
    $hashContent += "$($mod.Hash) $($mod.Name)"
}
$hashContent += ""
$hashContent += "# Blocked Mods"
foreach ($mod in $blockedMods) {
    $hashContent += "$($mod.Hash) $($mod.Name)"
}

$hashFileName = "hash.txt"
$hashContent | Out-File -FilePath (Join-Path $actualOutputPath $hashFileName) -Encoding UTF8

# Create comprehensive README
$readmeContent = @()
$readmeContent += "# Minecraft Modpack Documentation"
$readmeContent += ""
$readmeContent += "Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$readmeContent += ""
$readmeContent += "## Summary"
$readmeContent += "- **Mandatory Mods:** $($mandatoryMods.Count)"
$readmeContent += "- **Optional Mods:** $($softWhitelistedMods.Count)"
$readmeContent += "- **Blocked Mods:** $($blockedMods.Count)"
$readmeContent += "- **Combined Hash:** $combinedHash"
$readmeContent += ""
$readmeContent += "## Included Mods"
$readmeContent += ""
$readmeContent += "## Mandatory Mods"
$readmeContent += ""
$readmeContent += "| Name | ID | Version | Description | Category | License | Homepage | Contact |"
$readmeContent += "|------|----|---------|-------------|----------|---------|----------|---------|"
foreach ($mod in $mandatoryMods) {
    $name = $mod.Name -replace '\|', '\|'
    $id = $mod.Id -replace '\|', '\|'
    $version = $mod.Version -replace '\|', '\|'
    $description = if ($mod.Description) { ($mod.Description -replace '\|', '\|' -replace "`r?`n", " ").Substring(0, [Math]::Min(50, $mod.Description.Length)) } else { "" }
    if ($mod.Description -and $mod.Description.Length -gt 50) { $description += "..." }
    $category = if ($mod.Category) { $mod.Category -replace '\|', '\|' } else { "" }
    $license = $mod.License -replace '\|', '\|'
    $homepage = $mod.Homepage -replace '\|', '\|'
    $contact = $mod.Contact -replace '\|', '\|'
    
    $readmeContent += "| $name | $id | $version | $description | $category | $license | $homepage | $contact |"
}

if ($softWhitelistedMods.Count -gt 0) {
    $readmeContent += ""
    $readmeContent += "## Optional Mods"
    $readmeContent += ""
    $readmeContent += "| Name | ID | Version | Description | Category | License | Homepage | Contact |"
    $readmeContent += "|------|----|---------|-------------|----------|---------|----------|---------|"
    foreach ($mod in $softWhitelistedMods) {
        $name = $mod.Name -replace '\|', '\|'
        $id = $mod.Id -replace '\|', '\|'
        $version = $mod.Version -replace '\|', '\|'
        $description = if ($mod.Description) { ($mod.Description -replace '\|', '\|' -replace "`r?`n", " ").Substring(0, [Math]::Min(50, $mod.Description.Length)) } else { "" }
        if ($mod.Description -and $mod.Description.Length -gt 50) { $description += "..." }
        $category = if ($mod.Category) { $mod.Category -replace '\|', '\|' } else { "" }
        $license = $mod.License -replace '\|', '\|'
        $homepage = $mod.Homepage -replace '\|', '\|'
        $contact = $mod.Contact -replace '\|', '\|'
        
        $readmeContent += "| $name | $id | $version | $description | $category | $license | $homepage | $contact |"
    }
}

if ($blockedMods.Count -gt 0) {
    $readmeContent += ""
    $readmeContent += "## Blocked Mods"
    $readmeContent += ""
    $readmeContent += "| Name | ID | Version | Description | Category | License | Homepage | Contact |"
    $readmeContent += "|------|----|---------|-------------|----------|---------|----------|---------|"
    foreach ($mod in $blockedMods) {
        $name = $mod.Name -replace '\|', '\|'
        $id = $mod.Id -replace '\|', '\|'
        $version = $mod.Version -replace '\|', '\|'
        $description = if ($mod.Description) { ($mod.Description -replace '\|', '\|' -replace "`r?`n", " ").Substring(0, [Math]::Min(50, $mod.Description.Length)) } else { "" }
        if ($mod.Description -and $mod.Description.Length -gt 50) { $description += "..." }
        $category = if ($mod.Category) { $mod.Category -replace '\|', '\|' } else { "" }
        $license = $mod.License -replace '\|', '\|'
        $homepage = $mod.Homepage -replace '\|', '\|'
        $contact = $mod.Contact -replace '\|', '\|'
        
        $readmeContent += "| $name | $id | $version | $description | $category | $license | $homepage | $contact |"
    }
}

$readmeContent += ""
$readmeContent += "## Server Updates"
$readmeContent += ""
$readmeContent += "1. Install Fabric Loader for your target Minecraft version"
$readmeContent += "2. Download all mandatory mods listed above"
$readmeContent += "3. Place all mandatory mod JAR files in your server's `mods` folder"
$readmeContent += "4. Run the hash script to generate the combined hash for InertiaAntiCheat"
$readmeContent += ""
$readmeContent += "## Client Updates"
$readmeContent += ""
$readmeContent += "1. Install Fabric Loader for your target Minecraft version"
$readmeContent += "2. Download all mandatory mods listed above"
$readmeContent += "3. Place all mandatory mod JAR files in your `.minecraft/mods` folder"
$readmeContent += "4. Note: Optional mods are treated as required by this server. Ensure you install them as well."
$readmeContent += "5. Place optional mod JAR files in your `.minecraft/mods` folder"
$readmeContent += ""
$readmeContent += "> **Note:** All clients must have the mandatory mods. Optional mods are only needed by clients who want those specific features."
$readmeContent += ""
$readmeContent += "## Server Setup"
$readmeContent += ""
$readmeContent += "This modpack is configured for use with InertiaAntiCheat. The server will validate that clients have the correct mandatory mods installed."
$readmeContent += ""
$readmeContent += "### Hash File"
$readmeContent += "The `hash.txt` file contains MD5 hashes for all mods and can be used with external tools."
$readmeContent += ""
$readmeContent += "### IAC Configuration"
$readmeContent += "Run the script with `-UpdateConfig` to automatically update your InertiaAntiCheat configuration."
$readmeContent += ""
$readmeContent += "### Client Modpack Zip"
$readmeContent += "The script automatically creates a zip file containing all mandatory and optional mods for easy distribution to clients."
$readmeContent += "The zip file is named `modpack.zip` and contains the expected folder structure at the root: `mods/` (with `mods/optional/`) and `shaderpacks/`."
$readmeContent += ""
$readmeContent += "### Package Documentation"
$readmeContent += "The zip package includes installation instructions and package information."
$readmeContent += ""
$readmeContent += "### Package Verification"
$readmeContent += "The script creates signature files (`.md5`, `.sha1`, `.sha256`, `.sha512`) for the zip package to verify integrity."
$readmeContent += "The zip package also includes a `README.md` file with installation instructions and verification commands."

$readmeFileName = "README.md"
$readmeContent | Out-File -FilePath (Join-Path $actualOutputPath $readmeFileName) -Encoding UTF8

# Update IAC config if requested
if ($UpdateConfig) {
    Write-Host "`nUpdating InertiaAntiCheat config..." -ForegroundColor Yellow
    Write-Host "Using config from $ConfigPath..." -ForegroundColor Yellow
    $iacCopyName = Get-ChildItem -Path $ConfigPath -Name
    $iacCopyPath = Join-Path $OutputPath $iacCopyName
    Write-Host "Copying config to $iacCopyPath..." -ForegroundColor Yellow

    # Create minimal config if it does not exist
    if (-not (Test-Path $ConfigPath)) {
        $defaultConfig = @(
            "[validation.group]",
            "hash = []",
            "softWhitelist = []",
            "",
            "[validation.individual]",
            "blacklist = []",
            "",
            "[motd]",
            "whitelist = []",
            "blacklist = []"
        )
        $defaultConfig | Out-File -FilePath $ConfigPath -Encoding UTF8
    }
    $allModNames = ($mandatoryMods + $softWhitelistedMods | ForEach-Object { $_.Name })
    # Optional mods are treated as required; leave softWhitelist empty
    $softWhitelistHashes = @()
    # Create MOTD whitelist with custom message
    $motdWhitelist = @($MotdMessage) + $allModNames
    # Create required and optional mod name arrays
    $requiredModNames = @($ModpackMessage) + $mandatoryMods.Name + $softWhitelistedMods.Name
    $optionalModNames = @($MotdMessage, "None")
    # Create blocked mod names array
    if ($blockedMods.Count -gt 0) {
        $blockedModNames = @($BannedModsMessage) + $blockedMods.Name
    } else {
        $blockedModNames = @($BannedModsMessage, "None")
    }
    
    # Copy the original config to the output file, then update only the output file
    Get-Content -Path $ConfigPath | Set-Content -Path $iacCopyPath
    Update-IACConfig -ConfigPath $iacCopyPath -CombinedHash $combinedHash -SoftWhitelist $softWhitelistHashes -AllModNames $motdWhitelist -RequiredModNames $requiredModNames -OptionalModNames $optionalModNames -BlockedMods $blockedMods -BlockedModNames $blockedModNames -MotdMessage $MotdMessage -ModpackMessage $ModpackMessage -BannedModsMessage $BannedModsMessage
}

# Create zip file with all mods (only if CreateZip flag is set)
$zipResult = $null
if ($CreateZip) {
    $zipResult = Create-ModsZip -MandatoryMods $mandatoryMods -SoftWhitelistedMods $softWhitelistedMods -CombinedHash $combinedHash -OutputPath $actualOutputPath
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Output directory: $(Resolve-Path $OutputPath)" -ForegroundColor White
Write-Host "  Mandatory mods: $($mandatoryMods.Count)" -ForegroundColor White
Write-Host "  Soft-whitelisted mods: $($softWhitelistedMods.Count)" -ForegroundColor White
Write-Host "  Blocked mods: $($blockedMods.Count)" -ForegroundColor White
Write-Host "  Combined hash: $combinedHash" -ForegroundColor White
Write-Host "  hash.txt: $hashFileName" -ForegroundColor White
Write-Host "  README.md: $readmeFileName" -ForegroundColor White
if ($zipResult) {
    $zipFileName = [System.IO.Path]::GetFileName($zipResult.Path)
    Write-Host "  Mods zip: $zipFileName" -ForegroundColor White
    Write-Host "  Signature files created:" -ForegroundColor White
    Write-Host "    MD5: $($zipResult.Signatures.MD5)" -ForegroundColor Gray
    Write-Host "    SHA1: $($zipResult.Signatures.SHA1)" -ForegroundColor Gray
    Write-Host "    SHA256: $($zipResult.Signatures.SHA256)" -ForegroundColor Gray
    Write-Host "    SHA512: $($zipResult.Signatures.SHA512)" -ForegroundColor Gray
}
if ($UpdateConfig) {
    $iacFileName = [System.IO.Path]::GetFileName($iacCopyPath)
    Write-Host "  IAC config: $iacFileName" -ForegroundColor White
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  .\hash.ps1                    # Generate hash.txt and README-MOD.md only" -ForegroundColor White
Write-Host "  .\hash.ps1 -CreateZip         # Generate files and create mods zip package" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig     # Generate files and update IAC config" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig -CreateZip  # Generate files, update IAC config, and create zip" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig -ConfigPath 'path\to\custom\config\InertiaAntiCheat\InertiaAntiCheat.toml'" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig -MotdMessage 'Allowed Mods:'  # Use custom MOTD message" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig -ModpackMessage 'Required Mods:'  # Use custom modpack message" -ForegroundColor White
Write-Host "  .\hash.ps1 -UpdateConfig -BannedModsMessage 'Banned Mods:'  # Use custom banned mods message" -ForegroundColor White
Write-Host "  .\hash.ps1 -ModsPath 'C:\path\to\mods'  # Use custom mods directory" -ForegroundColor White
Write-Host "  .\hash.ps1 -OutputPath 'C:\path\to\output'  # Save files to custom directory" -ForegroundColor White
Write-Host "  .\hash.ps1 -ModsPath 'C:\path\to\mods' -OutputPath 'C:\path\to\output'  # Use both custom paths" -ForegroundColor White
