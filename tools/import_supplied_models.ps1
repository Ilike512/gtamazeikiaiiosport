param([string]$Downloads = (Join-Path $env:USERPROFILE 'Downloads'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$project = Split-Path -Parent $PSScriptRoot
$models = Join-Path $project 'assets/models/supplied'
$manifest = @(
    @{ archive = 'low-poly-metal-shelf'; source = 'Shelf.glb'; model = 'metal_shelf.glb' },
    @{ archive = 'beer-bottle-psx'; source = 'bottle.glb'; model = 'beer_bottle.glb' },
    @{ archive = 'paulsvids-henry'; source = 'PaulsVids Henry.glb'; model = 'henry_engine.glb' },
    @{ archive = 'blitzo-character-design'; source = 'Blitzo character design.fbx'; model = 'blitzo.fbx'; textures = $true },
    @{ archive = 'psx-backroom'; source = 'Backroom.fbx'; model = 'backroom.fbx'; textures = $true },
    @{ archive = 'psx-vending-machine'; source = 'cocacola vending machine.fbx'; model = 'vending_machine.fbx'; textures = $true },
    @{ archive = 'henry-stickmin'; source = 'Desktop.rar'; model = 'henry.fbx'; textures = $true }
)

function Copy-Entry($Entry, $Destination) {
    if ($null -eq $Entry) { throw "A required archive entry for $Destination is missing." }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($Entry, $Destination, $true)
}

foreach ($asset in $manifest) {
    $zipPath = Join-Path $Downloads ($asset.archive + '.zip')
    $destination = Join-Path $models $asset.archive
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $model = $zip.GetEntry('source/' + $asset.source)
        if ($asset.source -eq 'Desktop.rar') {
            $temp = Join-Path $destination 'Desktop.rar'
            Copy-Entry $model $temp
            & tar.exe -xf $temp -C $destination -- hs.fbx
            if ($LASTEXITCODE -ne 0) { throw 'Could not extract the Henry Stickmin FBX.' }
            Move-Item -LiteralPath (Join-Path $destination 'hs.fbx') -Destination (Join-Path $destination $asset.model) -Force
            Remove-Item -LiteralPath $temp
        } else {
            Copy-Entry $model (Join-Path $destination $asset.model)
        }
        if ($asset.textures) {
            foreach ($texture in $zip.Entries | Where-Object FullName -Match '^textures/[^/\\]+\.(png|jpg|jpeg)$') {
                Copy-Entry $texture (Join-Path $destination $texture.Name)
            }
        }
    } finally {
        $zip.Dispose()
    }
}

