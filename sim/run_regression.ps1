param(
    [ValidateRange(1, 1000)][int]$SeedsPerTest = 10,
    [ValidateRange(1, 1000000)][int]$RandomTransactions = 500,
    [ValidateRange(1, 1000000)][int]$SimulationTimeoutUs = 10000
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Vsim = 'D:\Questasim\win64\vsim.exe'
$Vcover = 'D:\Questasim\win64\vcover.exe'
$ResultsDir = Join-Path $ProjectRoot 'results'
$LogsDir = Join-Path $ResultsDir 'logs'
$PreviousTimeout = $env:AXI_SIM_TIMEOUT_US

function Test-SimulatorErrors([string]$LogText) {
    # SVA $error is independent of the UVM report server.
    return $LogText -match '(?m)^#\s*\*\*\s+(Error|Fatal|Failure):|^#\s*Errors:\s*[1-9]'
}

if (-not (Test-Path -LiteralPath $Vsim)) {
    throw "QuestaSim not found: $Vsim"
}

New-Item -ItemType Directory -Force -Path $ResultsDir, $LogsDir | Out-Null

Push-Location $ProjectRoot
try {
    $compileLog = Join-Path $LogsDir 'compile.log'
    & $Vsim -c -do 'sim/compile_coverage.do' *> $compileLog
    if ($LASTEXITCODE -ne 0 -or (Test-SimulatorErrors (Get-Content -Raw -LiteralPath $compileLog))) {
        throw "Coverage compilation failed. See $compileLog"
    }

    $tests = @(
        'axi_lite_smoke_test',
        'axi_lite_random_test',
        'axi_lite_wstrb_test',
        'axi_lite_error_test',
        'axi_lite_backpressure_test',
        'axi_lite_learning_test'
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
            # A stopped/timed-out run must not reuse a database from a prior run.
            if (Test-Path -LiteralPath $ucdb) { Remove-Item -LiteralPath $ucdb }
            $do = "run $SimulationTimeoutUs us; coverage save {$ucdb}; quit -f"

            $vsimArgs = @(
                '-c', '-nodpiexports', '-coverage', '-onfinish', 'stop',
                '-sv_seed', "$seed", 'top_tb',
                "+UVM_TESTNAME=$test", "+NUM_TXNS=$RandomTransactions", '+UVM_NO_RELNOTES',
                '-do', $do
            )
            & $Vsim @vsimArgs *> $log
            $simExitCode = $LASTEXITCODE

            $text = Get-Content -Raw -LiteralPath $log
            $uvmError = [regex]::Match($text, 'UVM_ERROR\s*:\s*(\d+)').Groups[1].Value
            $uvmFatal = [regex]::Match($text, 'UVM_FATAL\s*:\s*(\d+)').Groups[1].Value
            $functional = [regex]::Match($text, 'AXI-Lite functional coverage:\s*([0-9.]+)%').Groups[1].Value
            $observedCount = [regex]::Match($text, 'CHECKED_TRANSFERS=(\d+)').Groups[1].Value

            $transactionCount = switch ($test) {
                'axi_lite_smoke_test'        { 13 }
                'axi_lite_random_test'       { $RandomTransactions }
                'axi_lite_wstrb_test'        { 36 }
                'axi_lite_error_test'        { 20 }
                'axi_lite_backpressure_test' { $RandomTransactions }
                'axi_lite_learning_test'     { 29 }
            }

            $passed = ($simExitCode -eq 0 -and $uvmError -eq '0' -and $uvmFatal -eq '0' -and
                -not (Test-SimulatorErrors $text) -and $functional -ne '' -and
                $text.Contains('[TEST_DONE]') -and $observedCount -ne '' -and
                [int]$observedCount -eq $transactionCount -and (Test-Path -LiteralPath $ucdb))

            $rows.Add([pscustomobject]@{
                Run = $runIndex
                Test = $test
                Seed = $seed
                Transactions = $observedCount
                ExpectedTransactions = $transactionCount
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
    $directedUcdb = Join-Path $ResultsDir 'directed_smoke.ucdb'
    if (Test-Path -LiteralPath $directedUcdb) { Remove-Item -LiteralPath $directedUcdb }
    $env:AXI_SIM_TIMEOUT_US = "$SimulationTimeoutUs"
    & $Vsim -c -do 'sim/run_directed_coverage.do' *> $directedLog
    $directedText = Get-Content -Raw -LiteralPath $directedLog
    $directedPassed = ($LASTEXITCODE -eq 0 -and $directedText -match '(?m)^# PASS\r?$' -and
        -not (Test-SimulatorErrors $directedText) -and (Test-Path -LiteralPath $directedUcdb))
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
    $env:AXI_SIM_TIMEOUT_US = $PreviousTimeout
    Pop-Location
}
