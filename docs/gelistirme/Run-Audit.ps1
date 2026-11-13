param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$GodotPath = 'Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputPath = (Join-Path $PSScriptRoot ('results-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch]$IncludeLegacy # docs/gelistirme/audit.gd (v0.10.1) senaryolari; v3 oncesi, seal/ending_touch artik guncel degil (AUDIT_TIMEOUT)
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
foreach ($folder in @('assets', 'scenes', 'scripts', 'themes', 'data', 'android')) {
    Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $work -Recurse
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'audit.gd') -Destination $work
# e2e_runner export/belge kontrolleri icin kok dosyalar
foreach ($f in @('export_presets.cfg','PROJECT.md','TEST_INFRA.md','TEST_READY.md')) { if (Test-Path -LiteralPath (Join-Path $source $f)) { Copy-Item -LiteralPath (Join-Path $source $f) -Destination $work } }
$originalConfig = [IO.File]::ReadAllText((Join-Path $source 'project.godot'))
$isolatedConfig = [regex]::Replace($originalConfig, 'config/name="[^"]*"', ('config/name="TorimonAudit_' + $auditId + '"'))
[IO.File]::WriteAllText((Join-Path $work 'project.godot'), $isolatedConfig, [Text.UTF8Encoding]::new($false))
$oldCase = $env:TORIMON_AUDIT_CASE
$oldSmoke = $env:TORIMON_SMOKE
$oldTest = $env:TORIMON_TEST
$oldTitle = $env:TORIMON_FORCE_TITLE
$records = @()
# v3 SceneTree denetimleri (scripts/dev). Hepsi TORIMON_TEST=1 ile calisir; cikis kodu 0 = gecti.
# Yeni v3 denetimleri: lore_canon, story_flags, save_split, memory_seal, curse_reload, final_sequence.
$devAudits = @(
    'lore_canon','story_flags','save_split','memory_seal','curse_reload','final_sequence',
    'save_quit','start_flow','death_loop','interact','ui_header_portrait','keeper_naming',
    'plate_rule','ascent','release','controls','door','push','jump','eye_intro','room_header_fit','room_identity','dialogue_data','room_graph','save_robust',
    'resume_m3','update_check','m1_stress','softlock_reset','save_robustness','move_time','softlock_phase0','dialogue_lint','phase2_rooms','phase3_rooms'
)
$devRecords = @()
try {
    # Godot stderr (ornegin import uyarilari) PowerShell 5.1'de NativeCommandError olmasin; sonuc $LASTEXITCODE ile denetlenir.
    $ErrorActionPreference = 'Continue'
    $env:TORIMON_SMOKE = $null
    & $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'import.log')
    # Ilk import bazen font/ses cikti dosyalarini yazmadan biter (fontdata yok -> tum denetimler yuklenemez); ikinci gecis ucuzdur.
    & $engine --headless --editor --path $work --import --quit *> (Join-Path $output 'import2.log')
    # Temiz kopyada ilk import font/ses icin hata kodu donebilir; senaryolar kendi sonucunu dogrular, kod yalniz uyari.
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Import sifirdan olmayan cikis kodu dondu (import.log); senaryolar yine de calistirilacak.' }
    if ($IncludeLegacy) {
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
    }
    # --- v3 dev denetimleri (izole kopya, TORIMON_TEST=1) ---
    $env:TORIMON_TEST = '1'
    foreach ($a in $devAudits) {
        $ns = 'dev_' + $a
        $devConfig = [regex]::Replace($originalConfig, 'config/name="[^"]*"', ('config/name="TorimonAudit_' + $auditId + '_' + $ns + '"'))
        [IO.File]::WriteAllText((Join-Path $work 'project.godot'), $devConfig, [Text.UTF8Encoding]::new($false))
        $env:TORIMON_FORCE_TITLE = if ($a -eq 'start_flow') { '1' } else { $null }
        $log = Join-Path $output ($ns + '.log')
        & $engine --headless --path $work --script ("res://scripts/dev/{0}_audit.gd" -f $a) *> $log
        $code = $LASTEXITCODE
        $text = Get-Content -LiteralPath $log -Raw
        $pass = ([regex]::Matches($text, '\bPASS\b')).Count
        $fail = ([regex]::Matches($text, '\bFAIL\b')).Count
        $devRecords += [pscustomobject]@{ audit = $a; exit_code = $code; pass_lines = $pass; fail_lines = $fail; passed = ($code -eq 0 -and $fail -eq 0) }
    }
    # e2e ve faz67 smoke
    $env:TORIMON_FORCE_TITLE = $null
    $e2eLog = Join-Path $output 'dev_e2e.log'
    & $engine --headless --path $work --script 'res://scripts/dev/e2e_runner.gd' *> $e2eLog
    $e2eCode = $LASTEXITCODE
    $e2eText = Get-Content -LiteralPath $e2eLog -Raw
    $e2ePass = ([regex]::Matches($e2eText, '\bPASS\b')).Count
    $e2eFail = ([regex]::Matches($e2eText, '\bFAIL\b')).Count
    $devRecords += [pscustomobject]@{ audit = 'e2e_runner'; exit_code = $e2eCode; pass_lines = $e2ePass; fail_lines = $e2eFail; passed = ($e2eCode -eq 0 -and $e2eFail -eq 0) }
    $env:TORIMON_SMOKE = '1'
    $smokeLog = Join-Path $output 'dev_smoke.log'
    & $engine --headless --path $work *> $smokeLog
    $devRecords += [pscustomobject]@{ audit = 'faz67_smoke'; exit_code = $LASTEXITCODE; pass_lines = 0; fail_lines = 0; passed = ($LASTEXITCODE -eq 0) }
    $env:TORIMON_SMOKE = $null
    $devFailed = @($devRecords | Where-Object { -not $_.passed })
    $devRecords | Format-Table -AutoSize | Out-String | Write-Output
    $checks = @($records | ForEach-Object { $_.results })
    $failed = @($checks | Where-Object { -not $_.passed })
    $summary = [ordered]@{ cases = $records.Count; checks = $checks.Count; passed = $checks.Count - $failed.Count; failed = $failed.Count; dev_audits = $devRecords.Count; dev_failed = $devFailed.Count; isolated_project = $work; records = $records; dev_records = $devRecords }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding utf8
    Write-Output ("{0} senaryo, {1} kontrol, {2} basarili, {3} basarisiz. Sonuclar: {4}" -f $records.Count,$checks.Count,($checks.Count-$failed.Count),$failed.Count,$output)
    Write-Output 'Bunlar mevcut surumun davranis kontrolleridir; fixture ile gecen final, dogal oyun rotasini kanitlamaz.'
    Write-Output ("{0} dev denetimi, {1} basarisiz." -f $devRecords.Count, $devFailed.Count)
    if ($failed.Count -gt 0 -or $devFailed.Count -gt 0) { exit 1 }
} finally {
    $env:TORIMON_AUDIT_CASE = $oldCase
    $env:TORIMON_SMOKE = $oldSmoke
    $env:TORIMON_TEST = $oldTest
    $env:TORIMON_FORCE_TITLE = $oldTitle
}
