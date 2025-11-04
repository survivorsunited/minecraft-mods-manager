function Invoke-RestMethodWithRetry {
    <#
    .SYNOPSIS
    Invoke-RestMethod with automatic retry and backoff for 429/5xx responses.

    .DESCRIPTION
    Wraps Invoke-RestMethod to handle common transient API failures such as
    HTTP 429 (Too Many Requests) and 5xx server errors. Respects the Retry-After
    header when present and applies exponential backoff otherwise. Also ensures
    a reasonable User-Agent header is sent to APIs.

    .PARAMETER Uri
    The request URL.

    .PARAMETER Method
    HTTP method (default: GET).

    .PARAMETER Headers
    Optional headers to include.

    .PARAMETER TimeoutSec
    Request timeout in seconds (default: 30).

    .PARAMETER MaxRetries
    Maximum retry attempts for retriable errors (default: 5).

    .PARAMETER InitialDelaySec
    Initial delay before first retry when Retry-After is not provided (default: 1).

    .EXAMPLE
    $resp = Invoke-RestMethodWithRetry -Uri "https://api.modrinth.com/v2/project/fabric-api" -Method Get
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [ValidateSet('Get','Post','Put','Delete','Patch','Head','Options')]
        [string]$Method = 'Get',
        [hashtable]$Headers,
        [int]$TimeoutSec = 30,
        [int]$MaxRetries = 5,
        [int]$InitialDelaySec = 1
    )

    $attempt = 0
    $delay = [Math]::Max(1, $InitialDelaySec)

    if (-not $Headers) { $Headers = @{} }
    $ua = $env:MMM_USER_AGENT
    if ([string]::IsNullOrWhiteSpace($ua)) { $ua = 'survivorsunited.minecraft-mods-manager/ci' }
    if (-not $Headers.ContainsKey('User-Agent')) { $Headers['User-Agent'] = $ua }

    while ($true) {
        try {
            return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -TimeoutSec $TimeoutSec
        }
        catch {
            $attempt++
            $statusCode = $null
            $retryAfterHeader = $null

            # Try to extract HTTP status code and Retry-After header from the exception
            if ($_.Exception -and ($_.Exception.PSObject.Properties.Name -contains 'Response') -and $_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode.value__ } catch { try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = $null } }
                try { $retryAfterHeader = $_.Exception.Response.Headers['Retry-After'] } catch { $retryAfterHeader = $null }
            }

            $isRetriable = $false
            if ($statusCode) {
                if ($statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -lt 600)) { $isRetriable = $true }
            }

            if ($isRetriable -and $attempt -le $MaxRetries) {
                # Determine sleep time
                $sleepSec = $delay
                if ($retryAfterHeader) {
                    if ($retryAfterHeader -is [array]) { $retryAfterHeader = $retryAfterHeader[0] }
                    if ($retryAfterHeader -match '^[0-9]+$') {
                        $sleepSec = [int]$retryAfterHeader
                    }
                    else {
                        try {
                            $dt = [DateTimeOffset]::Parse($retryAfterHeader)
                            $delta = [int][Math]::Ceiling(($dt - [DateTimeOffset]::UtcNow).TotalSeconds)
                            if ($delta -ge 1) { $sleepSec = $delta }
                        } catch {}
                    }
                }

                if ($sleepSec -lt 1) { $sleepSec = 1 }
                Write-Host ("Rate limited or server error ({0}). Retry {1}/{2} in {3}s -> {4}" -f $statusCode, $attempt, $MaxRetries, $sleepSec, $_.Exception.Message) -ForegroundColor Yellow
                Start-Sleep -Seconds $sleepSec
                if (-not $retryAfterHeader) { $delay = [Math]::Min($delay * 2, 30) }
                continue
            }

            throw
        }
    }
}
