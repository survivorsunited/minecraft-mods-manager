# =============================================================================
# Adoptium JDK Provider Module
# =============================================================================
# This module handles retrieval of JDK download information from Adoptium API.
# =============================================================================

<#
.SYNOPSIS
    Gets JDK download information from Adoptium API.

.DESCRIPTION
    Retrieves JDK binary download URLs from the Adoptium API (Eclipse Temurin).
    Supports multiple Java versions, operating systems, and architectures.

.PARAMETER Version
    Java version to download (e.g., "17", "21").

.PARAMETER OS
    Operating system: "windows", "linux", "mac".

.PARAMETER Architecture
    CPU architecture: "x64", "aarch64". Default: x64

.PARAMETER ImageType
    JDK type: "jdk" (full), "jre" (runtime only). Default: jdk

.EXAMPLE
    Get-AdoptiumJDK -Version "21" -OS "windows"

.EXAMPLE
    Get-AdoptiumJDK -Version "17" -OS "linux" -Architecture "aarch64"

.NOTES
    - Uses Adoptium API: https://api.adoptium.net
    - Returns download URL, version info, and file details
    - Supports cross-platform downloads
#>
function Get-AdoptiumJDK {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux", "mac")]
        [string]$OS,
        [ValidateSet("x64", "aarch64", "x86")]
        [string]$Architecture = "x64",
        [ValidateSet("jdk", "jre")]
        [string]$ImageType = "jdk"
    )
    
    try {
        # Adoptium API endpoint for latest GA (General Availability) release
        # Format: /v3/binary/latest/{version}/ga/{os}/{arch}/{image_type}/{heap_size}/hotspot
        $apiUrl = "https://api.adoptium.net/v3/binary/latest/$Version/ga/$OS/$Architecture/$ImageType/normal/eclipse"
        
        Write-Host "   🔍 Fetching JDK $Version info from Adoptium API..." -ForegroundColor Cyan
        Write-Host "      Platform: $OS/$Architecture" -ForegroundColor Gray
        
        # Get release info (metadata) instead of direct binary to extract details
        $infoUrl = "https://api.adoptium.net/v3/assets/feature_releases/$Version/ga?image_type=$ImageType&os=$OS&architecture=$Architecture&heap_size=normal&vendor=eclipse"
        
        $releaseInfo = Invoke-RestMethod -Uri $infoUrl -Method Get -TimeoutSec 30
        
        if (-not $releaseInfo -or $releaseInfo.Count -eq 0) {
            Write-Host "      ❌ No JDK $Version found for $OS/$Architecture" -ForegroundColor Red
            return $null
        }
        
        # Get the latest release
        $latestRelease = $releaseInfo[0]
        $binary = $latestRelease.binaries[0]
        
        if (-not $binary) {
            Write-Host "      ❌ No binary found in release" -ForegroundColor Red
            return $null
        }
        
        # Extract information
        $downloadUrl = $binary.package.link
        $fileName = $binary.package.name
        $fileSize = $binary.package.size
        $checksum = $binary.package.checksum
        $javaVersion = $latestRelease.version_data.semver
        $buildVersion = $latestRelease.version_data.build
        
        Write-Host "      ✓ Found JDK $javaVersion (build $buildVersion)" -ForegroundColor Green
        Write-Host "      ✓ File: $fileName" -ForegroundColor Gray
        Write-Host "      ✓ Size: $([Math]::Round($fileSize / 1MB, 2)) MB" -ForegroundColor Gray
        
        return @{
            Success = $true
            Version = $javaVersion
            BuildVersion = $buildVersion
            DownloadUrl = $downloadUrl
            FileName = $fileName
            FileSize = $fileSize
            Checksum = $checksum
            ChecksumType = $binary.package.checksum_type
            OS = $OS
            Architecture = $Architecture
            ImageType = $ImageType
        }
        
    } catch {
        Write-Host "      ❌ Error fetching JDK info: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function is available for dot-sourcing

