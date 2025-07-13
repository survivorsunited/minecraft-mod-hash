# Minecraft Mod Hash Generator

A PowerShell script for generating hash files and updating InertiaAntiCheat (IAC) configuration for Minecraft modpacks. The script scans mandatory mods in the `mods/` directory, optional mods in `mods/optional/`, and blocked mods in `mods/block/`, calculates MD5 hashes, and generates comprehensive documentation.

## Why?

### Tired of Manually Crafting Mod Whitelists? 😴

Running a Minecraft server with mods shouldn't be a nightmare. If you've ever spent hours manually calculating MD5 hashes, editing config files, or trying to figure out which mods are breaking your server - this script is your salvation.

**For Server Admins:**
- **Stop the Hash Madness**: No more manually calculating MD5 hashes for every mod
- **Kiss Config Chaos Goodbye**: Automatically updates InertiaAntiCheat configs
- **Flexible Freedom**: Let players use optional mods without breaking your server
- **Documentation Done Right**: Generate professional mod lists and guides automatically
- **Safety Net**: Automatic backups so you never lose your config again
- **Custom Branding**: Set your own MOTD and modpack messages

**For Players:**
- **Crystal Clear Setup**: Step-by-step installation guides that actually make sense
- **Know What You're Getting**: See mod names, versions, descriptions, and links
- **No More Guesswork**: Clear distinction between required and optional mods
- **Easy Updates**: Simple instructions for keeping your mods current

**The Bottom Line:**
Stop fighting with mod validation. Start enjoying your server. This script turns hours of manual work into a single command, while giving your players the information they need to join without issues.

**Perfect for:**
- Server owners who want to enforce modpacks without the headache
- Communities that need clear documentation for their mods
- Anyone tired of players getting kicked for "wrong mods"
- Admins who want to allow optional mods without security risks

## Features

- **Hash Generation**: Creates `hash.txt` with MD5 hashes for all mods
- **Metadata Extraction**: Extracts mod information from `fabric.mod.json` files including:
  - Mod name, ID, version, description
  - License information
  - Homepage and contact URLs
  - **Only mods with `"environment": "*"` or `"environment": "client"` (or missing the field) are included in all outputs. Mods with `"environment": "server"` are ignored.**
- **Comprehensive Documentation**: Generates `README-MOD.md` with detailed mod tables
- **IAC Configuration**: Updates InertiaAntiCheat config files with:
  - Combined hash for mandatory mods
  - Soft-whitelist for optional mods
  - Blacklist for blocked mods
  - MOTD whitelist with mod names
  - Modpack hash display
- **Backup Support**: Automatically backs up config files before updating
- **Customizable Messages**: Custom MOTD and modpack display messages

## Requirements

- PowerShell 5.1 or later
- Windows 10/11
- Minecraft mods organized in `mods/`, `mods/optional/`, and `mods/block/` folders

## Usage

### Basic Usage
```powershell
# Generate hash.txt and README-MOD.md only
.\hash.ps1

# Generate files and update IAC config
.\hash.ps1 -UpdateConfig
```

### Advanced Usage
```powershell
# Use custom config path
.\hash.ps1 -UpdateConfig -ConfigPath 'path\to\custom\config\InertiaAntiCheat\InertiaAntiCheat.toml'

# Use custom MOTD message
.\hash.ps1 -UpdateConfig -MotdMessage 'Allowed Mods:'

# Use custom modpack message
.\hash.ps1 -UpdateConfig -ModpackMessage 'Required Mods:'

# Use custom mods directory
.\hash.ps1 -ModsPath 'C:\path\to\mods'

# Save files to custom directory
.\hash.ps1 -OutputPath 'C:\path\to\output'

# Use both custom paths
.\hash.ps1 -ModsPath 'C:\path\to\mods' -OutputPath 'C:\path\to\output'

# Combine with other parameters
.\hash.ps1 -ModsPath 'C:\path\to\mods' -OutputPath 'C:\path\to\output' -CreateZip -UpdateConfig
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-UpdateConfig` | Switch | False | Update InertiaAntiCheat config file |
| `-CreateZip` | Switch | False | Create a ZIP file with all mods |
| `-ConfigPath` | String | `config\InertiaAntiCheat\InertiaAntiCheat.toml` | Path to IAC config file |
| `-MotdMessage` | String | `"Whitelisted mods:"` | Custom message for MOTD whitelist |
| `-ModpackMessage` | String | `"Requires modpack: "` | Custom message for modpack display |
| `-BannedModsMessage` | String | `"Banned mods: "` | Custom message for MOTD blacklist |
| `-ModsPath` | String | `"mods"` | Path to mods directory |
| `-OutputPath` | String | `"output"` | Path to output directory for generated files |

