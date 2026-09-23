param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk',
    [string[]]$PrototypeFiles = @('../prototype-a.xml','../prototype-c.xml'),
    [switch]$MovementProbe,
    [switch]$MovementOnly,
    [string]$DevelopmentSwf = '',
    [ValidateSet('app','visual-app')][string]$SessionDirectory = 'app',
    [switch]$CrossingProbe,
    [switch]$ArchitectureKinds,
    [ValidateRange(0,3)][int]$SamplesPerScene = 0,
    [switch]$DevelopmentShaftProbe,
    [switch]$VerticalProbe,
    [switch]$GrowthProbe,
    [switch]$SmokeOnly,
    [switch]$StartupDelay,
    [switch]$FixtureProbe,
    [switch]$FixtureCyclesOnly,
    [switch]$NavigationProbe,
    [switch]$SceneLifecycle,
    [switch]$AllScenes,
    [switch]$WaterProbe,
    [switch]$PopulationProbe,
    [switch]$ContentGallery,
    [ValidateRange(0,50)][int]$PopulationDepth = 0,
    [ValidateSet('','plant','stable','sewer','mane')][string]$Scene = '',
    [ValidateSet('both','random_rooms','rr_showroom')][string]$NavigationLand = 'both',
    [ValidateRange(0,16)][int]$PrototypeSampleCount = 0
)
$ErrorActionPreference = 'Stop'
if ($StartupDelay -and -not $DevelopmentSwf) { throw 'StartupDelay requires DevelopmentSwf.' }
if (($WaterProbe -or ($AllScenes -and $GrowthProbe)) -and -not $NavigationProbe) {
    throw 'Scene water/growth checks require NavigationProbe; the legacy fixed-floor driver cannot follow these rooms.'
}
$modRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$gameRoot = (Resolve-Path -LiteralPath (Join-Path $modRoot '../..')).Path
$appRoot = Join-Path $PSScriptRoot $SessionDirectory
$assetFiles = @('pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf',
    'sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','text_en.xml',
    'Music/mainmenu.mp3','Music/music_base.mp3','Music/music_plant_1.mp3','Music/music_begin.mp3',
    'Music/music_stable_1.mp3','Music/music_sewer_1.mp3','Music/music_mane_1.mp3')
$rooms = @(Get-ChildItem -LiteralPath (Join-Path $gameRoot 'Rooms') -File)
$assetBytes = 0L
foreach ($relative in $assetFiles) { $assetBytes += (Get-Item -LiteralPath (Join-Path $gameRoot $relative)).Length }
$assetBytes += ($rooms | Measure-Object Length -Sum).Sum
Write-Output ('Isolated assets: {0} bytes ({1:N2} MiB)' -f $assetBytes, ($assetBytes / 1MB))
if ($assetBytes -gt 300MB) { throw 'Resource selection exceeds the 300 MiB guard.' }
New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
$captureRoot = Join-Path $appRoot 'captures'
$previousLog = Join-Path $captureRoot 'runner.log'
if (Test-Path -LiteralPath $previousLog) {
    $priorLine = Get-Content -LiteralPath $previousLog -TotalCount 1
    $priorId = ($priorLine -replace '^appId=', '') -replace '[^A-Za-z0-9.-]', '-'
    $archiveRoot = Join-Path $appRoot ('history/' + $priorId + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
    $previousStarted = $null
    $priorManifest = Join-Path $captureRoot 'manifest.json'
    if (Test-Path -LiteralPath $priorManifest) {
        $priorMetadata = Get-Content -LiteralPath $priorManifest -Raw | ConvertFrom-Json
        if ($priorMetadata.startedUtc) { $previousStarted = [DateTime]::Parse($priorMetadata.startedUtc).ToUniversalTime().AddSeconds(-2) }
    }
    foreach ($previous in @(Get-ChildItem -LiteralPath $captureRoot -File | Where-Object { $null -eq $previousStarted -or $_.LastWriteTimeUtc -ge $previousStarted })) {
        Copy-Item -LiteralPath $previous.FullName -Destination (Join-Path $archiveRoot $previous.Name)
    }
    foreach ($previousName in @('cases.xml','stdout.txt','stderr.txt')) {
        $previousPath = Join-Path $appRoot $previousName
        if (Test-Path -LiteralPath $previousPath) { Copy-Item -LiteralPath $previousPath -Destination (Join-Path $archiveRoot $previousName) }
    }
    Write-Output ('Previous capture archived: ' + $archiveRoot)
}
foreach ($relative in $assetFiles) {
    $source = Join-Path $gameRoot $relative
    $destination = Join-Path $appRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destination) -or (Get-Item -LiteralPath $destination).Length -ne (Get-Item -LiteralPath $source).Length -or
        ($relative -eq 'pfe.swf' -and (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash)) {
        Copy-Item -LiteralPath $source -Destination $destination
    }
}
New-Item -ItemType Directory -Path (Join-Path $appRoot 'Rooms') -Force | Out-Null
foreach ($roomFile in $rooms) { Copy-Item -LiteralPath $roomFile.FullName -Destination (Join-Path $appRoot ('Rooms/' + $roomFile.Name)) }

