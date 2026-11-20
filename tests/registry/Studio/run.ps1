param(
    [ValidateSet('Lookup', 'RequireForms', 'Matrix')]
    [string] $Suite = 'Lookup',

    [string] $StudioExecutable,

    [ValidateRange(1, 3600)]
    [int] $TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'

if (-not $StudioExecutable) {
    $versions = Join-Path $env:LOCALAPPDATA 'Roblox/Versions'
    $StudioExecutable = Get-ChildItem -LiteralPath $versions -Filter RobloxStudioBeta.exe -Recurse |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $StudioExecutable) {
    throw 'Roblox Studio was not found. Pass -StudioExecutable with its full path.'
}
$studio = (Resolve-Path -LiteralPath $StudioExecutable).Path
$testRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $testRoot)
$case = @{
    Lookup = @{ Script = 'Studio/run-lookup.lua'; Marker = 'REGISTRY_LOOKUP_OK' }
    RequireForms = @{ Script = 'Benchmark/run-require-forms.lua'; Marker = 'REQUIRE_FORMS_OK' }
    Matrix = @{ Script = 'Studio/run-matrix.lua'; Marker = 'REGISTRY_MATRIX_OK' }
}[$Suite]

$runId = [guid]::NewGuid().ToString('N')
$runDirectory = Join-Path $repoRoot "build/studio-runner/$Suite-$runId"
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$place = Join-Path $runDirectory 'Registry.rbxlx'
$log = Join-Path $runDirectory 'studio.log'
$script = (Resolve-Path -LiteralPath (Join-Path $testRoot $case.Script)).Path
& python (Join-Path $PSScriptRoot 'build.py') $runDirectory
if ($LASTEXITCODE -ne 0) { throw 'Studio test asset generation failed.' }

$arguments = '--task RunScript --localPlaceFile "{0}" --runScriptFile "{1}" --outputFile "{2}" --quitAfterExecution' -f $place, $script, $log
Write-Output "Running $Suite in Studio. Log: $log"
$process = Start-Process -FilePath $studio -ArgumentList $arguments -WindowStyle Hidden -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
while (-not $process.WaitForExit(1000)) {
    if ([DateTime]::UtcNow -ge $deadline) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        throw "Studio exceeded ${TimeoutSeconds}s. See $log"
    }
}
if (-not (Test-Path -LiteralPath $log) -or
    -not (Select-String -LiteralPath $log -Pattern ('^' + [regex]::Escape($case.Marker) + '$') -Quiet)) {
    if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 15 }
    throw "Studio did not report success. See $log"
}
Write-Output "Passed $Suite. Log: $log"
