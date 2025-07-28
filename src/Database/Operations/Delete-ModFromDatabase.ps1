# =============================================================================
# Delete Mod From Database Function
# =============================================================================
# This function removes a mod from the CSV database
# =============================================================================

<#
.SYNOPSIS
    Removes a mod from the CSV database.
.DESCRIPTION
    Removes a mod entry from the CSV database by ID or URL.
    Currently supports CSV storage provider only.
.PARAMETER DeleteModID
    The mod ID to delete.
.PARAMETER DeleteModUrl
    The mod URL to delete.
.PARAMETER DeleteModType
    The mod type for deletion (optional).
.PARAMETER CsvPath
    Path to the CSV database file.
.EXAMPLE
    Delete-ModFromDatabase -DeleteModID "fabric-api" -CsvPath "modlist.csv"
#>
function Delete-ModFromDatabase {
    param(
        [string]$DeleteModID,
        [string]$DeleteModUrl,
        [string]$DeleteModType = "",
        [string]$CsvPath = "modlist.csv"
    )

    try {
        # Validate required parameters
        if (-not $DeleteModID -and -not $DeleteModUrl) {
            Write-Host "Error: Either DeleteModID or DeleteModUrl must be provided" -ForegroundColor Red
            return $false
        }

        # Extract ID from URL if not provided
        if (-not $DeleteModID -and $DeleteModUrl) {
            if ($DeleteModUrl -match "modrinth\.com/mod/([^/]+)") {
                $DeleteModID = $matches[1]
            } elseif ($DeleteModUrl -match "modrinth\.com/shader/([^/]+)") {
                $DeleteModID = $matches[1]
            } elseif ($DeleteModUrl -match "curseforge\.com/minecraft/mc-mods/([^/]+)") {
                $DeleteModID = $matches[1]
            } else {
                Write-Host "Error: Could not extract mod ID from URL: $DeleteModUrl" -ForegroundColor Red
                return $false
            }
        }

        # Load existing mods
        if (-not (Test-Path $CsvPath)) {
            Write-Host "Error: Database file not found: $CsvPath" -ForegroundColor Red
            return $false
        }

        $mods = Import-Csv -Path $CsvPath
        if (-not $mods) {
            Write-Host "Error: Database is empty" -ForegroundColor Red
            return $false
        }

        # Find the mod to delete
        $modToDelete = $mods | Where-Object { $_.ID -eq $DeleteModID }
        if (-not $modToDelete) {
            Write-Host "Error: Mod with ID '$DeleteModID' not found in database" -ForegroundColor Red
            return $false
        }

        # Optional type filtering - handle empty type fields
        if ($DeleteModType -and $modToDelete.Type -ne $DeleteModType) {
            # If the mod has an empty type field, treat it as "mod" for compatibility
            $effectiveType = if ([string]::IsNullOrWhiteSpace($modToDelete.Type)) { "mod" } else { $modToDelete.Type }
            if ($effectiveType -ne $DeleteModType) {
                Write-Host "Error: Mod with ID '$DeleteModID' has type '$effectiveType', expected '$DeleteModType'" -ForegroundColor Red
                return $false
            }
        }

        # Remove the mod
        $mods = $mods | Where-Object { $_.ID -ne $DeleteModID }

        # Save back to CSV
        $mods | Export-Csv -Path $CsvPath -NoTypeInformation

        Write-Host "✅ Successfully deleted mod '$($modToDelete.Name)' (ID: $DeleteModID) from database" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Error deleting mod from database: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
} 