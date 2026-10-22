param(
    [ValidateSet('all', 'arm64-v8a', 'x86_64')][string]$Abi = 'all',
    [string]$DownloadDirectory = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../android/office-runtime'))
if (!$DownloadDirectory) { $DownloadDirectory = Join-Path $runtimeRoot 'downloads' }
New-Item -ItemType Directory -Force -Path $DownloadDirectory | Out-Null
$artifacts = @(
    @{ Abi='arm64-v8a'; Code=131; Sha='751AC3836890B79A56801BF6D9A2788CDA3761AB5131A4F0B6ABFBAD822BB475'; Cache='libreoffice-arm64.apk' },
    @{ Abi='x86_64'; Code=129; Sha='CFAF9EEA5FD695C449E92EB10CC0B1617EC51D068345068CEA9B7E1C67968DF5'; Cache='libreoffice-x86_64.apk' }
)
foreach ($artifact in $artifacts) {
    if ($Abi -ne 'all' -and $Abi -ne $artifact.Abi) { continue }
    $apkPath = Join-Path $DownloadDirectory $artifact.Cache
    if (!(Test-Path -LiteralPath $apkPath)) {
        Invoke-WebRequest -Uri "https://f-droid.org/repo/org.documentfoundation.libreoffice_$($artifact.Code).apk" -OutFile "$apkPath.part"
        Move-Item -LiteralPath "$apkPath.part" -Destination $apkPath -Force
    }
    if ((Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash -ne $artifact.Sha) { throw "LibreOffice APK checksum mismatch: $($artifact.Abi)" }
    $archive = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
    try {
        foreach ($entry in $archive.Entries) {
            $relative = $null
            if ($entry.FullName.StartsWith("lib/$($artifact.Abi)/")) {
                $relative = 'jniLibs/' + $entry.FullName.Substring(4)
            } elseif ($entry.FullName.StartsWith('assets/') -and !$entry.FullName.StartsWith('assets/dexopt/')) {
                $relative = $entry.FullName
            }
            if (!$relative -or $entry.FullName.EndsWith('/')) { continue }
            $destination = [System.IO.Path]::GetFullPath((Join-Path $runtimeRoot $relative))
            if (!$destination.StartsWith($runtimeRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid runtime entry' }
            New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($destination)) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        }
    } finally { $archive.Dispose() }
    Write-Output "Prepared LibreOffice 26.2.6.3 for $($artifact.Abi)"
}
