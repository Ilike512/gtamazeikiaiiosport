param([Parameter(Mandatory)][string] $Tiles)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$gridFile = Join-Path $PSScriptRoot '../data/city/elevation.json'
$grid = Get-Content -LiteralPath $gridFile -Raw | ConvertFrom-Json
$images = @{}
foreach ($x in 2301,2302) {
  foreach ($y in 1269,1270) {
    $path = (Resolve-Path -LiteralPath (Join-Path $Tiles "$x-$y.png")).Path
    $images["$x-$y"] = [System.Drawing.Bitmap]::new($path)
  }
}

function Read-Terrarium([double] $east, [double] $south) {
  $pi = [Math]::PI
  $longitudeScale = 111319.49 * [Math]::Cos(56.3066 * $pi / 180.0)
  $longitude = 22.3320 + $east / $longitudeScale
  $latitude = (56.3066 - $south / 111319.49) * $pi / 180.0
  $x = ($longitude + 180.0) / 360.0 * 4096.0
  $latitudeTangent = [Math]::Tan($latitude)
  $y = (1.0 - [Math]::Log($latitudeTangent + [Math]::Sqrt(1 + $latitudeTangent * $latitudeTangent)) / $pi) * 2048.0
  $i = [int][Math]::Floor($x)
  $j = [int][Math]::Floor($y)
  $color = $images["$i-$j"].GetPixel([Math]::Min(255,[int][Math]::Floor(($x-$i)*256)), [Math]::Min(255,[int][Math]::Floor(($y-$j)*256)))
  return $color.R * 256.0 + $color.G + $color.B / 256.0 - 32768.0 - $grid.datum
}

try {
  $edge = $grid.origin[1] + ($grid.height - 1) * $grid.step
  $before = [double[]]$grid.samples
  $result = [System.Collections.Generic.List[double]]::new($before)
  $rows = [int][Math]::Ceiling((5900.0 - $edge) / $grid.step)
  for ($row=1; $row -le $rows; $row++) {
    $south = $edge + $row * $grid.step
    $blend = [Math]::Min(1.0, $row / 18.0)
    for ($column=0; $column -lt $grid.width; $column++) {
      $east = $grid.origin[0] + $column * $grid.step
      $old = $before[($grid.height - 1) * $grid.width + $column]
      $new = Read-Terrarium $east $south
      $result.Add([Math]::Round($old + ($new - $old) * $blend, 2))
    }
  }
  $grid.height += $rows
  $grid.sources += 'AWS Terrain Tiles, Terrarium z12'
  $grid.samples = $result
  $grid | ConvertTo-Json -Compress -Depth 5 | Set-Content -LiteralPath $gridFile -Encoding utf8
} finally {
  foreach ($image in $images.Values) { $image.Dispose() }
}

