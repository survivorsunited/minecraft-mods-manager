# =============================================================================
# Environment Variables Module
# =============================================================================
# This module handles loading and managing environment variables from .env files
# and provides default configuration values.
# =============================================================================

<#
.SYNOPSIS
    Loads environment variables from .env file.

.DESCRIPTION
    Reads environment variables from a .env file and sets them as global variables.
    Supports the standard .env format with KEY=VALUE pairs.

.EXAMPLE
    Load-EnvironmentVariables

.NOTES
    - Looks for .env file in the current directory
    - Ignores lines starting with # (comments)
    - Sets variables in global scope for use throughout the application
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