param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk',
    [ValidatePattern('^[a-zA-Z0-9-]+$')][string]$Output = 'partition-prototype-1',
    [ValidateRange(1,16)][int]$Samples = 8
)
$ErrorActionPreference = 'Stop'
$rrRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$rrGame = (Resolve-Path -LiteralPath (Join-Path $rrRoot '../..')).Path
$rrCompiler = Join-Path $FlexSdk 'lib/mxmlc.jar'
$rrSwf = Join-Path $PSScriptRoot 'PartitionPreview.swf'
$rrDescriptor = Join-Path $PSScriptRoot 'partition-preview-app.xml'
foreach ($rrRequired in @($Java,$rrCompiler,$rrDescriptor,(Join-Path $rrGame 'adl64.exe'))) {
    if (-not (Test-Path -LiteralPath $rrRequired)) { throw "Missing: $rrRequired" }
}
@{output=$Output;samples=$Samples} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'partition-settings.json') -Encoding utf8
& $Java '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
    '-jar' $rrCompiler ('+flexlib='+(Join-Path $FlexSdk 'frameworks')) `
    ('-load-config='+(Join-Path $rrRoot 'build/rr-config.xml')) '-swf-version=32' '-use-network=false' `
    '-static-link-runtime-shared-libraries=true' ('-source-path+='+$PSScriptRoot) `
    ('-output='+$rrSwf) (Join-Path $PSScriptRoot 'PartitionPreview.as')
if ($LASTEXITCODE -ne 0) { throw 'Preview compiler failed.' }
$rrProcess = $null
$rrStarted = [DateTime]::UtcNow
try {
    $rrProcess = Start-Process -FilePath (Join-Path $rrGame 'adl64.exe') `
        -ArgumentList @('-runtime',('"'+(Join-Path $rrGame 'runtimes/air/win64')+'"'),('"'+$rrDescriptor+'"')) `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $PSScriptRoot 'adl-partition-out.txt') `
        -RedirectStandardError (Join-Path $PSScriptRoot 'adl-partition-err.txt')
    while (-not $rrProcess.WaitForExit(1000)) {
        if (([DateTime]::UtcNow-$rrStarted).TotalSeconds -gt 300) { throw 'Partition export exceeded 300 seconds.' }
    }
    $rrProcess.Refresh()
    if ($rrProcess.ExitCode -ne 0) { throw "AIR export failed: $($rrProcess.ExitCode)" }
    $rrResults = Join-Path $PSScriptRoot ('../'+$Output+'-results.json')
    if (-not (Test-Path -LiteralPath $rrResults) -or (Get-Item -LiteralPath $rrResults).LastWriteTimeUtc -lt $rrStarted.AddSeconds(-2)) { throw 'No fresh result file.' }
    $rrData = Get-Content -LiteralPath $rrResults -Raw -Encoding utf8 | ConvertFrom-Json
    $rrManifest = [ordered]@{requested=$rrData.requested;newOK=@($rrData.cases | Where-Object {$_.new.ok}).Count;oldOK=@($rrData.cases | Where-Object {$_.old.ok}).Count;repeatChecks=$rrData.repeatChecks;sources=@{};files=@{};utc=[DateTime]::UtcNow.ToString('o')}
    foreach ($rrSource in (Get-ChildItem -LiteralPath (Join-Path $rrRoot 'src/rr') -Filter '*.as')) {
        $rrManifest.sources[$rrSource.Name]=(Get-FileHash -LiteralPath $rrSource.FullName -Algorithm SHA256).Hash
    }
    foreach ($rrSuffix in @('-new.xml','-old.xml','-results.json')) {
        $rrFile = Join-Path $PSScriptRoot ('../'+$Output+$rrSuffix)
        $rrManifest.files[$rrSuffix]=(Get-FileHash -LiteralPath $rrFile -Algorithm SHA256).Hash
    }
    $rrManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot ('../'+$Output+'-manifest.json')) -Encoding utf8
    [pscustomobject]$rrManifest | Select-Object requested,newOK,oldOK,repeatChecks,utc | ConvertTo-Json
}
finally { if ($null -ne $rrProcess -and -not $rrProcess.HasExited) { Stop-Process -Id $rrProcess.Id } }
