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
                # Set both as environment variable and global variable for compatibility
                Set-Item -Path "env:$name" -Value $value
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
    }
}

# Set default configuration values for modular functions
$script:DefaultGameVersion = "1.21.5"
$script:DefaultLoader = "fabric"
$script:DefaultModType = "mod"
$script:ModListPath = "modlist.csv"
$script:ApiResponseFolder = ".cache/apiresponse"

# Function is available for dot-sourcing 