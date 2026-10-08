param(
    [int]$SeedsPerTest = 10,
    [int]$RandomTransactions = 500
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Vsim = 'D:\Questasim\win64\vsim.exe'
$Vcover = 'D:\Questasim\win64\vcover.exe'
$ResultsDir = Join-Path $ProjectRoot 'results'
$LogsDir = Join-Path $ResultsDir 'logs'

if (-not (Test-Path -LiteralPath $Vsim)) {
    throw "QuestaSim not found: $Vsim"
}

New-Item -ItemType Directory -Force -Path $ResultsDir, $LogsDir | Out-Null

Push-Location $ProjectRoot
try {
    $compileLog = Join-Path $LogsDir 'compile.log'
    & $Vsim -c -do 'sim/compile_coverage.do' *> $compileLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $compileLog -Pattern '^# Errors: [1-9]' -Quiet)) {
        throw "Coverage compilation failed. See $compileLog"
    }

    $tests = @(
        'axi_lite_smoke_test',
        'axi_lite_random_test',
        'axi_lite_wstrb_test',
        'axi_lite_error_test',
        'axi_lite_backpressure_test'
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $runIndex = 0
    foreach ($test in $tests) {
        for ($iteration = 1; $iteration -le $SeedsPerTest; $iteration++) {
            $runIndex++
            $seed = 1000 + $runIndex
            $stem = "${test}_seed_${seed}"
            $ucdb = "results/${stem}.ucdb"
            $log = Join-Path $LogsDir "${stem}.log"
            $do = "run -all; coverage save {$ucdb}; quit -f"

            $vsimArgs = @(
                '-c', '-nodpiexports', '-coverage', '-onfinish', 'stop',
                '-sv_seed', "$seed", 'top_tb',
                "+UVM_TESTNAME=$test", "+NUM_TXNS=$RandomTransactions", '+UVM_NO_RELNOTES',
                '-do', $do
            )
            & $Vsim @vsimArgs *> $log

            $text = Get-Content -Raw -LiteralPath $log
            $uvmError = [regex]::Match($text, 'UVM_ERROR\s*:\s*(\d+)').Groups[1].Value
            $uvmFatal = [regex]::Match($text, 'UVM_FATAL\s*:\s*(\d+)').Groups[1].Value
            $functional = [regex]::Match($text, 'AXI-Lite functional coverage:\s*([0-9.]+)%').Groups[1].Value
            $passed = ($LASTEXITCODE -eq 0 -and $uvmError -eq '0' -and $uvmFatal -eq '0' -and (Test-Path -LiteralPath $ucdb))

            $rows.Add([pscustomobject]@{
                Run = $runIndex
                Test = $test
                Seed = $seed
                Transactions = if ($test -eq 'axi_lite_random_test') { $RandomTransactions } elseif ($test -eq 'axi_lite_backpressure_test') { 100 } else { 'directed' }
                FunctionalCoveragePercent = $functional
                UvmErrors = $uvmError
                UvmFatals = $uvmFatal
                Result = if ($passed) { 'PASS' } else { 'FAIL' }
            })

            if (-not $passed) {
                throw "Regression failed: $test seed $seed. See $log"
            }
        }
    }

    $rows | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $ResultsDir 'regression_results.csv')

    $ucdbFiles = foreach ($row in $rows) {
        Join-Path $ResultsDir "$($row.Test)_seed_$($row.Seed).ucdb"
    }
    $merged = Join-Path $ResultsDir 'merged_coverage.ucdb'
    & $Vcover merge -out $merged $ucdbFiles *> (Join-Path $LogsDir 'merge.log')
    if ($LASTEXITCODE -ne 0) {
        throw 'Coverage merge failed.'
    }

    & $Vcover report -details -output (Join-Path $ResultsDir 'merged_coverage.txt') $merged *> (Join-Path $LogsDir 'report.log')
    if ($LASTEXITCODE -ne 0) {
        throw 'Coverage report failed.'
    }

    $directedLog = Join-Path $LogsDir 'directed_smoke.log'
    & $Vsim -c -do 'sim/run_directed_coverage.do' *> $directedLog
    $directedPassed = ($LASTEXITCODE -eq 0 -and (Select-String -LiteralPath $directedLog -Pattern '^# PASS$' -Quiet))
    if (-not $directedPassed) {
        throw "Directed smoke test failed. See $directedLog"
    }

    $allUcdbFiles = @($ucdbFiles) + (Join-Path $ResultsDir 'directed_smoke.ucdb')
    $finalMerged = Join-Path $ResultsDir 'final_merged_coverage.ucdb'
    & $Vcover merge -out $finalMerged $allUcdbFiles *> (Join-Path $LogsDir 'final_merge.log')
    if ($LASTEXITCODE -ne 0) {
        throw 'Final UVM + directed coverage merge failed.'
    }

    & $Vcover report -details -output (Join-Path $ResultsDir 'final_merged_coverage.txt') $finalMerged *> (Join-Path $LogsDir 'final_report.log')
    if ($LASTEXITCODE -ne 0) {
        throw 'Final UVM + directed coverage report failed.'
    }

    $passCount = ($rows | Where-Object Result -eq 'PASS').Count
    $totalRuns = $rows.Count + 1
    $totalPass = $passCount + 1
    Write-Output "REGRESSION_COMPLETE runs=$totalRuns pass=$totalPass fail=$($totalRuns - $totalPass)"
}
finally {
    Pop-Location
}
