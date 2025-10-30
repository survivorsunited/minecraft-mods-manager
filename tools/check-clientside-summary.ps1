param(
    [string]$CsvPath = 'modlist.csv'
)
if (!(Test-Path $CsvPath)) {
    Write-Host "CSV not found: $CsvPath" -ForegroundColor Red
    exit 1
}
$rows = Import-Csv -Path $CsvPath
$total = $rows.Count
$hasClient = ($rows | Where-Object { $_.PSObject.Properties.Name -contains 'ClientSide' -and $_.ClientSide -and $_.ClientSide.Trim() -ne '' }).Count
$hasServer = ($rows | Where-Object { $_.PSObject.Properties.Name -contains 'ServerSide' -and $_.ServerSide -and $_.ServerSide.Trim() -ne '' }).Count
$unsupported = @()
if ($rows.Count -gt 0 -and ($rows[0].PSObject.Properties.Name -contains 'ClientSide')) {
    $unsupported = $rows | Where-Object { $_.ClientSide -eq 'unsupported' }
}
$serverOnly = $rows | Where-Object { 
    ($_.PSObject.Properties.Name -contains 'ClientSide' -and $_.ClientSide -eq 'unsupported') -or 
    ($_.PSObject.Properties.Name -contains 'Group' -and $_.Group -eq 'admin') -or 
    ($_.PSObject.Properties.Name -contains 'Type' -and $_.Type -in @('server','launcher','installer'))
}
Write-Host ("Total rows: {0}" -f $total)
Write-Host ("ClientSide populated: {0}" -f $hasClient)
Write-Host ("ServerSide populated: {0}" -f $hasServer)
Write-Host ("Server-only candidates: {0}" -f ($serverOnly.Count))
Write-Host ("ClientSide=unsupported: {0}" -f ($unsupported.Count))
Write-Host ''
Write-Host 'Examples (ClientSide=unsupported):' -ForegroundColor Cyan
$unsupported | Select-Object -First 10 Name,ID,Host,Type,Group,ClientSide,ServerSide,CurrentGameVersion | Format-Table -AutoSize
