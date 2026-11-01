param([string]$OutputDirectory='results/v1.1')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force $destination | Out-Null
Push-Location $root
try {
    $log=Join-Path $destination 'fault_injection_request.log'
    & 'D:/Questasim/win64/vsim.exe' -c -do sim/run_fault_injection_request.do *> $log
    $exitCode=$LASTEXITCODE
    $text=Get-Content -Raw -LiteralPath $log
    $errors=[regex]::Matches($text,'(?m)^#\s*\*\*\s+Error:').Count
    $expected=@('AWADDR/AWVALID changed before AW handshake','WDATA/WSTRB/WVALID changed before W handshake','ARADDR/ARVALID changed before AR handshake')
    if($exitCode -notin @(0,1) -or $errors -ne 3 -or -not $text.Contains('EXPECTED_REQUEST_FAILURE_COMPLETE') -or
       $text -match '(?m)^#\s*\*\*\s+(Fatal|Failure):') { throw "Unexpected fault-injection result: $log" }
    foreach($message in $expected) {
        if([regex]::Matches($text,[regex]::Escape($message)).Count -ne 1) {throw "Missing or repeated assertion: $message"}
    }
    'EXPECTED_FAILURE_VERIFIED assertions=3' | Set-Content -Encoding utf8 (Join-Path $destination 'fault_injection_request_result.txt')
    Write-Output 'EXPECTED_FAILURE_VERIFIED assertions=3'
} finally {Pop-Location}
