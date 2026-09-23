param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk'
)
$ErrorActionPreference='Stop'
$rrRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$rrGame=(Resolve-Path -LiteralPath (Join-Path $rrRoot '../..')).Path
$rrRun=Join-Path $PSScriptRoot '../comparison-batch'
New-Item -ItemType Directory -Path $rrRun -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach($pair in @(@('12.2','partition-preview-v12-2','partition-scale-dev3'),@('12.3','partition-preview-v12-3','partition-mass-dev4'))) {
    $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $rrRoot ('design/'+$pair[1]+'/evidence/'+$pair[2]+'.zip')))
    try { [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('build/style-review/'+$pair[2]+'-new.xml'),(Join-Path $rrRun ('baseline-'+$pair[0]+'.xml')),$true) }
    finally { $zip.Dispose() }
}
$rrSwf=Join-Path $rrRun 'ComparisonBatch.swf'
& $Java '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
    '-jar' (Join-Path $FlexSdk 'lib/mxmlc.jar') ('+flexlib='+(Join-Path $FlexSdk 'frameworks')) `
    ('-load-config='+(Join-Path $rrRoot 'build/rr-config.xml')) '-swf-version=32' '-use-network=false' `
    '-static-link-runtime-shared-libraries=true' ('-source-path+='+$PSScriptRoot) `
    ('-output='+$rrSwf) (Join-Path $PSScriptRoot 'ComparisonBatch.as')
if($LASTEXITCODE -ne 0) { throw 'Comparison compiler failed.' }
$descriptor=Join-Path $rrRun 'comparison-app.xml'
$appId='pferr-style-batch-'+[guid]::NewGuid().ToString('N')
@"
<?xml version="1.0" encoding="UTF-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0"><id>$appId</id><versionNumber>1.0.0</versionNumber><filename>RRComparisonBatch</filename><initialWindow><content>ComparisonBatch.swf</content><visible>false</visible><width>160</width><height>100</height></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>
"@ | Set-Content -LiteralPath $descriptor -Encoding utf8
$instance=$null; $started=[DateTime]::UtcNow
try {
    $instance=Start-Process -FilePath (Join-Path $rrGame 'adl64.exe') -ArgumentList @('-runtime',('"'+(Join-Path $rrGame 'runtimes/air/win64')+'"'),('"'+$descriptor+'"')) -WorkingDirectory $rrRun -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $rrRun 'stdout.txt') -RedirectStandardError (Join-Path $rrRun 'stderr.txt')
    while(-not $instance.WaitForExit(10000)) {
        Get-Content -LiteralPath (Join-Path $rrRun 'progress.txt') -ErrorAction SilentlyContinue
        if(([DateTime]::UtcNow-$started).TotalSeconds -gt 480) { throw 'Comparison batch timeout.' }
    }
    $instance.Refresh()
    $path=Join-Path $rrRun 'results.json'
    if((Get-Item -LiteralPath $path).LastWriteTimeUtc -lt $started) { throw 'Results are stale.' }
    $result=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    [pscustomobject]@{parity=$result.parity;maps=$result.maps;failures=$result.failures.Count} | ConvertTo-Json
    if($instance.ExitCode -ne 0) { throw 'Comparison cases failed; inspect results.json.' }
} finally { if($instance -and -not $instance.HasExited) { Stop-Process -Id $instance.Id } }
