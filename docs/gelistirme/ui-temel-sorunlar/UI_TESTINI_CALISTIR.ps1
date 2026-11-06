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
$work = Join-Path ([IO.Path]::GetTempPath()) ('TorimonUIAudit-' + $auditId)
$null = New-Item -ItemType Directory -Path $work
$null = New-Item -ItemType Directory -Path $OutputPath -Force
$output = (Resolve-Path -LiteralPath $OutputPath).Path
foreach ($folder in @('assets', 'scenes', 'scripts')) {
    Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $work -Recurse
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ui_audit.gd') -Destination $work
$config = [IO.File]::ReadAllText((Join-Path $source 'project.godot'))
$config = [regex]::Replace($config, 'config/name="[^"]*"', ('config/name="TorimonUIAudit_' + $auditId + '"'))
[IO.File]::WriteAllText((Join-Path $work 'project.godot'), $config, [Text.UTF8Encoding]::new($false))
$oldSmoke = $env:TORIMON_SMOKE
try {
    $env:TORIMON_SMOKE = $null
    & $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Test kopyasi import edilemedi; import.log dosyasina bakin.' }
    & $engine --headless --path $work --script res://ui_audit.gd *> (Join-Path $output 'ui_audit.log')
    $resultFile = Join-Path $work 'ui_audit.json'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) { throw 'UI testi tamamlanamadi; ui_audit.log dosyasina bakin.' }
    Copy-Item -LiteralPath $resultFile -Destination $output
    $record = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
    $checks = @($record.results)
    $failed = @($checks | Where-Object { -not $_.passed })
    [ordered]@{ checks = $checks.Count; passed = $checks.Count - $failed.Count; failed = $failed.Count; isolated_project = $work } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding utf8
    Write-Output ("{0} kontrol, {1} basarili, {2} basarisiz. Sonuclar: {3}" -f $checks.Count,($checks.Count-$failed.Count),$failed.Count,$output)
    Write-Output 'Headless, geometri ve fixture kontrolleridir; gercek Android veya gorsel render testi degildir.'
    if ($failed.Count -gt 0) { exit 1 }
} finally {
    $env:TORIMON_SMOKE = $oldSmoke
}
