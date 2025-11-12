# 98-TestHttpRetryWrapper.ps1
# Validates Invoke-RestMethodWithRetry behavior for 429/5xx and non-retriable errors.

Import-Module (Join-Path $PSScriptRoot '..\TestFramework.ps1') -ErrorAction SilentlyContinue
. "$PSScriptRoot\..\..\src\Net\Invoke-RestMethodWithRetry.ps1"

$TestFileName = "98-TestHttpRetryWrapper.ps1"
Initialize-TestEnvironment $TestFileName

Write-TestHeader "HTTP Retry Wrapper"

# We'll shadow Start-Sleep to avoid real delays during tests
$originalStartSleep = Get-Command Start-Sleep -ErrorAction SilentlyContinue
function Start-Sleep { param([int]$Seconds) Write-Host "(sleep $Seconds s suppressed for test)" -ForegroundColor DarkGray }

# Helper to attach a Response-like object to an Exception and throw it
function Throw-HttpError {
    param([int]$StatusCode, [object]$RetryAfter = $null, [string]$Message = "Synthetic HTTP error")
    $e = New-Object System.Exception $Message
    $resp = [pscustomobject]@{ StatusCode = ([pscustomobject]@{ value__ = $StatusCode }); Headers = @{} }
    if ($RetryAfter) { $resp.Headers['Retry-After'] = $RetryAfter }
    $e | Add-Member -NotePropertyName Response -NotePropertyValue $resp
    throw $e
}

# Backup original Invoke-RestMethod and create a shadow in the test scope
$hasOriginalIRM = $false
try { $origIRM = Get-Command Invoke-RestMethod -ErrorAction Stop; $hasOriginalIRM = $true } catch {}

# Case 1: 429 with Retry-After header, then success
$script:irmCalls = 0
function Invoke-RestMethod {
    param([Parameter(Mandatory=$true)][string]$Uri,[string]$Method='Get',[hashtable]$Headers,[int]$TimeoutSec)
    $script:irmCalls++
    if ($Uri -eq 'https://test.case1/ok') {
        if ($script:irmCalls -eq 1) { Throw-HttpError -StatusCode 429 -RetryAfter 1 -Message 'Too Many Requests' }
        return @{ ok = $true; attempt = $script:irmCalls }
    }
    throw (New-Object System.Exception "Unexpected URI: $Uri")
}

try {
    $resp = Invoke-RestMethodWithRetry -Uri 'https://test.case1/ok' -TimeoutSec 2 -MaxRetries 3
    $passed = ($resp.ok -eq $true) -and ($script:irmCalls -eq 2)
    Write-TestResult "429 respected Retry-After and retried" $passed "Attempts: $script:irmCalls"
} catch {
    Write-TestResult "429 respected Retry-After and retried" $false $_.Exception.Message
}

# Case 2: 500 twice then success
$script:irmCalls = 0
Remove-Item Function:Invoke-RestMethod -ErrorAction SilentlyContinue
function Invoke-RestMethod {
    param([Parameter(Mandatory=$true)][string]$Uri,[string]$Method='Get',[hashtable]$Headers,[int]$TimeoutSec)
    $script:irmCalls++
    if ($Uri -eq 'https://test.case2/ok') {
        if ($script:irmCalls -le 2) { Throw-HttpError -StatusCode 500 -Message 'Server Error' }
        return @{ ok = $true; attempt = $script:irmCalls }
    }
    throw (New-Object System.Exception "Unexpected URI: $Uri")
}

try {
    $resp = Invoke-RestMethodWithRetry -Uri 'https://test.case2/ok' -TimeoutSec 2 -MaxRetries 5 -InitialDelaySec 1
    $passed = ($resp.ok -eq $true) -and ($script:irmCalls -eq 3)
    Write-TestResult "500 retried with exponential backoff" $passed "Attempts: $script:irmCalls"
} catch {
    Write-TestResult "500 retried with exponential backoff" $false $_.Exception.Message
}

# Case 3: 400 (non-retriable) -> immediate throw
$script:irmCalls = 0
Remove-Item Function:Invoke-RestMethod -ErrorAction SilentlyContinue
function Invoke-RestMethod {
    param([Parameter(Mandatory=$true)][string]$Uri,[string]$Method='Get',[hashtable]$Headers,[int]$TimeoutSec)
    $script:irmCalls++
    if ($Uri -eq 'https://test.case3/bad') { Throw-HttpError -StatusCode 400 -Message 'Bad Request' }
    return @{ ok = $true }
}

$thrown = $false
try {
    $null = Invoke-RestMethodWithRetry -Uri 'https://test.case3/bad' -TimeoutSec 2 -MaxRetries 2
} catch {
    $thrown = $true
}
Write-TestResult "400 does not retry and throws" $thrown "Attempts: $script:irmCalls"

# Cleanup: restore originals
try { Remove-Item Function:Invoke-RestMethod -ErrorAction SilentlyContinue } catch {}
if ($hasOriginalIRM) {
    Set-Item -Path function:Invoke-RestMethod -Value $origIRM.ScriptBlock -ErrorAction SilentlyContinue | Out-Null
}
try { if ($originalStartSleep -and $originalStartSleep.ScriptBlock) { Set-Item -Path function:Start-Sleep -Value $originalStartSleep.ScriptBlock -ErrorAction SilentlyContinue } else { Remove-Item Function:Start-Sleep -ErrorAction SilentlyContinue } } catch {}

Show-TestSummary "HTTP Retry Wrapper"
return ($script:TestResults.Failed -eq 0)
