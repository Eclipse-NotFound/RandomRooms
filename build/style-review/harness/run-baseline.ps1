param(
    [string]$Java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe',
    [string]$FlexSdk = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk',
    [string]$OutputName = 'generated-current.xml',
    [string]$VersionTag = 'RRSynth-current',
    [ValidateRange(1,256)][int]$SamplesPerBiome = 8,
    [uint32]$BaseSeed = 20260910,
    [ValidateRange(0,8)][int]$CookCopies = 0,
    [ValidateRange(0,12)][int]$MapSize = 0,
    [ValidateRange(0,50)][int]$PopulationDepth = 0,
    [ValidateSet('','atrium','workshop','offices','damaged','service','warehouse','connector')][string]$RoomKind = ''
)
$ErrorActionPreference = 'Stop'
$modRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$gameRoot = (Resolve-Path -LiteralPath (Join-Path $modRoot '../..')).Path
$compiler = Join-Path $FlexSdk 'lib/mxmlc.jar'
$adl = Join-Path $gameRoot 'adl64.exe'
$runtime = Join-Path $gameRoot 'runtimes/air/win64'
$descriptor = Join-Path $PSScriptRoot 'synth-baseline-app.xml'
$output = Join-Path $PSScriptRoot 'SynthBaseline.swf'
if ([IO.Path]::GetFileName($OutputName) -ne $OutputName -or -not $OutputName.EndsWith('.xml')) { throw 'OutputName must be an XML leaf filename.' }
$outputStem = [IO.Path]::GetFileNameWithoutExtension($OutputName)
[ordered]@{outputName=$OutputName;versionTag=$VersionTag;samplesPerBiome=$SamplesPerBiome;baseSeed=$BaseSeed;cookCopies=$CookCopies;roomKind=$RoomKind;mapSize=$MapSize;populationDepth=$PopulationDepth} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'harness-settings.json') -Encoding utf8
foreach ($required in @($Java, $compiler, $adl, $runtime, $descriptor)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing: $required" }
}

& $Java '-Xmx384m' '-Dsun.io.useCanonCaches=false' '-Djava.util.Arrays.useLegacyMergeSort=true' `
    '-jar' $compiler ('+flexlib=' + (Join-Path $FlexSdk 'frameworks')) `
    ('-load-config=' + (Join-Path $modRoot 'build/rr-config.xml')) `
    '-swf-version=32' '-use-network=false' '-static-link-runtime-shared-libraries=true' `
    ('-source-path+=' + $PSScriptRoot) ('-output=' + $output) (Join-Path $PSScriptRoot 'SynthBaseline.as')
if ($LASTEXITCODE -ne 0) { throw "Compiler failed: $LASTEXITCODE" }

