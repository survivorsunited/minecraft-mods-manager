# Pester 5.x tests for Minecraft Mod Manager
# Run with: Invoke-Pester -Script ./test/ModManagerPesterTest.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $here
$modManager = Join-Path $projectRoot 'ModManager.ps1'

function Run-ModManager {
    param(
        [string]$Arguments
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$modManager`" $Arguments"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return @{ Output = $stdout; Error = $stderr; ExitCode = $proc.ExitCode }
}

Describe 'Minecraft Mod Manager Integration' {
    $tempDb = Join-Path $TestDrive 'pester-modlist.csv'

    BeforeAll {
        # Clean up before test
        if (Test-Path $tempDb) { Remove-Item $tempDb -Force }
    }
    AfterAll {
        # Clean up after test
        if (Test-Path $tempDb) { Remove-Item $tempDb -Force }
    }

    It 'Adds Fabric API mod by ID' {
        $result = Run-ModManager "-ModListFile `"$tempDb`" -AddMod -AddModId 'fabric-api' -AddModName 'Fabric API' -AddModType 'mod' -AddModLoader 'fabric' -AddModGameVersion '1.21.5' -AddModDescription 'Core API for the Fabric toolchain'"
        $csv = Import-Csv $tempDb
        ($csv | Where-Object { $_.ID -eq 'fabric-api' }).ID | Should -Be 'fabric-api'
    }
    It 'Adds Sodium mod by ID' {
        $result = Run-ModManager "-ModListFile `"$tempDb`" -AddMod -AddModId 'sodium' -AddModName 'Sodium' -AddModType 'mod' -AddModLoader 'fabric' -AddModGameVersion '1.21.5' -AddModDescription 'Modern rendering engine and client-side optimization mod'"
        $csv = Import-Csv $tempDb
        ($csv | Where-Object { $_.ID -eq 'sodium' }).ID | Should -Be 'sodium'
    }
    It 'Adds Complementary Reimagined shaderpack' {
        $result = Run-ModManager "-ModListFile `"$tempDb`" -AddMod -AddModId 'complementary-reimagined' -AddModName 'Complementary Reimagined' -AddModType 'shaderpack' -AddModLoader 'iris' -AddModGameVersion '1.21.5' -AddModDescription 'Beautiful shaderpack'"
        $csv = Import-Csv $tempDb
        ($csv | Where-Object { $_.ID -eq 'complementary-reimagined' }).ID | Should -Be 'complementary-reimagined'
    }
    It 'Validates all mods without error' {
        $result = Run-ModManager "-ModListFile `"$tempDb`" -ValidateAllModVersions"
        $result.ExitCode | Should -Be 0
    }
    It 'Shows help text' {
        $result = Run-ModManager "-ShowHelp"
        $result.Output | Should -Match 'USAGE EXAMPLES'
        $result.Output | Should -Match 'FUNCTIONS'
    }
    It 'Downloads mods without error' {
        $result = Run-ModManager "-ModListFile `"$tempDb`" -Download"
        $result.ExitCode | Should -Be 0
    }
} 