# Helper function to clean filenames (decode URL, remove Minecraft formatting codes, and non-printable characters)
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