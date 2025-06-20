# Run Pester tests for Minecraft Mod Manager
$ErrorActionPreference = 'Stop'
$testFile = Join-Path $PSScriptRoot 'ModManagerPesterTest.ps1'
$pesterPath = Join-Path $PSScriptRoot 'Pester5'

# Ensure local Pester 5 install in test folder
if (-not (Test-Path $pesterPath)) {
    Write-Host "Installing Pester 5.x locally to $pesterPath..." -ForegroundColor Yellow
    Save-Module -Name Pester -Path $pesterPath -Force -RequiredVersion 5.5.0
}

# Import Pester 5 from local folder
$pesterModule = Get-ChildItem -Path $pesterPath -Recurse -Filter Pester.psd1 | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pesterModule) {
    Write-Host "Failed to find Pester 5.x after install. Exiting." -ForegroundColor Red
    exit 1
}
Import-Module $pesterModule.FullName -Force
Write-Host "Pester version: $((Get-Module Pester).Version)" -ForegroundColor Green

# Run the tests using Pester 5 syntax
Invoke-Pester -Script $testFile -CI

if ($result.FailedCount -eq 0) {
    Write-Host "All Pester tests passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some Pester tests failed." -ForegroundColor Red
    exit 1
} 