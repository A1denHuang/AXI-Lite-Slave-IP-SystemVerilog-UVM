param([string]$OutputDirectory='results/project-regs/mutation')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $destination | Out-Null
$rtl=Get-Content -Raw (Join-Path $root 'rtl/axi_lite_slave_project_regs.v')
$pattern='\(intr_status_reg\[b\*8 \+: 8\] & ~write_data\[b\*8 \+: 8\]\) \|\s*intr_status_set_i\[b\*8 \+: 8\]'
if([regex]::Matches($rtl,$pattern).Count -ne 1){throw 'Expected one set-priority expression'}
$mutant=[regex]::Replace($rtl,$pattern,'(intr_status_reg[b*8 +: 8] | intr_status_set_i[b*8 +: 8]) & ~write_data[b*8 +: 8]')
[System.IO.File]::WriteAllText((Join-Path $destination 'software_clear_priority.v'),$mutant,[System.Text.UTF8Encoding]::new($false))
$previous=$env:AXI_PROJECT_MUTATION_DIR
$env:AXI_PROJECT_MUTATION_DIR=$destination.Replace('\','/')
Push-Location $root
try {
    $log=Join-Path $destination 'software_clear_priority.log'
    & 'D:/Questasim/win64/vsim.exe' -c -do sim/run_project_priority_mutation.do *> $log
    $simExit=$LASTEXITCODE
    $text=Get-Content -Raw $log
    if($simExit -notin @(0,1) -or $text -notmatch 'CASE 6: set wins same-bit conflict' -or
       $text -notmatch '\*\* Fatal: RDATA actual=00000000 expected=00000001' -or
       $text.Contains('PROJECT_REGS_PASS') -or $text -match '(?m)^#\s*\*\*\s+(Error|Failure):') {
        throw "Unexpected mutation-test result: $log"
    }
    'PRIORITY_MUTATION_REJECTED old software-clear priority fails same-bit conflict check' |
        Set-Content -Encoding utf8 (Join-Path $destination 'result.txt')
    Write-Output 'PRIORITY_MUTATION_REJECTED'
} finally {
    $env:AXI_PROJECT_MUTATION_DIR=$previous
    Pop-Location
}
