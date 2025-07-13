# PowerShell Test Runner for Minecraft Mod Hash Generator
# Runs all test scripts in the tests/ directory

$ErrorActionPreference = "Stop"

# Ensure we're in the correct directory
$OriginalLocation = Get-Location
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptPath

try {
    # Change to tests directory to run tests
    Set-Location "tests"
    
    # Get all test scripts
    $TestFiles = Get-ChildItem -Filter "*.ps1" | Where-Object { $_.Name -match "^\d{5}-.*\.ps1$" } | Sort-Object Name
    
    if ($TestFiles.Count -eq 0) {
        Write-Host "No test files found in tests directory" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found $($TestFiles.Count) test files" -ForegroundColor Green
    
    $PassedTests = 0
    $FailedTests = 0
    $FailedTestNames = @()
    
    foreach ($TestFile in $TestFiles) {
        Write-Host "Running $($TestFile.Name)" -ForegroundColor Cyan
        
        try {
            & "pwsh" -File $TestFile.Name
            if ($LASTEXITCODE -eq 0) {
                $PassedTests++
                Write-Host "✓ $($TestFile.Name) passed" -ForegroundColor Green
            } else {
                $FailedTests++
                $FailedTestNames += $TestFile.Name
                Write-Host "✗ $($TestFile.Name) failed with exit code $LASTEXITCODE" -ForegroundColor Red
            }
        } catch {
            $FailedTests++
            $FailedTestNames += $TestFile.Name
            Write-Host "✗ $($TestFile.Name) failed with exception: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Test Results ===" -ForegroundColor Yellow
    Write-Host "Total tests: $($TestFiles.Count)" -ForegroundColor White
    Write-Host "Passed: $PassedTests" -ForegroundColor Green
    Write-Host "Failed: $FailedTests" -ForegroundColor Red
    
    if ($FailedTests -gt 0) {
        Write-Host "`nFailed tests:" -ForegroundColor Red
        foreach ($FailedTest in $FailedTestNames) {
            Write-Host "  - $FailedTest" -ForegroundColor Red
        }
        exit 1
    } else {
        Write-Host "`nAll tests passed! 🎉" -ForegroundColor Green
        exit 0
    }
    
} finally {
    # Return to original location
    Set-Location $OriginalLocation
} 