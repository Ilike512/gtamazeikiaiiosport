param(
  [string] $ProjectPath = (Split-Path $PSScriptRoot -Parent),
  [string] $AudioSourcePath = $ProjectPath
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$source = (Resolve-Path -LiteralPath $AudioSourcePath).Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$bundle = Join-Path $project 'assets/bundled_audio'
$null = [IO.Directory]::CreateDirectory($bundle)
$want = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$formats = @('.mp3', '.ogg', '.wav')
$stations = Join-Path $source 'Radio Music'
$audio = @(if (Test-Path -LiteralPath $stations) {
  Get-ChildItem -LiteralPath $stations -Directory | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -File -Recurse | Where-Object Extension -In $formats
  }
})
foreach ($name in 'studio_start','loading') {
  $sound = Join-Path $source 'Custom Assets/sound'
  $audio += @(Get-ChildItem -LiteralPath $sound -File -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -eq $name -and $_.Extension -in $formats })
}
foreach ($entry in $audio) {
  $relative = $entry.FullName.Substring($source.Length + 1)
  $destination = Join-Path $bundle "$relative.audio"
  $null = $want.Add($destination)
  $null = [IO.Directory]::CreateDirectory((Split-Path $destination))
  Copy-Item -LiteralPath $entry.FullName -Destination $destination -Force
}
foreach ($existing in Get-ChildItem -LiteralPath $bundle -File -Recurse -Filter '*.audio') {
  if (-not $want.Contains($existing.FullName)) {
    Remove-Item -LiteralPath $existing.FullName
  }
}
"Staged $($want.Count) supplied audio files for mobile exports."

