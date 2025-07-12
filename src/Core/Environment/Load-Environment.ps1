# =============================================================================
# Environment Loading Module
# =============================================================================
# This module handles loading environment variables from .env files.
# =============================================================================

<#
.SYNOPSIS
    Loads environment variables from .env file.

.DESCRIPTION
    Reads environment variables from a .env file and sets them
    as global variables in the current PowerShell session.

.EXAMPLE
    Load-EnvironmentVariables

.NOTES
    - Reads from .env file in current directory
    - Sets variables as global scope
    - Skips comment lines (starting with #)
    - Handles key=value format
#>
function Load-EnvironmentVariables {
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^#][^=]+)=(.*)$") {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
    }
}

# Function is available for dot-sourcing 