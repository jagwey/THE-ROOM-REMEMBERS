param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$GodotPath = 'Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputPath = (Join-Path $PSScriptRoot ('results-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $source 'project.godot'))) { throw 'Godot projesi bulunamadi.' }
$engine = (Get-Command $GodotPath -ErrorAction Stop).Source
$auditId = [Guid]::NewGuid().ToString('N')
$work = Join-Path ([IO.Path]::GetTempPath()) ('RoomNextAudit-' + $auditId)
$null = New-Item -ItemType Directory -Path $work
$null = New-Item -ItemType Directory -Path $OutputPath -Force
$output = (Resolve-Path -LiteralPath $OutputPath).Path
foreach ($folder in @('assets', 'scenes', 'scripts', 'themes')) {
    if (Test-Path -LiteralPath (Join-Path $source $folder)) {
        Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $work -Recurse
    }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'next_audit.gd') -Destination $work
$config = [IO.File]::ReadAllText((Join-Path $source 'project.godot'))
$config = [regex]::Replace($config, 'config/name="[^"]*"', ('config/name="RoomNextAudit_' + $auditId + '"'))
# Cold imports must build font data before the custom project theme loads.
$bootstrap = [regex]::Replace($config, '(?m)^theme/custom=.*\r?\n', '')
[IO.File]::WriteAllText((Join-Path $work 'project.godot'), $bootstrap, [Text.UTF8Encoding]::new($false))
& $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'bootstrap-import.log')
if ($LASTEXITCODE -ne 0) { throw 'Font ve asset importu tamamlanamadi.' }
[IO.File]::WriteAllText((Join-Path $work 'project.godot'), $config, [Text.UTF8Encoding]::new($false))
& $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Test kopyasi import edilemedi.' }
& $engine --headless --path $work --script res://next_audit.gd *> (Join-Path $output 'next_audit.log')
$resultFile = Join-Path $work 'next_audit.json'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) { throw 'Test raporu olusmadi; logu inceleyin.' }
Copy-Item -LiteralPath $resultFile -Destination $output
$result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
Write-Output ("{0} kontrol, {1} gecti, {2} kaldi. Sonuclar: {3}" -f $result.checks,$result.passed,$result.failed,$output)
Write-Output 'Headless ve fixture testidir; dogal oynanis/telefon testi degildir.'
if ($result.failed -gt 0) { exit 1 }
