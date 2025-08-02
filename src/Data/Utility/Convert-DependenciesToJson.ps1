# =============================================================================
# Dependency Conversion Module
# =============================================================================
# This module handles conversion of dependencies to JSON format for storage.
# =============================================================================

<#
.SYNOPSIS
    Converts dependencies to a clean, readable format for CSV storage.

.DESCRIPTION
    Takes dependency objects from API responses and converts them to a
    clean, readable format suitable for CSV storage. Separates required
    and optional dependencies.

.PARAMETER Dependencies
    The dependencies object from API response.

.EXAMPLE
    Convert-DependenciesToJson -Dependencies $apiResponse.dependencies

.NOTES
    - Separates required and optional dependencies
    - Creates clean, readable format for CSV storage
    - Returns empty string if no dependencies
#>
function Convert-DependenciesToJson {
    param(
        [Parameter(Mandatory=$false)]
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
    Converts dependencies to required dependencies only.

.DESCRIPTION
    Extracts only the required dependencies from a dependencies object.

.PARAMETER Dependencies
    The dependencies object from API response.

.EXAMPLE
    Convert-DependenciesToJsonRequired -Dependencies $apiResponse.dependencies

.NOTES
    - Returns only required dependencies
    - Sorts and removes duplicates
    - Returns empty string if no required dependencies
#>
function Convert-DependenciesToJsonRequired {
    param([Parameter(Mandatory=$false)] $Dependencies)
    if (-not $Dependencies -or $Dependencies.Count -eq 0) { return "" }
    $required = $Dependencies | Where-Object { $_.dependency_type -eq "required" -or -not $_.dependency_type } | ForEach-Object { $_.project_id }
    return ($required | Sort-Object | Get-Unique) -join ","
}

<#
.SYNOPSIS
    Converts dependencies to optional dependencies only.

.DESCRIPTION
    Extracts only the optional dependencies from a dependencies object.

.PARAMETER Dependencies
    The dependencies object from API response.

.EXAMPLE
    Convert-DependenciesToJsonOptional -Dependencies $apiResponse.dependencies

.NOTES
    - Returns only optional dependencies
    - Sorts and removes duplicates
    - Returns empty string if no optional dependencies
#>
function Convert-DependenciesToJsonOptional {
    param([Parameter(Mandatory=$false)] $Dependencies)
    if (-not $Dependencies -or $Dependencies.Count -eq 0) { return "" }
    $optional = $Dependencies | Where-Object { $_.dependency_type -eq "optional" } | ForEach-Object { $_.project_id }
    return ($optional | Sort-Object | Get-Unique) -join ","
}

<#
.SYNOPSIS
    Compares two dependency strings for equality.

.DESCRIPTION
    Compares two comma-separated dependency strings, accounting for
    order differences and empty values.

.PARAMETER a
    First dependency string.

.PARAMETER b
    Second dependency string.

.EXAMPLE
    Set-Equals -a "mod1,mod2" -b "mod2,mod1"

.NOTES
    - Normalizes dependency strings for comparison
    - Removes empty values
    - Sorts and removes duplicates before comparison
#>
function Set-Equals {
    param([string]$a, [string]$b)
    $setA = ($a -split ",") | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
    $setB = ($b -split ",") | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
    return ($setA -join ",") -eq ($setB -join ",")
}

# Functions are available for dot-sourcing 