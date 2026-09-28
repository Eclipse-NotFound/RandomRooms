param([switch]$Run)
$ErrorActionPreference='Stop'
$rrHere=$PSScriptRoot
$rrApp=Join-Path $rrHere 'probe-app'
$rrMod=(Resolve-Path "$rrHere/../..").Path
$rrGame=(Resolve-Path "$rrMod/../..").Path
$rrJava='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe'
$rrSdk='D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk'
$rrCfg=Join-Path $rrApp 'probe-config.xml'
@"
<flex-config><compiler><source-path><path-element>$rrHere</path-element><path-element>$rrMod/src/editor/vendor</path-element></source-path><library-path><path-element>$rrSdk/frameworks/libs/air/airglobal.swc</path-element></library-path><debug>true</debug><optimize>true</optimize><strict>true</strict><fonts><local-fonts-snapshot>$rrSdk/frameworks/localFonts.ser</local-fonts-snapshot></fonts></compiler><target-player>32.0</target-player><swf-version>32</swf-version><use-network>false</use-network><static-link-runtime-shared-libraries>true</static-link-runtime-shared-libraries></flex-config>
"@ | Set-Content -LiteralPath $rrCfg -Encoding utf8
& $rrJava -jar "$rrSdk/lib/mxmlc.jar" -load-config $rrCfg '-theme=' -output "$rrApp/EditorRuntimeProbe.swf" "$rrHere/EditorRuntimeProbe.as"
if($LASTEXITCODE -ne 0) { throw 'Editor probe compile failed' }
if(!$Run) { return }
$rrId='pferr-editor-review-'+[Guid]::NewGuid().ToString('N')
$rrDescriptor=Join-Path $rrApp 'probe-app.xml'
@"
<application xmlns="http://ns.adobe.com/air/application/30.0"><id>$rrId</id><versionNumber>1.0</versionNumber><filename>RR Editor Review Test</filename><initialWindow><content>EditorRuntimeProbe.swf</content><visible>false</visible><width>1800</width><height>950</height><renderMode>cpu</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>
"@ | Set-Content -LiteralPath $rrDescriptor -Encoding utf8
$rrProcess=$null;$rrStart=[DateTime]::UtcNow
try {
    $rrArgs='-runtime "{0}" "{1}"' -f "$rrGame/runtimes/air/win64",$rrDescriptor
    $rrProcess=Start-Process -FilePath "$rrGame/adl64.exe" -ArgumentList $rrArgs -WorkingDirectory $rrApp -WindowStyle Hidden -PassThru -RedirectStandardOutput "$rrApp/stdout.txt" -RedirectStandardError "$rrApp/stderr.txt"
    while(!$rrProcess.WaitForExit(10000)) { if(([DateTime]::UtcNow-$rrStart).TotalSeconds -gt 95) { throw 'Editor probe timed out' } }
    $rrProcess.Refresh()
    [ordered]@{appId=$rrId;exitCode=$rrProcess.ExitCode;startedUtc=$rrStart.ToString('o');completedUtc=[DateTime]::UtcNow.ToString('o');driverSHA256=(Get-FileHash "$rrApp/EditorRuntimeProbe.swf").Hash} | ConvertTo-Json | Set-Content -LiteralPath "$rrHere/execution.json" -Encoding utf8
    $rrResult=Get-Content "$rrHere/results.json" -Raw | ConvertFrom-Json
    [ordered]@{status=$rrResult.status;cases=$rrResult.cases.Count;checks=$rrResult.checks;error=$rrResult.error} | ConvertTo-Json
    if($rrProcess.ExitCode -ne 0 -or $rrResult.status -ne 'passed') { throw 'Editor runtime validation failed' }
} finally { if($rrProcess -and !$rrProcess.HasExited) { $rrProcess.Kill() };Remove-Item -LiteralPath $rrDescriptor -ErrorAction SilentlyContinue }
