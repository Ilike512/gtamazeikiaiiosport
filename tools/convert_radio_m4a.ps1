# Run with Windows PowerShell 5.1. Original M4A files are preserved.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
$null = [Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime]
$null = [Windows.Media.Transcoding.PrepareTranscodeResult, Windows.Media.Transcoding, ContentType = WindowsRuntime]
$extensions = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object Name -eq AsTask
$asOperation = $extensions | Where-Object { $_.IsGenericMethod -and $_.GetGenericArguments().Length -eq 1 -and $_.GetParameters().Length -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq ('IAsyncOperation' + [char]96 + '1') } | Select-Object -First 1
$asProgressAction = $extensions | Where-Object { $_.IsGenericMethod -and $_.GetGenericArguments().Length -eq 1 -and $_.GetParameters().Length -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq ('IAsyncActionWithProgress' + [char]96 + '1') } | Select-Object -First 1

function Wait-WinRT($Operation, [type]$ResultType) {
    $task = $asOperation.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult()
}

$root = Join-Path (Split-Path -Parent $PSScriptRoot) 'Radio Music'
$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav([Windows.Media.MediaProperties.AudioEncodingQuality]::Medium)
$transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
foreach ($entry in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.m4a') {
    $targetName = $entry.BaseName + '.wav'
    $target = Join-Path $entry.DirectoryName $targetName
    if (Test-Path -LiteralPath $target) { continue }
    $source = Wait-WinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($entry.FullName)) ([Windows.Storage.StorageFile])
    $folder = Wait-WinRT ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($entry.DirectoryName)) ([Windows.Storage.StorageFolder])
    $temporary = Wait-WinRT ($folder.CreateFileAsync($targetName + '.tmp', [Windows.Storage.CreationCollisionOption]::GenerateUniqueName)) ([Windows.Storage.StorageFile])
    try {
        $job = Wait-WinRT ($transcoder.PrepareFileTranscodeAsync($source, $temporary, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
        if (-not $job.CanTranscode) { throw "Windows could not decode $($entry.Name): $($job.FailureReason)." }
        $task = $asProgressAction.MakeGenericMethod([double]).Invoke($null, @($job.TranscodeAsync()))
        $null = $task.GetAwaiter().GetResult()
        Move-Item -LiteralPath $temporary.Path -Destination $target
    } finally {
        if (Test-Path -LiteralPath $temporary.Path) { Remove-Item -LiteralPath $temporary.Path }
    }
    Write-Output "Converted $($entry.Directory.Name)/$($entry.Name) to WAV."
}

