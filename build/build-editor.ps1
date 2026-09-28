param(
    [string]$Java='D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk='D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk'
)
$ErrorActionPreference='Stop'
$rrRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rrGame=(Resolve-Path (Join-Path $rrRoot '../..')).Path
$rrOut=Join-Path $PSScriptRoot 'editor'
New-Item -ItemType Directory -Path $rrOut -Force | Out-Null
foreach($job in @(@('RandomRoomsEditor',"$rrRoot/src/editor","$rrRoot/src/editor/vendor","$rrRoot/src/editor/RandomRoomsEditor.as"),@('EditorTools',"$rrRoot/src/editor/bridge","$rrGame/Editor/Enhancements/src","$rrRoot/src/editor/bridge/EditorTools.as"))) {
    $rrCfg=Join-Path $rrOut ($job[0]+'-config.xml')
    @"
<flex-config><compiler><source-path><path-element>$($job[1])</path-element><path-element>$($job[2])</path-element><path-element>$rrRoot/src</path-element></source-path><library-path><path-element>$FlexSdk/frameworks/libs/air/airglobal.swc</path-element></library-path><debug>false</debug><optimize>true</optimize><strict>true</strict><fonts><local-fonts-snapshot>$FlexSdk/frameworks/localFonts.ser</local-fonts-snapshot></fonts></compiler><target-player>32.0</target-player><swf-version>32</swf-version><use-network>false</use-network><static-link-runtime-shared-libraries>true</static-link-runtime-shared-libraries></flex-config>
"@ | Set-Content -LiteralPath $rrCfg -Encoding utf8
    & $Java -jar "$FlexSdk/lib/mxmlc.jar" -load-config $rrCfg '-theme=' ('-output='+$rrOut+'/'+$job[0]+'.swf') $job[3]
    if($LASTEXITCODE -ne 0) { throw ('Compiler failed: '+$job[0]) }
    Get-FileHash -LiteralPath ($rrOut+'/'+$job[0]+'.swf') -Algorithm SHA256
}
