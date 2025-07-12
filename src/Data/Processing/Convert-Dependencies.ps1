# =============================================================================
# Dependency Conversion Module
# =============================================================================
# This module handles conversion of dependencies to various formats.
# =============================================================================

<#
.SYNOPSIS
    Converts dependencies to a clean, readable format for CSV storage.

.DESCRIPTION
    Converts dependency objects to a clean, readable format suitable
    for storage in CSV files.

.PARAMETER Dependencies
    The dependency objects to convert.

.EXAMPLE
    Convert-DependenciesToJson -Dependencies $deps

.NOTES
    - Separates required and optional dependencies
    - Creates clean, readable format
    - Returns empty string if no dependencies
#>
function Convert-DependenciesToJson {
    param(
        [Parameter(Mandatory=$true)]
        $Dependencies
    )
    
    try {
        if (-not $Dependencies -or $Dependencies.Count -eq 0) {
            return ""
        }
        
        # Separate required and optional dependencies
        $requiredDeps = @()
        $optionalDeps = @()
        
        foreach ($dep in $Dependencies) {
            $depId = $dep.project_id
            if ($dep.dependency_type -eq "required") {
                $requiredDeps += $depId
            } elseif ($dep.dependency_type -eq "optional") {
                $optionalDeps += $depId
            } else {
                # Default to required if type is not specified
                $requiredDeps += $depId
            }
        }
        
        # Create clean, readable format
        $result = @()
        if ($requiredDeps.Count -gt 0) {
            $result += "required: $($requiredDeps -join ',')"
        }
        if ($optionalDeps.Count -gt 0) {
            $result += "optional: $($optionalDeps -join ',')"
        }
        
        return $result -join "; "
    }
    catch {
        Write-Warning "Failed to convert dependencies to readable format: $($_.Exception.Message)"
        return ""
    }
}

<#
.SYNOPSIS
    Converts dependencies to required-only format.

.DESCRIPTION
    Extracts only required dependencies from dependency objects.

.PARAMETER Dependencies
    The dependency objects to convert.

.EXAMPLE
    Convert-DependenciesToJsonRequired -Dependencies $deps

.NOTES
    - Returns comma-separated list of required dependency IDs
    - Returns empty string if no required dependencies
#>
function Convert-DependenciesToJsonRequired {
    param([Parameter(Mandatory=$true)] $Dependencies)
    if (-not $Dependencies -or $Dependencies.Count -eq 0) { return "" }
    $required = $Dependencies | Where-Object { $_.dependency_type -eq "required" -or -not $_.dependency_type } | ForEach-Object { $_.project_id }
    return ($required | Sort-Object | Get-Unique) -join ","
}

<#
.SYNOPSIS
    Converts dependencies to optional-only format.

.DESCRIPTION
    Extracts only optional dependencies from dependency objects.

.PARAMETER Dependencies
    The dependency objects to convert.

.EXAMPLE
    Convert-DependenciesToJsonOptional -Dependencies $deps

.NOTES
    - Returns comma-separated list of optional dependency IDs
    - Returns empty string if no optional dependencies
#>
function Convert-DependenciesToJsonOptional {
    param([Parameter(Mandatory=$true)] $Dependencies)
    if (-not $Dependencies -or $Dependencies.Count -eq 0) { return "" }
    $optional = $Dependencies | Where-Object { $_.dependency_type -eq "optional" } | ForEach-Object { $_.project_id }
    return ($optional | Sort-Object | Get-Unique) -join ","
}

<#
.SYNOPSIS
    Compares two comma-separated strings as sets.

.DESCRIPTION
    Compares two comma-separated strings as sets, ignoring order and duplicates.

.PARAMETER a
    First comma-separated string.

.PARAMETER b
    Second comma-separated string.

.EXAMPLE
    Set-Equals -a "a,b,c" -b "c,a,b"

.NOTES
    - Returns true if sets are equal
    - Ignores order and duplicates
    - Handles empty strings
#>
function Set-Equals {
    param([string]$a, [string]$b)
    $setA = ($a -split ",") | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
    $setB = ($b -split ",") | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
    return ($setA -join ",") -eq ($setB -join ",")
}

# Function is available for dot-sourcing 