## File Structure

### Default Structure
```
.minecraft/
├── mods/
│   ├── mandatory-mod-1.jar
│   ├── mandatory-mod-2.jar
│   ├── optional/
│   │   ├── optional-mod-1.jar
│   │   └── optional-mod-2.jar
│   └── block/
│       ├── blocked-mod-1.jar
│       └── blocked-mod-2.jar
├── config/
│   └── InertiaAntiCheat/
│       ├── InertiaAntiCheat.toml (updated)
│       └── InertiaAntiCheat.toml.backup.* (backup files)
├── hash.ps1
├── hash.txt (generated)
└── README-MOD.md (generated)
```

### Custom Paths Example
```
C:\custom-mods\
├── mandatory-mod-1.jar
├── mandatory-mod-2.jar
├── optional/
│   ├── optional-mod-1.jar
│   └── optional-mod-2.jar
└── block/
    ├── blocked-mod-1.jar
    └── blocked-mod-2.jar

C:\output\
├── hash.txt (generated)
├── README-MOD.md (generated)
└── client-mod-all-*.zip (if -CreateZip used)
```

## Generated Files

### hash.txt
Contains MD5 hashes for all mods:
```
# Mandatory Mods
fc02d374abceca214507d415283a9e2b AppleSkin
1367e1f8f007217c466f3f876ec18d49 Balm
...

# Soft-Whitelisted Mods
be361e11b76aeaf5c8f12fbfd6aa63f3 Amecs Reborn
...

# Blocked Mods
a1b2c3d4e5f678901234567890123456 CheatMod
...
```

> **Note:** Only mods with `"environment": "*"` or `"environment": "client"` in their `fabric.mod.json` (or missing the field) are included. Mods with `"environment": "server"` are ignored for all outputs and config.

### README-MOD.md
Comprehensive documentation including:
- Summary statistics
- Detailed mod tables with metadata
- Server and client update instructions
- Installation guidelines

## IAC Configuration

The script updates the following sections in `InertiaAntiCheat.toml`:

### [validation.group]
- `hash`: Combined MD5 hash of all mandatory mods
- `softWhitelist`: Array of MD5 hashes for optional mods

### [validation.individual]
- `blacklist`: Array of MD5 hashes for blocked mods

### [motd]
- `whitelist`: Array of mod names starting with MOTD message
- `blacklist`: Array of blocked mod names starting with banned mods message
- `hash`: Array of required mod names starting with modpack message

## Metadata Extraction

The script extracts mod information from `fabric.mod.json` files:

```json
{
  "name": "Mod Display Name",
  "id": "modid",
  "version": "1.0.0",
  "description": "Mod description",
  "license": "MIT",
  "contact": {
    "homepage": "https://modrinth.com/mod/example",
    "issues": "https://github.com/author/mod/issues"
  },
  "environment": "client" // Only mods with "*" or "client" (or missing) are included
}
```

If `fabric.mod.json` is not available, the script falls back to `META-INF/MANIFEST.MF` for basic mod names. If the environment cannot be determined, the mod is included by default.