[xml]$authorPool = Get-Content -LiteralPath (Join-Path $gameRoot 'Rooms/rooms_stable.xml') -Raw
[xml]$baseline = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../baseline-v66.xml') -Raw
[xml]$caseDoc = '<cases/>'
$caseDoc.DocumentElement.SetAttribute('movement', $MovementProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('crossing', $CrossingProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('shaft', ($DevelopmentShaftProbe.IsPresent -or $VerticalProbe.IsPresent).ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('growth', $GrowthProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('startupDelay', $StartupDelay.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('fixtures', ($FixtureProbe.IsPresent -or $FixtureCyclesOnly.IsPresent).ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('fixtureCyclesOnly', $FixtureCyclesOnly.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('navigation', $NavigationProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('sceneLifecycle', $SceneLifecycle.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('waterProbe', $WaterProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('population', $PopulationProbe.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('contentGallery', $ContentGallery.IsPresent.ToString().ToLowerInvariant())
$caseDoc.DocumentElement.SetAttribute('populationDepth', $PopulationDepth.ToString())
$sourceHashes = [ordered]@{
    'Rooms/rooms_stable.xml' = (Get-FileHash -LiteralPath (Join-Path $gameRoot 'Rooms/rooms_stable.xml') -Algorithm SHA256).Hash
    'baseline-v66.xml' = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot '../baseline-v66.xml') -Algorithm SHA256).Hash
}
$caseSources = @(
    @{ id = 'rrstyle-original'; room = $authorPool.all.room[0] },
    @{ id = 'rrstyle-baseline'; room = $baseline.baseline.room[0] }
)
foreach ($prototypeFile in $PrototypeFiles) {
    $prototypePath = if ([IO.Path]::IsPathRooted($prototypeFile)) { $prototypeFile } else { Join-Path $PSScriptRoot $prototypeFile }
    if (Test-Path -LiteralPath $prototypePath) {
        [xml]$prototype = Get-Content -LiteralPath $prototypePath -Raw
        $prototypeRooms = @($prototype.SelectNodes('/*/room'))
        if ($prototypeRooms.Count -eq 0) { throw "No room in prototype: $prototypePath" }
        if ($VerticalProbe) { $prototypeRooms = @($prototypeRooms | Where-Object { $_.rrKind -eq 'connector' }) }
        if ($SamplesPerScene -gt 0) {
            $selectedRooms = @()
            foreach ($scene in @('plant','stable','sewer','mane')) {
                $sceneRooms = @($prototypeRooms | Where-Object { $_.rrTheme -eq $scene })
                $forms = @($sceneRooms | Group-Object rrForm | ForEach-Object { $_.Group[0] } | Select-Object -First $SamplesPerScene)
                if ($forms.Count -ne $SamplesPerScene) { throw "Not enough distinct forms for scene $scene" }
                $selectedRooms += $forms
            }
            $prototypeRooms = $selectedRooms
        }
        if ($ArchitectureKinds) {
            $selectedRooms = @()
            $wantedKinds = @('atrium','workshop','offices','damaged','service','warehouse')
            $wantedThemes = @('stable','plant','mane','sewer','stable','sewer')
            for ($kindIndex = 0; $kindIndex -lt $wantedKinds.Count; $kindIndex++) {
                $kindMatches = @($prototypeRooms | Where-Object { $_.rrKind -eq $wantedKinds[$kindIndex] })
                $themeMatches = @($kindMatches | Where-Object { $_.rrTheme -eq $wantedThemes[$kindIndex] })
                if ($kindMatches.Count -eq 0) { throw ('Missing architecture kind: ' + $wantedKinds[$kindIndex]) }
                $selectedRooms += if ($themeMatches.Count -gt 0) { $themeMatches[0] } else { $kindMatches[0] }
            }
            $prototypeRooms = $selectedRooms
        }
        $prototypeName = [IO.Path]::GetFileNameWithoutExtension($prototypePath)
        $sourceHashes[([IO.Path]::GetFileName($prototypePath))] = (Get-FileHash -LiteralPath $prototypePath -Algorithm SHA256).Hash
        $take = if ($prototypeName -eq 'prototype-c') { [Math]::Min(2, $prototypeRooms.Count) } else { 1 }
        if ($PrototypeSampleCount -gt 0) { $take = [Math]::Min($PrototypeSampleCount, $prototypeRooms.Count) }
        if ($ArchitectureKinds) { $take = $prototypeRooms.Count }
        if ($SamplesPerScene -gt 0) { $take = $prototypeRooms.Count }
        if ($VerticalProbe) { $take = [Math]::Min(2,$prototypeRooms.Count) }
        for ($sample = 0; $sample -lt $take; $sample++) {
            $suffix = if ($take -gt 1) { '-' + $sample } else { '' }
            $caseSources += @{ id = 'rrstyle-' + $prototypeName + $suffix; room = $prototypeRooms[$sample]; prototype=$true }
        }
    }
}
if ($MovementOnly -or $FixtureProbe -or $FixtureCyclesOnly -or $SamplesPerScene -gt 0) { $caseSources = @($caseSources | Where-Object { $_.prototype }) }
if ($CrossingProbe -or $VerticalProbe) {
    if ($MovementProbe -or $DevelopmentSwf) { throw 'Run crossing as a separate probe.' }
    $crossSources = @($caseSources | Where-Object { $_.prototype })
    if ($crossSources.Count -lt 2) { throw 'Crossing requires at least two prototype rooms.' }
    $caseSources = @()
    $crossCount = if ($ArchitectureKinds) { $crossSources.Count } else { 1 }
    for ($crossIndex=0; $crossIndex -lt $crossCount; $crossIndex++) {
        $crossId = if ($VerticalProbe) { 'rrstyle-vertical' } elseif ($ArchitectureKinds) { 'rrstyle-crossing-' + $crossSources[$crossIndex].room.rrKind } else { 'rrstyle-crossing' }
        $caseSources += @{id=$crossId;room=$crossSources[$crossIndex].room;neighbor=$crossSources[($crossIndex+1)%$crossSources.Count].room;prototype=$true}
    }
}
if ($DevelopmentSwf) {
    if ($MovementProbe) { throw 'Run complete-mod travel and fixed-room movement as separate probes.' }
    $developmentPath = (Resolve-Path -LiteralPath $DevelopmentSwf).Path
    New-Item -ItemType Directory -Path (Join-Path $appRoot 'development') -Force | Out-Null
    Copy-Item -LiteralPath $developmentPath -Destination (Join-Path $appRoot 'development/RandomRoomsMod.swf')
    $sourceHashes['development/RandomRoomsMod.swf'] = (Get-FileHash -LiteralPath $developmentPath -Algorithm SHA256).Hash
    $caseDoc.DocumentElement.SetAttribute('development','true')
    $caseSources = @(@{id='rrstyle-f5';landId='rr_showroom'},@{id='rrstyle-f5-refresh';landId='rr_showroom'},@{id='rrstyle-f1';landId='random_rooms'},@{id='rrstyle-f1-refresh';landId='random_rooms'})
    if ($SmokeOnly) { $caseSources = @(@{id='rrstyle-smoke-f5';landId='rr_showroom'},@{id='rrstyle-smoke-f1';landId='random_rooms'}) }
    if ($DevelopmentShaftProbe) { $caseSources = @(@{id='rrstyle-f5-shaft';landId='rr_showroom'}) }
    if ($GrowthProbe) { $caseSources = @(@{id='rrstyle-growth';landId='random_rooms'}) }
    if ($NavigationProbe -and $NavigationLand -ne 'both') { $caseSources = @($caseSources | Where-Object { $_.landId -eq $NavigationLand }) }
    if ($AllScenes) {
        $caseSources = @()
        foreach ($theme in @('plant','stable','sewer','mane')) {
            $caseSources += @{id=('rrstyle-' + $(if ($GrowthProbe) {'growth'} else {'navigation'}) + '-' + $theme);landId='random_rooms';scene=$theme}
        }
    }
    if ($WaterProbe) { $caseSources=@(@{id='rrstyle-water-sewer';landId='random_rooms';scene='sewer'}) }
    if ($SceneLifecycle) {
        $caseSources = @()
        foreach ($theme in @('plant','stable','sewer','mane','random')) {
            $caseSources += @{id=('rrstyle-scene-' + $theme);landId='random_rooms';scene=$theme;action='pick'}
            $caseSources += @{id=('rrstyle-deeper-' + $theme);landId='random_rooms';scene=$theme;action='deeper'}
        }
        foreach ($theme in @('sewer','mane')) {
            $caseSources += @{id=('rrstyle-show-' + $theme);landId='rr_showroom';scene=$theme;action='pick'}
        }
    }
}
foreach ($caseSource in $caseSources) {
    $case = $caseDoc.CreateElement('case')
    $case.SetAttribute('id', $caseSource.id)
    if ($DevelopmentSwf) {
        $case.SetAttribute('landId',$caseSource.landId)
        $case.SetAttribute('scene',$(if ($caseSource.scene) { $caseSource.scene } else { $Scene }))
        if ($caseSource.action) { $case.SetAttribute('action',$caseSource.action) }
        $caseDoc.DocumentElement.AppendChild($case) | Out-Null
        continue
    }
    if ($MovementProbe -and $caseSource.prototype) { $case.SetAttribute('move','true') }
    $room = $caseDoc.ImportNode($caseSource.room, $true)
    $options = $room.SelectSingleNode('options')
    if ($null -eq $options) { $options = $caseDoc.CreateElement('options'); $room.AppendChild($options) | Out-Null }
    $options.SetAttribute('tip','beg0')
    $options.SetAttribute('entip','0')
    $options.SetAttribute('kolspawn','0')
    foreach ($enemy in @($room.SelectNodes("obj[starts-with(@id,'en')]"))) { $room.RemoveChild($enemy) | Out-Null }
    $case.AppendChild($room) | Out-Null
    if ($CrossingProbe -or $VerticalProbe) {
        $neighbor = $caseDoc.ImportNode($caseSource.neighbor,$true)
        $neighborOptions = $neighbor.SelectSingleNode('options')
        if ($null -eq $neighborOptions) { $neighborOptions = $caseDoc.CreateElement('options'); $neighbor.AppendChild($neighborOptions) | Out-Null }
        $neighborOptions.RemoveAttribute('tip')
        $neighborOptions.RemoveAttribute('nornd')
        $neighborOptions.SetAttribute('entip','0')
        $neighborOptions.SetAttribute('kolspawn','0')
        foreach ($enemy in @($neighbor.SelectNodes("obj[starts-with(@id,'en')]"))) { $neighbor.RemoveChild($enemy) | Out-Null }
        $neighborNode = $caseDoc.CreateElement('neighbor')
        $neighborNode.AppendChild($neighbor) | Out-Null
        $case.AppendChild($neighborNode) | Out-Null
    }
    $caseDoc.DocumentElement.AppendChild($case) | Out-Null
}
$caseDoc.Save((Join-Path $appRoot 'cases.xml'))

$testOutput = Join-Path $appRoot 'mods/RandomRooms/release/RandomRoomsMod.swf'
New-Item -ItemType Directory -Path (Split-Path -Parent $testOutput) -Force | Out-Null
$entrySource = 'RandomRoomsMod.as'
$windowContent = 'pfe.swf'
$driverSlot = Join-Path $appRoot 'mods/TDFC/release/TDFCMod.swf'
if ($DevelopmentSwf) {
    if (Test-Path -LiteralPath $testOutput) { Remove-Item -LiteralPath $testOutput }
    $testOutput = $driverSlot
    New-Item -ItemType Directory -Path (Split-Path -Parent $testOutput) -Force | Out-Null
    $entrySource = 'TDFCMod.as'
} elseif (Test-Path -LiteralPath $driverSlot) {
    Remove-Item -LiteralPath $driverSlot
}
& $Java '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
    '-jar' (Join-Path $FlexSdk 'lib/mxmlc.jar') ('+flexlib=' + (Join-Path $FlexSdk 'frameworks')) `
    ('-load-config=' + (Join-Path $modRoot 'build/rr-config.xml')) `
    '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' `
    ('-source-path=' + $PSScriptRoot) ('-output=' + $testOutput) (Join-Path $PSScriptRoot $entrySource)
if ($LASTEXITCODE -ne 0) { throw "Compiler failed: $LASTEXITCODE" }

# Current hosts discover entries through mods/loader-manifest.txt. This file
# belongs only to the isolated app; never copy/enable the user's whole mod set.
# Older embedded-loader hosts simply ignore this additional test-local file.
$testLoaderManifest = Join-Path $appRoot 'mods/loader-manifest.txt'
$testLoaderEntry = if ($DevelopmentSwf) { 'TDFC|TDFCMod|1|0|0' } else { 'RandomRooms|RandomRoomsMod|1|0|0' }
Set-Content -LiteralPath $testLoaderManifest -Value $testLoaderEntry -Encoding utf8
$sourceHashes['test-local/loader-manifest.txt'] = (Get-FileHash -LiteralPath $testLoaderManifest -Algorithm SHA256).Hash

$appId = 'pferr-style-' + [guid]::NewGuid().ToString('N')
$descriptor = Join-Path $appRoot 'style-capture-app.xml'
$descriptorText = @"
<?xml version="1.0" encoding="UTF-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
  <id>$appId</id><versionNumber>1.0.0</versionNumber><filename>RandomRoomsStyleCapture</filename>
  <initialWindow><content>$windowContent</content><visible>false</visible><width>1024</width><height>768</height><renderMode>cpu</renderMode></initialWindow>
  <supportedProfiles>extendedDesktop</supportedProfiles>
</application>
"@
Set-Content -LiteralPath $descriptor -Value $descriptorText -Encoding utf8
$instance = $null
try {
    $runStarted = [DateTime]::UtcNow
    New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
    $manifestPath = Join-Path $captureRoot 'manifest.json'
    [ordered]@{appId=$appId; status='running'; startedUtc=$runStarted.ToString('o'); sourceSha256=$sourceHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    $runtime = Join-Path $gameRoot 'runtimes/air/win64'
    $instance = Start-Process -FilePath (Join-Path $gameRoot 'adl64.exe') `
        -ArgumentList @('-runtime', ('"' + $runtime + '"'), ('"' + $descriptor + '"')) `
        -WorkingDirectory $appRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $appRoot 'stdout.txt') -RedirectStandardError (Join-Path $appRoot 'stderr.txt')
    $elapsed = 0
    while (-not $instance.WaitForExit(1000)) {
        $elapsed++
        if ($elapsed % 10 -eq 0) { Write-Output ('Capture process running: ' + $elapsed + 's; PID ' + $instance.Id) }
        if ($elapsed % 10 -eq 0) {
            $bootOutput = Get-Content -LiteralPath (Join-Path $appRoot 'stdout.txt') -Raw -ErrorAction SilentlyContinue
            if ($bootOutput -match 'ModLoader\[err_loader\].*manifest') { throw 'Test-local loader manifest could not be loaded.' }
        }
        $timeout = if ($NavigationProbe) { if ($AllScenes) {1860} else {960} } elseif ($DevelopmentSwf -or $ArchitectureKinds) { 360 } elseif ($MovementProbe -or $CrossingProbe -or $VerticalProbe) { 240 } else { [Math]::Max(120,75+25*$caseSources.Count) }
        if ($elapsed -ge $timeout) { throw ('Capture process exceeded ' + $timeout + ' second timeout.') }
    }
    $instance.Refresh()
    if ($instance.ExitCode -ne 0) { throw "AIR returned $($instance.ExitCode); inspect app/captures/runner.log and app/stdout.txt" }
    if ((Get-Item -LiteralPath (Join-Path $captureRoot 'runner.log')).LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) { throw 'Runner log predates this capture run.' }
    $runLog = Get-Content -LiteralPath (Join-Path $captureRoot 'runner.log') -Raw
    if ($runLog.Contains('FAIL') -or -not $runLog.Contains('DONE ' + $caseSources.Count + ' cases')) { throw 'Driver did not complete every case.' }
    $imageHashes = [ordered]@{}
    foreach ($caseSource in $caseSources) {
        foreach ($kind in @('stage','room')) {
            $imageName = $caseSource.id + '-' + $kind + '.png'
            $imagePath = Join-Path $captureRoot $imageName
            $imageInfo = Get-Item -LiteralPath $imagePath
            if ($imageInfo.Length -eq 0 -or $imageInfo.LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) { throw "Capture absent or stale: $imageName" }
            $imageHashes[$imageName] = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash
        }
    }
    $hostHash = (Get-FileHash -LiteralPath (Join-Path $gameRoot 'pfe.swf') -Algorithm SHA256).Hash
    $copiedHostHash = (Get-FileHash -LiteralPath (Join-Path $appRoot 'pfe.swf') -Algorithm SHA256).Hash
    if ($hostHash -ne $copiedHostHash) { throw 'Copied host differs from original host.' }
    $runtimeArtifacts = [ordered]@{}
    $topologySummaries = @()
    if ($DevelopmentSwf) {
        foreach ($caseSource in $caseSources) {
            foreach ($suffix in @('-pool.xml','-layout.xml','-topology.json')) {
                $artifactName = $caseSource.id + $suffix
                $artifactPath = Join-Path $captureRoot $artifactName
                if ((Get-Item -LiteralPath $artifactPath).LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) { throw "Runtime artifact stale: $artifactName" }
                $runtimeArtifacts[$artifactName] = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
            }
            $topology = Get-Content -LiteralPath (Join-Path $captureRoot ($caseSource.id + '-topology.json')) -Raw | ConvertFrom-Json
            $topologySummaries += [ordered]@{case=$caseSource.id;poolRooms=$topology.poolRooms;generatedPoolRooms=$topology.generatedPoolRooms;themeCounts=$topology.themeCounts;issues=$topology.issues}
        }
    }
    foreach ($fresh in @(Get-ChildItem -LiteralPath $captureRoot -File | Where-Object { $_.LastWriteTimeUtc -ge $runStarted.AddSeconds(-2) -and $_.Name -ne 'manifest.json' })) {
        if ($fresh.Extension -eq '.png') { $imageHashes[$fresh.Name] = (Get-FileHash -LiteralPath $fresh.FullName -Algorithm SHA256).Hash }
        elseif ($fresh.Name -ne 'runner.log') { $runtimeArtifacts[$fresh.Name] = (Get-FileHash -LiteralPath $fresh.FullName -Algorithm SHA256).Hash }
    }
    $movementResults = @()
    if ($PopulationProbe) {
        foreach ($caseSource in $caseSources) {
            $population = Get-Content -LiteralPath (Join-Path $captureRoot ($caseSource.id + '-population.json')) -Raw | ConvertFrom-Json
            if (-not $population.passed) { throw ('Native population failed: ' + $caseSource.id) }
        }
    }
    $navigationResults = @()
    if ($NavigationProbe) {
        foreach ($caseSource in $caseSources) {
            $nav = Get-Content -LiteralPath (Join-Path $captureRoot ($caseSource.id + '-navigation.json')) -Raw | ConvertFrom-Json
            if (-not $nav.success) { throw ('Native navigation failed: ' + $caseSource.id) }
            $navigationResults += [ordered]@{case=$caseSource.id;success=$nav.success;completed=$nav.completed;targets=$nav.targets;frames=$nav.frames;milestones=$nav.milestones}
        }
    }
    if (-not $NavigationProbe -and -not $FixtureCyclesOnly -and ($MovementProbe -or $CrossingProbe -or $DevelopmentShaftProbe -or $VerticalProbe -or $GrowthProbe -or $FixtureProbe)) {
        $movementResults = @(Get-Content -LiteralPath (Join-Path $captureRoot 'movement.json') -Raw | ConvertFrom-Json)
    }
    [ordered]@{
        appId=$appId; status='complete'; startedUtc=$runStarted.ToString('o'); completedUtc=[DateTime]::UtcNow.ToString('o')
        exitCode=$instance.ExitCode; failed=$false; done=$true
        cases=@($caseSources | ForEach-Object { $_.id }); roomIds=@($caseSources | ForEach-Object { $_.room.name })
        stageSize=@(1008,729); roomSize=@(1920,1000); fullRoomLightOverlay=$false
        sourceSha256=$sourceHashes; hostSha256=$hostHash
        navigationProbe=$NavigationProbe.IsPresent
        populationProbe=$PopulationProbe.IsPresent
        movementProbe=$MovementProbe.IsPresent
        crossingProbe=$CrossingProbe.IsPresent
        verticalProbe=$VerticalProbe.IsPresent
        growthProbe=$GrowthProbe.IsPresent
        fixtureProbe=$FixtureProbe.IsPresent
        fixtureCyclesOnly=$FixtureCyclesOnly.IsPresent
        startupDelay=$StartupDelay.IsPresent
        hitProtection=($GrowthProbe.IsPresent -or $NavigationProbe.IsPresent)
        physicalPass= if ($NavigationProbe) { $true } elseif ($movementResults.Count -gt 0) { @($movementResults | Where-Object { -not $_.success }).Count -eq 0 } else { $null }
        developmentSwf=$DevelopmentSwf
        runtimeArtifacts=$runtimeArtifacts
        topology=$topologySummaries
        movement=$movementResults
        navigation=$navigationResults
        casesSha256=(Get-FileHash -LiteralPath (Join-Path $appRoot 'cases.xml') -Algorithm SHA256).Hash
        driverSha256=(Get-FileHash -LiteralPath $testOutput -Algorithm SHA256).Hash
        runnerLogSha256=(Get-FileHash -LiteralPath (Join-Path $captureRoot 'runner.log') -Algorithm SHA256).Hash
        captured=$imageHashes
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Get-ChildItem -LiteralPath (Join-Path $appRoot 'captures') -File | Where-Object { $_.LastWriteTimeUtc -ge $runStarted.AddSeconds(-2) } | Select-Object Name,Length
}
catch {
    if ($null -ne $manifestPath) {
        [ordered]@{appId=$appId;status='failed';startedUtc=$runStarted.ToString('o');error=$_.Exception.Message;sourceSha256=$sourceHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    }
    throw
}
finally {
    if ($null -ne $instance -and -not $instance.HasExited) { Stop-Process -Id $instance.Id }
    if (Test-Path -LiteralPath $descriptor) { Remove-Item -LiteralPath $descriptor }
}
