param([ValidateSet("assemble","test","build","program")][string]$Action="build")
$ErrorActionPreference="Stop"
Set-Location $PSScriptRoot
$yosysPath=(Get-Command yosys -ErrorAction Stop).Source
$suiteRoot=Split-Path (Split-Path $yosysPath)
$env:PATH=(Join-Path $suiteRoot "lib")+";"+$env:PATH
function Run([string]$Tool,[string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool fallo ($LASTEXITCODE)" }
}
New-Item -ItemType Directory -Force build | Out-Null
Run "python" @("tools/assembler.py","sw/game.s","sw/game.hex")
if ($Action -eq "assemble") { exit 0 }
if ($Action -eq "test") {
    Run "python" @("-m","unittest","discover","-s","tests","-v")
    Run "python" @("tests/simulate.py")
    exit 0
}
# Rutas relativas y script .ys: evita comillas anidadas en PowerShell 5.1.
$rtl=@(Get-ChildItem rtl -Filter *.v -Recurse | ForEach-Object {
    $_.FullName.Substring($PSScriptRoot.Length + 1).Replace('\','/')
})
$src=$rtl -join " "
$yosysScript="read_verilog $src; synth_ice40 -top game_top -run begin:map_luts; abc -lut 4; ice40_wrapcarry -unwrap; opt_lut -tech ice40; techmap -map +/ice40/ff_map.v -map +/ice40/cells_map.v; clean; check; stat; blackbox =A:whitebox; write_json build/game.json"
Set-Content -LiteralPath "build/synth.ys" -Value $yosysScript -Encoding ASCII
Run "yosys" @("-Q","-l","build/yosys.log","-s","build/synth.ys")
Run "nextpnr-ice40" @("--hx1k","--package","vq100","--freq","25","--json","build/game.json","--pcf","goboard.pcf","--asc","build/game.asc","--log","build/nextpnr.log")
Run "icepack" @("build/game.asc","build/game.bin")
if ($Action -eq "program") { Run "iceprog" @("build/game.bin") }