## Integration with InertiaAntiCheat

This script is designed to work with [InertiaAntiCheat](https://modrinth.com/mod/inertiaanticheat), a server-side anti-cheat mod that validates client mods. The generated configuration ensures:

1. **Mandatory mods** are required for all clients
2. **Optional mods** are allowed but not required
3. **Blocked mods** are rejected and clients with these mods are kicked
4. **Server MOTD** displays allowed and banned mods to clients
5. **Modpack information** is shown in server browser

## Troubleshooting

### Common Issues

1. **"mods/ directory not found"**: 
   - Run the script from your `.minecraft` folder, or
   - Use `-ModsPath` to specify the correct mods directory path
2. **"IAC config file not found"**: Ensure InertiaAntiCheat is installed and has generated its config
3. **Empty metadata fields**: Some mods may not have complete `fabric.mod.json` files
4. **"Output directory not found"**: The script will automatically create the output directory if it doesn't exist
5. **Permission errors**: Ensure you have write permissions to the output directory
6. **Mod not included in output**: Only mods with `"environment": "*"` or `"environment": "client"` in their `fabric.mod.json` (or missing the field) are included. Mods with `"environment": "server"` are ignored.

### Path Validation
The script validates input paths and provides helpful error messages:
- **ModsPath**: Must exist and contain `.jar` files
- **OutputPath**: Will be created automatically if it doesn't exist
- **ConfigPath**: Must exist when using `-UpdateConfig`

### Verbose Output
Use `-Verbose` flag for detailed processing information:
```powershell
.\hash.ps1 -UpdateConfig -Verbose
```

## Test Suite

The project includes a comprehensive test suite with 19 automated tests covering all functionality:

### Running Tests

```powershell
# Run all tests
./run-tests.ps1

# Run individual test
pwsh -File tests/00001-basic.ps1
```

### Test Categories

#### Basic Functionality Tests (00001-00012)
- **00001-basic**: Basic hash generation and README creation
- **00002-createzip**: ZIP package creation with signature files
- **00003-updateconfig**: InertiaAntiCheat configuration updates
- **00004-updateconfig-createzip**: Combined config update and ZIP creation
- **00005-updateconfig-nobackup**: Config updates without backup files
- **00006-updateconfig-customconfig**: Custom configuration file paths
- **00007-updateconfig-motdmessage**: Custom MOTD messages
- **00008-updateconfig-modpackmessage**: Custom modpack messages
- **00009-updateconfig-bannedmodsmessage**: Custom banned mods messages
- **00010-modspath**: Custom mods directory paths
- **00011-outputpath**: Custom output directory paths
- **00012-modspath-outputpath**: Combined custom mods and output paths

#### Advanced Functionality Tests (00013-00020)
- **00013-error-missing-modspath**: Error handling for missing mods directory
- **00014-empty-directories**: Handling of empty mod directories
- **00015-server-only-mods**: Server-only mod filtering (environment: "server")
- **00016-complex-parameters**: Complex parameter combinations
- **00017-file-content-validation**: Output file content and structure validation
- **00018-jar-parsing-fallback**: JAR metadata parsing with filename fallback
- **00020-zip-content-validation**: ZIP package content and structure validation

### Test Coverage

The test suite achieves comprehensive coverage of:
- ✅ All script parameters and combinations
- ✅ Error handling and edge cases
- ✅ File I/O operations and path handling
- ✅ JAR file parsing and metadata extraction
- ✅ Configuration file updates and backups
- ✅ ZIP package creation and validation
- ✅ Cross-platform compatibility
- ✅ Output file format validation

### CI/CD Integration

Tests run automatically on:
- All pull requests
- Pushes to main branch
- Use GitHub Actions with Windows PowerShell environment
- Generate release artifacts upon successful test completion

## License

This script is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues or pull requests for improvements. Please ensure all tests pass before submitting:

```powershell
./run-tests.ps1
```

fml