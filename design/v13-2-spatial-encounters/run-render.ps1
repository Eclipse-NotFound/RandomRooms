$ErrorActionPreference='Stop'
$rrMod=(Resolve-Path "$PSScriptRoot/../..").Path
$rrGame=(Resolve-Path "$rrMod/../..").Path
$rrApp=Join-Path $rrMod 'build/spatial-v132/render'
$rrSdk='D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk'
$rrJava='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe'
$rrCfg=Join-Path $rrApp 'render-config.xml'
@"
<flex-config><compiler><source-path><path-element>$PSScriptRoot</path-element><path-element>$rrMod/src/editor</path-element><path-element>$rrMod/src/editor/vendor</path-element><path-element>$rrMod/src</path-element></source-path><library-path><path-element>$rrSdk/frameworks/libs/air/airglobal.swc</path-element></library-path><debug>false</debug><optimize>true</optimize><strict>true</strict><fonts><local-fonts-snapshot>$rrSdk/frameworks/localFonts.ser</local-fonts-snapshot></fonts></compiler><target-player>32.0</target-player><swf-version>32</swf-version><use-network>false</use-network><static-link-runtime-shared-libraries>true</static-link-runtime-shared-libraries></flex-config>
"@ | Set-Content -LiteralPath $rrCfg -Encoding utf8
& $rrJava -jar "$rrSdk/lib/mxmlc.jar" -load-config $rrCfg '-theme=' -output "$rrApp/RenderSamples.swf" "$PSScriptRoot/RenderSamples.as"
if($LASTEXITCODE -ne 0) { throw 'Render compilation failed' }
$rrId='pferr-v132-render-'+[Guid]::NewGuid().ToString('N');$rrDescriptor=Join-Path $rrApp 'render-app.xml'
@"
<application xmlns="http://ns.adobe.com/air/application/30.0"><id>$rrId</id><versionNumber>1.0</versionNumber><filename>RR Comparison Render</filename><initialWindow><content>RenderSamples.swf</content><visible>false</visible><width>100</width><height>100</height><renderMode>cpu</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>
"@ | Set-Content -LiteralPath $rrDescriptor -Encoding utf8
$rrProcess=$null;$rrStart=[DateTime]::UtcNow
try {
 $rrProcess=Start-Process -FilePath "$rrGame/adl64.exe" -ArgumentList ('-runtime "{0}" "{1}"' -f "$rrGame/runtimes/air/win64",$rrDescriptor) -WorkingDirectory $rrApp -WindowStyle Hidden -PassThru -RedirectStandardOutput "$rrApp/stdout.txt" -RedirectStandardError "$rrApp/stderr.txt"
 while(!$rrProcess.WaitForExit(10000)) { if(([DateTime]::UtcNow-$rrStart).TotalSeconds -gt 180) { throw 'Render timeout' } }
 $rrProcess.Refresh();$rrResult=Get-Content "$rrApp/results.json" -Raw | ConvertFrom-Json
 if((Get-Item "$rrApp/results.json").LastWriteTimeUtc -lt $rrStart -or $rrProcess.ExitCode -ne 0 -or $rrResult.status -ne 'passed') { throw 'Native rendering failed' }
 New-Item -ItemType Directory -Path "$PSScriptRoot/native" -Force | Out-Null
 foreach($rrImage in Get-ChildItem -LiteralPath "$rrApp/images" -Filter '*.png' -File) {
  Copy-Item -LiteralPath $rrImage.FullName -Destination (Join-Path "$PSScriptRoot/native" $rrImage.Name)
 }
 Copy-Item -LiteralPath "$rrApp/results.json" -Destination "$PSScriptRoot/render-results.json"
 [ordered]@{appId=$rrId;startedUtc=$rrStart.ToString('o');driverSHA256=(Get-FileHash "$rrApp/RenderSamples.swf").Hash;renders=$rrResult.renders.Count} | ConvertTo-Json | Set-Content "$PSScriptRoot/render-execution.json"
 Write-Output "Native images: $($rrResult.renders.Count)"
} finally { if($rrProcess -and !$rrProcess.HasExited) { $rrProcess.Kill() };Remove-Item -LiteralPath $rrDescriptor -ErrorAction SilentlyContinue }
