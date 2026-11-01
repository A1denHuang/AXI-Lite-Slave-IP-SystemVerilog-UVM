param([string]$OutputDirectory='results/v1.1')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$dir=Join-Path $root $OutputDirectory
$rows=@(Import-Csv (Join-Path $dir 'regression_results.csv'))
if($rows.Count -ne 90 -or @($rows | Where-Object Result -ne 'PASS').Count) {throw 'Expected 90 passing UVM runs'}
$counts=@{}
foreach($row in $rows) {
    $log=Get-Content -Raw (Join-Path $dir "logs/$($row.Test)_seed_$($row.Seed).log")
    $line=[regex]::Match($log,'(?m)^.*\[TIMING_COUNTS\] (.*)$').Groups[1].Value
    if(-not $line) {throw "Missing timing counts: $($row.Test)"}
    foreach($pair in [regex]::Matches($line,'([A-Z_]+)=(\d+)')) {
        $key=$pair.Groups[1].Value
        $counts[$key]+=[int]$pair.Groups[2].Value
    }
}
$coverage=Get-Content -Raw (Join-Path $dir 'final_merged_coverage.txt')
$groups=@{}
foreach($match in [regex]::Matches($coverage,'(?m)^ TYPE /axi_lite_pkg/[^\r\n]+/(axi_lite_cg|timing_cg)\s+([0-9.]+)%')) {
    $groups[$match.Groups[1].Value]=[double]$match.Groups[2].Value
}
$assertions=@{}
foreach($name in @('a_awaddr_stable_until_handshake','a_wdata_stable_until_handshake','a_araddr_stable_until_handshake')) {
    $pattern='(?m)^/top_tb/axi_assert_i/'+$name+'\r?\n\s+UVM/assertions.sv\(\d+\)\s+(\d+)\s+(\d+)'
    $m=[regex]::Match($coverage,$pattern)
    if(-not $m.Success) {throw "Missing assertion statistics: $name"}
    $assertions[$name]=@{Failures=[int]$m.Groups[1].Value; Passes=[int]$m.Groups[2].Value}
    if([int]$m.Groups[1].Value -ne 0 -or [int]$m.Groups[2].Value -eq 0) {throw "Assertion not exercised: $name"}
}
$directed=Get-Content -Raw (Join-Path $dir 'logs/directed_smoke.log')
if($directed -notmatch '(?m)^# PASS\r?$') {throw 'Missing directed PASS'}
$summary=[ordered]@{
    Version='v1.1'; BaselineCommit='30ab586'; Date='2026-11-01'; Timezone='Asia/Shanghai'
    Simulator='QuestaSim-64 10.7c'; NormalRuns=91; Passed=91
    UvmCheckedTransfers=($rows | Measure-Object Transactions -Sum).Sum; DirectedTransfers=13
    FunctionalCoveragePercent=$groups['axi_lite_cg']; TimingCoveragePercent=$groups['timing_cg']
    TimingCounts=$counts; RequestStabilityAssertions=$assertions
    ExpectedFailure='Three isolated AW/W/AR payload stability failures; excluded from normal regression'
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $dir 'summary.json')
$files=foreach($subdir in @('UVM','rtl','sim')) {
    Get-ChildItem (Join-Path $root $subdir) -Recurse -File | Where-Object Extension -in @('.sv','.v','.ps1','.do') | Sort-Object FullName | ForEach-Object {
        [ordered]@{Path=$_.FullName.Substring($root.Length+1).Replace('\','/'); Sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLower()}
    }
}
[ordered]@{Version='v1.1'; HashConvention='Raw file bytes (Git may normalize CRLF on checkout)'; Files=@($files)} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $dir 'source_manifest.json')
$summary | ConvertTo-Json -Depth 6
