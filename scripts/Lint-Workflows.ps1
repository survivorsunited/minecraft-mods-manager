# =============================================================================
# GitHub Actions Workflow Linting Script
# =============================================================================
# Uses actionlint to validate GitHub Actions workflow files
# =============================================================================

<#
.SYNOPSIS
    Validates GitHub Actions workflow YAML files using actionlint.

.DESCRIPTION
    Downloads and runs actionlint to check all workflow files in .github/workflows/
    for syntax errors, indentation issues, and GitHub Actions-specific problems.

.PARAMETER SkipDownload
    Skip downloading actionlint (assumes it's already present)

.EXAMPLE
    .\scripts\Lint-Workflows.ps1

.EXAMPLE
    .\scripts\Lint-Workflows.ps1 -SkipDownload

.NOTES
    - Requires Windows x64
    - Downloads actionlint automatically if not present
    - Caches actionlint in .cache/tools/
#>

param(
    [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 GitHub Actions Workflow Linter" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$actionlintVersion = "1.6.27"
$toolsDir = ".cache\tools"
$actionlintPath = Join-Path $toolsDir "actionlint.exe"
$downloadUrl = "https://github.com/rhysd/actionlint/releases/download/v$actionlintVersion/actionlint_${actionlintVersion}_windows_amd64.zip"

# Ensure tools directory exists
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    Write-Host "📁 Created tools directory: $toolsDir" -ForegroundColor Gray
}

# Download actionlint if not present
if (-not (Test-Path $actionlintPath) -and -not $SkipDownload) {
    Write-Host "📥 Downloading actionlint v$actionlintVersion..." -ForegroundColor Yellow
    Write-Host "   URL: $downloadUrl" -ForegroundColor Gray
    
    try {
        $zipPath = Join-Path $toolsDir "actionlint.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        
        Write-Host "📦 Extracting actionlint..." -ForegroundColor Yellow
        Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
        Remove-Item $zipPath -Force
        
        Write-Host "✅ actionlint downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to download actionlint: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
}

# Verify actionlint exists
if (-not (Test-Path $actionlintPath)) {
    Write-Host "❌ actionlint not found: $actionlintPath" -ForegroundColor Red
    Write-Host "💡 Run without -SkipDownload to download it automatically" -ForegroundColor Yellow
    exit 1
}

# Find all workflow files
$workflowDir = ".github\workflows"
if (-not (Test-Path $workflowDir)) {
    Write-Host "❌ Workflow directory not found: $workflowDir" -ForegroundColor Red
    exit 1
}

$workflowFiles = Get-ChildItem -Path $workflowDir -Filter "*.yml" -File
if ($workflowFiles.Count -eq 0) {
    Write-Host "⚠️  No workflow files found in $workflowDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "📋 Found $($workflowFiles.Count) workflow file(s) to validate:" -ForegroundColor Cyan
foreach ($file in $workflowFiles) {
    Write-Host "   - $($file.Name)" -ForegroundColor Gray
}
Write-Host ""

# Run actionlint
Write-Host "🔍 Running actionlint..." -ForegroundColor Yellow
Write-Host ""

try {
    # Run actionlint with detailed output
    $output = & $actionlintPath -color $workflowFiles.FullName 2>&1
    $exitCode = $LASTEXITCODE
    
    # Display output
    if ($output) {
        Write-Host $output
    }
    
    Write-Host ""
    
    if ($exitCode -eq 0) {
        Write-Host "✅ All workflows passed linting!" -ForegroundColor Green
        Write-Host "📊 Validated $($workflowFiles.Count) workflow file(s)" -ForegroundColor Cyan
        exit 0
    } else {
        Write-Host "❌ Workflow linting failed with exit code: $exitCode" -ForegroundColor Red
        Write-Host "💡 Fix the errors above and run linting again" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Error running actionlint: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

