param([switch]$Run)
$ErrorActionPreference = 'Stop'
$probeDir = $PSScriptRoot
$appDir = Join-Path $probeDir 'probe-app'
$gameRoot = (Resolve-Path (Join-Path $probeDir '../../../..')).Path
$java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe'
$sdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk'
$config = Join-Path $appDir 'probe-config.xml'
$swf = Join-Path $appDir 'PreviewProbe.swf'
$descriptor = Join-Path $appDir 'preview-probe-app.xml'
foreach ($path in @($java, "$sdk/lib/mxmlc.jar", "$sdk/frameworks/libs/air/airglobal.swc", "$appDir/cases.json")) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing $path; run audit.py first." }
}
@"
<flex-config><compiler>
<source-path><path-element>$probeDir</path-element></source-path>
<library-path><path-element>$sdk/frameworks/libs/air/airglobal.swc</path-element></library-path>
<debug>false</debug><optimize>true</optimize><strict>true</strict>
<fonts><local-fonts-snapshot>$sdk/frameworks/localFonts.ser</local-fonts-snapshot></fonts>
</compiler><target-player>32.0</target-player><swf-version>32</swf-version>
<use-network>false</use-network><static-link-runtime-shared-libraries>true</static-link-runtime-shared-libraries>
</flex-config>
"@ | Set-Content -LiteralPath $config -Encoding UTF8
& $java -jar "$sdk/lib/mxmlc.jar" -load-config $config '-theme=' -output $swf "$probeDir/PreviewProbe.as"
if ($LASTEXITCODE -ne 0) { throw "Compiler exit $LASTEXITCODE" }
if (!$Run) { return }
$appId = 'remains-randomrooms-editor-audit-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
@"
<application xmlns="http://ns.adobe.com/air/application/30.0">
<id>$appId</id><versionNumber>1.0</versionNumber><filename>RR Editor Audit</filename>
<initialWindow><content>PreviewProbe.swf</content><visible>false</visible><width>960</width><height>500</height><renderMode>direct</renderMode></initialWindow>
<supportedProfiles>extendedDesktop</supportedProfiles>
</application>
"@ | Set-Content -LiteralPath $descriptor -Encoding UTF8
$process = $null
try {
    $arguments = '-runtime "{0}" "{1}"' -f "$gameRoot/runtimes/air/win64", $descriptor
    $process = Start-Process -FilePath "$gameRoot/adl64.exe" -ArgumentList $arguments -WorkingDirectory $appDir -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(50000)) { throw 'Isolated probe timed out after 50 seconds.' }
    $process.Refresh()
    [ordered]@{appId=$appId; processId=$process.Id; exitCode=$process.ExitCode; finishedUtc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath "$probeDir/probe-execution.json" -Encoding UTF8
    if ($process.ExitCode -ne 0) { throw "Isolated probe exit $($process.ExitCode)" }
    Get-Content -LiteralPath "$probeDir/preview-results.json"
} finally {
    if ($null -ne $process -and !$process.HasExited) { $process.Kill(); $process.WaitForExit(3000) | Out-Null }
    Remove-Item -LiteralPath $descriptor -ErrorAction SilentlyContinue
}
