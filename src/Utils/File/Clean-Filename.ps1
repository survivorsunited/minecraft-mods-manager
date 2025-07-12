# =============================================================================
# Filename Cleaning Module
# =============================================================================
# This module handles cleaning and sanitizing filenames.
# =============================================================================

<#
.SYNOPSIS
    Cleans filenames by removing problematic characters.

.DESCRIPTION
    Decodes URL-encoded characters, removes Minecraft formatting codes,
    and strips non-printable characters from filenames.

.PARAMETER filename
    The filename to clean.

.EXAMPLE
    Clean-Filename -filename "§rMy%20Mod%20Name.jar"

.NOTES
    - Decodes URL-encoded characters (%20, etc.)
    - Removes Minecraft formatting codes (§r, §l, etc.)
    - Strips non-printable and control characters
    - Returns clean, safe filename
#>
function Clean-Filename {
    param([string]$filename)
    # Decode URL-encoded characters
    $decoded = [System.Uri]::UnescapeDataString($filename)
    # Remove Minecraft formatting codes (e.g., §r, §l, etc.)
    $cleaned = $decoded -replace "§[0-9a-fl-or]", ""
    # Remove any non-printable or control characters
    $cleaned = -join ($cleaned.ToCharArray() | Where-Object { [int]$_ -ge 32 -and [int]$_ -le 126 })
    return $cleaned
}

# Function is available for dot-sourcing 