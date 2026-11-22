param([Parameter(Mandatory)][string] $Tiles)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$gridPath = Join-Path $PSScriptRoot '../data/city/elevation.json'
$grid = Get-Content -LiteralPath $gridPath -Raw | ConvertFrom-Json
$west = -13064
$north = -14490
$columns = [int](($grid.origin[0] - $west) / $grid.step)
$rows = [int](($grid.origin[1] - $north) / $grid.step)
if ($columns -eq 0 -and $rows -eq 0) { return }
if ($columns -lt 0 -or $rows -lt 0) { throw 'The input grid already extends past the target origin.' }
$width = $grid.width + $columns
$height = $grid.height + $rows
$new = [double[]]::new($width * $height)
$tilesById = @{}
$pi = [Math]::PI
$longitudeScale = 111319.49 * [Math]::Cos(56.3066 * $pi / 180.0)
$pixels = 4096 * 256
$xCoordinates = [int[]]::new($width)
for ($x = 0; $x -lt $width; $x++) {
  $lon = 22.3320 + ($west + $x * $grid.step) / $longitudeScale
  $xCoordinates[$x] = [int][Math]::Floor(($lon + 180.0) / 360.0 * $pixels)
}
try {
  foreach ($x in 2299..2302) {
    foreach ($y in 1266..1270) {
      $path = (Resolve-Path -LiteralPath (Join-Path $Tiles "$x-$y.png")).Path
      $tilesById["$x-$y"] = [System.Drawing.Bitmap]::new($path)
    }
  }
  for ($z = 0; $z -lt $height; $z++) {
    $lat = (56.3066 - ($north + $z * $grid.step) / 111319.49) * $pi / 180.0
    $latTangent = [Math]::Tan($lat)
    $pixelY = [int][Math]::Floor((1 - [Math]::Log($latTangent + [Math]::Sqrt(1 + $latTangent * $latTangent)) / $pi) * $pixels * 0.5)
    $tileY = $pixelY -shr 8
    $rowStart = $z * $width
    $oldRow = [Math]::Max(0, $z - $rows) * $grid.width
    for ($x = 0; $x -lt $width; $x++) {
      $old = $grid.samples[$oldRow + [Math]::Max(0, $x - $columns)]
      if ($x -ge $columns -and $z -ge $rows) {
        $new[$rowStart + $x] = $old
        continue
      }
      $pixelX = $xCoordinates[$x]
      $tileX = $pixelX -shr 8
      $color = $tilesById["$tileX-$tileY"].GetPixel($pixelX -band 255, $pixelY -band 255)
      $measured = $color.R * 256.0 + $color.G + $color.B / 256.0 - 32768.0 - $grid.datum
      $blend = [Math]::Min(1.0, [Math]::Max($columns - $x, $rows - $z) / 13.0)
      $new[$rowStart + $x] = [Math]::Round($old + ($measured - $old) * $blend, 2)
    }
  }
  $grid.origin = @($west, $north)
  $grid.width = $width
  $grid.height = $height
  $grid.samples = $new
  $grid | ConvertTo-Json -Compress -Depth 5 | Set-Content -LiteralPath $gridPath -Encoding utf8
} finally {
  foreach ($image in $tilesById.Values) { $image.Dispose() }
}
