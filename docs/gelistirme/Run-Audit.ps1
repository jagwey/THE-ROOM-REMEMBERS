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
$work = Join-Path ([IO.Path]::GetTempPath()) ('TorimonAudit-' + $auditId)
$null = New-Item -ItemType Directory -Path $work
$null = New-Item -ItemType Directory -Path $OutputPath -Force
$output = (Resolve-Path -LiteralPath $OutputPath).Path
foreach ($folder in @('assets', 'scenes', 'scripts', 'themes')) {
    Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $work -Recurse
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'audit.gd') -Destination $work
$originalConfig = [IO.File]::ReadAllText((Join-Path $source 'project.godot'))
$isolatedConfig = [regex]::Replace($originalConfig, 'config/name="[^"]*"', ('config/name="TorimonAudit_' + $auditId + '"'))
[IO.File]::WriteAllText((Join-Path $work 'project.godot'), $isolatedConfig, [Text.UTF8Encoding]::new($false))
$oldCase = $env:TORIMON_AUDIT_CASE
$oldSmoke = $env:TORIMON_SMOKE
$records = @()
try {
    $env:TORIMON_SMOKE = $null
    & $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Test kopyasi import edilemedi; import.log dosyasina bakin.' }
    foreach ($case in @('baseline','save_write','save_read','death','seal','core_corpse','trim','ending_touch','bad_attacks','plate_chain')) {
        # Every fixture has its own user data. The two save cases share one namespace.
        $namespace = if ($case -in @('save_write','save_read')) { 'save' } else { $case }
        $caseConfig = [regex]::Replace($originalConfig, 'config/name="[^"]*"', ('config/name="TorimonAudit_' + $auditId + '_' + $namespace + '"'))
        [IO.File]::WriteAllText((Join-Path $work 'project.godot'), $caseConfig, [Text.UTF8Encoding]::new($false))
        $env:TORIMON_AUDIT_CASE = $case
        & $engine --headless --path $work --script res://audit.gd *> (Join-Path $output ($case + '.log'))
        $resultFile = Join-Path $work ('audit_' + $case + '.json')
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) { throw "Senaryo calismadi: $case" }
        Copy-Item -LiteralPath $resultFile -Destination $output
        $records += Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
    }
    $checks = @($records | ForEach-Object { $_.results })
    $failed = @($checks | Where-Object { -not $_.passed })
    $summary = [ordered]@{ cases = $records.Count; checks = $checks.Count; passed = $checks.Count - $failed.Count; failed = $failed.Count; isolated_project = $work; records = $records }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding utf8
    Write-Output ("{0} senaryo, {1} kontrol, {2} basarili, {3} basarisiz. Sonuclar: {4}" -f $records.Count,$checks.Count,($checks.Count-$failed.Count),$failed.Count,$output)
    Write-Output 'Bunlar mevcut surumun davranis kontrolleridir; fixture ile gecen final, dogal oyun rotasini kanitlamaz.'
    if ($failed.Count -gt 0) { exit 1 }
} finally {
    $env:TORIMON_AUDIT_CASE = $oldCase
    $env:TORIMON_SMOKE = $oldSmoke
}