$instance = $null
try {
    $runStarted = [DateTime]::UtcNow
    $instance = Start-Process -FilePath $adl -ArgumentList @('-runtime', ('"' + $runtime + '"'), ('"' + $descriptor + '"')) `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $PSScriptRoot 'adl-stdout.txt') `
        -RedirectStandardError (Join-Path $PSScriptRoot 'adl-stderr.txt')
    if (-not $instance.WaitForExit(60000)) { throw 'Generator exceeded 60 second timeout.' }
    $instance.Refresh()
    if ($instance.ExitCode -ne 0) { throw "AIR failed: $($instance.ExitCode)" }
    $xmlPath = Join-Path $PSScriptRoot ('../' + $OutputName)
    if (-not (Test-Path -LiteralPath $xmlPath)) { throw 'AIR returned without baseline XML.' }
    if ((Get-Item -LiteralPath $xmlPath).LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) {
        throw 'Baseline XML predates this run.'
    }
    [xml]$baseline = Get-Content -LiteralPath $xmlPath -Raw
    if ($baseline.baseline.room.Count -ne (4 * $SamplesPerBiome)) { throw ('Expected ' + (4 * $SamplesPerBiome) + ' generated rooms.') }
    $roomChecks = @()
    foreach ($room in $baseline.baseline.room) {
        $bottom = ([string]$room.a[-1]).Split('.')
        $openColumns = @()
        for ($x = 0; $x -lt $bottom.Length; $x++) {
            if ($bottom[$x].StartsWith('_')) { $openColumns += $x }
        }
        $roomChecks += [ordered]@{
            room = $room.name
            biome = $room.harnessBiome
            rows = $room.a.Count
            rowWidths = @($room.a | ForEach-Object { ([string]$_).Split('.').Length } | Sort-Object -Unique)
            validate = $room.harnessValid -eq 'true'
            generator = $room.rrGen
            theme = $room.rrTheme
            kind = $room.rrKind
            doorsCount = ([string]$room.doors).Split('.').Length
            bottomOpenColumns = $openColumns
        }
    }
    $manifest = [ordered]@{
        baseline = (Resolve-Path -LiteralPath $xmlPath).Path
        rooms = $baseline.baseline.room.Count
        outputSha256 = (Get-FileHash -LiteralPath $xmlPath -Algorithm SHA256).Hash
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        sources = @{}
        roomChecks = $roomChecks
        versionTag = $VersionTag
        cookCopies = $CookCopies
    }
    foreach ($source in @('rr/RRSynth.as', 'rr/RRGrammar.as', 'rr/RRSeed.as','rr/RRCook.as','rr/RRArchitecture.as','rr/RRFurnish.as','rr/RRPorts.as','rr/RRTraversal.as','rr/RRMapPlan.as','rr/RRScene.as','rr/RRPopulation.as','rr/RREcology.as')) {
        if (-not (Test-Path -LiteralPath (Join-Path $modRoot ('src/' + $source)))) { continue }
        $manifest.sources[$source] = (Get-FileHash -LiteralPath (Join-Path $modRoot ('src/' + $source)) -Algorithm SHA256).Hash
    }
    if ($MapSize -gt 0) {
        $mapPath = Join-Path $PSScriptRoot ('../' + $outputStem + '-map.xml')
        if ((Get-Item -LiteralPath $mapPath).LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) { throw 'Map XML predates this run.' }
        $manifest.map = [ordered]@{path=(Resolve-Path -LiteralPath $mapPath).Path; size=$MapSize;
            sha256=(Get-FileHash -LiteralPath $mapPath -Algorithm SHA256).Hash}
    }
    if ($CookCopies -gt 0) {
        $cookedPath = Join-Path $PSScriptRoot ('../' + $outputStem + '-cooked.xml')
        if ((Get-Item -LiteralPath $cookedPath).LastWriteTimeUtc -lt $runStarted.AddSeconds(-2)) { throw 'Cooked XML predates this run.' }
        [xml]$cookedPool = Get-Content -LiteralPath $cookedPath -Raw
        $cookedChecks = @()
        foreach ($cookedRoom in $cookedPool.all.room) {
            $bottom = ([string]$cookedRoom.a[-1]).Split('.')
            $openColumns = @()
            for ($x = 0; $x -lt $bottom.Length; $x++) { if ($bottom[$x].StartsWith('_')) { $openColumns += $x } }
            $cookedChecks += [ordered]@{
                room=$cookedRoom.name; rows=$cookedRoom.a.Count
                rowWidths=@($cookedRoom.a | ForEach-Object { ([string]$_).Split('.').Length } | Sort-Object -Unique)
                validate=$cookedRoom.harnessValid -eq 'true'; bottomOpenColumns=$openColumns
            }
        }
        $manifest.cooked = [ordered]@{
            path=(Resolve-Path -LiteralPath $cookedPath).Path
            sha256=(Get-FileHash -LiteralPath $cookedPath -Algorithm SHA256).Hash
            rooms=$cookedPool.all.room.Count; copiesAdded=[int]$cookedPool.all.copiesAdded
            changedTotal=[int]$cookedPool.all.changedTotal; roomChecks=$cookedChecks
        }
    }
    $manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $PSScriptRoot ('../' + $outputStem + '-manifest.json')) -Encoding utf8
    [pscustomobject]$manifest | Format-List
}
finally {
    if ($null -ne $instance -and -not $instance.HasExited) { Stop-Process -Id $instance.Id }
}
