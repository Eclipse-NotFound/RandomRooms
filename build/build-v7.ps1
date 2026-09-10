param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk',
    [string]$OutputName = 'RandomRooms-v7-dev.swf'
)
$ErrorActionPreference = 'Stop'
$rrModRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ([IO.Path]::GetFileName($OutputName) -ne $OutputName -or -not $OutputName.EndsWith('.swf')) {
    throw 'OutputName must be a .swf leaf filename; this command only builds into build/.'
}
$rrCompiler = Join-Path $FlexSdk 'lib/mxmlc.jar'
foreach ($rrRequired in @($Java, $rrCompiler, (Join-Path $PSScriptRoot 'rr-config.xml'))) {
    if (-not (Test-Path -LiteralPath $rrRequired)) { throw "Missing tool/config: $rrRequired" }
}
$rrOutput = Join-Path $PSScriptRoot $OutputName
& $Java '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
    '-jar' $rrCompiler ('+flexlib=' + (Join-Path $FlexSdk 'frameworks')) `
    ('-load-config=' + (Join-Path $PSScriptRoot 'rr-config.xml')) `
    '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' `
    ('-output=' + $rrOutput) (Join-Path $rrModRoot 'src/RandomRoomsMod.as')
if ($LASTEXITCODE -ne 0) { throw "Compiler failed: $LASTEXITCODE" }
[ordered]@{
    output = $rrOutput
    bytes = (Get-Item -LiteralPath $rrOutput).Length
    sha256 = (Get-FileHash -LiteralPath $rrOutput -Algorithm SHA256).Hash
} | ConvertTo-Json
