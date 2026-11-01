param([string]$OutputDirectory='results/project-regs')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$results=Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $results | Out-Null
$previous=$env:AXI_PROJECT_RESULTS_DIR
$env:AXI_PROJECT_RESULTS_DIR=$results.Replace('\','/')
Push-Location $root
try {
    $log=Join-Path $results 'project_regs.log'
    $database=Join-Path $results 'project_regs.ucdb'
    if(Test-Path -LiteralPath $database){Remove-Item -LiteralPath $database}
    & 'D:/Questasim/win64/vsim.exe' -c -do sim/run_project_regs.do *> $log
    $simExit=$LASTEXITCODE
    $text=Get-Content -Raw -LiteralPath $log
    $pass=[regex]::Match($text,'PROJECT_REGS_PASS cases=(\d+) checks=(\d+) writes=(\d+) reads=(\d+) transfers=(\d+)')
    if($simExit -ne 0 -or -not $pass.Success -or [int]$pass.Groups[1].Value -ne 10 -or
       [int]$pass.Groups[2].Value -ne 458 -or [int]$pass.Groups[3].Value -ne 137 -or
       [int]$pass.Groups[4].Value -ne 114 -or [int]$pass.Groups[5].Value -ne 251 -or
       $text -match '(?m)^#\s*\*\*\s+(Error|Fatal|Failure):|^#\s*Errors:\s*[1-9]' -or -not(Test-Path -LiteralPath $database)) {
        throw "Project register directed test failed: $log"
    }
    [ordered]@{
        Result='PASS'; Cases=[int]$pass.Groups[1].Value; Checks=[int]$pass.Groups[2].Value
        Writes=[int]$pass.Groups[3].Value; Reads=[int]$pass.Groups[4].Value; Transfers=[int]$pass.Groups[5].Value
        RW1CPolicy='hardware set wins simultaneous software clear'
        Simulator='QuestaSim-64 10.7c'; Testbench='standalone SV with AXI SVA'
    } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $results 'summary.json')
    Write-Output $pass.Value
} finally {
    $env:AXI_PROJECT_RESULTS_DIR=$previous
    Pop-Location
}
